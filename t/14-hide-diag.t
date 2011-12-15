use Test::More; {

	use strict;
	use warnings;
	
	require_ok 'Test::DBIx::Class';

	ok my $config = {
		schema_class => 'Test::DBIx::Class::Example::Schema',
        tdbic_debug => 0,
	}, 'Created Sample inline configuration';


    ok my $schema_manager = Test::DBIx::Class->_initialize_schema($config)
      => 'Connected and deployed a testable schema';

    my $fh;
    $schema_manager->builder->failure_output(\$fh);

	SKIP: {
		eval {require DBIx::Class::Schema::PopulateMore};
		skip "You need the optional DBIx::Class::Schema::PopulateMore", 
		2 if $@;

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

        ok !$fh, 'no diag emitted';

        $config->{tdbic_debug} = 1;
        ok $schema_manager = Test::DBIx::Class->_initialize_schema($config)
          => 'Connected and deployed a testable schema';

		ok %return2 = $schema_manager->install_fixtures(
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

        ok $fh, 'diag emitted';

	}

	done_testing();
}
