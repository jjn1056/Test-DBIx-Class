package Test::DBIx::Class::SchemaManager::Trait::Replicated; {
	
	use Moose::Role;
	use MooseX::Attribute::ENV;
	use Test::DBIx::Class::Types qw(ReplicantsConnectInfo);

	requires 'deploy_testdb', 'setup', 'prepare_schema_class';

    has deployed_replicants => (is=>'rw', isa=>'ArrayRef', auto_deref=>1);
    
	has replicants => (
		is=>'rw',
		isa=>ReplicantsConnectInfo,
		required=>1,
		coerce=>1,
		auto_deref=>1,
	);

	has pool_args => (
		is=>'ro',
		isa=>'HashRef',
		required=>0,
		predicate=>'has_pool_args',
	);
	
	has balancer_type => (
		is=>'ro',
		isa=>'Str',
		required=>1,
		predicate=>'has_balancer_type',
		default=>'::Random',
	);

	has balancer_args => (
		is=>'ro',
		isa=>'HashRef',
		required=>1,
		predicate=>'has_balancer_args',
		default=> sub {
			return {
				auto_validate_every=>10,
				master_read_weight => 1,
            },	
		},
	);

	has my_replicant_cnf => (
		is=>'ro', 
		isa=>'HashRef', 
		auto_deref=>1,
	);

	has default_replicant_cnf => (
		is=>'ro', 
		init_arg=>undef, 
		isa=>'HashRef', 
		auto_deref=>1, 
		lazy_build=>1,
	);

	sub _build_default_replicant_cnf {
		return {
		};
	}

	sub prepare_replicant_config {
		my ($self, $replicant, @replicants,%extra) = @_;
		my %my_cnf_extra = $extra{my_cnf} ? delete $extra{my_cnf} : ();
        my $port = 8000 + (0+@replicants);
		my %config = (
			my_cnf => {
                'port'=>$port,
                'server-id'=>($replicant->{name}+2),
				$self->default_replicant_cnf,
				$self->my_replicant_cnf,
				%my_cnf_extra,
			},
			%extra,
		);

use Data::Dump 'dump';warn dump %config;

		my $replicant_name =$replicant->{name};
		my $base_dir = $self->test_db_manager->base_dir . "/$replicant_name";

		$config{base_dir} = $base_dir;	
		$config{mysql_install_db} = $self->mysql_install_db if $self->mysql_install_db;	
		$config{mysqld} = $self->mysqld if $self->mysqld;	
		
		return %config;
	}

	around 'prepare_schema_class' => sub {
		my ($prepare_schema_class, $self, @args) = @_;
		my $schema_class = $self->$prepare_schema_class(@args);

		$schema_class->storage_type({
			'::DBI::Replicated' => {
				pool_args => $self->has_pool_args ? $self->pool_args : {},
				balancer_type => $self->has_balancer_type ? $self->balancer_type : '',
				balancer_args => $self->has_balancer_args ? $self->balancer_args : {},
			},
		});

		return $schema_class;
	};

	around 'setup' => sub {
		my ($setup, $self, @args) = @_;

		## Do we need to invent replicants?
		my @replicants = ();
        my @deployed_replicants = ();
		foreach	my $replicant ($self->replicants) {
			if($replicant->{dsn}) {
				push @replicants, $replicant;
			} else {
				## If there is no 'dsn' key, that means we should auto generate
				## a test db and request its connect info.
				$replicant->{name} = defined $replicant->{name} ? $replicant->{name} : ($#replicants+1);
				my %config = $self->prepare_replicant_config($replicant, @replicants);
				my $deployed = $self->deploy_testdb(%config);
				my $replicant_base_dir = $deployed->base_dir;

				Test::More::diag(
					"Starting replicant mysqld with: ".
					$deployed->mysqld.
					" --defaults-file=".$replicant_base_dir . '/etc/my.cnf'.
					" --user=root"
				);

				Test::More::diag("DBI->connect('DBI:mysql:test;mysql_socket=$replicant_base_dir/tmp/mysql.sock','root','')");
                push @deployed_replicants, $deployed;
				push @replicants, 
				  ["DBI:mysql:test;mysql_socket=$replicant_base_dir/tmp/mysql.sock",'root',''];

			}	
		}

        $self->deployed_replicants(\@deployed_replicants);
		$self->replicants(\@replicants);
		$self->schema->storage->ensure_connected;
		$self->schema->storage->connect_replicants($self->replicants);

        foreach my $storage ($self->schema->storage->pool->all_replicant_storages) {
            ## TODO, need to change this to dbh_do
            my $dbh = $storage->_get_dbh;
            $dbh->do("CHANGE MASTER TO  master_host='127.0.0.1',  master_port=3306,  master_user='root',  master_password=''") or warn $dbh->errstr;
            $dbh->do("START SLAVE") or warn $dbh->errstr;
        }

		return $self->$setup(@args);
	};

} 1;

__END__

=head1 NAME

Test::DBIx::Class::SchemaManager::Trait::Replicated - Support Replication 

=head1 DESCRIPTION

This adds support for L<DBIx::Class::Storage::DBI::Replicated> configuration
information.  It allows you to configurate your tests to run against a database
using the supported "master to many slaves" style replication.  Additionally,
if you are using the L<Test::DBIx::Class::SchemaManager::Trait::Testmysql> 
trait, you can use the capacity of that trait to automatically create a
replication cluster, in the same way it allows you to automatically create a
temporary or localized mysql database.  Using this feature you can create,
deploy and test against a mysql native replication cluster without any prior
configuration or setup effort.

Currently L<DBIx::Class> has built in support for Mysql native replication.
Should more replication schemes be added, we will try to leverage existing
code to support them. 

Please note that you may also be interested in L<MySql::Sandbox>, which also
is a tool you can use to automate creating a temporary mysql database.

=head1 CONFIGURATION

In addition to supporting all the configuration options outlined in other
documents (L<Test::DBIx::Class> and L<Test::DBIx::Class::SchemaManager>), this
trait adds the following extended options.  Options are described in brief,
pleace see documentation for L<DBIx::Class::Storage::DBI::Replicated> for more
details.

Currently none of the following options can be populated via %ENV.

=head2 replicants

An array of items where each item can be passed to $schema->connect_info" OR
a number of replicants to automatically deploy.

=head2 pool_args

A hashref of initialization info that gets passed to the Pool object.  See
L<DBIx::Class::Storage::DBI::Replicated::Pool> for argument details.  Currently
the most relevant option is 'maximum_lag', which set your tolerance for how far
behind the master data the replicant can be before it is temporary dropped from
the pool.  Defaults to '0'.

Please note that a value of '0' will not garantee perfect consistence between
the master and a replicant.

=head2 balancer_type

See L<DBIx::Class::Storage::DBI::Replicated/balancer_type> for details.  In
general you can use the default option of 'Random'.

=head2 balancer_args

A hashref of initialization info passed to the Balancer object.

See "balancer_args" in DBIx::Class::Storage::DBI::Replicated.  In general the
most interesting option is 'auto_validate_every' which takes an integer that
indicates the number of seconds between validating all the replications.  Lower
numbers increases consistency by dropping lagging replicants more quickly, but
the validation check requires an SQL query to each replicant, so it's not free
from a performance perspective.


=head1 AUTHOR

John Napiorkowski C<< <jjnapiork@cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009, John Napiorkowski C<< <jjnapiork@cpan.org> >>

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
