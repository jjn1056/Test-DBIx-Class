package Test::DBIx::Class;

use 5.008;
use strict;
use warnings;

use base 'Test::Builder::Module';

our $VERSION = '0.39';
our $AUTHORITY = 'cpan:JJNAPIORK';

use Config::Any;
use Data::Visitor::Callback;
use Digest::MD5;
use Hash::Merge;
use Path::Class;
use Scalar::Util ();
use Sub::Exporter;
use Test::DBIx::Class::SchemaManager;
use Test::Deep ();
use Test::More ();

sub eq_or_diff2 {
    my ($given, $expected, $message) = @_;
    my ($ok, $stack) = Test::Deep::cmp_details($given, $expected);
    if($ok) {
        Test::More::pass($message);
    } else {
        my $diag = Test::Deep::deep_diag($stack);
        Test::More::fail("$message: $diag");
    }
}

sub import {
    my ($class, @opts) = @_;
    my ($schema_manager, $merged_config, @exports) = $class->_initialize(@opts);
    my $exporter = Sub::Exporter::build_exporter({
        exports => [
            dump_settings => sub {
                return sub {
                    return $merged_config, @exports;
                };
            },
            Schema => sub {
                return sub {
                    return $schema_manager->schema;
                }
            },
            ResultSet => sub {
                my ($local_class, $name, $arg) = @_;
                return sub {
                    my $source = shift @_;
                    my $search = shift @_;
                    my $resultset = $schema_manager->schema->resultset($source);

                    if(my $global_search = $arg->{search}) {
                        my @global_search = ref $global_search eq 'ARRAY' ? @$global_search : ($global_search);
                        $resultset = $resultset->search(@global_search);
                    }

                    if(my $global_cb = $arg->{exec}) {
                        $resultset = $global_cb->($resultset);
                    }

                    if($search) {
                        my @search = ref $search ? @$search : ($search, @_);
                        $resultset = $resultset->search(@search);
                    }

                    return $resultset;
                }
            },
            is_result => sub {
                my ($local_class, $name, $arg) = @_;
                my $global_class = defined $arg->{isa_class} ? $arg->{isa_class} : '';
                return sub {
                    my $rs = shift @_;
                    my $compare = shift @_ || $global_class || "DBIx::Class";
                    my $message = shift @_;
                    Test::More::isa_ok($rs, $compare, $message);
                }
            },
            is_resultset => sub {
                my ($local_class, $name, $arg) = @_;
                my $global_class = defined $arg->{isa_class} ? $arg->{isa_class} : '';
                return sub {
                    my $rs = shift @_;
                    my $compare = shift @_ || $global_class || "DBIx::Class::ResultSet";
                    my $message = shift @_;
                    Test::More::isa_ok($rs, $compare, $message);
                }
            },
            eq_result => sub {
                return sub {
                    my ($result1, $result2, $message) = @_;
                    $message = defined $message ? $message : ref($result1) . " equals " . ref($result2);
                    if( ref($result1) eq ref($result2) ) {
                        eq_or_diff2(
                            {$result2->get_columns},
                            {$result1->get_columns},
                            $message,
                        );
                    } else {
                        Test::More::fail($message ." :Result arguments not of same class");
                    }
                },
            },
            eq_resultset => sub {
                return sub {
                    my ($rs1, $rs2, $message) = @_;
                    $message = defined $message ? $message : ref($rs1) . " equals " . ref($rs2);
                    if( ref($rs1) eq ref($rs2) ) {
                        ($rs1, $rs2) = map {
                            my $me = $_->current_source_alias;
                            my @pks = map { "$me.$_"} $_->result_source->primary_columns;
                            my @result = $_->search({}, {
                                result_class => 'DBIx::Class::ResultClass::HashRefInflator',
                                order_by => [@pks],
                            })->all;
                            [@result];
                        } ($rs1, $rs2);

                        eq_or_diff2([$rs2],[$rs1],$message);
                    } else {
                        Test::More::fail($message ." :ResultSet arguments not of same class");
                    }
                },
            },
            hri_dump => sub {
                return sub {
                    (shift)->search ({}, {
                        result_class => 'DBIx::Class::ResultClass::HashRefInflator'
                    });
                }
            },
            fixtures_ok => sub {
                return sub {
                    my ($arg, $message) = @_;
                    $message = defined $message ? $message : 'Fixtures Installed';

                    if ($arg && ref $arg && (ref $arg eq 'CODE')) {
                        eval {
                            $arg->($schema_manager->schema);
                        }; if($@) {
                            Test::More::fail($message);
                            $schema_manager->builder->diag($@);

                        } else {
                            Test::More::pass($message);
                        }
                    } elsif( $arg && ref $arg && (ref $arg eq 'HASH' || ref $arg eq 'ARRAY') ) {
                        my @return;
                        eval {
                            @return = $schema_manager->install_fixtures($arg);
                        }; if($@) {
                            Test::More::fail($message);
                            $schema_manager->builder->diag($@);
                        } else {
                            Test::More::pass($message);
                            return @return;
                        }
                    } elsif( $arg ) {
                        my @sets = ref $arg ? @$arg : ($arg);
                        my @fixtures = $schema_manager->get_fixture_sets(@sets);
                        my @return;
                        foreach my $fixture (@fixtures) {
                            eval {
                                push @return, $schema_manager->install_fixtures($fixture);
                            }; if($@) {
                                Test::More::fail($message);
                                $schema_manager->builder->diag($@);
                            } else {
                                Test::More::pass($message);
                                return @return;
                            }
                        }
                    } else {
                        Test::More::fail("Can't figure out what fixtures you want");
                    }
                }
            },
            is_fields => sub {
                my ($local_class, $name, $arg) = @_;
                my @default_fields = ();
                if(defined $arg && ref $arg eq 'HASH' && defined $arg->{fields}) {
                    @default_fields = ref $arg->{fields} ? @{$arg->{fields}} : ($arg->{fields});
                }
                return sub {
                    my @args = @_;
                    my @fields = @default_fields;
                    if(!ref($args[0]) || (ref($args[0]) eq 'ARRAY')) {
                        my $fields = shift(@args);
                        @fields = ref $fields ? @$fields : ($fields); 
                    } 
                    if(Scalar::Util::blessed($args[0]) && 
                        $args[0]->isa('DBIx::Class') && 
                        !$args[0]->isa('DBIx::Class::ResultSet')
                    ) {
                        my $result = shift(@args);
                        unless(@fields) {
                            my @pks = $result->result_source->primary_columns;
                            push @fields, grep {
                                my $field = $_; 
                                $field ne ((grep { $field eq $_ } @pks)[0] || '')
                            } ($result->result_source->columns);
                        }
                        my $compare = shift(@args);
                        if(ref $compare eq 'HASH') {
                        } elsif(ref $compare eq 'ARRAY') {
                            my @localfields = @fields;
                            $compare = {map {
                                my $value = $_;
                                my $key = shift(@localfields);
                                $key => $value } @$compare};
                            Test::More::fail('Too many fields!') if @localfields;
                        } elsif(!ref $compare) {
                            my @localfields = @fields;
                            $compare = {map {
                                my $value = $_;
                                my $key = shift(@localfields);
                                $key => $value } ($compare)};
                            Test::More::fail('Too many fields!') if @localfields;
                        }
                        my $message = shift(@args) || 'Fields match';
                        my $compare_rs = {map {
                            die "$_ is not an available field"
                              unless $result->can($_); 
                            $_ => $result->$_ } @fields};
                        eq_or_diff2($compare,$compare_rs,$message);
                        return $compare;
                    } elsif (Scalar::Util::blessed($args[0]) && $args[0]->isa('DBIx::Class::ResultSet')) {

                        my $resultset = shift(@args);
                        unless(@fields) {
                            my @pks = $resultset->result_source->primary_columns;
                            push @fields, grep {
                                my $field = $_; 
                                $field ne ((grep { $field eq $_ } @pks)[0] || '')
                            } ($resultset->result_source->columns);
                        }
                        my @compare = @{shift(@args)};
                        foreach (@compare) {
                            if(!ref $_) {
                                my @localfields = @fields;
                                $_ = {map {
                                    my $value = $_;
                                    my $key = shift(@localfields);
                                    $key => $value } ($_)};
                                Test::More::fail('Too many fields!') if @localfields;
                            } elsif(ref $_ eq 'ARRAY') {
                                my @localfields = @fields;
                                $_ = {map {
                                    my $value = $_;
                                    my $key = shift(@localfields);
                                    $key => $value } (@$_)};
                                Test::More::fail('Too many fields!') if @localfields;
                            }
                        }
                        my $message = shift(@args) || 'Fields match';

                        my @resultset = $resultset->search({}, {
                                result_class => 'DBIx::Class::ResultClass::HashRefInflator',
                                columns => [@fields],
                            })->all;
                        my %compare_rs;
                        foreach my $row(@resultset) {
                            no warnings 'uninitialized';
                            my $id = Digest::MD5::md5_hex(join('.', map {$row->{$_}} sort keys %$row));
                            $compare_rs{$id} = { map { $_,"$row->{$_}"} keys %$row};
                        }
                        my %compare;
                        foreach my $row(@compare) {
                            no warnings 'uninitialized';
                            my $id = Digest::MD5::md5_hex(join('.', map {$row->{$_}} sort keys %$row));
                            ## Force comparison stuff in stringy form :(
                            $compare{$id} = { map { $_,"$row->{$_}"} keys %$row};
                        }
                        eq_or_diff2(\%compare,\%compare_rs,$message);
                        return \@compare;
                    } else {
                        die "I'm not sure what to do with your arguments";
                    }
                };
            },
            reset_schema => sub {
                return sub {
                    my $message = shift @_ || 'Schema reset complete';
                    $schema_manager->reset;
                    Test::More::pass($message);
                }
            },
            cleanup_schema => sub {
                return sub {
                    my $message = shift @_ || 'Schema cleanup complete';
                    $schema_manager->cleanup;
                    Test::More::pass($message);
                }
            },
            map {
                my $source = $_;
                 $source => sub {
                    my ($local_class, $name, $arg) = @_;
                    my $resultset = $schema_manager->schema->resultset($source);
                    if(my $search = $arg->{search}) {
                        my @search = ref $search eq 'ARRAY' ? @$search : ($search);
                        $resultset = $resultset->search(@search);
                    }
                    return sub {
                        my $search = shift @_;
                        if($search) {
                            my @search = ();
                            if(ref $search && ref $search eq 'HASH') {
                                @search = ($search, @_); 
                            } else {
                                @search = ({$search, @_});
                            }
                            return $resultset->search(@search);
                        }
                        return $resultset;
                    }
                };
            } $schema_manager->schema->sources,
        ],
        groups => {
            resultsets => [$schema_manager->schema->sources],
        },
        into_level => 1,    
    });

    $class->$exporter(
        qw/Schema ResultSet is_result is_resultset hri_dump fixtures_ok reset_schema
            eq_result eq_resultset is_fields dump_settings cleanup_schema /,
         @exports
    );
}

