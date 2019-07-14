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
requires 'A1', '==0.10';
requires 'A2', '==0.10';
requires 'B1', '<=0.10';
requires 'B2', '<=0.10';
requires 'C1', '>=0.10';
requires 'C2', '>=0.10';
requires 'D1', '!=0.10';
requires 'D2', '!=0.10';
requires 'E1', '>=0.10, !=0.11';
requires 'E2', '>=0.10, !=0.11';
...
}
{
    open my $fh, '>', $snapshot or die $!;
    print {$fh} <<'...';
# carton snapshot format: version 1.0
DISTRIBUTIONS
  A1-0.01
    pathname: F/FO/FOO/A1-0.01.tar.gz
    provides:
      A1 0.01
  A2-0.01
    pathname: F/FO/FOO/A2-0.01.tar.gz
    provides:
      A1 0.01
  B1-0.01
    pathname: F/FO/FOO/B1-0.01.tar.gz
    provides:
      B1 0.01
  B2-0.01
    pathname: F/FO/FOO/B2-0.01.tar.gz
    provides:
      B2 0.01
  C1-0.01
    pathname: F/FO/FOO/C1-0.01.tar.gz
    provides:
      C1 0.01
  C2-0.01
    pathname: F/FO/FOO/C2-0.01.tar.gz
    provides:
      C2 0.01
  D1-0.01
    pathname: F/FO/FOO/D1-0.01.tar.gz
    provides:
      D1 0.01
  D2-0.01
    pathname: F/FO/FOO/D2-0.01.tar.gz
    provides:
      D2 0.01
  E1-0.01
    pathname: F/FO/FOO/E1-0.01.tar.gz
    provides:
      E1 0.01
  E2-0.01
    pathname: F/FO/FOO/E2-0.01.tar.gz
    provides:
      E2 0.01
...
}

my $module_details = mock {} => (track => 1);

my %module2release = (
    A1 => CPAN::DistnameInfo->new('F/FO/FOO/A1-0.10.tar.gz'),
    A2 => CPAN::DistnameInfo->new('F/FO/FOO/A2-0.11.tar.gz'),
    B1 => CPAN::DistnameInfo->new('F/FO/FOO/B1-0.10.tar.gz'),
    B2 => CPAN::DistnameInfo->new('F/FO/FOO/B1-0.11.tar.gz'),
    C1 => CPAN::DistnameInfo->new('F/FO/FOO/C1-0.10.tar.gz'),
    C2 => CPAN::DistnameInfo->new('F/FO/FOO/C2-0.09.tar.gz'),
    D1 => CPAN::DistnameInfo->new('F/FO/FOO/D1-0.11.tar.gz'),
    D2 => CPAN::DistnameInfo->new('F/FO/FOO/D1-0.10.tar.gz'),
    E1 => CPAN::DistnameInfo->new('F/FO/FOO/E1-0.12.tar.gz'),
    E2 => CPAN::DistnameInfo->new('F/FO/FOO/E1-0.11.tar.gz'),
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
                    module         => 'A1',
                    dist           => 'A1',
                    version        => '0.01',
                    author_release => 'FOO/A1-0.01',
                    phase          => 'runtime',
                    relationship   => 'requires',
                    version_range  => '== 0.10',
                },
                {
                    dist           => 'A1',
                    version        => '0.10',
                    author_release => 'FOO/A1-0.10',
                },
            ],
        },
        {
            sub_name => 'show',
            sub_ref  => E,
            args     => [
                E,
                {
                    module         => 'B1',
                    dist           => 'B1',
                    version        => '0.01',
                    author_release => 'FOO/B1-0.01',
                    phase          => 'runtime',
                    relationship   => 'requires',
                    version_range  => '<= 0.10',
                },
                {
                    dist           => 'B1',
                    version        => '0.10',
                    author_release => 'FOO/B1-0.10',
                },
            ],
        },
        {
            sub_name => 'show',
            sub_ref  => E,
            args     => [
                E,
                {
                    module         => 'C1',
                    dist           => 'C1',
                    version        => '0.01',
                    author_release => 'FOO/C1-0.01',
                    phase          => 'runtime',
                    relationship   => 'requires',
                    version_range  => '0.10',
                },
                {
                    dist           => 'C1',
                    version        => '0.10',
                    author_release => 'FOO/C1-0.10',
                },
            ],
        },
        {
            sub_name => 'show',
            sub_ref  => E,
            args     => [
                E,
                {
                    module         => 'D1',
                    dist           => 'D1',
                    version        => '0.01',
                    author_release => 'FOO/D1-0.01',
                    phase          => 'runtime',
                    relationship   => 'requires',
                    version_range  => '!= 0.10',
                },
                {
                    dist           => 'D1',
                    version        => '0.11',
                    author_release => 'FOO/D1-0.11',
                },
            ],
        },
        {
            sub_name => 'show',
            sub_ref  => E,
            args     => [
                E,
                {
                    module         => 'E1',
                    dist           => 'E1',
                    version        => '0.01',
                    author_release => 'FOO/E1-0.01',
                    phase          => 'runtime',
                    relationship   => 'requires',
                    version_range  => '>= 0.10, != 0.11',
                },
                {
                    dist           => 'E1',
                    version        => '0.12',
                    author_release => 'FOO/E1-0.12',
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
requires 'A1', '0.10';
requires 'A2', '==0.10';
requires 'B1', '0.10';
requires 'B2', '<=0.10';
requires 'C1', '0.10';
requires 'C2', '>=0.10';
requires 'D1', '0.11';
requires 'D2', '!=0.10';
requires 'E1', '0.12';
requires 'E2', '>=0.10, !=0.11';
...
};

done_testing;
