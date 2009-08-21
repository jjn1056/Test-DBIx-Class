package Test::DBIx::Class::Example::Schema::Result::Company::Employee; {
	use base 'Test::DBIx::Class::Example::Schema::Result';

	__PACKAGE__->table('company_employee');

	__PACKAGE__->add_columns(
 		fk_company_id => {
			data_type => 'varchar', 
			size => '36', 
			is_nullable => 0, 
		},
		fk_employee_id => {
			data_type => 'varchar', 
			size => '36', 
			is_nullable => 0, 
		},
		fk_job_id => {
			data_type => 'varchar', 
			size => '36', 
			is_nullable => 0, 
		},
		started => {
			data_type => 'datetime', 
			is_nullable => 0,
		},
		ended => {
			data_type => 'datetime', 
			is_nullable => 0,
		},
	);

	__PACKAGE__->set_primary_key('fk_company_id', 'fk_employee_id');

	__PACKAGE__->belongs_to(
		job => 'Test::DBIx::Class::Example::Schema::Result::Job',
		{ 'foreign.job_id' => 'self.fk_job_id' },
	);

	__PACKAGE__->belongs_to(
		company => 'Test::DBIx::Class::Example::Schema::Result::Company',
		{ 'foreign.company_id' => 'self.fk_company_id' },
	);

	__PACKAGE__->belongs_to(
		employee => 'Test::DBIx::Class::Example::Schema::Result::Person::Employee',
		{ 'foreign.employee_id' => 'self.fk_employee_id' },
	);

} 1

__END__

=head1 NAME

Test::DBIx::Class::Example::Schema::Result::Company::Employee - Company To Employee M2M

=head1 DESCRIPTION

Bridge table between Company and Employee, since each company has many Employees and a
given employee can be performed at more than one company.

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
