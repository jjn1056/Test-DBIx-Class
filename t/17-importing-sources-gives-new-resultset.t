use strict;
use warnings;

use Test::More;
use Test::DBIx::Class 'Person';
use Scalar::Util qw(refaddr);

isnt(refaddr(Person()), refaddr(Person()), 'Got two different resultsets');
done_testing();
