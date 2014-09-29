package Test::DBIx::Class::SchemaManager;

use Test::More ();
use List::MoreUtils qw(uniq);
use Moo::Role ();
use Test::DBIx::Class::Types qw( :types :to );
use Types::Standard qw(Bool HashRef Str);

use Moo;
use namespace::clean;

has 'force_drop_table' => (
    is=>'rw',
    required=>1,
    isa=>Bool,
    builder=>1,
);
sub _build_force_drop_table {
    $ENV{force_drop_table} || $ENV{FORCE_DROP_TABLE} || 0
}

has 'keep_db' => (
    is=>'ro',
    isa=>Bool,
    required=>1,
    builder=>1,
);
sub _build_keep_db {
    $ENV{keep_db} || $ENV{KEEP_DB} || 0
}

has 'tdbic_debug' => (
    is=>'ro',
    isa=>Bool,
    required=>1,
    builder=>1,
);
sub _build_tdbic_debug {
    $ENV{tdbic_debug} || $ENV{TDBIC_DEBUG} || 0
}

has 'deploy_db' => (
    is=>'ro',
    required=>1,
    isa=>Bool,
    builder=>1,
);
sub _build_deploy_db {
    $ENV{deploy_db} || $ENV{DEPLOY_DB} || 1
}

has 'builder' => (
    is => 'ro',
    isa => TestBuilder,
    required => 1,
);

has 'schema_class' => (
    is => 'ro',
    isa => SchemaManagerClass,
    required => 1,
    coerce => 1,
    builder => 1,
);
sub _build_schema_class {
    $ENV{schema_class} || $ENV{SCHEMA_CLASS}
        || die '"schema_class" is a required parameter';
}

has 'schema' => (
    is => 'ro',
    lazy => 1,
    builder => 1,
);

has 'connect_info' => (
    is => 'ro',
    isa => ConnectInfo,
    coerce => 1,
    lazy => 1,
    builder => 1,
);

has 'connect_opts' => (
    is => 'ro',
    isa => HashRef,
);

has 'deploy_opts' => (
    is => 'ro',
    isa => HashRef,
    default => sub { {} },
);

has 'connect_info_with_opts' => (
    is => 'ro',
    isa => HashRef,
    lazy => 1,
    builder => 1,
);

has 'fixture_class' => (
    is => 'ro',
    isa => FixtureClass,
    required => 1,
    coerce => 1,
    builder => 1,
);
sub _build_fixture_class {
    $ENV{fixture_class} || $ENV{FIXTURE_CLASS} || '::Populate'
}

has 'fixture_command' => (
    is => 'ro',
    init_arg => undef,
    lazy => 1,
    builder => 1,
);

has 'fixture_sets' => (
    is => 'ro',
    isa => HashRef,
);

has 'last_statement' => (
    is=>'rw',
    isa=>Str,
);

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
    my $connect_info = $self->connect_info_with_opts;

    return unless $schema_class;

    $schema_class = $self->prepare_schema_class($schema_class);

    return $schema_class->connect($connect_info);
}

sub _build_connect_info {
    my ($self) = @_;
    if(my $default = $self->can('get_default_connect_info') ) {
        return $self->$default;
    } else {
        Test::More::fail("Can't build a default connect info");
    }
}

sub _build_connect_info_with_opts{
    my ($self) = @_;
    return { %{$self->connect_info}, %{$self->connect_opts || {}} };
}

sub _build_fixture_command {
    my $self = shift @_;
    return $self->fixture_class->new(schema_manager=>$self);
}

sub prepare_schema_class {
    my ($self, $schema_class) = @_;
    return $schema_class;
}

sub initialize_schema {
    my ($class, $config) = @_;

    my @traits = ();
    if(defined $config->{traits}) {
        @traits = ref $config->{traits} ? @{$config->{traits}} : ($config->{traits});
    }

    if(my $connect_info = $config->{connect_info}) {
        $connect_info = to_ConnectInfo($connect_info);
        my ($driver) = $connect_info->{dsn} =~ /dbi:([^:]+):/i;
                    if(lc $driver eq "sqlite") {
                        push @traits, 'SQLite';
                    }
                    # Don't assume mysql means we want Testmysqld; we may
                    # want to connect to a real mysql server to test.
    } else {
        push @traits, 'SQLite'
          unless @traits;
    }
    @traits = map { __PACKAGE__."::Trait::$_"} uniq @traits;
    $config->{traits} = \@traits;

    my $self = Moo::Role->create_class_with_roles($class, @traits)->new($config)
        or return;

    $self->schema->storage->ensure_connected;
    $self->setup if $self->deploy_db;

    return $self;
}

## TODO we need to fix DBIC to allow debug levels and channels
sub _setup_debug {
    my $self = shift @_;
    my $cb = $self->schema->storage->debugcb;

    $self->schema->storage->debug(1);
    $self->schema->storage->debugcb(sub {
        $cb->(@_) if $cb;
        $self->last_statement($_[1]);
    });
}

sub setup {
    my $self = shift @_;
    my $deploy_opts = {%{$self->deploy_opts}, $self->force_drop_table ? (add_drop_table => 1) : ()};
    if(my $schema = $self->schema) {
        eval {
            $schema->deploy($deploy_opts);
        };if($@) {
            Test::More::fail("Error Deploying Schema: $@");
        }
        return $self;
    }
    return;
}

sub cleanup {
    my $self = shift @_;
    my $schema = $self->schema;

    return unless $schema;
    return unless $schema->storage;

    unless ($self->keep_db) {
        $schema->storage->with_deferred_fk_checks(sub {
            foreach my $source ($schema->sources) {
                my $tablesource = $schema->source($source);
                next unless $tablesource;
                my $table = $tablesource->name;
                $schema->storage->dbh->do($self->drop_table_sql($table))
                    if !($schema->source($source)->can('is_virtual') &&
                        $schema->source($source)->is_virtual);
            }
        });
    }

    $self->schema->storage->disconnect;
}

# this has been pushed out to a method so that it can be overriden
# by the traits.
sub drop_table_sql
{
    my $self = shift;
    my $table = shift;
    return "drop table $table";
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
        $self->builder->diag("Override default FixtureClass '".$self->fixture_class."' with $fixture_class") if $self->tdbic_debug;
        $fixture_command = $fixture_class->new(schema_manager=>$self);
        shift(@args);
    }
    return $self->schema->txn_do( sub {
        $fixture_command->install_fixtures(@args);
    });
}

sub DEMOLISH {
    my $self = shift @_;
    if(defined $self) {
        $self->cleanup;
    }
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

Test::DBIx::Class::SchemaManager - Manages a DBIx::Class::SchemaManager for Testing

=head1 DESCRIPTION

this class is a helper for L<Test::DBIx::Class>.  Basically it is a type of
wrapper or adaptor for your schema so we can more easily and quickly deploy it
and cleanup it for the purposes of automated testing.

You shouldn't need to use anything here.  However, we do define %ENV variables
that you might be interested in using (although its probably best to define
inline configuration or use a configuration file).

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

Please Note that KEEP_DB is not intended for use as a way to preserve deployed
databases across tests or test runs.  I realize you may wish to try this as a
way to reduce testing time, since starting and deploying databases can be time
consuming, however it negates the goal we have to properly isolate the test
cases.

If there is tremendous need for this type of feature, we may in the future try
to develop a good working system.  For now I recomment using the C<reset_schema>
(see L<Test::DBIx::Class/reset_schema> for more) and subtests if you want to
try this for a given test run..

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

