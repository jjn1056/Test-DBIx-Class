use inc::Module::Install 0.91;

use warnings;
use strict;

all_from 'lib/Test/DBIx/Class.pm';
repository 'TBD';	

requires 'Moose' => '0.88';
requires 'MooseX::Types' => '0.16';
requires 'MooseX::Attribute::ENV' => '0.01';
requires 'Data::UUID' => '1.202';
requires 'DBIx::Class' => '0.08108';
requires 'DBIx::Class::UUIDColumns' => '0.02005';
requires 'DBIx::Class::TimeStamp' => '0.12'; 
requires 'SQL::Translator' => '0.09007';
requires 'Test::Builder' => '0.92';
requires 'DBIx::Class::Schema::PopulateMore' => '0.14';
requires 'Path::Class' => '0.17';
requires 'Config::Any' => '0.17';
requires 'Sub::Exporter' => '0.982';
requires 'Scalar::Utils';
requires 'Digest::MD5' => '2.39';

build_requires 'Test::More' => '0.92';

auto_install;
tests_recursive;
WriteAll;

