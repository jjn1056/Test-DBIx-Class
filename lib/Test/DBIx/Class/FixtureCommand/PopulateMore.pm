package Test::DBIx::Class::FixtureCommand::PopulateMore; {

	use Moose;
	use Test::More ();
	use DBIx::Class::Schema::PopulateMore::Command;
	with 'Test::DBIx::Class::Role::FixtureCommand';

	sub install_fixtures {
		my ($self, $arg, @rest) = @_;
		my $builder = $self
			->schema_manager
			->builder;

		$builder->croak("Argument is required.")
		  unless $arg;

		my @args;
		if(ref $arg && ref $arg eq 'ARRAY') {
			@args = @$arg;
		}
		elsif(ref $arg && ref $arg eq 'HASH') {
			@args = %$arg;
		}
		else {
			@args = ($arg, @rest);
		}

		my @definitions;
		while(@args) {
			my $next = shift(@args);
			if( (ref $next) && (ref $next eq 'HASH') ) {
				push @definitions, $next;
			} else {
				my $value = shift(@args);
				push @definitions, {$next => $value};
			}
		}

		my ($command, %return);
		
		eval {
			$command = DBIx::Class::Schema::PopulateMore::Command->new(
				definitions=>[@definitions],
				schema=>$self->schema_manager->schema,
				exception_cb=>sub {
					$builder->croak(@_);
				},
			);
		}; if ($@) {
			Test::More::fail("Can't create command class: $@");
		} else {
			eval {
				%return = $command->execute;
			}; if ($@) {
				Test::More::fail("Can't install fixtures: $@");
			}
		}		

		return %return;
	}
} 1;

__END__

=head1 NAME

Test::DBIx::Class::FixtureCommand::PopulateMore - Install fixtures using PopulateMore

=head1 SYNOPSIS

	my $command = Test::DBIx::Class::FixtureComand::PopulateMore->new(schema=>$schema);
	$command->install_fixtures($fixtures);

=head1 DESCRIPTION

This uses the L<DBIx::Class::Schema::PopulateMore> to install fixtures. Please
review the documentation for that module for more.

=head1 METHODS

This class defines the following methods

=head2 install_fixtures

Takes an Array or ArrayRef of arguments and installs them into your target
database.  Returns as L<DBIx::Class::Schema::PopulateMore>.

=head1 AUTHOR

John Napiorkowski C<< <jjnapiork@cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009, John Napiorkowski C<< <jjnapiork@cpan.org> >>

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
