requires 'Config::Any' => '0.19';
requires 'DBIx::Class' => '0.08123';
requires 'DBIx::Class::Schema::PopulateMore' => '0.16';
requires 'DBIx::Class::TimeStamp' => '0.13';
requires 'DBIx::Class::UUIDColumns' => '0.02005';
requires 'Data::UUID' => '1.215';
requires 'Data::Visitor' => '0.27';
requires 'Digest::MD5' => '2.39';
requires 'Hash::Merge' => '0.11';
requires 'List::MoreUtils' => '0.22';
requires 'Module::Runtime' => '0.013';
requires 'Moose' => '1.10';
requires 'MooseX::Attribute::ENV' => '0.01';
requires 'MooseX::Types' => '0.23';
requires 'Path::Class' => '0.21';
requires 'SQL::Translator' => '0.11006';
requires 'Scalar::Util' => '1.23';
requires 'Sub::Exporter' => '0.982';
requires 'Test::Builder' => '0.96';
requires 'Test::Deep' => '0.106';
requires 'File::Temp';
requires 'File::Path';

feature 'mysql', 'MySql Support' => sub { 
	requires 'Test::mysqld' => '0.14',
};

feature 'postgres', 'Postgresql Support' => sub { 
	requires 'Test::PostgreSQL' => '0.09',
	requires 'DateTime::Format::Pg' => '0',
};

test_requires 'Test::More' => '0.94';

