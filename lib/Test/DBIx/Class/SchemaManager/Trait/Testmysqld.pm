package Test::DBIx::Class::SchemaManager::Trait::Testmysqld;

use Moose::Role;
use Test::mysqld;
use Test::More ();
use Path::Class qw(dir);
use Test::DBIx::Class::Types qw(ReplicantsConnectInfo);
use Socket;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use Types::Standard qw(ArrayRef HashRef Str);

requires 'setup', 'cleanup';

## has '+force_drop_table' => (is=>'rw',default=>1);

has base_dir => (is => 'ro', builder => '_build_base_dir');
sub _build_base_dir { $ENV{base_dir} || $ENV{BASE_DIR} }
has mysql_install_db => (is => 'ro', builder => '_build_mysql_install_db');
sub _build_mysql_install_db { $ENV{mysql_install_db} || $ENV{MYSQL_INSTALL_DB} }
has mysqld => (is => 'ro', builder => '_build_mysqld');
sub _build_mysqld { $ENV{mysqld} || $ENV{MYSQLD} }

has test_db_manager => (
    is=>'ro',
    init_arg=>undef,
    lazy_build=>1,
);

sub _build_test_db_manager {
    my $self = shift @_;
    my %config = $self->prepare_config(@_);

    if($self->keep_db) {
        $ENV{TEST_MYSQLD_PRESERVE} = 1;
    }

    if(my $testdb = $self->deploy_testdb(%config)) {
        return $testdb;
    } else {
        die $Test::mysqld::errstr;
    }
}

has default_cnf => (
    is=>'ro',
    init_arg=>undef,
    isa=>HashRef,
    auto_deref=>1,
    lazy_build=>1,
);

sub _build_default_cnf {
    my $port = $_[0]->find_next_unused_port();
    return {
        'server-id'=>1,
        'log-bin'=>'mysql-bin',
        'binlog-do-db'=>'test',
        'port'=>$port,
    };
}

has port_to_try_first => (
    is=>'rw',
    default=> sub { 8000 + int(rand(2000)) },
);

has my_cnf => (
    is=>'ro',
    isa=>HashRef,
    auto_deref=>1,
);

## Replicant stuff... probably should be a delegate

has deployed_replicants => (is=>'rw', isa=>ArrayRef, auto_deref=>1);

has replicants => (
    is=>'rw',
    isa=>ReplicantsConnectInfo,
    coerce=>1,
    auto_deref=>1,
    predicate=>'has_replicants',
);

has pool_args => (
    is=>'ro',
    isa=>HashRef,
    required=>0,
    predicate=>'has_pool_args',
);

has balancer_type => (
    is=>'ro',
    isa=>Str,
    required=>1,
    predicate=>'has_balancer_type',
    default=>'::Random',
);

has balancer_args => (
    is=>'ro',
    isa=>HashRef,
    required=>1,
    predicate=>'has_balancer_args',
    default=> sub {
        return {
            auto_validate_every=>10,
            master_read_weight => 1,
        },
    },
);

has default_replicant_cnf => (
    is=>'ro',
    init_arg=>undef,
    isa=>HashRef,
    auto_deref=>1,
    required=>1,
    default=> sub { +{} },
);

has my_replicant_cnf => (
    is=>'ro',
    isa=>HashRef,
    auto_deref=>1,
);

sub prepare_replicant_config {
    my ($self, $replicant, @replicants,%extra) = @_;
    my %my_cnf_extra = $extra{my_cnf} ? delete $extra{my_cnf} : ();
    my $port = $self->find_next_unused_port();
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

    my $replicant_name =$replicant->{name};
    my $base_dir = $self->test_db_manager->base_dir . "/$port" .'_'. "$replicant_name";

    $config{base_dir} = $base_dir;
    $config{mysql_install_db} = $self->mysql_install_db if $self->mysql_install_db;
    $config{mysqld} = $self->mysqld if $self->mysqld;

    return %config;
}

around 'prepare_schema_class' => sub {
    my ($prepare_schema_class, $self, @args) = @_;
    my $schema_class = $self->$prepare_schema_class(@args);
    if($self->has_replicants) {
        $schema_class->storage_type({
            '::DBI::Replicated' => {
                pool_args => $self->has_pool_args ? $self->pool_args : {},
                balancer_type => $self->has_balancer_type ? $self->balancer_type : '',
                balancer_args => $self->has_balancer_args ? $self->balancer_args : {},
            },
        });
    }

    return $schema_class;
};

