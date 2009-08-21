use Test::More; {

	use strict;
	use warnings;
	use Path::Class;

	require_ok 'Test::DBIx::Class';

	is_deeply Test::DBIx::Class->_prepare_fixtures(
		{
			fixture_sets => { core => {a => 100 }},
			schema_class => 'MyApp::Schema',
			fixture_path=>[
				[qw/t etc example fixtures/]
				,'+',
				[qw/t etc example2 fixtures/]
			],
		}),
  {
    fixture_sets => {
                      core => {
                                Person => [
                                      ["name", "age", "email"],
                                      ["John", 40, "john\@nowehere.com"],
                                      ["Vincent", 15, "vincent\@home.com"],
                                      ["Vanessa", 35, "vanessa\@school.com"],
                                    ],
                                a => 100,
                                b => 2,
                              },
                      more => { a => 5, c => 6, cc => 100 },
                    },
    schema_class => "MyApp::Schema",
  }, "got expected fixtures";

	done_testing();
}
