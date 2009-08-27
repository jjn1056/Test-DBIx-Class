package Test::DBIx::Class::Example::Schema::Result::Person; {
	use base 'Test::DBIx::Class::Example::Schema::Result';

	__PACKAGE__->table('person');

	__PACKAGE__->add_columns(
 		person_id => {
			data_type => 'varchar', 
			size => '36', 
			is_nullable => 0, 
		},
		name => {
			data_type => 'varchar',
			size => '24',
			is_nullable => 0,
		},
		age => {
			data_type => 'integer',
			is_numeric => 1,
			is_nullable => 0,
		},
		email => {
			data_type => 'varchar',
			size=>'128',
		},
		created => {
			data_type => 'timestamp', 
			set_on_create => 1, 
			is_nullable => 0,
		},
	);

	__PACKAGE__->set_primary_key('person_id');
	__PACKAGE__->uuid_columns('person_id');

	__PACKAGE__->has_many(
		phone_rs => 'Test::DBIx::Class::Example::Schema::Result::Phone',
		{ 'foreign.fk_person_id' => 'self.person_id' },
	);

	__PACKAGE__->might_have(
		employee  => 'Test::DBIx::Class::Example::Schema::Result::Person::Employee',
		{
			'foreign.employee_id' => 'self.person_id',
		},
	);

	__PACKAGE__->might_have(
		artist  => 'Test::DBIx::Class::Example::Schema::Result::Person::Employee',
		{
			'foreign.artist_id' => 'self.person_id',
		},
	);
} 1

__END__

=head1 NAME

Test::DBIx::Class::Example::Schema::Result::Person - The base result class

=head1 SYNOPSIS

A Person has many Phone number and might be an employee.
	
=head1 DESCRIPTION

Sample result class for testing and for other component authors

=head1 SEE ALSO

The following modules or resources may be of interest.

L<DBIx::Class>

=head1 AUTHOR

John Napiorkowski C<< <jjnapiork@cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009, John Napiorkowski C<< <jjnapiork@cpan.org> >>

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