sub _initialize {
    my ($class, @opts) = @_;
    my ($config, @exports) = $class->_normalize_opts(@opts);
    my $merged_config = $class->_prepare_config($config);

    if(my $resultsets = delete $merged_config->{resultsets}) {
        if(ref $resultsets eq 'ARRAY') {
            push @exports, @$resultsets;
        } else {
            die '"resultsets" options must be a Array Reference.';
        }
    }
    my $merged_with_fixtures_config = $class->_prepare_fixtures($merged_config);
    my $visitor = Data::Visitor::Callback->new(plain_value=>\&_visit_config_values);
    $visitor->visit($merged_with_fixtures_config);

    my $schema_manager = $class->_initialize_schema($merged_with_fixtures_config);

    return (
        $schema_manager,
        $merged_config,
        @exports,
    );
}

sub _visit_config_values {
    return unless $_;

    &_config_substitutions($_);
    
}

sub _config_substitutions {
    my $subs = {};
    $subs->{ ENV } = 
        sub { 
            my ( $v ) = @_;
            if (! defined($ENV{$v})) {
                Test::More::fail("Missing environment variable: $v");
                return '';
            } else {
                return $ENV{ $v }; 
            }
        };
    $subs->{ literal } ||= sub { return $_[ 1 ]; };
    my $subsre = join( '|', keys %$subs );

    for ( @_ ) {
        s{__($subsre)(?:\((.+?)\))?__}{ $subs->{ $1 }->( $2 ? split( /,/, $2 ) : () ) }eg;
    }
}

