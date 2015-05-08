package Test::DBIx::Class::SchemaManager::Trait::Testpostgresql; {
	
	use Moo::Role;
	use MooseX::Attribute::ENV;
	use Test::PostgreSQL;
	use Test::More ();
	use Path::Class qw(dir);


	has postgresqlobj => (
		is=>'ro',
		init_arg=>undef,
		lazy_build=>1,
	);


	has [qw/base_dir initdb postmaster/] => (
		is=>'ro', 
		traits=>['ENV'], 
	);

	sub _build_postgresqlobj {
		my ($self) = @_;
		if($self->keep_db) {
			$ENV{TEST_POSTGRESQL_PRESERVE} = 1;
		}

		my %config = (
			initdb_args => $Test::PostgreSQL::Defaults{initdb_args} ."",
			postmaster_args => $Test::PostgreSQL::Defaults{postmaster_args},
		);

		$config{base_dir} = $self->base_dir if $self->base_dir;	
		$config{initdb} = $self->initdb if $self->initdb;	
		$config{postmaster} = $self->postmaster if $self->postmaster;
		
		if($self->base_dir && -e $self->base_dir) {
			$self->builder->ok(-w $self->base_dir, "Path ".$self->base_dir." is accessible, forcing 'force_drop_table'");
			$self->force_drop_table(1);
		}

		if(my $testdb = Test::PostgreSQL->new(%config)) {
			return $testdb;
		} else {
			die $Test::PostgreSQL::errstr;
		}
	}

	sub get_default_connect_info {
		my ($self) = @_;
		my $port = $self->postgresqlobj->port;

        if ($self->tdbic_debug || ($self->keep_db && !$self->base_dir)){
            Test::More::diag(
                "Starting postgresql with: ".
                $self->postgresqlobj->postmaster.
                ' -p ', $port,
                ' -D ', $self->postgresqlobj->base_dir . '/data'
            );

            Test::More::diag("DBI->connect('DBI:Pg:dbname=template1;host=127.0.0.1;port=$port','postgres',''])");
        }
		return ["DBI:Pg:dbname=template1;host=127.0.0.1;port=$port",'postgres',''];
	}

	after 'cleanup' => sub {
		my ($self) = @_;
		unless($self->keep_db) {
			if($self->base_dir) {
				my $dir = dir($self->base_dir);
				$dir->rmtree;
			}
		}
	};

    around drop_table_sql => sub {
        my $orig = shift;
        my $self = shift;
        my $table = shift;
        return "drop table $table cascade";
    };

} 1;

__END__

=head1 NAME

Test::DBIx::Class::SchemaManager::Trait::Testpostgresql - deploy to a test Postgresql instance

=head1 DESCRIPTION

This trait uses L<Test::PostgreSQL> to auto create a test instance of Postgresql in a
temporary area.  This way you can test against Postgresql without having to create
a test database, users, etc.  Postgresql needs to be installed (but doesn't need to
be running) as well as L<DBD::Pg>.  You need to install these yourself.

Please review L<Test::PostgreSQL> for help if you get stuck.

=head1 CONFIGURATION

This trait supports all the existing features but adds some additional options
you can put into your inlined of configuration files.  These following 
additional configuration options basically map to the options supported by 
L<Test::PostgreSQL> and the docs are adapted shamelessly from that module.

For the most part, if you have Postgresql installed in a normal, findable manner
you should be able to leave all these options blank.

=head2 base_dir

Returns directory under which the postgresql instance is being created. If you leave
this unset we automatically create a place in the temporary directory and then
clean it up later.  Unless you plan to roundtrip to the same database a lot
you can just leave this blank.

Please note if you set this to a particular area, we will delete it unless
you specifically use the 'keep_db' option.  SO be care where you point it!

Here's an example use.  I often want the test database setup in my local
testing directory, that makes it easy for me to examine the logs, etc.  I do:

	BASE_DIR=t/tmp KEEP_DB=1 prove -lv t/my-postgresql-test.t

