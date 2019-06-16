package App::ccu::CPANfile;
use strict;
use warnings;

use Carton::Snapshot;
use CPAN::DistnameInfo;
use Module::CPANfile;

sub load {
    my ($class, $cpanfile, $snapshot) = @_;

    $cpanfile = Module::CPANfile->load($cpanfile);
    $snapshot = Carton::Snapshot->new(path => $snapshot);
    $snapshot->load;

    my %modules;
    my $prereqs = $cpanfile->prereqs->as_string_hash;
    for my $phase (keys %$prereqs) {
        for my $relationship (keys %{$prereqs->{$phase}}) {
            for my $module (keys %{$prereqs->{$phase}{$relationship}}) {
                next if $module eq 'perl';

                my $dist = $snapshot->find_or_core($module) or next;
                if ($dist->is_core) {
                    $modules{$module} = {
                        module         => $module,
                        dist           => undef,
                        version        => $dist->version_for,
                        author_release => undef,
                        phase          => $phase,
                        relationship   => $relationship,
                    };
                } else {
                    my $di = CPAN::DistnameInfo->new($dist->pathname);
                    $modules{$module} = {
                        module         => $module,
                        dist           => $di->dist,
                        version        => $di->version,
                        author_release => $di->cpanid . '/' . $di->distvname,
                        phase          => $phase,
                        relationship   => $relationship,
                    };
                }
            }
        }
    }

    return \%modules;
}

1;