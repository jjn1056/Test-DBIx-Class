use strict;
use warnings;

use Test::DBIx::Class;

use Test::More;
use File::Spec::Functions;
use File::Temp qw(tempdir);

{
  ok my $schema_manager = Test::DBIx::Class->_initialize_schema({
      schema_class     => 'Test::DBIx::Class::Example::Schema',
      fixture_class    => '::Populate',
      force_drop_table => 1,
    }), 'Initialized schema without specifying dsn.';

  is $schema_manager->dbname, ':memory:', 'Defaulted to SQLite, memory.';
}

{
  my $dir    = tempdir(CLEANUP => 1);
  my $dbname = catfile($dir, 'mytestdb.sqlite');

  {
    ok !-f $dbname, 'SQLite DB does not yest exist'; 

    ok my $schema_manager = Test::DBIx::Class->_initialize_schema(build_config($dbname, 1)),
      'Initialize schema with keep_db => 1';

    ok -f $dbname, 'SQLite DB was created'; 
  }

  ok -f $dbname, 'SQLite DB was kept, respecting to keep_db';

  unlink $dbname;
}

{
  my $dir    = tempdir(CLEANUP => 1);
  my $dbname = catfile($dir, 'mytestdb.sqlite');

  {
    ok !-f $dbname, 'SQLite DB does not yest exist'; 

    ok my $schema_manager = Test::DBIx::Class->_initialize_schema(build_config($dbname, 0)),
      'Initialize schema with keep_db => 0';

    ok -f $dbname, 'SQLite DB was created'; 
  }

  ok !-f $dbname, 'SQLite DB was deleted when schema manager was destroyed';
}

done_testing;
exit;

sub build_config {
  my ($dbname, $keep) = @_;
  return {
    schema_class     => 'Test::DBIx::Class::Example::Schema',
    connect_info     => ["dbi:SQLite:dbname=$dbname",'',''],
    fixture_class    => '::Populate',
    keep_db          => $keep,
  };
}

