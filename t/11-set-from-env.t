use strict;
use warnings;

BEGIN {
    use File::Spec;
    use FindBin qw/$Bin/;
    my $path = File::Spec->catdir($Bin, 'test.db');
    $ENV{DBNAME} = $path;
    #$ENV{KEEP_DB} = 1;
}

use Test::More;
use Test::DBIx::Class 'CD', 'Person';
	
isa_ok CD, 'Test::DBIx::Class::Example::Schema::DefaultRS';
isa_ok Person, 'Test::DBIx::Class::Example::Schema::DefaultRS';

Schema->cleanup;
	
ok -e "$Bin/test.db", "Can find file 'test.db' file";
unlink "$Bin/test.db";

ok ! -e "$Bin/test.db", "Test file 'test.db' is now gone!";

done_testing;
