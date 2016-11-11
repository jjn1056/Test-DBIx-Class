package Test::DBIx::Class::SchemaManager::Trait::SQLite; {
	
	use Moose::Role;
	use MooseX::Attribute::ENV;
	use Test::DBIx::Class::Types qw(ConnectInfo);

	sub dbname {
		my ($self) = @_;

		my $env_path = $ENV{DBNAME};
		my $dsn      = $self->{connect_info}{dsn};  

		if($env_path) {
			return $env_path;
		}
		elsif($dsn) {
			my ($dbname) = $self->_extract_dbname_from_dsn($dsn);
			if($dbname) {
				return $dbname;
			}
			else {
				croak("Couldn't find dbname in sqlite dsn '$dsn'");
			}
		}
		else {
			return ':memory:';
		}
	}

    sub _extract_dbname_from_dsn
    {
        my ($self, $dsn) = @_;
        my ($dbname) = $dsn =~ m/dbi:[^:]+:(?:dbname=)?(.+)/i;
        return $dbname;
    }

	sub get_default_connect_info {
		my ($self) = @_;
		return ["dbi:SQLite:dbname=".$self->dbname,'',''];
	}

	before 'setup' => sub {
		my ($self) = @_;
		if(my $path = $ENV{DBNAME}) {
			if(-e $path) {
				$self->builder->ok(-w $path, "Path $path is accessible, forcing 'force_drop_table'");
				$self->force_drop_table(1);
			}
		}
	};

	after 'cleanup' => sub {
		my ($self) = @_;
		if(!$self->keep_db && lc $self->dbname ne ':memory:') {
			unlink $self->dbname;
		}
	};
} 1;

__END__

=head1 NAME

Test::DBIx::Class::SchemaManager::Trait::SQLite - The Default Role

=head1 DESCRIPTION

The default Storage trait which provides the ability to deploy to a SQLite
database.  It also sets some %ENV and or configuration options that you can
use to specify alternative database setup.

In addition to the documented %ENV settings, this Trait adds the following:

=over 4

=item DBNAME

Defaults to ':memory:' to create an in memory database.  Provide a string
suitable for the "dbname=XXX" part of your connect string.  Typically this
should be the path to a location on the filesystem you want the datbase file
to be stored.

Please note that this file will automatically be deleted unless you have
specified to 'keep_db' in the config or via the $ENV{KEEP_DB} setting.

Also note that if you specify a path that already exists, we will automatically
add the option 'force_drop_table', on the assumption you are roundtripping
tests to the same database file.  This way you can avoid having to specifically
tell the system to delete the file each time.

=back

=head1 AUTHOR

John Napiorkowski C<< <jjnapiork@cpan.org> >>

=head1 CONTRIBUTORS

Tristan Pratt

=head1 COPYRIGHT & LICENSE

Copyright 2009, John Napiorkowski C<< <jjnapiork@cpan.org> >>

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
