
# testing options while respecting external ENV variables
#
# KEEP_DB=1
#    keep all databases created
# BASE_DIR=1
#    use the specified base dir
#    don't emit diag (we know where the databases are created)
# KEEP_DB=1 && BASE_DIR=0
#    emit diag (so we can see where databases are created)
# KEEP_DB=0
#    clean up all databases created
#    don't emit diag (we don't need to know where the databases are created)

use Test::More; {

	use strict;
	use warnings;

	BEGIN {
		eval "use Test::PostgreSQL"; if($@) {
			plan skip_all => 'Test::PostgreSQL not installed';
		}
	}

	use File::Path qw!rmtree!;

    use FindBin qw($Bin);

    use lib "$Bin/lib";
    use TDBICOptions;

    my $env_keep_db = $ENV{KEEP_DB};
    my $env_base_dir = $ENV{BASE_DIR};

    #TDBICOptions::check_base_dir();

	require_ok 'Test::DBIx::Class';

    TDBICOptions::notify();

    my $dirs_created = {};

    my $builder = Test::DBIx::Class->builder;
    my $fh;
    $builder->failure_output(\$fh);

	ok my $config = {
		schema_class => 'Test::DBIx::Class::Example::Schema',
        traits => [qw!Testpostgresql!],
        tdbic_debug => 0,
        keep_db => $env_keep_db,
        connect_opts => {
            on_connect_do => 'SET client_min_messages=WARNING;',
        },
	}, 'Created Sample inline configuration';

    #-------------------
    note('tdbic_debug=1');

    $config->{tdbic_debug} = 1;
    $fh = '';

    my $manager = Test::DBIx::Class::SchemaManager->initialize_schema({
        %$config, 
        builder => $builder,
    });

    undef $manager;

    cmp_ok $fh, '=~', '# Starting postgresql with:', 'diag emitted';
    print ("$fh\n") if $env_keep_db;

    my $dir = dir_created($fh);
    print "# ERROR: could not identify dir from diag:\n$fh\n" unless $dir;

    #-------------------
    note('tdbic_debug=0');

    $config->{tdbic_debug} = 0;
    $fh = '';

    $manager = Test::DBIx::Class::SchemaManager->initialize_schema({
        %$config, 
        builder => $builder,
    });

    undef $manager;

    if ($env_keep_db && !$env_base_dir){
        ok $fh, 'diag emitted as KEEP_DB was true and BASE_DIR was not';
        print ("$fh\n");
        my $dir = dir_created($fh);
        print "# ERROR: could not identify dir from diag:\n$fh\n" unless $dir;
    } else{
        ok !$fh, 'no diag emitted';
    }

    #-------------------
    note('keep_db=1');

    $config->{keep_db} = 1;
    $fh = '';

    $manager = Test::DBIx::Class::SchemaManager->initialize_schema({
        %$config, 
        builder => $builder,
    });

    undef $manager;

    if ($env_base_dir){
        ok !$fh, 'no diag emitted as BASE_DIR was true';
    } else {
        cmp_ok ($fh, '=~', '# Starting postgresql with:', 'diag emitted') or diag $fh;
        print ("$fh\n") if $env_keep_db;
    }

    $dir = dir_created($fh);
    print "# ERROR: could not identify dir from diag:\n$fh\n" unless $dir;

    TDBICOptions::print_dirs_created($dirs_created);

	done_testing();


    sub dir_created{
        my $diag = $_[0];
        my $regex = qr!\s\-D\s(/tmp/\w+)/data!;
        return TDBICOptions::dir_created($dirs_created, $regex, $diag);
    }

}
