use Test2::V0;

use File::Temp qw/tempfile/;

use App::ccu::CPANfile;

subtest 'load' => sub {
    my $cpanfile_fh = File::Temp->new;
    my $snapshot_fh = File::Temp->new;
    print {$cpanfile_fh} <<'...';
requires 'Carp', '1.50';
requires 'Config'; # core-module and non dual-life
requires 'Foo';

on develop => sub {
    recommends 'Baz';
};

requires 'Foo::NotInSnapshot';
...
    print {$snapshot_fh} <<'...';
# carton snapshot format: version 1.0
DISTRIBUTIONS
  Carp-1.50
    pathname: X/XS/XSAWYERX/Carp-1.50.tar.gz
    provides:
      Carp 1.50
      Carp::Heavy 1.50
    requirements:
      Config 0
      Exporter 0
      ExtUtils::MakeMaker 0
      IPC::Open3 1.0103
      Test::More 0.47
      overload 0
      strict 0
      warnings 0
  FooBar-0.01
    pathname: F/FO/FOO/FooBar-0.01.tar.gz
    provides:
      Foo 0.01
  Baz-0.01
    pathname: B/BA/BAZ/Baz-0.01.tar.gz
    provides:
      Baz 0.01
...
    close $cpanfile_fh;
    close $snapshot_fh;

    is +App::ccu::CPANfile->load($cpanfile_fh->filename, $snapshot_fh->filename), {
        Carp => {
            module         => 'Carp',
            dist           => 'Carp',
            version        => '1.50',
            author_release => 'XSAWYERX/Carp-1.50',
            phase          => 'runtime',
            relationship   => 'requires',
            version_range  => '1.50',
        },
        Config => {
            module         => 'Config',
            dist           => undef,
            version        => E, # taken from Module::CoreList
            author_release => undef,
            phase          => 'runtime',
            relationship   => 'requires',
            version_range  => '0',
        },
        Foo  => {
            module         => 'Foo',
            dist           => 'FooBar',
            version        => '0.01',
            author_release => 'FOO/FooBar-0.01',
            phase          => 'runtime',
            relationship   => 'requires',
            version_range  => '0',
        },
        Baz  => {
            module         => 'Baz',
            dist           => 'Baz',
            version        => '0.01',
            author_release => 'BAZ/Baz-0.01',
            phase          => 'develop',
            relationship   => 'recommends',
            version_range  => '0',
        },
    };
};

done_testing;