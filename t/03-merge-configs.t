use Test::More; {

	use strict;
	use warnings;
	use Path::Class;

	require_ok 'Test::DBIx::Class';

	is_deeply [Test::DBIx::Class->_normalize_config_path(
		Test::DBIx::Class->_default_paths,
		[
			[qw( / etc test )],
			'+',
			[qw(~ etc test)] 
		]
	)], [
		Path::Class::file(qw( / etc test)),
		Path::Class::file(qw(t/etc/schema)),
		Path::Class::file(qw(t/etc/03-merge-configs)),
		Path::Class::file(qw(~/etc/test)),
	], "Properly normalized a path";

	is_deeply [Test::DBIx::Class->_valid_config_files([],[
		['+'],
		[qw(t etc example schema1)], 
		[qw(t etc example schema2)],
	])], [
		Path::Class::file(qw/t etc example schema1.pl/),
		Path::Class::file(qw/t etc example schema2.pl/), 
	], 'Got correct valid configuration files';

	is_deeply [Test::DBIx::Class->_load_via_config_any(
		[
			['+'],
			[qw(t etc example schema1)], 
			[qw(t etc example schema2)],
		]
	)], [
		{ schema_class => "Test::DBIx::Class::Example::Schema" },
		{ a => 1, b => 2 },
		{ a => 5, c => 3, config_path => [qw/t etc example schema3/] },
	], 'Got correct load from configuration';

	 is_deeply [Test::DBIx::Class->_prepare_config({
			aa => 100,
			c => 40,
			config_path => [
				['+'],
				[qw(t etc example schema1)], 
				[qw(t etc example schema2)],
			]
	})], [
		{ schema_class => "Test::DBIx::Class::Example::Schema", 
		a => 5, aa => 100, b => 2, c => 40, aaaa=>1, bbbb=>2 },
	], 'Got correct _prepare_config';
	
	{
		$ENV{TEST_DBIC_CONFIG_SUFFIX} = '-prod';
		
		is_deeply [Test::DBIx::Class->_valid_config_files([],[
			['+'],
			[qw(t etc example schema1)], 
			[qw(t etc example schema2)],
		])], [
			Path::Class::file(qw/t etc example schema1.pl/),
			Path::Class::file(qw/t etc example schema1-prod.pl/),
			Path::Class::file(qw/t etc example schema2.pl/), 
		], 'Got correct valid configuration files';
		
	}

	 is_deeply [Test::DBIx::Class->_prepare_config({
			aa => 100,
			c => 40,
			config_path => [
				['+'],
				[qw(t etc example schema1)], 
				[qw(t etc example schema2)],
			]
	})], [
		{ schema_class => "Test::DBIx::Class::Example::Schema", 
		a => 5, aa => 100, b => 2, c => 40, aaaa=>1, bbbb=>2, z=>1 },
	], 'Got correct _prepare_config';
	
	done_testing();
}
