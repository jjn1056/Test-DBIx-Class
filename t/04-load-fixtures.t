use strict;
use warnings;

use Test::More;
use Test::Differences;
use Path::Class;

ok my %options = (
    fixture_sets => { core => {a => '100' }},
    schema_class => 'MyApp::Schema',
    fixture_path => [
        [qw/t etc example fixtures/]
        ,'+',
        [qw/t etc example2 fixtures/]
    ],
), 'prepare the options';

require_ok 'Test::DBIx::Class';

ok my $prepared_fixtures = Test::DBIx::Class->_prepare_fixtures({%options}),
    'got prepared fixtures';

eq_or_diff(
    $prepared_fixtures, {fixture_sets => {
        core => [
            { a => '100' },
            {
                Person => [
                    ["name", "age", "email"],
                    ["John", '40', "john\@nowehere.com"],
                    ["Vincent", '15', "vincent\@home.com"],
                    ["Vanessa", '35', "vanessa\@school.com"],
                ],
            },
            { Company => [["name"], ["Acme"]] },
            { a => '1', b => '2' },
        ],
        more => [{ c => '6', cc => '100' }, { a => '5', c => '3' }],
    },
    schema_class => "MyApp::Schema",
}, 'as expected' );


done_testing();


