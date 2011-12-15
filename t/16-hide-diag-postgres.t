use Test::More; {

	use strict;
	use warnings;
	use File::Path qw!rmtree!;

	require_ok 'Test::DBIx::Class';

    my $builder = Test::DBIx::Class->builder;
    my $fh;
    $builder->failure_output(\$fh);

	ok my $config = {
		schema_class => 'Test::DBIx::Class::Example::Schema',
        traits => [qw!Testpostgresql!],
	}, 'Created Sample inline configuration';

    #-------------------
    note('tdbic_debug=1');

    $config->{tdbic_debug} = 1;
    $fh = '';

    my $manager = Test::DBIx::Class::SchemaManager->initialize_schema({
        %$config, 
        builder => $builder,
    });

    cmp_ok $fh, '=~', '# Starting postgresql with:', 'diag emitted';

    #-------------------
    note('tdbic_debug=0');

    $config->{tdbic_debug} = 0;
    $fh = '';

    my $manager2 = Test::DBIx::Class::SchemaManager->initialize_schema({
        %$config, 
        builder => $builder,
    });

    ok !$fh, 'no diag emitted';

    #-------------------
    note('keep_db=1');

    $config->{keep_db} = 1;
    $fh = '';

    my $manager3 = Test::DBIx::Class::SchemaManager->initialize_schema({
        %$config, 
        builder => $builder,
    });

    cmp_ok $fh, '=~', '# Starting postgresql with:', 'diag emitted';

    my ($dir) = $fh =~ m!\s\-D\s(/tmp/\w+)/data!;
    rmtree($dir);


	done_testing();
}
