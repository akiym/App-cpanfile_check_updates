package App::ccu::ChangesParser;
use strict;
use warnings;

use CPAN::Changes;

# Original code was taken from MetaCPAN::Web::Model::API::Changes::Parser and MetaCPAN::Web::Model::API::Changes
# https://github.com/metacpan/metacpan-web/blob/aa99708b1e4ed57437aa5ef201d26d6de6cf1f51/lib/MetaCPAN/Web/Model/API/Changes/Parser.pm
# https://github.com/metacpan/metacpan-web/blob/aa99708b1e4ed57437aa5ef201d26d6de6cf1f51/lib/MetaCPAN/Web/Model/API/Changes.pm

my %months;
my $m = 0;
$months{$_} = ++$m for qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );

sub load {
    my ( $class, $file ) = @_;
    open my $fh, '<', $file
        or die "can't open $file: $!";
    my $content = do { local $/; <$fh> };
    $class->parse($content);
}

sub parse {
    my ( $class, $string ) = @_;

    my @lines = split /\r\n?|\n/, $string;

    my $preamble = q{};
    my @releases;
    my $release;
    my @indents;
    for my $linenr ( 0 .. $#lines ) {
        my $line = $lines[$linenr];
        if ( $line
            =~ /^(?:version\s+)?($version::LAX(?:-TRIAL)?)(\s+(.*))?$/i )
        {
            my $version = $1;
            my $note    = $3;
            if ($note) {
                $note =~ s/^[\W\s]+//;
                $note =~ s/\s+$//;
            }
            my $date;

            # munge date formats, save the remainder as note
            if ($note) {

                # unknown dates
                if ( $note =~ s{^($CPAN::Changes::UNKNOWN_VALS)}{}i ) {
                    $date = $1;
                }

                # handle localtime-like timestamps
                elsif ( $note
                    =~ s{^\D{3}\s+(\D{3})\s+(\d{1,2})\s+([\d:]+)?\D*(\d{4})}{}
                )
                {
                    if ($3) {

                        # unfortunately ignores TZ data
                        $date = sprintf( '%d-%02d-%02dT%sZ',
                            $4, $months{$1}, $2, $3 );
                    }
                    else {
                        $date
                            = sprintf( '%d-%02d-%02d', $4, $months{$1}, $2 );
                    }
                }

                # RFC 2822
                elsif ( $note
                    =~ s{^\D{3}, (\d{1,2}) (\D{3}) (\d{4}) (\d\d:\d\d:\d\d) ([+-])(\d{2})(\d{2})}{}
                )
                {
                    $date = sprintf( '%d-%02d-%02dT%s%s%02d:%02d',
                        $3, $months{$2}, $1, $4, $5, $6, $7 );
                }

                # handle dist-zilla style, again ingoring TZ data
                elsif ( $note
                    =~ s{^(\d{4}-\d\d-\d\d)\s+(\d\d:\d\d(?::\d\d)?)(?:\s+[A-Za-z]+/[A-Za-z_-]+)}{}
                )
                {
                    $date = sprintf( '%sT%sZ', $1, $2 );
                }

                # start with W3CDTF, ignore rest
                elsif ( $note =~ m{^($CPAN::Changes::W3CDTF_REGEX)} ) {
                    $date = $1;
                    $date =~ s{ }{T};

                    # Add UTC TZ if date ends at H:M, H:M:S or H:M:S.FS
                    $date .= 'Z'
                        if length($date) == 16
                            || length($date) == 19
                            || $date =~ m{\.\d+$};
                }

                # clean date from note
                $note =~ s{^\s+}{};
            }
            $release = {
                version => $version,
                date    => $date,
                note    => $note,
                entries => [],
                line    => $linenr,
            };
            push @releases, $release;
            @indents = ($release);
        }
        elsif (@indents) {
            if ( $line =~ /^[-_*+~#=\s]*$/ ) {
                $indents[-1]{done}++
                    if @indents > 1;
                next;
            }
            $line =~ s/\s+$//;
            $line =~ s/^(\s*)//;
            my $indent = 1 + length _expand_tab($1);
            my $change;
            my $done;
            my $nest;
            if ( $line =~ /^\[\s*([^\[\]]*)\]$/ ) {
                $done   = 1;
                $nest   = 1;
                $change = $1;
                $change =~ s/\s+$//;
            }
            elsif ( $line =~ /^[-*+=#]+\s+(.*)/ ) {
                $change = $1;
            }
            else {
                $change = $line;
                if (   $indent >= $#indents
                    && $indents[-1]{text}
                    && !$indents[-1]{done} )
                {
                    $indents[-1]{text} .= " $change";
                    next;
                }
            }

            my $group;
            my $nested;

            if ( !$nest && $indents[$indent]{nested} ) {
                $nested = $group = $indents[$indent]{nested};
            }
            elsif ( !$nest && $indents[$indent]{nest} ) {
                $nested = $group = $indents[$indent];
            }
            else {
                ($group)
                    = grep {defined} reverse @indents[ 0 .. $indent - 1 ];
            }

            my $entry = {
                text   => $change,
                line   => $linenr,
                done   => $done,
                nest   => $nest,
                nested => $nested,
            };
            push @{ $group->{entries} ||= [] }, $entry;

            if ( $indent <= $#indents ) {
                $#indents = $indent;
            }

            $indents[$indent] = $entry;
        }
        elsif (@releases) {

            # garbage
        }
        else {
            $preamble .= "$line\n";
        }
    }
    $preamble =~ s/^\s*\n//;
    $preamble =~ s/\s+$//;
    my @entries = @releases;
    while ( my $entry = shift @entries ) {
        push @entries, @{ $entry->{entries} } if $entry->{entries};
        delete @{$entry}{qw(done nest nested)};
    }
    return {
        preamble => $preamble,
        releases => [ reverse @releases ],
    };
}

sub _expand_tab {
    my $string = "$_[0]";
    $string =~ s/([^\t]*)\t/$1 . (" " x (8 - (length $1) % 8))/eg;
    return $string;
}

my $rt_cpan_base = 'https://rt.cpan.org/Ticket/Display.html?id=';
my $rt_perl_base = 'https://rt.perl.org/Ticket/Display.html?id=';
my $sep          = qr{[-:]|\s*[#]?};

sub _link_issues {
    my ( $class, $change, $gh_base, $rt_base ) = @_;
    $change =~ s{(
        (?:
        (
        \b(?:blead)?perl\s+(?:RT|bug)$sep
        |
        (?<=\[)(?:blead)?perl\s+$sep
        |
        \brt\.perl\.org\s+\#
        |
        \bP5\#
        )
        |
        (
        \bCPAN\s+(?:RT|bug)$sep
        |
        (?<=\[)CPAN\s+$sep
        |
        \brt\.cpan\.org\s+\#
        )
        |
        (\bRT$sep)
        |
        (\b(?:GH|PR)$sep)
        |
        ((?:\bbug\s*)?\#)
        )
        (\d+)\b
        )}{
            my $text = $1;
        my $issue = $7;
        my $base
            = $2 ? $rt_perl_base
            : $3 ? $rt_cpan_base
            : $4 ? $rt_base
            : $5 ? $gh_base
            # this form is non-specific, so guess based on issue number
            : ($gh_base && $issue < 10000)
            ? $gh_base
            : $rt_base;
        $base ? qq{[$text]($base$issue)} : $text;
    }xgei;

    return $change;
}

sub filter_release_changes {
    my ( $class, $changelog, $release ) = @_;

    my $gh_base;
    my $rt_base;
    my $bt = $release->{resources}{bugtracker}
        && $release->{resources}{bugtracker}{web};
    my $repo = $release->{resources}{repository};
    $repo = ref $repo ? $repo->{url} : $repo;
    if ( $bt && $bt =~ m|^https?://github\.com/| ) {
        $gh_base = $bt;
        $gh_base =~ s{/*$}{/};
    }
    elsif ( $repo && $repo =~ m|\bgithub\.com/([^/]+/[^/]+)| ) {
        my $name = $1;
        $name =~ s/\.git$//;
        $gh_base = "https://github.com/$name/issues/";
    }
    if ( $bt && $bt =~ m|\brt\.perl\.org\b| ) {
        $rt_base = $rt_perl_base;
    }
    else {
        $rt_base = $rt_cpan_base;
    }

    my @entries_list = $changelog->{entries};

    while ( my $entries = shift @entries_list ) {
        for my $entry (@$entries) {
            for ( $entry->{text} ) {
                s/&/&amp;/g;
                s/</&lt;/g;
                s/>/&gt;/g;
                s/"/&quot;/g;
            }
            $entry->{text}
                = $class->_link_issues( $entry->{text}, $gh_base, $rt_base );
            push @entries_list, $entry->{entries}
                if $entry->{entries};
        }
    }

    return $changelog;
}

1;