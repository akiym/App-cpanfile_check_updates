package MyFatPacker;
use strict;
use warnings;

use App::cpm::CLI;
use App::FatPacker::Simple;
use Carton::Snapshot;
use Config;
use CPAN::Meta::Requirements;
use File::Path qw/remove_tree/;
use Getopt::Long ();
use Path::Tiny ();

# Original code was taken from App::cpm
# https://github.com/skaji/cpm/blob/8952cc77fe4bc2d29690473e0692309fa8f03864/author/fatpack.pl

=for hint

Show new dependencies

    git diff cpanfile-check-updates | perl -nle 'print $1 if /^\+\$fatpacked\{"([^"]+)/'

=cut

sub new {
    my ($class, %args) = @_;
    return bless {
        release_version => $ENV{CPAN_RELEASE_VERSION},
        target          => '5.8.1',
        exclude         => [],
        extra           => [],
        %args,
    }, $class;
}

sub run {
    my ($self, @argv) = @_;

    my $p = Getopt::Long::Parser->new;
    my $parsed = $p->getoptionsfromarray(
        \@argv,
        "f|force"     => \my $force,
        "t|test"      => \my $test,
        "update-only" => \my $update_only,
    );
    if (!$parsed) {
        return 1;
    }

    my ($git_describe, $git_url);
    if (my $version = $self->{release_version}) {
        $git_describe = $version;
        $git_url = "$self->{github_url}/tree/$version";
    } else {
        ($git_describe, $git_url) = $self->git_info;
    }
    warn "\e[1;31m!!! GIT IS DIRTY !!!\e[m\n" if !$update_only && $git_describe =~ /dirty/;

    my $shebang = <<"___";
#!/usr/bin/env perl
use $self->{target};
___

    my $resolver = -f "cpanfile.snapshot" && !$force && !$test && !$update_only ? "snapshot" : "metadb";

    warn "Resolver: $resolver\n";
    cpm("install", "--target-perl", $self->{target}, "--resolver", $resolver);
    cpm("install", "--target-perl", $self->{target}, "--resolver", $resolver, @{$self->{extra}});
    $self->gen_snapshot if !$test;
    $self->remove_version_xs;
    exit if $update_only;

    print STDERR "FatPacking...";

    my $fatpack_dir = $test ? "local" : "../lib,local";
    my $output = $test ? "../$self->{fatpacked_script}.test" : "../$self->{fatpacked_script}";
    fatpack("-q", "-o", $output, "-d", $fatpack_dir, "-e", join(',', @{$self->{exclude}}), "--shebang", $shebang, "../$self->{script}", "--cache", ".cache");
    print STDERR " DONE\n";
    $self->inject_git_info($output, $git_describe, $git_url);
    chmod 0755, $output;

}

sub cpm {
    App::cpm::CLI->new->run(@_) == 0 or die
}

sub fatpack {
    App::FatPacker::Simple->new->parse_options(@_)->run
}

sub remove_version_xs {
    my $self = shift;
    my $arch = $Config{archname};
    my $file = "local/lib/perl5/$arch/version/vxs.pm";
    my $dir  = "local/lib/perl5/$arch/auto/version";
    unlink $file if -f $file;
    remove_tree($dir) if -d $dir;
}

sub gen_snapshot {
    my $self = shift;
    my $snapshot = Carton::Snapshot->new(path => "cpanfile.snapshot");
    my $no_exclude = CPAN::Meta::Requirements->new;
    $snapshot->find_installs("local", $no_exclude);
    $snapshot->save;
}

sub git_info {
    my $self = shift;
    my $describe = `git describe --tags --dirty` || 'no tags';
    chomp $describe;
    my $hash = `git rev-parse --short HEAD`;
    chomp $hash;
    my $url = "$self->{github_url}/tree/$hash";
    ($describe, $url);
}

sub inject_git_info {
    my ($self, $file, $describe, $url) = @_;
    my $inject = <<"...";
use $self->{package};
\$$self->{package}::GIT_DESCRIBE = '$describe';
\$$self->{package}::GIT_URL = '$url';
...
    my $content = Path::Tiny->new($file)->slurp_raw;
    $content =~ s/^use $self->{cli_package};/$inject\nuse $self->{cli_package};/sm;
    Path::Tiny->new($file)->spew_raw($content);
}

1;