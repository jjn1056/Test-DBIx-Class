use strict;
use warnings;
use FindBin qw/$Bin/;
use Test::More; {
    BEGIN { $ENV{DBPATH} = "$Bin/test.db";
            $ENV{KEEP_DB} = 1;
    }
    use Test::DBIx::Class
        'CD',
		'Person';
	
	isa_ok CD, 'Test::DBIx::Class::Example::Schema::DefaultRS';
    isa_ok Person, 'Test::DBIx::Class::Example::Schema::DefaultRS';
	
	ok -r "$Bin/test.db", "Can find test db file";
    unlink "$Bin/test.db";
}

done_testing;
