package Test::DBIx::Class::Example::Schema::Result::Job; {
	use base 'Test::DBIx::Class::Example::Schema::Result';

	__PACKAGE__->table('job');

	__PACKAGE__->add_columns(
 		job_id => {
			data_type => 'varchar', 
			size => '36', 
			is_nullable => 0, 
		},
		name => {
			data_type => 'varchar',
			size => '20',
			is_nullable => 0,
		},
		description => {
			data_type => 'varchar',
			size => '100',
			is_nullable => 0,
		},
	);

	__PACKAGE__->set_primary_key('job_id');
	__PACKAGE__->uuid_columns('job_id');

	__PACKAGE__->has_many(
		company_employee_rs => 'Test::DBIx::Class::Example::Schema::Result::Company::Employee',
		{ 'foreign.fk_job_id' => 'self.job_id'}
	);

	__PACKAGE__->many_to_many(
		companies => 'company_job_rs', 'company',
	);

	__PACKAGE__->many_to_many(
		employees => 'company_job_rs', 'employee',
	);

} 1

__END__

=head1 NAME

Test::DBIx::Class::Example::Schema::Result::Job - A Job

=head1 DESCRIPTION

A job is something you gotta do.

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
