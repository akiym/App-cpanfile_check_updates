package App::ccu;
use strict;
use warnings;

use App::CpanfileSlipstop::Writer;
use CPAN::DistnameInfo;
use HTTP::Tinyish;
use IO::Uncompress::Gunzip qw/$GunzipError/;

use App::ccu::CPANfile;
use App::ccu::ModuleDetails;

use Class::Tiny {
    cpanfile       => 'cpanfile',
    snapshot       => 'cpanfile.snapshot',
    phase          => undef,
    relationship   => undef,
    interactive    => undef,
    module_details => sub { App::ccu::ModuleDetails->new },
    releases       => sub { $_[0]->_build_releases },
};

our $VERSION = "0.01";
our ($GIT_DESCRIBE, $GIT_URL);

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

sub run {
    my $self = shift;

    # TODO: check outdated modules in cpanfile.snapshot

    my $modules = App::ccu::CPANfile->load(
        $self->cpanfile,
        $self->snapshot,
    );

    my %updated_modules;
    for my $module_name (sort keys %$modules) {
        my $module = $modules->{$module_name};

        next if $self->phase && $self->phase ne $module->{phase};
        next if $self->relationship && $self->relationship ne $module->{relationship};

        my $release = $self->find_release($module->{dist}, $module_name);
        next unless $release;
        next if $release->dist eq 'perl';

        if ($release && $release->version ne $module->{version}) {
            $updated_modules{$module_name} = $release->version;
            $self->module_details->show($module, $release);
        }
    }

    if (%updated_modules) {
        my $writer = App::CpanfileSlipstop::Writer->new(
            cpanfile_path => $self->cpanfile,
        );
        $writer->set_versions(sub {
            my $module = shift;
            return $updated_modules{$module};
        }, sub {});
    }
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
__END__

=encoding utf-8

=head1 NAME

App::ccu - Update newer versions of module from cpanfile and cpanfile.snapshot

=head1 SYNOPSIS

    % cpanfile-check-updates

=head1 DESCRIPTION

App::ccu is ...

=head1 LICENSE

Copyright (C) Takumi Akiyama.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Takumi Akiyama E<lt>t.akiym@gmail.comE<gt>

=cut

