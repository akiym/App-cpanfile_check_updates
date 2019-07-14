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

on develop => sub {
    requires 'B';
    recommends 'C';
};
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
    phase          => 'develop',
    relationship   => 'recommends',
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
                    module         => 'C',
                    dist           => 'C',
                    version        => '0.01',
                    author_release => 'FOO/C-0.01',
                    phase          => 'develop',
                    relationship   => 'recommends',
                    version_range  => 0,
                },
                {
                    dist           => 'C',
                    version        => '0.02',
                    author_release => 'FOO/C-0.02',
                },
            ],
        },
    ];
};

subtest 'cpanfile is updated' => sub {
    my $todo = todo 'App::CpanfileSlipstop::Writer does not support to update versions in recommends';
    my $cpanfile_src = do {
        open my $fh, '<', $cpanfile or die $!;
        local $/; <$fh>;
    };
    is $cpanfile_src, <<'...';
requires 'A';

on develop => sub {
    requires 'B';
    recommends 'C', '0.02';
};
...
};


done_testing;