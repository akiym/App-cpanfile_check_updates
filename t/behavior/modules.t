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
requires 'B';
requires 'C';
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
  B-0.01
    pathname: F/FO/FOO/B-0.01.tar.gz
    provides:
      B 0.01
  C-0.01
    pathname: F/FO/FOO/C-0.01.tar.gz
    provides:
      C 0.01
...
}

my $module_details = mock {} => (track => 1);

my %module2release = (
    A => CPAN::DistnameInfo->new('F/FO/FOO/A-0.02.tar.gz'),
    B => CPAN::DistnameInfo->new('F/FO/FOO/B-0.02.tar.gz'),
    C => CPAN::DistnameInfo->new('F/FO/FOO/C-0.02.tar.gz'),
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
)->run('A', 'B');

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
                    module         => 'B',
                    dist           => 'B',
                    version        => '0.01',
                    author_release => 'FOO/B-0.01',
                    phase          => 'runtime',
                    relationship   => 'requires',
                },
                {
                    dist           => 'B',
                    version        => '0.02',
                    author_release => 'FOO/B-0.02',
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
requires 'B', '0.02';
requires 'C';
...
};


done_testing;
