BEGIN {
	$ENV{TEST_DBIC_LAST_NAME} = 'Li' unless
	  defined $ENV{TEST_DBIC_LAST_NAME};
}

use strict;
use warnings;
use Test::More;


BEGIN {
    eval "use Test::mysqld"; if($@) {
        plan skip_all => 'Test::mysqld not installed';
    }
}

my $lastname;
ok $lastname = $ENV{TEST_DBIC_LAST_NAME},
  "Got Lastname of $lastname";

use Test::DBIx::Class 
    -config_path=>[qw/t etc example schema/],
    -traits=>'Testmysqld',
    -replicants=>2;


is_resultset Person;
is_resultset Job;

fixtures_ok 'basic';

sleep(3);

ok Schema->storage->pool->has_replicants
    => 'does have replicants';

is Schema->storage->pool->num_replicants => 2
    => 'has two replicants';

Schema->storage->pool->validate_replicants;

is_fields 'email', NotTeenager, [
    "vanessa$lastname\@school.com",
    'john@nowehere.com',
], 'Got Expected Email Addresses';

is_fields ['name','age'], Person, [
    ['John',40],
    ['Vincent',15],
    ["Vanessa",35],
], 'Found People';

is_fields ['name','age'], NotTeenager, [
    ['John',40],
    ["Vanessa",35],
], 'No longer a teenager';

done_testing;


