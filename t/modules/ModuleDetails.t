use Test2::V0;

use Capture::Tiny qw/capture_stdout/;

use App::ccu::ModuleDetails;

subtest 'show' => sub {
    my $metacpan = mock {} => (
        add => [
            author_release => sub { 'FOO/Foo-0.01' },
        ],
    );
    my $module_details = App::ccu::ModuleDetails->new(metacpan => $metacpan);
    my $stdout = capture_stdout {
        $module_details->show(
            {
                module  => 'Foo',
                dist    => 'Foo',
                version => '0.01',
            },
            {
                dist           => 'Foo',
                version        => '0.10',
                author_release => 'FOO/Foo-0.10',
            }
        );
    };
    is $stdout, <<'...';
## Foo
[`0.01` -> `0.10`](https://metacpan.org/diff/file?source=FOO%2FFoo-0.01&target=FOO%2FFoo-0.10)
...
};

subtest 'print_advisory' => sub {
    my $module_details = App::ccu::ModuleDetails->new;
    my $stdout = capture_stdout {
        $module_details->print_advisory('Archive-Zip', '1.60');
    };
    is $stdout, <<'...';
### :warning: Affected security updates
- CVE-2018-10860: perl-archive-zip is vulnerable to a directory traversal in Archive::Zip. It was found that the Archive::Zip module did not properly sanitize paths while extracting zip files. An attacker able to provide a specially crafted archive for processing could use this flaw to write or overwrite arbitrary files in the context of the perl interpreter.
  - https://security-tracker.debian.org/tracker/CVE-2018-10860
  - https://github.com/redhotpenguin/perl-Archive-Zip/pull/33
...

    is capture_stdout {
        $module_details->print_advisory('Archive-Zip', '1.61');
    }, '';
};

subtest 'print_changes' => sub {
    my $metacpan = mock {} => (
        add => [
            release => sub {
                +{
                    "resources" => {
                        "repository" => {
                            "type" => "git",
                            "url"  => "https://github.com/example/Foo.git",
                            "web"  => "https://github.com/example/Foo"
                        }
                    },
                };
            },
            changes => sub {
                <<'...';
Revision history for Foo

0.10 - 2019-02-01
  - 2 #1
  - 3
    - 4
    - 5
    - 6

0.09 - 2019-02-01
  - 8
  - 9
  - 10

0.01 - 2019-01-01
  - a
...
            },
        ],
    );
    my $module_details = App::ccu::ModuleDetails->new(metacpan => $metacpan);

    my $stdout = capture_stdout {
        $module_details->print_changes('FOO/Foo-0.10', '0.01', '0.10');
    };
    is $stdout, <<'...';
### Changes
#### 0.10: 2019-02-01
- 2 [#1](https://github.com/example/Foo/issues/1)
- 3
  - 4
  - 5
  - 6
#### 0.09: 2019-02-01
- 8
- 9
- 10
...

    subtest 'collapse for long changes' => sub {
        my $metacpan = mock {} => (
            add => [
                release => sub {
                    +{
                        "resources" => {
                            "repository" => {
                                "type" => "git",
                                "url"  => "https://github.com/example/Foo.git",
                                "web"  => "https://github.com/example/Foo"
                            }
                        },
                    };
                },
                changes => sub {
                    <<'...';
Revision history for Foo

0.10 - 2019-02-01
  - 2

0.09 - 2019-02-01
  - 4
  - 5
  - 6
  - 7
  - 8
  - 9
  - 10
  - 11

0.01 - 2019-01-01
  - a
...
                },
            ],
        );
        my $module_details = App::ccu::ModuleDetails->new(metacpan => $metacpan);

        my $stdout = capture_stdout {
            $module_details->print_changes('FOO/Foo-0.10', '0.01', '0.10');
        };
        is $stdout, <<'...';
### Changes
<details>
<summary>
#### 0.10: 2019-02-01
- 2
</summary>
#### 0.09: 2019-02-01
- 4
- 5
- 6
- 7
- 8
- 9
- 10
- 11
</details>
...
    };
};

subtest 'count_changes_line' => sub {
    my $module_details = App::ccu::ModuleDetails->new;
    is $module_details->count_changes_line(
        { entries => [{ text => 'a' }] },
    ), 2;
    is $module_details->count_changes_line(
        { entries => [{ text => 'a' }] },
        { entries => [{ text => 'a' }] },
    ), 4;
    is $module_details->count_changes_line(
        { entries => [{ text => 'a', entries => [{ text => 'a' }] }] },
    ), 3;
};

done_testing;
