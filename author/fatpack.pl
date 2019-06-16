#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use MyFatPacker;

=for hint

Show new dependencies

    git diff cpanfile-check-updates | perl -nle 'print $1 if /^\+\$fatpacked\{"([^"]+)/'

=cut

chdir $FindBin::Bin;

MyFatPacker->new(
    script           => 'script/cpanfile-check-updates',
    fatpacked_script => 'cpanfile-check-updates',
    target           => '5.8.1',
    package          => 'App::ccu',
    cli_package      => 'App::ccu::CLI',
    exclude          => [ qw/
        Carp
        Digest::SHA
        ExtUtils::CBuilder
        ExtUtils::MakeMaker
        ExtUtils::MakeMaker::CPANfile
        ExtUtils::ParseXS
        File::Spec
        Module::Build::Tiny
        Module::CoreList
        Params::Check
        Perl::OSType
        Test
        Test2
        Test::Harness
    / ],
    github_url       => 'https://github.com/akiym/cpanfile-check-updates',
)->run(@ARGV);
