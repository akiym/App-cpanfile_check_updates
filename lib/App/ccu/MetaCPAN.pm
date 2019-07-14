package App::ccu::MetaCPAN;
use strict;
use warnings;

use HTTP::Tinyish;
use JSON::PP qw/decode_json encode_json/;

use Class::Tiny {
    http => sub { HTTP::Tinyish->new },
};

sub author_release {
    my ($self, $module, $version) = @_;

    my $res = $self->http->post("https://fastapi.metacpan.org/v1/module/_search?size=1", {
        content => encode_json({
            _source => [qw/author release/],
            query => {
                bool => {
                    must => [
                        {term => {'module.name' => $module}},
                        {term => {version => $version}},
                    ],
                },
            },
        }),
    });
    unless ($res->{success}) {
        die "$res->{status} $res->{reason}";
    }

    my $r = decode_json($res->{content});
    if ($r->{hits}{total} > 0) {
        my $m = $r->{hits}{hits}[0]{_source};
        return $m->{author} . '/' . $m->{release};
    }

    return;
}

sub release {
    my ($self, $author_release) = @_;

    my $res = $self->http->get("https://fastapi.metacpan.org/v1/release/$author_release");
    unless ($res->{success}) {
        die "$res->{status} $res->{reason}";
    }

    return decode_json($res->{content})->{release};
}

sub changes {
    my ($self, $author_release) = @_;

    my $res = $self->http->get("https://fastapi.metacpan.org/v1/changes/$author_release");
    unless ($res->{success}) {
        die "$res->{status} $res->{reason}";
    }

    return decode_json($res->{content})->{content};
}

1;
