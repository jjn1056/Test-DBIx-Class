use Test::More; {

	use strict;
	use warnings;
	
	require_ok 'Test::DBIx::Class';

	is_deeply [Test::DBIx::Class->_normalize_opts({a=>1,b=>2}, (3,4,5))],
		[{ a => 1, b => 2 }, 3,4,5],
		'Hashref plus array of sources good';

	is_deeply [Test::DBIx::Class->_normalize_opts({a=>1,b=>2, resultsets=>[6,7]}, (3,4,5))],
		[{ a => 1, b => 2 }, 3,4,5,6,7],
		'Hashref with extra resultsource plus array of sources good';

	is_deeply [Test::DBIx::Class->_normalize_opts(-a => 1, -b => 2, (3,4,5))],
		[{ a => 1, b => 2 }, 3,4,5],
		'Dash style options plus array of sources good';

	done_testing();
}