Now I can roundtrip the test as often as I want and in between tests I can
review the logs, start the database manually and login (see the 'keep_db'
section below for an example of how to do this).  Next time I run the tests
the framework will automatically clean it up and rest the schema for testing.

You may need to do this if you are stuck on a shared host and can't write
anything to /tmp.  Remember, you can also put the 'base_dir' option into
configuration instead of having to type it into the commandline each time!

Note that if you override the BASE_DIR we will set the 'force_drop_tables'
option to true to ensure that we properly clean the database before trying
to install tables and fixtures.

=head2 initdb and postmaster

If your postgresql is not in the $PATH you might need to specify the location
to one of there binaries.  If you have a normal postgresql setup this should 
not be a problem and you can leave this blank.

If you have to set these, please note you need to set the full path to the
required file, not just the path to containing directory.

=head1 NOTES

The following are notes regarding the way this trait alters or extends the 
core functionality as described in the basic documentation.

=head2 keep_db

If you use the 'keep_db' option, this will preserve the temporarily created
database files, however it will not prevent L<Test::PostgreSQL> from stopping the
database when you are finished.  This is a safety measure, since if we didn't
stop a test generated database instance automatically, you could easily end up
with many databases running at once, and that could bring your server or testing
box to a halt.

If you use the 'keep_db' option and want to start and log into the test generated
database instance, you can start the database by noticing the diagnostic output
that should be generated at the top of your test.  It will look similar to:

	# Starting postgresql with: /Library/PostgreSQL/8.4/bin/postmaster \
	 -p 15432 -D /tmp/E4tuZF5uFR/data
	# DBI->connect('DBI:Pg:dbname=template1;port=15432','postgres',''])

If you have specified the base_dir to use, this output will not be displayed by
default. You can force it's display by setting tdbic_debug to true. eg.

    TDBIC_DEBUG=1 BASE_DIR=t/tmp KEEP_DB=1 prove -lv t/my-postgresql-test.t

You can then start the database instance yourself with something like:

	./Library/PostgreSQL/8.4/bin/postmaster -p 15432 \
	-D /tmp/E4tuZF5uFR/data &

You will get output that looks like:

	[1] 1564
	LOG:  database system is ready to accept connections
	LOG:  autovacuum launcher started

There will be some additional output to the term and then the server will go
into the background.  If you don't like the extra output, you can just redirect
it all to /dev/null or whatever is similar for your OS.

You can now log into the test generated database instance with:

	psql -h localhost --user postgres --port 15432 -d template1

You may need to specify the full path to 'mysql' if it's not in your search 
$PATH.

When you are finished you can then kill the process.  In this case our reported
process id is '1564'

	kill 1564

And then you might wish to 'tidy' up temp

	rm -rf /tmp/E4tuZF5uFR

All the above assume you are on a unix or unixlike system.  Would welcome 
document patches for how to do all the above on windows.

=head2 Noisy warnings

When running the L<Test::PostgreSQL> instance, you'll probably see a lot of
mostly harmless warnings, similar to:

	NOTICE:  drop cascades to 2 other objects
	DETAIL:  drop cascades to constraint cd_track_fk_cd_id_fkey on table cd_track
	drop cascades to constraint cd_artist_fk_cd_id_fkey on table cd_artist
	NOTICE:  CREATE TABLE / PRIMARY KEY will create implicit index "cd_pkey" for table "cd"

In general these are harmless and can be ignored.

If you like to avoid these messages, you could change your connect_info like this:

    connect_info => {
        dsn => 'dbi:Pg:dbname=dbname', 
        user => 'user', 
        pass => 'secret',
        on_connect_do => 'SET client_min_messages=WARNING;',
    },

=head1 AUTHOR

John Napiorkowski C<< <jjnapiork@cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009, John Napiorkowski C<< <jjnapiork@cpan.org> >>

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
