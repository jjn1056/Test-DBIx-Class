package Test::DBIx::Class::FixtureCommand::Populate; {

	use Moose;
	use Test::More ();
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

		my @return;
		foreach my $definition (@definitions) {
			while (my ($source, $rows) = each %$definition) {
				my $rs = $self->schema_manager->schema->resultset($source);

				my @rows =  $rs->populate($rows);
				push @return, {$source => [@rows]};
			}
		}
		return @return;
	}
} 1;

__END__

=head1 NAME

Test::DBIx::Class::FixtureCommand::Populate - Install fixtures using Populate

=head1 SYNOPSIS

	my $command = Test::DBIx::Class::FixtureComand::Populate->new(schema=>$schema);
	$command->install_fixtures($fixtures);

=head1 DESCRIPTION

This uses the L<DBIx::Class::Schema/populate> method to install fixture data.
Expects an hash of "Source => [\@fields, \@rows]".  Please see the 'populate'
method for more information.  Examples:

	->install_fixtures(
		Person => [
			['name', 'age'],
			['john', 40],
			['vincent', 15],
		],
		Job => [
			[title => 'description'],
			[programmer => 'Who wrote the code'],
			[marketer => 'Who sold the code'],
		],
	);

You may include as many Sources as you like, and even the same one more than
once.

For additional flexibility with various configuration formats, we accept three
variations of the incoming arguments:

	## Array of HashRefs
	->install_fixtures(
		{Person => [
			['name', 'age'],
			['john', 40],
			['vincent', 15],
		]},
		{Job => [
			[title => 'description'],
			[programmer => 'Who wrote the code'],
			[marketer => 'Who sold the code'],
		]},
	);

	## ArrayRef
	->install_fixtures([
		Person => [
			['name', 'age'],
			['john', 40],
			['vincent', 15],
		],
		Job => [
			[title => 'description'],
			[programmer => 'Who wrote the code'],
			[marketer => 'Who sold the code'],
		],
	]);

	## ArrayRef of HashRefs
	->install_fixtures([
		{Person => [
			['name', 'age'],
			['john', 40],
			['vincent', 15],
		]},
		{Job => [
			[title => 'description'],
			[programmer => 'Who wrote the code'],
			[marketer => 'Who sold the code'],
		]},
	]);

This should allow you to model your fixtures in your configuration format of
choice without a lot of trouble.

=head1 METHODS

This class defines the following methods

=head2 install_fixtures

Takes an Array or ArrayRef of arguments and installs them into your target
database.  Returns an array of hashrefs, where each hashref is a {$source =>
@rows} pair.

=head1 AUTHOR

John Napiorkowski C<< <jjnapiork@cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009, John Napiorkowski C<< <jjnapiork@cpan.org> >>

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
