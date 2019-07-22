package App::ccu;
use strict;
use warnings;

use Module::CPANfile::Writer;

use App::ccu::CPANfile;
use App::ccu::ModuleDetails;
use App::ccu::PAUSEPackages;

use Class::Tiny {
    cpanfile       => 'cpanfile',
    snapshot       => 'cpanfile.snapshot',
    phase          => undef,
    relationship   => undef,
    module_details => sub { App::ccu::ModuleDetails->new },
    pause_packages => sub { App::ccu::PAUSEPackages->new },
};

our $VERSION = "0.01";
our ($GIT_DESCRIBE, $GIT_URL);

sub run {
    my ($self, @modules) = @_;

    # TODO: check outdated modules in cpanfile.snapshot

    my $modules = App::ccu::CPANfile->load(
        $self->cpanfile,
        $self->snapshot,
    );
    my $writer = Module::CPANfile::Writer->new($self->cpanfile);

    for my $module_name (sort keys %$modules) {
        my $module = $modules->{$module_name};

        next if $self->phase && $self->phase ne $module->{phase};
        next if $self->relationship && $self->relationship ne $module->{relationship};
        next if @modules && not grep { $_ eq $module_name } @modules;

        my $release = $self->pause_packages->find_release($module->{dist}, $module_name);
        next unless $release;
        next unless App::ccu::Version->in_range($release->version, $module->{version_range});
        next if $release->dist eq 'perl';

        if ($release && $release->version ne $module->{version}) {
            $self->module_details->show($module, {
                dist           => $release->dist,
                version        => $release->version,
                author_release => $release->cpanid . '/' . $release->distvname,
            });
            $writer->add_prereq($module_name, $release->version, relationship => $self->relationship);
        }
    }

    $writer->save($self->cpanfile);
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

