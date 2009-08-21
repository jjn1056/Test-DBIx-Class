package Test::DBIx::Class::Example::Schema::Result::Person::Employee; {
	use base 'Test::DBIx::Class::Example::Schema::Result';

	__PACKAGE__->table('person_employee');

	__PACKAGE__->add_columns(
 		employee_id => {
			data_type => 'varchar', 
			size => '36', 
			is_nullable => 0, 
		},
		created => {
			data_type => 'timestamp', 
			set_on_create => 1, 
			is_nullable => 0,
		},
	);

	__PACKAGE__->set_primary_key('employee_id');

	__PACKAGE__->belongs_to(
		person => 'Test::DBIx::Class::Example::Schema::Result::Person',
		{ 'foreign.person_id' => 'self.employee_id'},
	);

	__PACKAGE__->has_many(
		company_employee_rs => 'Test::DBIx::Class::Example::Schema::Result::Company::Employee',
		{ 'foreign.fk_employee_id' => 'self.employee_id'}
	);

	__PACKAGE__->many_to_many(
		companies => 'company_emplopyee_rs', 'company',
	);

} 1

__END__

=head1 NAME

Test::DBIx::Class::Example::Schema::Result::Person::Employee - Employee Role
	
=head1 DESCRIPTION

Some Persons are employees.  Each Employee works at one or more companies.

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
