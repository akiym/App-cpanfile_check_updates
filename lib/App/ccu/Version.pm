package App::ccu::Version;
use strict;
use warnings;

use version;

# Original code was taken from CPAN::Audit::Version
# https://github.com/vti/cpan-audit/blob/10e5b1413cba17d3b6995ac37ed0020129a991b7/lib/CPAN/Audit/Version.pm

sub in_range {
    my $class = shift;
    my ( $version, $range ) = @_;

    return unless defined $version && defined $range;

    my @ands = split /\s*,\s*/, $range;

    return unless defined( $version = eval { version->parse($version) } );

    foreach my $and (@ands) {
        my ( $op, $range_version ) = $and =~ m/^(<=|<|>=|>|==|!=)?\s*([^\s]+)$/;

        return
          unless defined( $range_version = eval { version->parse($range_version) } );

        $op = '>=' unless defined $op;

        if ( $op eq '<' ) {
            return unless $version < $range_version;
        }
        elsif ( $op eq '<=' ) {
            return unless $version <= $range_version;
        }
        elsif ( $op eq '>' ) {
            return unless $version > $range_version;
        }
        elsif ( $op eq '>=' ) {
            return unless $version >= $range_version;
        }
        elsif ( $op eq '==' ) {
            return unless $version == $range_version;
        }
        elsif ( $op eq '!=' ) {
            return unless $version != $range_version;
        }
        else {
            return 0;
        }
    }

    return 1;
}

1;