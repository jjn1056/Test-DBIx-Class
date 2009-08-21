use Test::More; {

	use strict;
	use warnings;
	
	require_ok 'Test::DBIx::Class';

	ok my $config = {
		schema_class => 'Test::DBIx::Class::Example::Schema',
	}, 'Created Sample inline configuration';

	ok my $schema_manager = Test::DBIx::Class->_initialize_schema($config)
	  => 'Connected and deployed a testable schema';

	is_deeply [sort $schema_manager->schema->sources],
		[
			"CD",
			"CD::Artist",
			"CD::Track",
			"Company",
			"Company::Employee",
			"Job",
			"Person",
			"Person::Artist",
			"Person::Employee",
			"Phone",
		],
		'Got expected sources';

	ok my @return = $schema_manager->install_fixtures(
		Job => [
			[name => 'description'],
			[programmer => 'who writes the code'],
			[marketer => 'who sells the code'],
			[admin => 'who runs the code'],
		],
		Person => [
			['name', 'age', 'email'],
			['John', 40, 'john@nowehere.com'],
			['Vincent', 15, 'vincent@home.com'],
			['Vanessa', 35, 'vanessa@school.com'],
		],
	), "Installed Fixtures with Populate";

	is $return[0]->{Job}->[0]->name, 'programmer'
	  => 'Found expected name value of programmer';

	ok my %return2 = $schema_manager->install_fixtures(
			'::PopulateMore',
			Person => {
				fields => ['name', 'age', 'email'],
				data => {
					york => ['York', 45, 'york@york.com'],
					mike => ['Mike', 65, 'mike@mike.com'],
				},
			},
			'Person::Employee' => {
				fields => 'person',
				data => {
					employee_york => '!Index:Person.york',
					employee_mike => '!Index:Person.mike',
				},
			}
	), "Installed Fixtures with PopulateMore";

	is $return2{'Person.york'}->name, 'York',
	  => 'york is York!';

	done_testing();
}
