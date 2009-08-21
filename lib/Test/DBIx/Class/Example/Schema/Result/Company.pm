package Test::DBIx::Class::Example::Schema::Result::Company; {
	use base 'Test::DBIx::Class::Example::Schema::Result';

	__PACKAGE__->table('company');

	__PACKAGE__->add_columns(
 		company_id => {
			data_type => 'varchar', 
			size => '36', 
			is_nullable => 0, 
		},
		name => {
			data_type => 'varchar',
			size => '24',
			is_nullable => 0,
		},
		created => {
			data_type => 'timestamp', 
			set_on_create => 1, 
			is_nullable => 0,
		},
	);

	__PACKAGE__->set_primary_key('company_id');
	__PACKAGE__->uuid_columns('company_id');

	__PACKAGE__->has_many(
		company_employee_rs => 'Test::DBIx::Class::Example::Schema::Result::Company::Employee',
		{ 'foreign.fk_company_id' => 'self.company_id'}
	);

	__PACKAGE__->many_to_many(
		employees => 'company_employee_rs', 'employee',
	);

} 1

__END__

=head1 NAME

Test::DBIx::Class::Example::Schema::Result::Company - A company

=head1 DESCRIPTION

A company provides jobs and has employees

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
