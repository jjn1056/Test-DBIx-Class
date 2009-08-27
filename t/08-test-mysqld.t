BEGIN {
	$ENV{TEST_DBIC_LAST_NAME} = 'Li' unless
	  defined $ENV{TEST_DBIC_LAST_NAME};
}

use Test::More; {

	use strict;
	use warnings;

	## First we make sure we can use Test::mysqld.  This is really an author
	## aimed test so we will skip it unless told to run it.

	if($ENV{TEST_DBIC_TESTMYSQLD}) {

		my $lastname;
		ok $lastname = $ENV{TEST_DBIC_LAST_NAME},
		  "Got Lastname of $lastname";

		eval {
		use Test::DBIx::Class 
			-config_path=>[qw/t etc example schema/],
			-traits=>['Testmysqld'];
		}; if($@) {
			plan skip_all => "Can't setup the schema";
		}

		is_resultset Person;
		is_resultset Job;

		fixtures_ok 'basic';

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

	} else {
		plan skip_all => 'Do not run the test-mysqld tests';
	}

	done_testing;
}
