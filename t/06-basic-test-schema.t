use strict;
use warnings;

use Test::More;
use Test::DBIx::Class
    'CD',
    'Person',
    'Person' => {search => {age=>{'>'=>18}}, -as => 'NotTeenager'},
    'Person::Employee' => {-as => 'Employee'};

isa_ok Schema, 'Test::DBIx::Class::Example::Schema'
  => 'Got Correct Schema';

isa_ok ResultSet('Job'), 'Test::DBIx::Class::Example::Schema::DefaultRS'
  => 'Got the right Job set';

isa_ok Person, 'Test::DBIx::Class::Example::Schema::DefaultRS'
  => 'Got the right Person set';

isa_ok NotTeenager, 'Test::DBIx::Class::Example::Schema::DefaultRS'
  => 'Got the right NotTeenager set';

isa_ok Employee, 'Test::DBIx::Class::Example::Schema::DefaultRS'
  => 'Got the right Employee set';

is_resultset Person;
is_resultset Person, 'Test::DBIx::Class::Example::Schema::DefaultRS';
is_resultset Person, 'Test::DBIx::Class::Example::Schema::DefaultRS', 'custom message';

fixtures_ok sub {
    my $schema = shift @_;
    my $person_rs = $schema->resultset('Person');
    my ($john, $vincent, $vanessa) = $person_rs->populate([
        ['name', 'age', 'email'],
        ['John', 40, 'john@nowehere.com'],
        ['Vincent', 15, 'vincent@home.com'],
        ['Vanessa', 35, 'vanessa@school.com'],
    ]);
}, 'Installed fixtures';

is_deeply {map { $_->{name} => @$_{age} } hri_dump(Person)},
   { John => 40, Vanessa => 35, Vincent => 15 },
  'Got Expected results';

reset_schema;

is_deeply {map { $_->{name} => @$_{age} } hri_dump(Person)},
   {},
  'Got Expected results';

fixtures_ok {
    Person => [
        ['name', 'age', 'email'],
        ['John', 40, 'john@nowehere.com'],
        ['Vincent', 15, 'vincent@home.com'],
        ['Vanessa', 35, 'vanessa@school.com'],
    ],
}, 'Installed fixtures';

is_deeply {map { $_->{name} => @$_{age} } hri_dump(Person)},
   { John => 40, Vanessa => 35, Vincent => 15 },
  'Got Expected results';

reset_schema;

is_deeply {map { $_->{name} => @$_{age} } hri_dump(Person)},
   {},
  'Got Expected results';

fixtures_ok 'core';

is_deeply {map { $_->{name} => @$_{age} } hri_dump(Person)},
   { John => 40, Vanessa => 35, Vincent => 15 },
  'Got Expected results';

ok my $john = Person({name=>'John'})->first,
  => 'Found John';

ok my $vanessa = Person(name=>'Vanessa')->first,
  => 'Found Vanessa';

eq_result $john, $john, "John is John";

ok my $not_teenager_set1  = Person->search({age=>{'>'=>18}}),
  => 'got some people';

ok my $not_teenager_set2  = Person({age=>{'>'=>18}})
  => 'got some people';

ok my $not_teenager_set3  = Person(age=>{'>'=>18})
  => 'got some people';

eq_resultset $not_teenager_set1, $not_teenager_set2;
eq_resultset $not_teenager_set2, $not_teenager_set3;
eq_resultset $not_teenager_set1, NotTeenager, 'custom message';

is_fields 'name', $john, 'John';
is_fields ['name'], $john, 'John';
is_fields ['name'], $john, ['John'];
is_fields ['name'], $john, ['John'], 'custom message';
is_fields ['name','age'], $john, ['John',40];
is_fields ['name','age'], $john, {
    age => 40,
    name => 'John',
};

is_fields $john, {
    age => 40,
    name => 'John',
    created => $john->created,
    email => 'john@nowehere.com',
}, 'Last Result Matched';

is_fields 'name', $not_teenager_set3, [
    'John',
    'Vanessa',
], 'Found People and data1';

is_fields ['name'], Person, [
    'John',
    'Vanessa',
    'Vincent',
], 'Found People and data2';

is_fields ['name','age'], Person, [
    ['John',40],
    ['Vincent',15],
    ['Vanessa',35],
], 'Found People and data3';

is_fields ['name','age'], Person, [
    {name=>'John', age=>40},
    {name=>'Vanessa',age=>35},
    {name=>'Vincent', age=>15},
], 'Found People and data4';

done_testing();
