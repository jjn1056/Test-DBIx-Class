use Test::More; {

	use strict;
	use warnings;

	## Test to override the config path and test loading resultsets via the
	## configuration, as well as fixtures.

	use Test::DBIx::Class 
		-config_path=>[qw/t etc example schema/];

	is_resultset Person;
	is_resultset Job;

	fixtures_ok 'basic';

	is_fields ['name','age'], Person, [
		['John',40],
		['Vincent',15],
		['Vanessa',35],
	], 'Found People';

	is_fields ['name','age'], NotTeenager, [
		['John',40],
		['Vanessa',35],
	], 'No longer a teenager';

	done_testing;
}
