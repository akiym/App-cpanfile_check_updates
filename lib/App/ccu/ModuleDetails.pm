package App::ccu::ModuleDetails;
use strict;
use warnings;

use CPAN::Audit::DB;
use CPAN::Audit::Version;
use URI;

use App::ccu::ChangesParser;
use App::ccu::MetaCPAN;

use Class::Tiny {
    audit_db      => sub { CPAN::Audit::DB->db },
    audit_version => sub { CPAN::Audit::Version->new },
    metacpan      => sub { App::ccu::MetaCPAN->new },
};

sub show {
    my ($self, $module, $release) = @_;

    my $source_author_release = $module->{author_release} ||
        $self->metacpan->author_release($module->{module}, $module->{version});
    my $target_author_release = $release->cpanid . '/' . $release->distvname;

    printf "## %s\n", $module->{module};
    printf "[`%s` -> `%s`](%s)\n", $module->{version}, $release->version, $self->metacpan->diff_file_url($source_author_release, $target_author_release);

    $self->print_advisory($release->dist, $module->{version});
    $self->print_changes($target_author_release, $module->{version}, $release->version);
}

sub print_advisory {
    my ($self, $dist, $version) = @_;

    my $db = $self->audit_db->{dists}{$dist}
        or return;

    my @affected_advisories =
        grep { $self->audit_version->in_range($version, $_->{affected_versions}) }
            @{$db->{advisories}};

    return unless @affected_advisories;

    printf "### :warning: Affected security updates\n";
    for my $advisory (@affected_advisories) {
        my $description = $advisory->{description};
        $description =~ s/\s+$//;
        $description =~ s/\s+/ /g;
        my $cves = '';
        if (exists $advisory->{cves}) {
            $cves = join(', ', @{$advisory->{cves}}) . ': ';
        }
        printf "- %s%s\n", $cves, $description;
        if (exists $advisory->{references}) {
            printf "  - %s\n", $_ for @{$advisory->{references}};
        }
    }
}

sub print_changes {
    my ($self, $author_release, $version, $latest_version) = @_;

    my $release = $self->metacpan->release($author_release);
    my $changes_text = $self->metacpan->changes($author_release);
    my $changes = eval { App::ccu::ChangesParser->parse($changes_text) }
        or return;

    my @changelogs;
    my $skip = 1;
    for my $changelog (reverse @{$changes->{releases}}) {
        my $v = $changelog->{version};
        if ($v eq $latest_version) {
            $skip = 0;
        } elsif ($v eq $version) {
            last;
        }
        unless ($skip) {
            push @changelogs, App::ccu::ChangesParser->filter_release_changes($changelog, $release);
        }
    }

    return unless @changelogs;

    printf "### Changes\n";

    my $collapse = $self->count_changes_line(@changelogs) > 10;

    print "<details>\n" if $collapse;

    my $first = 1;
    for my $changelog (@changelogs) {
        print "<summary>\n" if $collapse && $first;
        printf "#### %s: %s\n", $changelog->{version}, $changelog->{date} || '';
        for my $entry (@{$changelog->{entries}}) {
            $self->_print_entry($entry, 0);
        }
        print "</summary>\n" if $collapse && $first;
        $first = 0;
    }

    print "</details>\n" if $collapse;

}

sub _print_entry {
    my ($self, $entry, $level) = @_;

    printf "%s- %s\n", '  ' x $level, $entry->{text};
    for my $e (@{$entry->{entries}}) {
        $self->_print_entry($e, $level + 1);
    }
}

sub count_changes_line {
    my ($self, @entries) = @_;

    my $count = 0;
    for my $entry (@entries) {
        $count += 1 + $self->count_changes_line(@{$entry->{entries}});
    }
    return $count;
}

1;
