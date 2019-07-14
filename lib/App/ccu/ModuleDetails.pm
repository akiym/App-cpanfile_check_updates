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

    print "### Changes\n";

    my $collapse = $self->count_entries(@changelogs) > 10;

    print "<details>\n" if $collapse;

    my $first = 1;
    for my $i (0..$#changelogs) {
        my $changelog = $changelogs[$i];

        print "<summary>\n" if $collapse && $first;
        printf "#### %s: %s\n", $changelog->{version}, $changelog->{date} || '';
        my @entries = $self->expand_entries(@{$changelog->{entries}});
        for my $j (0..$#entries) {
            my $entry = $entries[$j];

            printf "%s- %s\n", '  ' x $entry->[0], $entry->[1];
            # if changes cannot be parse correctly, omit the last too long entry
            if ($i == $#changelogs && $j + 1 >= 10) {
                printf "...\n";
                last;
            }
        }
        print "</summary>\n" if $collapse && $first;
        $first = 0;
    }

    print "</details>\n" if $collapse;

}

sub expand_entries {
    my ($self, @entries) = @_;

    my @expanded;
    for my $entry (@entries) {
        push @expanded, [0, $entry->{text}];
        push @expanded, map { [$_->[0] + 1, $_->[1]] } $self->expand_entries(@{$entry->{entries}});
    }
    return @expanded;
}

sub count_entries {
    my ($self, @entries) = @_;

    my $count = 0;
    for my $entry (@entries) {
        $count += 1 + $self->count_entries(@{$entry->{entries}});
    }
    return $count;
}

1;
