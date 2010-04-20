use inc::Module::Install 0.91;

use warnings;
use strict;

all_from 'lib/Test/DBIx/Class.pm';
repository 'git://github.com/jjn1056/Test-DBIx-Class.git';	

requires 'Config::Any' => '0.17';
requires 'DBIx::Class' => '0.08121';
requires 'DBIx::Class::Schema::PopulateMore' => '0.14';
requires 'DBIx::Class::TimeStamp' => '0.12'; 
requires 'DBIx::Class::UUIDColumns' => '0.02005';
requires 'Data::UUID' => '1.202';
requires 'Data::Visitor' => '0.25';
requires 'Digest::MD5' => '2.39';
requires 'Hash::Merge' => '0.11';
requires 'List::MoreUtils' => '0.22';
requires 'Moose' => '0.88';
requires 'MooseX::Attribute::ENV' => '0.01';
requires 'MooseX::Traits::Pluggable' => '0.09';
requires 'MooseX::Types' => '0.16';
requires 'Path::Class' => '0.17';
requires 'SQL::Translator' => '0.11005';
requires 'Scalar::Util' => '1.19';
requires 'Sub::Exporter' => '0.982';
requires 'Test::Builder' => '0.92';
requires 'Test::Differences' => '0.5';

feature('MySql Support', -default => 0, 'Test::mysqld' => '0.11');
feature('Postgresql Support', -default => 0, 'Test::postgresql' => '0.09'); 

build_requires 'Test::More' => '0.92';

auto_install;
tests_recursive;
WriteAll;

