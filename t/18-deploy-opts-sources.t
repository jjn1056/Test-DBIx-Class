use strict;
use warnings;

use Test::More;

use Test::DBIx::Class
    {deploy_opts => {sources => ['Person']}},
    'Person';

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

reset_schema();

is_deeply {map { $_->{name} => @$_{age} } hri_dump(Person)},
    {},
    'Got Expected results';

done_testing();
