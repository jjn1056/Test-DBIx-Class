BEGIN {
	$ENV{TEST_DBIC_LAST_NAME} = 'Li' unless
	  defined $ENV{TEST_DBIC_LAST_NAME};
}

use Test::More; {

	use strict;
	use warnings;

	BEGIN {
		eval "use Test::Postgresql58"; if($@) {
			plan skip_all => 'Test::Postgresql58 not installed';
		}
		eval "use DateTime::Format::Pg"; if($@) {
			plan skip_all => 'DateTime::Format::Pg not installed';
		}
	}

	my $lastname;
	ok $lastname = $ENV{TEST_DBIC_LAST_NAME},
	  "Got Lastname of $lastname";

	use Test::DBIx::Class 
		-config_path=>[qw/t etc example schema/],
		-traits=>'Testpostgresql';

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

	done_testing;
}