around 'setup' => sub {
    my ($setup, $self, @args) = @_;

    return $self->$setup(@args) unless $self->has_replicants;

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

            if ($self->tdbic_debug || ($self->keep_db && !$self->base_dir)){
                Test::More::diag(
                    "Starting replicant mysqld with: ".
                    $deployed->mysqld.
                    " --defaults-file=".$replicant_base_dir . '/etc/my.cnf'.
                    " --user=root"
                );
                Test::More::diag("DBI->connect('DBI:mysql:test;mysql_socket=$replicant_base_dir/tmp/mysql.sock','root','')");
            }

            push @deployed_replicants, $deployed;
            push @replicants,
              ["DBI:mysql:test;mysql_socket=$replicant_base_dir/tmp/mysql.sock",'root',''];

        }
    }


    $self->deployed_replicants(\@deployed_replicants);
    $self->replicants(\@replicants);
    $self->schema->storage->connect_replicants($self->replicants);
    $self->schema->storage->ensure_connected;
    my $port =  $self->default_cnf->{port};  ## TODO I doubt this is correct.....

    foreach my $storage ($self->schema->storage->pool->all_replicant_storages) {
        ## TODO, need to change this to dbh_do
        my $dbh = $storage->_get_dbh;
        $dbh->do("STOP SLAVE") || die $dbh->errst;
        $dbh->do("CHANGE MASTER TO  master_host='127.0.0.1',  master_port=$port,  master_user='root',  master_password=''")
            || die $dbh->errstr;
        $dbh->do("START SLAVE")
            || die $dbh->errstr;
    }

    return $self->$setup(@args);
};

sub prepare_config {
    my ($self, %extra) = @_;
    my %my_cnf_extra = $extra{my_cnf} ? delete $extra{my_cnf} : ();
    my %config = (
        my_cnf => {
            $self->default_cnf,
            $self->my_cnf,
            %my_cnf_extra,
        },
        %extra,
    );
    my $port = $self->default_cnf->{port};
    my $cleanup = ($ENV{TEST_MYSQLD_PRESERVE} || $self->keep_db) ? undef : 1;
    $config{base_dir} = $self->base_dir ? $self->base_dir ."/$port" : tempdir(CLEANUP => $cleanup) . "/$port";
    make_path($config{base_dir}) unless -e $config{base_dir};
    $config{mysql_install_db} = $self->mysql_install_db if $self->mysql_install_db;
    $config{mysqld} = $self->mysqld if $self->mysqld;

    return %config;
}

sub deploy_testdb {
    my ($self, %config) = @_;
    return Test::mysqld->new(%config);
}

