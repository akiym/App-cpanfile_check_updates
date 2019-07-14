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
    my ($self, $source, $target) = @_;

    my $source_author_release = $source->{author_release} ||
        $self->metacpan->author_release($source->{module}, $source->{version});

    printf "## %s\n", $source->{module};
    printf "[`%s` -> `%s`](%s)\n", $source->{version}, $target->{version}, $self->_diff_file_url($source_author_release, $target->{author_release});

    $self->print_advisory($target->{dist}, $source->{version});
    $self->print_changes($target->{author_release}, $source->{version}, $target->{version});
}

sub _diff_file_url {
    my ($self, $source_author_release, $target_author_release) = @_;

    my $metacpan_diff_uri = URI->new('https://metacpan.org/diff/file');
    $metacpan_diff_uri->query_form(
        source => $source_author_release,
        target => $target_author_release,
    );
    return $metacpan_diff_uri->as_string;
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
