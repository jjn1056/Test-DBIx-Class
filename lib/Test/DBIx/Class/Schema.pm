package Test::DBIx::Class::Schema; {

	use Moose;
	use MooseX::Attribute::ENV;
	use Test::DBIx::Class::Types qw(
		TestBuilder SchemaClass ConnectInfo FixtureClass
	);

	has 'keep_db' => (
		traits=>['ENV'],
		is=>'ro',
		isa=>'Bool',
		required=>1, 
		default=>0,	
	);

	has 'builder' => (
		is => 'ro',
		isa => TestBuilder,
		required => 1,
	);

	has 'schema_class' => (
		traits => ['ENV'],
		is => 'ro',
		isa => SchemaClass,
		required => 1,
		coerce => 1,
	);

	has 'connect_info' => (
		is => 'ro',
		isa => ConnectInfo,
		coerce => 1,
		lazy_build => 1,
	);

	has 'schema' => (
		is => 'ro',
		init_arg => undef,
		lazy_build => 1,
	);

	has 'fixture_class' => (
		traits => ['ENV'],
		is => 'ro',
		isa => FixtureClass,
		required => 1,
		coerce => 1,
		default => '::Populate',		
	);

	has 'fixture_command' => (
		is => 'ro',
		init_arg => undef,
		lazy_build => 1,
	);

	has 'fixture_sets' => (
		is => 'ro',
		isa => 'HashRef',
	);

	sub _build_connect_info {
		## TODO should be delegated to a SQLite specific class
		my $self = shift @_;
		my $path = $ENV{SQLITE_TEST_DBNAME} || ':memory:';

		if(-e $path) {
			$self->builder->ok(
				-w $path,
				"Using $path as dbname for default SQLite Driver is accessible"
			);
		}

		return ["dbi:SQLite:dbname=$path",'',''];
	}

	sub get_fixture_sets {
		my ($self, @sets) = @_;
		my @return;
		foreach my $set (@sets) {
			if(my $fixture = $self->fixture_sets->{$set}) {
				push @return, $fixture;
			}
		}
		return @return;
	}

	sub _build_schema {
		my $self = shift @_;
		my $schema_class = $self->schema_class;
		my $connect_info = $self->connect_info;
		return $schema_class->connect($connect_info);
	}

	sub _build_fixture_command {
		my $self = shift @_;
		return $self->fixture_class->new(schema_manager=>$self);
	}

	sub initialize_schema {
		my $class = shift @_;

		if(my $self = $class->new(@_)) {
			$self->setup;
			return $self;
		}
	}

	sub setup {
		my $self = shift @_;
		$self->schema->storage->ensure_connected;
		my $deploy_args = $ENV{FORCE_DROP_TABLE} ? {add_drop_table => 1} : {};
		$self->schema->deploy($deploy_args);
	}

	sub cleanup {
		my $self = shift @_;
		my $schema = $self->schema;

		return unless $schema;

		unless ($self->keep_db) {
			$schema->storage->with_deferred_fk_checks(sub {
				foreach my $source ($schema->sources) {
					my $table = $schema->source($source)->name;
					$schema->storage->dbh->do("drop table $table;");
				}
			});
		}

		$self->schema->storage->disconnect;
	}

	sub reset {
		my $self = shift @_;
		$self->cleanup;
		$self->setup;
	}

	sub install_fixtures {
		my ($self, @args) = @_;
		my $fixture_command = $self->fixture_command;
		if(
			(!ref($args[0]) && ($args[0]=~m/^::/))
			or (ref $args[0] eq 'HASH' && $args[0]->{command}) ) {
			my $arg = ref $args[0] ?  $args[0]->{command} : $args[0];
			my $fixture_class = to_FixtureClass($arg);
			$self->builder->diag("Override default FixtureClass '".$self->fixture_class."' with $fixture_class");
			$fixture_command = $fixture_class->new(schema_manager=>$self);
			shift(@args);
		}
		return $fixture_command->install_fixtures(@args);
	}

	sub DESTROY {
		my $self = shift @_;
		if(defined $self) {
			$self->cleanup;
		}
	}
	
} 1;

__END__

=head1 NAME

Test::DBIx::Class::Schema - Manages a DBIx::Class::Schema for Testing

=head1 DESCRIPTION

This class is a helper for L<Test::DBIx::Class>.  Basically it is a type of
wrapper or adaptor for your schema so we can more easily and quickly deploy it
and cleanup it for the purposes of automated testing.

You shouldn't need to use anything here.  However, we do define %ENV variables
that you might be interested in using (although its probably best to define
inline configuration or use a configuration file_.

=over 4

=item FORCE_DROP_TABLE

Set to a true value will force dropping tables in the deploy phase.  This will
generate warnings in a database (like sqlite) that can't detect if a table 
exists before attempting to drop it.  Safe for Mysql though.

=item KEEP_DB

Usually at the end of tests we cleanup your database and remove all the tables
created, etc.  Sometimes you might want to preserve the database after testing
so that you can 'poke around'.  Personally I think it's better to write tests
for the poking, but sometimes you just need a quick look.

=item SQLITE_TEST_DBNAME

Use this to force the default mysql database to something other than :memory:

=back

=head1 SEE ALSO

The following modules or resources may be of interest.

L<DBIx::Class>, L<Test::DBIx::Class>

=head1 AUTHOR

John Napiorkowski C<< <jjnapiork@cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009, John Napiorkowski C<< <jjnapiork@cpan.org> >>

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