sub get_default_connect_info {
    my $self = shift @_;
    my $deployed_db = shift(@_) || $self->test_db_manager;
    my $base_dir = $deployed_db->base_dir;

    if ($self->tdbic_debug || ($self->keep_db && !$self->base_dir)){
        Test::More::diag(
            "Starting mysqld with: ".
            $deployed_db->mysqld.
            " --defaults-file=".$base_dir . '/etc/my.cnf'.
            " --user=root"
        );

        Test::More::diag("DBI->connect('DBI:mysql:test;mysql_socket=$base_dir/tmp/mysql.sock','root','')");
    }

    return ["DBI:mysql:test;mysql_socket=$base_dir/tmp/mysql.sock",'root',''];
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

sub is_port_open {
    my ($port) = @_;
    my ($host, $iaddr, $paddr, $proto);

    $host  =  '127.0.0.1';
    $iaddr   = inet_aton($host)
        or die "no host: $host";
    $paddr   = sockaddr_in($port, $iaddr);

    $proto   = getprotobyname('tcp');
    socket(SOCK, PF_INET, SOCK_STREAM, $proto)
        or die "error creating test socket for port $port: $!";
    if (connect(SOCK, $paddr)) {
        close (SOCK)
            or die "error closing test socket: $!";
        return 1;
    }
    return 0;
}

our $next_port;
sub find_next_unused_port {
    $next_port ||= $_[0]->port_to_try_first;
    my $port = $next_port;
    while (is_port_open($port)) {
        $port++;
        if ($port > 0xFFF0) {
            die "no ports available\n";
        }
    }
    ++$next_port;
    return $port;
}

1;

__END__

=head1 NAME

Test::DBIx::Class::SchemaManager::Trait::Testmysqld - deploy to a test mysql instance

=head1 DESCRIPTION

This trait uses L<Test::mysqld> to auto create a test instance of mysql in a
temporary area.  This way you can test against mysql without having to create
a test database, users, etc.  Mysql needs to be installed (but doesn't need to
be running) as well as L<DBD::mysql>.  You need to install these yourself.

Please review L<Test::mysqld> for help if you get stuck.


=head1 CONFIGURATION

This trait supports all the existing features but adds some additional options
you can put into your inlined configuration files.  These following additional
configuration options basically map to the options supported by L<Test::mysqld>
and the docs are adapted shamelessly from that module.

For the most part, if you have mysql installed in a normal, findable manner
you should be able to leave all these options blank.

=head2 base_dir

Returns directory under which the mysqld instance is being created. If you leave
this unset we automatically create a place in the temporary directory and then
clean it up later.  Unless you plan to roundtrip to the same database a lot
you can just leave this blank.

Please note if you set this to a particular area, we will delete it unless
you specifically use the 'keep_db' option.  SO be care where you point it!

Here's an example use.  I often want the test database setup in my local
testing directory, that makes it easy for me to examine the logs, etc.  I do:

	BASE_DIR=t/tmp KEEP_DB=1 prove -lv t/my-mysql-test.t

Now I can roundtrip the test as often as I want and in between tests I can
review the logs, start the database manually and login (see the 'keep_db'
section below for an example of how to do this).  Next time I run the tests
the framework will automatically clean it up and rest the schema for testing.

You may need to do this if you are stuck on a shared host and can't write
anything to /tmp.  Remember, you can also put the 'base_dir' option into
configuration instead of having to type it into the commandline each time!

=head2 my_cnf

A hashref containing the list of name=value pairs to be written into "my.cnf",
which is the primary configuration file for the mysql instance.  Again, unless
you have some specific needs you can leave this empty, since we set the few
things most needed to get a server running.  You will need to review the
documentation on the Mysql website for options related to this.

=head2 port_to_try_first

This is the port that will be used when starting mysqld. We check that this
port is available for use before starting mysqld. If it is not available we
increment by 1 and try again. We use the first free port found.

By default this is a random port between 8000 and 10000. The randomness is
an attempt to avoid race condition issues when running tests in parallel,
between checking the availability of a port and actually starting the server.
Spreading the "first port" numbers used greatly reduces the chance of these
issues occuring.

=head2 mysql_install_db or mysqld

If your mysqld is not in the $PATH you might need to specify the location to
one of there binaries.  If you have a normal mysql setup this should not be
a problem and you can leave this blank.

For example, I often use L<MySQL::Sandbox> to setup various versions of mysql
in my local user directory, particularly if I am on a shared host, or in the
case where I don't want mysql installed globally.  Personally I think this is
really your safest option (and there will probably be a trait based on this
in the future)

=head1 NOTES

The following are notes regarding the way this trait alters or extends the
core functionality as described in the basic documentation.

=head2 force_drop_table

Since it is always safe to use the 'force_drop_table' option with mysql, we set
the default to true.  We recommend you leave it this way, particularly if you
want to 'roundtrip' the same test database.

=head2 keep_db

If you use the 'keep_db' option, this will preserve the temporarily created
database files, however it will not prevent L<Test::mysqld> from stopping the
database when you are finished.  This is a safety measure, since if we didn't
stop a test generated database instance automatically, you could easily end up
with many databases running at once, and that could bring your server or testing
box to a halt.

If you use the 'keep_db' option and want to start and log into the test generated
database instance, you can start the database by noticing the diagnostic output
that should be generated at the top of your test.  It will look similar to:

	# Starting mysqld with: /usr/local/mysql/bin/mysqld --defaults-file=/tmp/KHKfJf0Yf6/etc/my.cnf --user=root

If you have specified the base_dir to use, this output will not be displayed by
default. You can force it's display by setting tdbic_debug to true. eg.

	TDBIC_DEBUG=1 BASE_DIR=t/tmp KEEP_DB=1 prove -lv t/my-mysql-test.t

You can then start the database instance yourself with something like:

	/usr/local/mysql/bin/mysqld --defaults-file=/tmp/WT0P0VutAe/etc/my.cnf \
	--user=root &
	[1] 3447
	....
	090827 15:06:16  InnoDB: Started; log sequence number 0 78863
	090827 15:06:16 [Note] Event Scheduler: Loaded 0 events
	090827 15:06:16 [Note] /usr/local/mysql/bin/mysqld: ready for connections.
	Version: '5.1.37'  socket: '/tmp/WT0P0VutAe/tmp/mysql.sock'  port: 0  MySQL Community Server (GPL)

There will be some additional output to the term and then the server will go
into the background.  If you don't like the extra output, you can just redirect
it all to /dev/null or whatever is similar for your OS.

You can now log into the test generated database instance with:

	mysql --socket=/tmp/WT0P0VutAe/tmp/mysql.sock -u root test

You may need to specify the full path to 'mysql' if it's not in your search
$PATH.

When you are finished you can then kill the process.  In this case our reported
process id is '3447'

	kill 3447

And then you might wish to 'tidy' up temp

	rm -rf /tmp/WT0P0VutAe

All the above assume you are on a unix or unixlike system.  Would welcome
document patches for how to do all the above on windows.

=head1 AUTHOR

John Napiorkowski C<< <jjnapiork@cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009, John Napiorkowski C<< <jjnapiork@cpan.org> >>

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
