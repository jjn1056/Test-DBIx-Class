use Test::More;

use strict;
use warnings;

require_ok 'Test::DBIx::Class';

note('default connect_info + connect_opts'); {

    ok my $config = {
        schema_class => 'Test::DBIx::Class::Example::Schema',
        connect_opts => { name_sep => '.', quote_char => '`', },
    }, 'Created Sample inline configuration';

    ok my $schema_manager = Test::DBIx::Class->_initialize_schema($config)
      => 'Connected and deployed a testable schema';

    my $connect_info = $schema_manager->connect_info_with_opts;

    is $connect_info->{name_sep}, '.', 'connect info name_sep ok';
    is $connect_info->{quote_char}, '`', 'connect info quote_char ok';

}

note('set connect_info + connect_opts'); {

    ok my $config = {
        schema_class => 'Test::DBIx::Class::Example::Schema',
        connect_info => ['dbi:SQLite:dbname=:memory:','',''],
        connect_opts => { name_sep => '.', quote_char => '`', },
    }, 'Created Sample inline configuration';

    ok my $schema_manager = Test::DBIx::Class->_initialize_schema($config)
      => 'Connected and deployed a testable schema';

    my $connect_info = $schema_manager->connect_info_with_opts;

    is $connect_info->{name_sep}, '.', 'connect info name_sep ok';
    is $connect_info->{quote_char}, '`', 'connect info quote_char ok';

}


done_testing;