sub _normalize_opts {
    my ($class, @opts) = @_;
    my ($config, @exports) = ({},());

    if(ref $opts[0]) {
        if(ref $opts[0] eq 'HASH') {
            $config = shift(@opts);
        } else {
            die 'First argument to "use Test::DBIx::Class @args" not properly formed.';
        }
    }

    while( my $opt = shift(@opts)) {
        if($opt =~m/^-(.+)/) {
            if($config->{$1}) {
                die "$1 already is defined as $config->{$1}";
            } else {
                $config->{$1} = shift(@opts);
            }
        } else {
            @exports = ($opt, @opts);
            last;
        }
    }

    if(my $resultsets = delete $config->{resultsets}) {
        if(ref $resultsets eq 'ARRAY') {
            push @exports, @$resultsets;
        } else {
            die '"resultsets" options must be a Array Reference.';
        }
    }

    @exports = map { ref $_ && ref $_ eq 'ARRAY' ? @$_:$_ } @exports;

    return ($config, @exports);
}

sub _prepare_fixtures {
    my ($class, $config) = @_;

    my @dirs;
    if(my $fixture_path = delete $config->{fixture_path}) {
        @dirs = $class->_normalize_config_path(
            $class->_default_fixture_paths, $fixture_path, 
        );
    } else {
        @dirs = $class->_normalize_config_path($class->_default_fixture_paths);
    }

    my @extensions = $class->_allowed_extensions;
    my @files = (
        grep { $class->_is_allowed_extension($_) }
        map {Path::Class::dir($_)->children} 
        grep { -e $_  }
        @dirs
    );

    my $fixture_definitions = Config::Any->load_files({
        files => \@files,
        use_ext => 1,
    });

    my %merged_fixtures;
    foreach my $fixture_definition(@$fixture_definitions) {
        my ($path, $fixture) = %$fixture_definition;
        ## hack to normalize arrayref fixtures.  needs work!!!
        $fixture = ref $fixture eq 'HASH' ? [$fixture] : $fixture;
        my $file = Path::Class::file($path)->basename;
        $file =~s/\..{1,4}$//;
        if($merged_fixtures{$file}) {
            my $old_fixture = $merged_fixtures{$file};
            my $merged_fixture = Hash::Merge::merge($fixture, $old_fixture);
            $merged_fixtures{$file} = $merged_fixture;
        } else {
            $merged_fixtures{$file} = $fixture;
        }
    }

    if(my $old_fixture_sets = delete $config->{fixture_sets}) {
        ## hack to normalize arrayref fixtures.  needs work!!!
        my %normalized_old_fixture_sets = map {
            ref($old_fixture_sets->{$_}) eq 'HASH' ? ($_, [$old_fixture_sets->{$_}]): ($_, $old_fixture_sets->{$_});
        } keys %$old_fixture_sets;
        my $new_fixture_sets = Hash::Merge::merge(\%normalized_old_fixture_sets, \%merged_fixtures );
        $config->{fixture_sets} = $new_fixture_sets;
    } else {
        $config->{fixture_sets} = \%merged_fixtures;
    }

    return $config;
}

sub _is_allowed_extension {
    my ($class, $file) = @_;
    my @extensions = $class->_allowed_extensions;
    foreach my $extension(@extensions) {
        if($file =~ m/\.$extension$/) {
            return $file;
        }
    }
    return;
}

sub _prepare_config {
    my ($class, $config) = @_;

    if(my $extra_config = delete $config->{config_path}) {
        my @config_data = $class->_load_via_config_any($extra_config);
        foreach my $config_datum(reverse @config_data) {
            $config = Hash::Merge::merge($config, $config_datum);
        }
    } else {
        my @config_data = $class->_load_via_config_any();
        foreach my $config_datum(reverse @config_data) {
            $config = Hash::Merge::merge($config, $config_datum);
        }
    }

    if(my $post_config = delete $config->{config_path}) {
        my @post_config_paths = $class->_normalize_external_paths($post_config); 
        my @extensions = $class->_allowed_extensions;
        my @post_config_files =  grep { -e $_} map {
            my $path = $_; 
            map {
            $ENV{TEST_DBIC_CONFIG_SUFFIX} ? 
              ("$path.$_", "$path$ENV{TEST_DBIC_CONFIG_SUFFIX}.$_") : 
              ("$path.$_");
            } @extensions;
        } map {
            my @local_path = ref $_ ? @$_ : ($_);
            Path::Class::file(@local_path);
        } @post_config_paths;

        my $post_config = $class->_config_any_load_files(@post_config_files);
        foreach my $config_datum(reverse map { values %$_ } @$post_config) {
            $config = Hash::Merge::merge($config, $config_datum);
        }
    }

    return $config;
}

