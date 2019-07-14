package App::ccu::PAUSEPackages;
use strict;
use warnings;

use CPAN::DistnameInfo;
use HTTP::Tinyish;
use IO::Uncompress::Gunzip qw/$GunzipError/;

use Class::Tiny {
    releases => sub { $_[0]->_build_releases },
};

sub _build_releases {
    my $self = shift;

    my %releases;
    my $inheader = 1;
    my $z = $self->_fetch_packages;
    while (defined(my $line = $z->getline)) {
        if ($line =~ /^$/ && $inheader) {
            $inheader = 0;
            next;
        }
        next if $inheader;

        my ($module, $version, $path) = split(/\s+/, $line);
        my $di = CPAN::DistnameInfo->new($path);
        if ($di && defined $di->dist && defined $di->version) {
            if (!exists $releases{$di->dist}) {
                $releases{$di->dist} = {
                    distinfo => $di,
                    modules  => [],
                };
            } elsif ($releases{$di->dist}->{distinfo}->version lt $di->version) {
                $releases{$di->dist}{distinfo} = $di;
            }
            push @{$releases{$di->dist}{modules}}, $module;
        }
    }
    return \%releases;
}

sub _fetch_packages {
    my $res = HTTP::Tinyish->new->get('http://www.cpan.org/modules/02packages.details.txt.gz');
    unless ($res->{success}) {
        die "$res->{status} $res->{reason}";
    }

    my $z = IO::Uncompress::Gunzip->new(\$res->{content})
        or die "gunzip failed: $GunzipError";
    return $z;
}

sub find_release {
    my ($self, $dist, $module) = @_;

    if (defined $dist) {
        my $release = $self->releases->{$dist};
        if ($release) {
            return $release->{distinfo};
        }
    }

    my $releases = $self->releases;
    for my $release (values %$releases) {
        for my $m (@{$release->{modules}}) {
            if ($m eq $module) {
                return $release->{distinfo};
            }
        }
    }

    return undef;
}

1;
