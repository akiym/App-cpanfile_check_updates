package App::ccu::CLI;
use strict;
use warnings;

use Getopt::Long ();

use App::ccu;

binmode STDOUT, ':encoding(utf8)';

sub new { bless {}, shift }

sub run {
    my ($self, @argv) = @_;

    my %opt = (
        cpanfile     => 'cpanfile',
        snapshot     => 'cpanfile.snapshot',
        phase        => undef,
        relationship => undef,
        interactive  => 0,
    );
    my $exitcode;
    my $p = Getopt::Long::Parser->new(
        config => ['gnu_getopt'],
    );
    my $parsed = $p->getoptionsfromarray(
        \@argv,
        'cpanfile=s'     => \$opt{cpanfile},
        'snapshot=s'     => \$opt{snapshot},
        'phase=s'        => \$opt{phase},
        'relationship=s' => \$opt{relationship},
        # TODO: implement interactive mode
        'interactive'    => \$opt{interactive},
        'version'        => sub { $exitcode = 0; version() },
        'help'           => sub { $exitcode = 0; usage()   },
    );

    if (!$parsed) {
        usage(1);
        $exitcode = 1;
    }

    return $exitcode if defined $exitcode;

    my $app = App::ccu->new(%opt);
    $app->run(@argv);

    return 0;
}

sub usage {
    my $fh = $_[0] ? *STDERR : *STDOUT;
    print $fh "    cpanfile-check-updates [--cpanfile file] [--snapshot file] [--interactive] [--version] [--help] [modules...]\n";
}

sub version {
    my $fh = $_[0] ? *STDERR : *STDOUT;
    print $fh "cpanfile-check-updates version $App::ccu::VERSION\n";
    if (defined $App::ccu::GIT_DESCRIBE) {
        print $fh "This is a self-contained version, $App::ccu::GIT_DESCRIBE ($App::ccu::GIT_URL)\n";
    }
}

1;
