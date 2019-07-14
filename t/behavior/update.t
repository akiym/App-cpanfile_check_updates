use Test2::V0;

use File::Spec;
use File::Temp;

use App::ccu::CLI;

my $tmpdir = File::Temp->newdir;
my $cpanfile = File::Spec->catfile($tmpdir, 'cpanfile');
my $snapshot = File::Spec->catfile($tmpdir, 'cpanfile.snapshot');
{
    open my $fh, '>', $cpanfile or die $!;
    print {$fh} <<'...';
requires 'A';
requires 'AA';
requires 'Version', '0.10';
requires 'Latest';
requires 'NotInSnapshot';
...
}
{
    open my $fh, '>', $snapshot or die $!;
    print {$fh} <<'...';
# carton snapshot format: version 1.0
DISTRIBUTIONS
  A-0.01
    pathname: F/FO/FOO/A-0.01.tar.gz
    provides:
      A 0.01
      AA undef
  Version-0.10
    pathname: F/FO/FOO/Version-0.10.tar.gz
    provides:
      Version 0.10
  Latest-0.01
    pathname: F/FO/FOO/Latest-0.01.tar.gz
    provides:
      Latest 0.01
...
}

my $module_details = mock {} => (track => 1);

my %module2release = (
    A       => CPAN::DistnameInfo->new('F/FO/FOO/A-0.02.tar.gz'),
    AA      => CPAN::DistnameInfo->new('F/FO/FOO/A-0.02.tar.gz'),
    Version => CPAN::DistnameInfo->new('F/FO/FOO/Version-0.20.tar.gz'),
    Latest  => CPAN::DistnameInfo->new('F/FO/FOO/Latest-0.01.tar.gz'),
);
my $pause_packages = mock {} => (
    add => [
        find_release => sub {
            my ($self, $dist, $module) = @_;
            return $module2release{$module};
        },
    ],
);

App::ccu->new(
    cpanfile       => $cpanfile,
    snapshot       => $snapshot,
    module_details => $module_details,
    pause_packages => $pause_packages,
)->run;

subtest 'module details is shown' => sub {
    my ($module_details_mock) = mocked $module_details;
    is $module_details_mock->call_tracking, [
        {
            sub_name => 'show',
            sub_ref  => E,
            args     => [
                E,
                {
                    module         => 'A',
                    dist           => 'A',
                    version        => '0.01',
                    author_release => 'FOO/A-0.01',
                    phase          => 'runtime',
                    relationship   => 'requires',
                    version_range  => 0,
                },
                {
                    dist           => 'A',
                    version        => '0.02',
                    author_release => 'FOO/A-0.02',
                },
            ],
        },
        {
            sub_name => 'show',
            sub_ref  => E,
            args     => [
                E,
                {
                    module         => 'AA',
                    dist           => 'A',
                    version        => '0.01',
                    author_release => 'FOO/A-0.01',
                    phase          => 'runtime',
                    relationship   => 'requires',
                    version_range  => 0,
                },
                {
                    dist           => 'A',
                    version        => '0.02',
                    author_release => 'FOO/A-0.02',
                },
            ],
        },
        {
            sub_name => 'show',
            sub_ref  => E,
            args     => [
                E,
                {
                    module         => 'Version',
                    dist           => 'Version',
                    version        => '0.10',
                    author_release => 'FOO/Version-0.10',
                    phase          => 'runtime',
                    relationship   => 'requires',
                    version_range  => '0.10',
                },
                {
                    dist           => 'Version',
                    version        => '0.20',
                    author_release => 'FOO/Version-0.20',
                },
            ],
        },
    ];
};

subtest 'cpanfile is updated' => sub {
    my $cpanfile_src = do {
        open my $fh, '<', $cpanfile or die $!;
        local $/; <$fh>;
    };
    is $cpanfile_src, <<'...';
requires 'A', '0.02';
requires 'AA', '0.02';
requires 'Version', '0.20';
requires 'Latest';
requires 'NotInSnapshot';
...
};

done_testing;