sub _load_via_config_any {
    my ($class, $extra_paths) = @_;
    my @files = $class->_valid_config_files($class->_default_paths, $extra_paths);
    my $config = $class->_config_any_load_files(@files);

    my @config_data = map { values %$_ } @$config;
    return @config_data;
}

sub _config_any_load_files {
    my ($class, @files) = @_;

    return Config::Any->load_files({
        files => \@files,
        use_ext => 1,
    });
}

sub _valid_config_files {
    my ($class, $default_paths, $extra_paths) = @_;
    my @extensions = $class->_allowed_extensions;
    my @paths = $class->_normalize_config_path($default_paths, $extra_paths);
    my @config_files = grep { -e $_} map { 
        my $path = $_; 
        map { 
            $ENV{TEST_DBIC_CONFIG_SUFFIX} ? 
              ("$path.$_", "$path$ENV{TEST_DBIC_CONFIG_SUFFIX}.$_") : 
              ("$path.$_");
        } @extensions;
     } @paths;

    return @config_files;
}

sub _allowed_extensions {
    return @{ Config::Any->extensions };
}

sub _normalize_external_paths {
    my ($class, $extra_paths) = @_;
    my @extra_paths;
    if(!ref $extra_paths) {
        @extra_paths = ([$extra_paths]); ## "t/etc" => (["t/etc"])
    } elsif(ref $extra_paths eq 'ARRAY') {
        if(!ref $extra_paths->[0]) {
            @extra_paths = ($extra_paths); ## [qw( t etc )]
        } elsif( ref $extra_paths->[0] eq 'ARRAY') {
            @extra_paths = @$extra_paths;
        }
    }
    return @extra_paths;
}

sub _normalize_config_path {
    my ($class, $default_paths, $extra_paths) = @_;

    if(defined $extra_paths) {
        my @extra_paths = map { "$_" eq "+" ? @$default_paths : $_ } map {
            my @local_path = ref $_ ? @$_ : ($_);
            Path::Class::file(@local_path);
        } $class->_normalize_external_paths($extra_paths);

        return @extra_paths;    
    } else {
        return @$default_paths;
    }
}

sub _script_path {
    return ($0 =~m/^(.+)\.t$/)[0];
}

sub _default_fixture_paths {
    my ($class) = @_;
    my $script_path = Path::Class::file($class->_script_path);
    my $script_dir = $script_path->dir;
    my @dir_parts = $script_dir->dir_list(1);

    return [
        Path::Class::file(qw/t etc fixtures/),
        Path::Class::file(qw/t etc fixtures/, @dir_parts, $script_path->basename),
    ];

}

sub _default_paths {
    my ($class) = @_;
    my $script_path = Path::Class::file($class->_script_path);
    my $script_dir = $script_path->dir;
    my @dir_parts = $script_dir->dir_list(1);

    if(
        $script_path->basename eq 'schema' &&
        (scalar(@dir_parts) == 0 )
    ) {
      return [
        Path::Class::file(qw/t etc schema/),
      ];

    } else {
      return [
        Path::Class::file(qw/t etc schema/),
        Path::Class::file(qw/t etc /, @dir_parts, $script_path->basename),
      ];
}
}

sub _initialize_schema {
    my $class = shift @_;
    my $config  = shift @_;
    my $builder = __PACKAGE__->builder;
    
    my $fail_on_schema_break = delete $config->{fail_on_schema_break};
    my $schema_manager;
     eval {
        $schema_manager = Test::DBIx::Class::SchemaManager->initialize_schema({
            %$config, 
            builder => $builder,
        });
    }; if ($@ or !$schema_manager) {
        Test::More::diag("Can't initialize a schema with the given configuration");
        Test::More::diag("Returned Error: ".$@) if $@;
        Test::More::diag(
            Test::More::explain("configuration: " => $config)
        );
        # FIXME: make this optional.
        if($fail_on_schema_break)
        {
            Test::More::fail("Failed remaining tests since we don't have a schema");
            Test::More::done_testing();
            $builder->finalize();
            exit(0);
        }
        else
        {
            $builder->skip_all("Skipping remaining tests since we don't have a schema");
        }
    }

    return $schema_manager
}

1;

__END__

=head1 NAME

Test::DBIx::Class - Easier test cases for your DBIx::Class applications

=head1 SYNOPSIS

The following is example usage for this module.  Assume you create a standard
Perl testing script, such as "MyApp/t/schema/01-basic.t" which is run from the
shell like "prove -l t/schema/01-basic.t" or during "make test".  That test 
script could contain:

    use Test::More;

    use strict;
    use warnings;

    use Test::DBIx::Class {
        schema_class => 'MyApp::Schema',
        connect_info => ['dbi:SQLite:dbname=:memory:','',''],
        connect_opts => { name_sep => '.', quote_char => '`', },
        fixture_class => '::Populate',
    }, 'Person', 'Person::Employee' => {-as => 'Employee'}, 'Job', 'Phone';

    ## Your testing code below ##

    ## Your testing code above ##

    done_testing;

Yes, it looks like a lot of boilerplate, but sensible defaults are in place
(the above code example shows most of the existing defaults) and configuration
data L<can be loaded from a central file|/"CONFIGURATION BY FILE">.  So,
assuming you put all of your test configuration in the standard place, your
'real life' example is going to look closer to:

    use Test::More;
        
    use strict;
    use warnings;
    use Test::DBIx::Class qw(:resultsets);

    ## Your testing code below ##
    ## Your testing code above ##

    done_testing;

