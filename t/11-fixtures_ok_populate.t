use strict;
use warnings;

# This test was created in response to a bug that caused only one table to
# get loaded when calling fixtures_ok, without errors or warnings.

# Hard-code a plan to verify Test::DBIx::Class's fixtures_ok behavior.
use Test::More 'tests' => 8;

use Test::DBIx::Class {
  schema_class => 'Test::DBIx::Class::Example::Schema',
  connect_info => ['dbi:SQLite:dbname=:memory:','','', {on_connect_call => 'use_foreign_keys'}],
  fixture_class => '::Populate',
}, 'Person', 'Company';

fixtures_ok [ 
  Company => [
    [qw/name/],
    ['Rockets'],
    ['Sprockets'],
  ],
  Person => [
    [qw/name age email/],
    ['Mommy', 55, 'mom@moms.com'],
    ['Tommy', 8,  'tommy@toms.com'],
  ],
], 'Install some fixtures as an array ref';

is_resultset Company;
is_resultset Person;

is_fields [qw/name/], Company, [
  ['Rockets'],
  ['Sprockets'],
], "Companies loaded ok";

is_fields [qw/name age email/], Person, [
    ['Mommy', 55, 'mom@moms.com'],
    ['Tommy', 8,  'tommy@toms.com'],
], "Persons ALSO loaded ok.  The key here being that both Companies and Persons were loaded";

fixtures_ok { 
  Company => [
    [qw/name/],
    ['Lockets'],
  ],
  Person => [
    [qw/name age email/],
    ['Salami', 1, 'sal@ami.com'],
  ],
}, 'Install more fixtures to the same table.  This time as a hashref to test a different code path';

is_fields [qw/name/], Company, [
  ['Lockets'],
  ['Rockets'],
  ['Sprockets'],
], "Second Company fixture loaded appended data, not replacing it";

is_fields [qw/name age email/], Person, [
    ['Mommy', 55, 'mom@moms.com'],
    ['Tommy', 8,  'tommy@toms.com'],
    ['Salami', 1, 'sal@ami.com'],
], "Second Person fixture ALSO loaded appended data, not replacing it";
