use Test2::V0;

use Capture::Tiny qw/capture/;

use App::ccu::CLI;

subtest 'run for default options' => sub {
    my $mock = mock 'App::ccu' => (
        override => [
            run => sub {
                my ($self, @modules) = @_;
                is $self, object {
                    field cpanfile     => 'cpanfile';
                    field snapshot     => 'cpanfile.snapshot';
                    field phase        => undef;
                    field relationship => undef;
                    field interactive  => 0;
                    end;
                };
                is \@modules, [];
            },
        ],
    );
    is +App::ccu::CLI->new->run, 0;
};

subtest 'run for specifying options' => sub {
    my $mock = mock 'App::ccu' => (
        override => [
            run => sub {
                my ($self, @modules) = @_;
                is $self, object {
                    field cpanfile     => 'a/cpanfile';
                    field snapshot     => 'a/cpanfile.snapshot';
                    field phase        => 'develop';
                    field relationship => 'recommends';
                    field interactive  => 1;
                    end;
                };
                is \@modules, ['A', 'B'];
            },
        ],
    );
    is +App::ccu::CLI->new->run(
        '--cpanfile'     => 'a/cpanfile',
        '--snapshot'     => 'a/cpanfile.snapshot',
        '--phase'        => 'develop',
        '--relationship' => 'recommends',
        '--interactive',
        'A',
        'B',
    ), 0;
};

subtest 'usage' => sub {
    my ($stdout, undef) = capture {
        is +App::ccu::CLI->new->run('--help'), 0;
    };
    like $stdout, qr/cpanfile-check-updates/;

    subtest 'invalid option' => sub {
        my (undef, $stderr) = capture {
            is +App::ccu::CLI->new->run('--invalid_option'), 1;
        };
        like $stderr, qr/cpanfile-check-updates/;
    };
};

subtest 'version' => sub {
    my ($stdout, undef) = capture {
        is +App::ccu::CLI->new->run('--version'), 0;
    };
    like $stdout, qr/cpanfile-check-updates version/;
};

done_testing;