Then, assuming the existence of a L<DBIx::Class::Schema> subclass called,
"MyApp::Schema" and some L<DBIx::Class::ResultSources> named like "Person", 
"Person::Employee", "Job" and "Phone", will automatically deploy a testing 
schema in the given database / storage (or auto deploy to an in-memory based
L<DBD::SQLite> database), install fixtures and let you run some test cases, 
such as:

    ## Your testing code below ##

    fixtures_ok 'basic'
      => 'installed the basic fixtures from configuration files';

    fixtures_ok [ 
        Job => [
            [qw/name description/],
            [Programmer => 'She who writes the code'],
            ['Movie Star' => 'Knows nothing about the code'],
        ],
    ], 'Installed some custom fixtures via the Populate fixture class',

    
    ok my $john = Person->find({email=>'jjnapiork@cpan.org'})
      => 'John has entered the building!';

    is_fields $john, {
        name => 'John Napiorkowski', 
        email => 'jjnapiork@cpan.org', 
        age => 40,
    }, 'John has the expected fields';

    is_fields ['job_title'], $john->jobs, [
        {job_title => 'programmer'},
        {job_title => 'administrator'},
    ], 
    is_fields 'job_title', $john->jobs, 
        [qw/programmer administrator/],
        'Same test as above, just different compare format;


    is_fields [qw/job_title salary/], $john->jobs, [
        ['programmer', 100000],
        ['administrator, 120000],
    ], 'Got expected fields from $john->jobs';

    is_fields [qw/name age/], $john, ['John Napiorkowski', 40],
      => 'John has expected name and age';

    is_fields_multi 'name', [
        $john, ['John Napiorkowski'],
        $vanessa, ['Vanessa Li'],
        $vincent, ['Vincent Zhou'],
    ] => 'All names as expected';

    is_fields 'fullname', 
        ResultSet('Country')->find('USA'), 
        'United States of America',
        'Found the USA';

    is_deeply [sort Schema->sources], [qw/
        Person Person::Employee Job Country Phone
    /], 'Found all expected sources in the schema';

    fixtures_ok my $first_album = sub {
        my $schema = shift @_;
        my $cd_rs = $schema->resultset('CD');
        return $cd_rs->create({
            name => 'My First Album',
            track_rs => [
                {position=>1, title=>'the first song'},
                {position=>2, title=>'yet another song'},
            ],
            cd_artist_rs=> [
                {person_artist=>{person => $vanessa}},
                {person_artist=>{person => $john}},
            ],
        });
    }, 'You can even use a code reference for custom fixtures';

    ## Your testing code above ##

Please see the test cases for more examples.

=head1 DESCRIPTION

The goal of this distribution is to make it easier to write test cases for your
L<DBIx::Class> based applications.  It does this in three ways.  First, it trys
to make it easy to deploy your Schema.  This can be to your dedicated testing
database, or a simple SQLite database.  This allows you to run tests without 
interfering with your development work and having to stop and set up a testing 
database instance.

Second, we allow you to load test fixtures via several different tools.  Last
we create some helper functions in your test script so that you can reduce
repeated or boilerplate code.

Overall, we attempt to reduce the amount of code you have to write before you
can begin writing tests.

=head1 IMPORTED METHODS

The following methods are automatically imported when you use this module.

=head2 Schema

You probably won't need this directly in your tests unless you have some
application logic methods in it.


=head2 ResultSet ($source, ?{%search}, ?{%conditions})

Although you can import your sources as local keywords, sometimes you might
need to get a particular resultset when you don't wish to import it globally.
Use like

    ok ResultSet('Job'), "Yeah, some jobs in the database";
    ok ResultSet( Job => {hourly_pay=>{'>'=>100}}), "Good paying jobs available!";

Since this returns a normal L<DBIx::Class::ResultSet>, you can just call the
normal methods against it.

    ok ResultSet('Job')->search({hourly_pay=>{'>'=>100}}), "Good paying jobs available!";

This is the same as the test above.

=head2 fixtures_ok

This is used to install and verify installation of fixtures, either inlined,
from a fixture set in a file, or through a custom sub reference.  Accept three
argument styles:

=over 4

=item coderef

Given a code reference, execute it against the currently defined schema.  This
is used when you need a lot of control over installing your fixtures.  Example:

    fixtures_ok sub {
        my $schema = shift @_;
        my $cd_rs = $schema->resultset('CD');
        return $cd_rs->create({
            name => 'My First Album',
            track_rs => [
                {position=>1, title=>'the first song'},
                {position=>2, title=>'yet another song'},
            ],
            cd_artist_rs=> [
                {person_artist=>{person => $vanessa}},
                {person_artist=>{person => $john}},
            ],
        });

    }, 'Installed fixtures';

The above gets executed at runtime and if there is an error it is trapped,
reported and we move on to the next test.

=item arrayref

Given an array reference, attempt to process it via the default fixtures loader
or through the specified loader.

    fixtures_ok [
        Person => [
            ['name', 'age', 'email'],
            ['John', 40, 'john@nowehere.com'],
            ['Vincent', 15, 'vincent@home.com'],
            ['Vanessa', 35, 'vanessa@school.com'],
        ],
    ], 'Installed fixtures';

This is a good option to use while you are building up your fixture sets or
when your sets are going to be small and not reused across lots of tests.  This
will get you rolling without messing around with configuration files.

=item fixture set name

Given a fixture name, or array reference of names, install the fixtures.

    fixtures_ok 'core';
    fixtures_ok [qw/core extra/];

Fixtures are installed in the order specified.

=back

All different types can be mixed and matched in a given test file.

=head2 is_result ($result, ?$result)

Quick test to make sure $result does inherit from L<DBIx::Class> or that it
inherits from a subclass of L<DBIx::Class>.

=head2 is_resultset ($resultset, ?$resultset)

Quick test to make sure $resultset does inherit from L<DBIx::Class::ResultSet>
or from a subclass of L<DBIx::Class::ResultSet>.

=head2 eq_resultset ($resultset, $resultset, ?$message)

Given two ResultSets, determine if the are equal based on class type and data.
This is a true set equality that ignores sorting order of items inside the
set.

=head2 eq_result ($resultset, $resultset, ?$message)

Given two row objects, make sure they are the same.

=head2 hri_dump ($resultset)

Not a test, just returns a version of the ResultSet that has its inflator set
to L<DBIx::Class::ResultClass::HashRefInflator>, which returns a set of hashes
and makes it easier to stop issues.  This return value is suitable for dumping
via L<Data::Dump>, for example.

=head2 reset_schema

Wipes and reloads the schema.

=head2 cleanup_schema

Wipes schema and disconnects.

=head2 dump_settings

Returns the configuration and related settings used to initialize this testing
module.  This is mostly to help you debug trouble with configuration and to help
the authors find and fix bugs.  At some point this won't be exported by default
so don't use it for your real tests, just to help you understand what is going
on.  You've been warned!

=head2 is_fields

A 'Swiss Army Knife' method to check your results or resultsets.  Tests the 
values of a Result or ResultSet against expected via a pattern.  A pattern
is automatically created by instrospecting the fields of your ResultSet or
Result.

Example usage for testing a result follows.

    ok my $john = Person->find('john');

    is_fields 'name', $john, ['John Napiorkowski'],
      'Found name of $john';

    is_fields [qw/name age/], $john, ['John Napiorkowski', 40],
      'Found $johns name and age';

    is_fields $john, {
        name => 'John Napiorkowski',
        age => 40,
        email => 'john@home.com'};  # Assuming $john has only the three columns listed

In the case where we need to infer the match pattern, we get the columns of the
given result but remove the primary key.  Please note the following would also
work:

    is_fields [qw/name age/] $john, {
        name => 'John Napiorkowski',
        age => 40}, 'Still got the name and age correct'; 

You should choose the method that makes most sense in your tests.

Example usage for testing a resultset follows.

    is_fields 'name', Person, [
        'John',
        'Vanessa',
        'Vincent',
    ];

    is_fields ['name'], Person, [
        'John',
        'Vanessa',
        'Vincent',
    ];

    is_fields ['name','age'], Person, [
        ['John',40],
        ['Vincent',15],
        ['Vanessa',35],
    ];

    is_fields ['name','age'], Person, [
        {name=>'John', age=>40},
        {name=>'Vanessa',age=>35},
        {name=>'Vincent', age=>15},
    ];

I find the array version is most consise.  Please note that the match is not
ordered.  If you need to test that a given Resultset is in a particular order,
you will currently need to write a custom test.  If you have a big need for 
this I'd be willing to write a test for it, or gladly accept a patch to add it.

You should examine the test cases for more examples.

=head2 is_fields_multi

    TBD: Not yet written.

=head1 SETUP AND INITIALIZATION

The generic usage for this would look like one of the following:

    use Test::DBIx::Class \%options, @sources
    use Test::DBIx::Class %options, @sources

Where %options are key value pairs and @sources an array as specified below.

=head2 Initialization Options

The only difference between the hash and hash reference version of %options
is that the hash version requires its keys to be prepended with "-".  If
you are inlining a lot of configuration the hash reference version may look
neater, while if you are only setting one or two options the hash version
might be more readable.  For example, the following are the same:

    use Test::DBIx::Class -config_path=>[qw(t etc config)], 'Person', 'Job';
    use Test::DBIx::Class {config_path=>[qw(t etc config)]}, 'Person', 'Job';

The following options are currently standard and always available.  Depending
on your storage engine (such as SQLite or MySQL) you will have other options.

=over 4

=item config_path

These are the relative paths searched for configuration file information. See
L</Initialization Sources> for more.

In the case were we have both inlined and file based configurations, the 
inlined is merged last (that is, has highest authority to override configuration
files).

When the final merging of all configurations (both anything inlined at 'use'
time, and anything found in any of the specified config_paths, we do a single
'post' config_path check.  This allows you to add in a configuration file from
inside a configuration file.  For safety and sanity you can only do this once.
This feature makes it easier to globalize any additional configuration files.
For example, I often store user specific settings in "~/etc/conf.*".  This
feature allows me to add that into my standard "t/etc/schema.*" so it's 
available to all my test cases.

=item schema_class

Required. This must be your subclass of L<DBIx::Class::Schema> that defines
your database schema. 

=item connect_info

Required. This will accept anything you can send to L<DBIx::Class/connect>.
Defaults to: ['dbi:SQLite:dbname=:memory:','',''] if left blank (but see
'traits' below for more)

=item connect_opts

Use this to customise connect_info if you have left that blank in order to
have the dsn auto-generated, but require extra attributes such as name_sep
and quote_char.

=item deploy_opts

Use this to customise any arguments that are to be passed to
L<DBIx::Class::Schema/deploy>, such as add_drop_table or quote_identifiers.

=item fixture_path

These are a list of relative paths search for fixtures.  Each item should be
a directory that contains files loadable by L<Config::Any> and suitable to
be installed via one of the fixture classes.

=item fixture_class

Command class that installs data into the database.  Must provide a method
called 'install_fixtures' that accepts a perl data structure and installs
it into the database.  Must capture and report errors.  Default value is
"::Populate", which loads L<Test::DBIx::Class::FixtureCommand::Populate>, which
is a command class based on L<DBIx::Class::Schema/populate>.

=item resultsets

Lets you add in some result source definitions to be imported at test script
runtime.  See L</Initialization Sources> for more.

=item force_drop_table

When deploying the database this option allows you add a 'drop table' statement
before the create ddl.  Since this will return an error if you attempt to drop
a table that doesn't exist, this is off by default for SQLite storage engines.
You may need to enble it you you are using the following 'keep_db' option.

=item keep_db

By default your testing database is 'cleaned up' after you are finished.  This
drops all the created tables (but currently doesn't delete any related files
or database users, if any).  If you want to keep your testing database after
all the tests are run, you can set this to true.  If so, you may also need to
set the previously mentioned option 'force_drop_table' to true as well, or we
will attempt to create tables and populate them when they are already populated
and created.

=item deploy_db

By default a fresh version of the schema is deployed when 'Test::DBIx::Class'
is invoked.  If you want to skip the schema deployment and instead connect
to an already existing and populated database, set this option to false.

=item traits

Traits are L<Moose::Role>s that are applied to the class managing the connection
to your database.  If you leave this option blank and you don't specify anything
for 'connect_info' (above), we automatically load the SQLite trait (which can
be reviewed at L<Test::DBIx::Class::SchemaManager::Trait::SQLite>).  This trait
installs the ability to automatically discover and deploy to an in memory or a
filesystem SQLite database.  If you are just getting started with testing, this
is probably your easiest option.

Currently there are only three traits, the SQLite trait just described (and since
it get's automatically loaded you never need to load it yourself). The
L<Test::DBIx::Class::SchemaManager::Trait::Testmysqld> trait, which is built on
top of L<Test::mysqld> and allows you the ability to deploy to and run tests
against a temporary instance of MySQL. For this trait MySQL and L<DBD::mysql>
needs to be installed, but MySQL does not need to be running, nor do you need
to create a test database or user.   The third one is the 
L<Test::DBIx::Class::SchemaManager::Trait::Testpostgresql> trait, which is
built on top of L<Test::postgresql> and allows you to deploy to and run tests
against a temporary instance of Postgresql.  For this trait Postgresql
and L<DBD::Pg> needs to be installed, but Postgresql does not need to be
running, nor do you need to create a test database or user.  
See L</TRAITS> for more.

=item fail_on_schema_break

Makes the test run fail when the schema can not be created.  Normally the
test run is skipped when the schema fails to create.  A failure can be more
convenient when you want to spot compilation failures.  

=back

Please note that although all initialization options can be set inlined or in
a configuration file, some options can also be set via %ENV variables. %ENV
settings will only apply IF there are no existing values for the option in any
configuration file.  As of this time we don't merge %ENV settings, they only
provider overrides to the default settings. Example use (assumes you are
using the default SQLite database)

    DBNAME=test.db KEEP_DB=1 prove -lv t/schema/check-person.t

After running the test there will be a new file called 'test.db' in the home
directory of your distribution.  You can use:

    sqlite3 test.db

to open and view the tables and their data as loaded by any fixtures or create
statements. See L<Test::DBIx::Class::SchemaManager::Trait::SQLite> for more.
Note that you can specify both 'dbpath' and 'keep_db' in your configuration
files if you prefer.  I tried to expose a subset of configuration to %ENV that
I thought the most useful.  Patches and suggestions welcomed.

=head2 Initialization Sources

The @sources are a list of result sources that you want helper methods injected
into your test script namespace.  This is the 'Source' part of:

    $schema->resultset('Source');

Injecting methods are optional since you can also use the 'ResultSet' keyword

Imported Source keywords use L<Sub::Exporter> so you have quite a few options
for controling how the keywords are imported.  For example:

    use Test::DBIx::Class 
      'Person',
      'Person::Employee' => {-as => 'Employee'},
      'Person' => {search => {age=>{'>'=>55}}, -as => 'OlderPerson'};

This would import three local keywork methods, "Person", "Employee" and 
"OlderPerson".  For "OlderPerson", the search parameter would automatically be
resolved via $resultset->search and the correct resultset returned.  You may
wish to preconfigure all your test result set cases in one go at the top of
your test script as a way to promote reusability.

In addition to the 'search' parameter, there is also an 'exec' parameter
which let's you process your resultset programatically.  For example:

    'Person' => {exec => sub { shift->older_than(55) }, -as => 'OlderPerson'};

This code reference gets passed the resultset object.  So you can use any 
method on $resultset.  For example:

    'Person' => {exec => sub { shift->find('john') }, -as => 'John'}; 

    is_result John;
    is John->name, 'John Napiorkowski', "Got Correct Name";

Although since fixtures will not yet be installed, the above is probably not
going to be a normally working example :)

Additionally, since you can also initialize sources via the 'resultsets'
configuration option, which can be placed into your global configuration files
this means you can predefine and result resultsets across all your tests.  Here
is an example 't/etc/schema.pl' file where I initialize pretty much everything
in one file:

     {
      'schema_class' => 'Test::DBIx::Class::Example::Schema',
      'resultsets' => [
        'Person',
        'Job',
        'Person' => { '-as' => 'NotTeenager', search => {age=>{'>'=>18}}},
      ],
      'fixture_sets' => {
        'basic' => [
          'Person' => [
            [
              'name',
              'age',
              'email'
            ],
            [
              'John',
              '40',
              'john@nowehere.com'
            ],
            [
              'Vincent',
              '15',
              'vincent@home.com'
            ],
            [
              'Vanessa',
              '35',
              'vanessa@school.com'
            ]
          ]
        ]
      },
    };

In this case you can simple do "use Test::DBIx::Class" and everything will
happen automatically.

=head1 CONFIGURATION BY FILE

By default, we try to load configuration fileis from the following locations:

     ./t/etc/schema.*
     ./t/etc/[test file path].*

Where "." is the root of the distribution and "*" is any of the configuration
file types supported by L<Config::Any> configuration loader.  This allows you
to store configuration in the format of your choice.

"[test file path]" is the relative path part under the "t" directory of the
calling test script.  For example, if your test script is "t/mytest.t" we add
the path "./t/etc/mytest.*" to the path.

Additionally, we do a merge using L<Hash::Merge> of all the matching found
configurations.  This allows you to do 'cascading' configuration from the most
global to the most local settings.

You can override this search path with the "-config_path" key in options. For
example, the following searches for "t/etc/myconfig.*" (or whatever is the
correct directory separator for your operating system):

    use Test::DBIx::Class -config_path => [qw/t etc myconfig/];

Relative paths are rooted to the distribution home directory (ie, the one that
contains your 'lib' and 't' directories).  Full paths are searched without
modification.

You can specify multiply paths.  The following would search for both "schema.*"
and "share/schema".

    use Test::DBIx::Class -config_path => [[qw/share schema/], [qw/schema/]];

Lastly, you can use the special symbol "+" to indicate that your custom path
adds to or prepends to the default search path.  Since as indicated we merge
all the configurations found, this means it's easy to create user level 
configuration settings mixed with global settings, as in:

    use Test::DBIx::Class
        -config_path => [ 
            [qw(/ etc myapp test-schema)],
            '+',
            [qw(~ etc test-schema)],
        ];

Which would search and combine "/etc/myapp/test-schema.*", "./t/etc/schema.*",
"./etc/[test script name].*" and "~/etc/test-schema.*".  This would let you set
up server level global settings, distribution level settings and finally user
level settings.

Please note that in all the examples given, paths are written as an array
reference of path parts, rather than as a string with delimiters (i.e. we do
[qw(t etc)] rather than "t/etc").  This is not required but recommended.  All
arguments, either string or array references, are passed to L<Path::Class> so
that we can maintain better compatibility with non unix filesystems.  If you
are writing for CPAN, please consider our non Unix filesystem friends :)

Lastly, there is an %ENV variable named '' which, if it
exists, can be used to further customize your configuration path.  If we find
that $ENV{TEST_DBIC_CONFIG_SUFFIX} is set, we attempt to find configuration files
with the suffix appended to each of the items in the config_path option.  So, if
you have:

    use Test::DBIx::Class
        -config_path => [ 
            [qw(/ etc myapp test-schema)],
            '+',
            [qw(~ etc test-schema)],
        ];
        
and $ENV{TEST_DBIC_CONFIG_SUFFIX} = '-mysql' we will check the following paths
for valid and loading configuration files (assuming unix filesystem conventions)

    /etc/myapp/test-schema.*
    /etc/myapp/test-schema-mysql.*
    ./t/etc/schema.*    
    ./t/etc/schema-mysql.*
    ./etc/[test script name].*
    ./etc/[test script name]-mysql.*
    ~/etc/test-schema.*
    ~/etc/test-schema-mysql.*
    
Each path is testing in turn and all found configurations are merged from top to
bottom.  This feature is intended to make it easier to switch between sets of
configuration files when developing.  For example, you can create a test suite
intended for a MySQL database, but allow a failback to the default Sqlite should
certain enviroment variables not exist.

=head1 CONFIGURATION SUBSTITUTIONS

Similarly to L<Catalyst::Plugin::ConfigLoader>, there are some macro style 
keyword inflators available for use within your configuration files.  This
allows you to set the value of a configuration setting from an external source,
such as from %ENV.  There are currently two macro substitutions:

=over 4

=item ENV

Given a value in %ENV, substitute the keyword for the value of the named
substitution.  For example, if you had:

    email = 'vanessa__ENV(TEST_DBIC_LAST_NAME)__@school.com'

in your configuration filem your could:

    TEST_DBIC_LAST_NAME=_lee prove -lv t/schema-your-test.t

and then:

    is $vanessa->email, 'vanessa_lee@school.com', 'Got expected email';

You might find this useful for configuring localized username and passwords
although personally I'd rather set that via configuration in the user home
directory.

=back

=head1 TRAITS

As described, a trait is a L<Moose::Role> that is applied to the class managing
your database and test instance.  Currently we only have the default 'SQLite'
trait and the 'Testmysqld' trait, but we eventually intend to have traits to
add easy support for creating Postgresql databases and supporting testing on
replicated systems.

Traits are installed by the 'traits' configuration option, which expects an
ArrayRef as its input (however will also normalize a scalar to an ArrayRef).

Available traits are as follows.

=head2 SQLite

This is the default trait which will be loaded if no other traits are installed
and there is not 'connect_info' in the configuration.  In this case we assume
you want us to go and create a tempory SQLite database for testing.  Please see
L<Test::DBIx::Class::SchemaManager::Trait::SQLite> for more.

=head2 Testmysqld

If MySQL is installed on the testing machine, and L<DBD::mysql>, we try to auto
create an instance of MySQL and deploy our tests to that.  Similarly to the way
the SQLite trait works, we attempt to create the database without requiring any
other using effort or setup.

See L<Test::DBIx::Class::SchemaManager::Trait::Testmysqld> for more.

=head2 Testpostgresql

If Postgresql is installed on the testing machine, along with L<DBD::Pg>, we try
to auto create an instance of Postgresql in a testing area and deploy our tests
and fixtures to it.

See L<Test::DBIx::Class::SchemaManager::Trait::Testpostgresql> for more.

=head1 SEE ALSO

The following modules or resources may be of interest.

L<DBIx::Class>, L<DBIx::Class::Schema::PopulateMore>, L<DBIx::Class::Fixtures>

=head1 AUTHOR

    John Napiorkowski C<< <jjnapiork@cpan.org> >>

=head1 CONTRIBUTORS

    Tristan Pratt
    Tomas Doran C<< <bobtfish@bobtfish.net> >>
    Kyle Hasselbacher C<< kyleha@gmail.com >>
    cvince
    colinnewell
    rbuels
    wlk
    yanick
    hippich
    lecstor
    bphillips
    abraxxa
    oalders

=head1 COPYRIGHT & LICENSE

Copyright 2012, John Napiorkowski C<< <jjnapiork@cpan.org> >>

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
