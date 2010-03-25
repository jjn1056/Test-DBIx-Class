use strict;
use warnings;
use Test::More;

# This test was created in response to a bug that caused only one table to
# get loaded when calling fixtures_ok, without errors or warnings.

SKIP: {
  eval {require DBIx::Class::Schema::PopulateMore};
  if($@) {
    plan skip_all => "Optional module DBIx::Class::Schema::PopulateMore not installed.";
  }
  else {
    # Hard-code a plan to verify Test::DBIx::Class's fixtures_ok behavior.
    plan tests => 8;
  }

  use Test::DBIx::Class {
    schema_class => 'Test::DBIx::Class::Example::Schema',
    connect_info => ['dbi:SQLite:dbname=:memory:','',''],
    fixture_class => '::PopulateMore',
  }, 'Person', 'Company';

  fixtures_ok { 
    Company => {
      fields => ['name'],
      data   => {
        sprockets => ['Sprockets'],
        rockets   => ['Rockets'],
      },
    },
    Person => {
      fields => [qw/name age email/],
      data   => {
        mommy => ['Mommy', 55, 'mom@moms.com'],
        tommy => ['Tommy', 8,  'tommy@toms.com'],
      }
    },
  }, 'Install some fixtures';

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
    Company => {
      fields => ['name'],
      data   => {
        lockets   => ['Lockets'],
      },
    },
    Person => {
      fields => [qw/name age email/],
      data   => {
        salami => ['Salami', 1, 'sal@ami.com'],
      }
    }
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
}
