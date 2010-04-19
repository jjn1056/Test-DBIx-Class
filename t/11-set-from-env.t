use strict;
use warnings;

use File::Spec;
use FindBin qw/$Bin/;
my $path = File::Spec->catdir($Bin, 'test.db');
$ENV{DBNAME} = $path;
$ENV{KEEP_DB} = 1;

use Test::More;
use Test::DBIx::Class 'CD', 'Person';
	
isa_ok CD, 'Test::DBIx::Class::Example::Schema::DefaultRS';
isa_ok Person, 'Test::DBIx::Class::Example::Schema::DefaultRS';
	
ok -r "$Bin/test.db", "Can find file '$path' file";
unlink "$Bin/test.db";

ok -r "$Bin/test.db", "Test file '$path' is now gone!";

done_testing;
