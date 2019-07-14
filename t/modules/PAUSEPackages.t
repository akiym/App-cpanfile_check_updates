use Test2::V0;

use App::ccu::PAUSEPackages;

subtest '_build_releases' => sub {
    my @packages_details_lines = split /\n/, <<'...';
File:         02packages.details.txt
URL:          http://www.perl.com/CPAN/modules/02packages.details.txt
Description:  Package names found in directory $CPAN/authors/id/
Columns:      package name, version, path
Intended-For: Automated fetch routines, namespace documentation.
Written-By:   PAUSE version 1.005
Line-Count:   2
Last-Updated: Sun, 14 Jul 2019 15:17:03 GMT

Bar                               0.01   F/FO/FOO/FooBar-0.01.tar.gz
Foo                               0.01   F/FO/FOO/FooBar-0.01.tar.gz
...
    my $z = mock {} => (
        add => [
            # emulate IO::Uncompress::Gunzip
            getline => sub {
                my $line = shift @packages_details_lines;
                return unless defined $line;
                return "$line\n";
            },
        ],
    );

    my $pause_packages = App::ccu::PAUSEPackages->new;
    my $mock = mock $pause_packages => (
        override => [
            _fetch_packages => sub { $z },
        ],
    );
    is $pause_packages->releases, {
        FooBar => {
            distinfo => object {
                call cpanid  => 'FOO';
                call dist    => 'FooBar';
                call version => '0.01';
            },
            modules => [qw/Bar Foo/],
        },
    };
};

subtest 'find_release' => sub {
    my $pause_packages = App::ccu::PAUSEPackages->new(
        releases => {
            FooBar => {
                distinfo => CPAN::DistnameInfo->new('F/FO/FOO/FooBar-0.01.tar.gz'),
                modules  => [
                    'Foo',
                    'Bar',
                ],
            },
        },
    );

    is $pause_packages->find_release('FooBar', 'Foo'), object {
        call cpanid  => 'FOO';
        call dist    => 'FooBar';
        call version => '0.01';
    };
    is $pause_packages->find_release('FooBar', 'Bar'), object {
        call dist => 'FooBar';
    };
    is $pause_packages->find_release('Baz', 'Baz'), undef;
};

done_testing;