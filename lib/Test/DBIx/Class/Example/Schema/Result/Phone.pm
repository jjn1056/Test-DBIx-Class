package Test::DBIx::Class::Example::Schema::Result::Phone; {
	use base 'Test::DBIx::Class::Example::Schema::Result';

	__PACKAGE__->table('phone');

	__PACKAGE__->add_columns(
 		fk_person_id => {
			data_type => 'varchar', 
			size => '36', 
			is_nullable => 0, 
		},
		number => {
			data_type => 'varchar',
			size => '10',
			is_nullable => 0,
		},
	);

	__PACKAGE__->set_primary_key('fk_person_id','number');

	__PACKAGE__->belongs_to(
		owner => 'Test::DBIx::Class::Example::Schema::Result::Person',
		{ 'foreign.person_id' => 'self.fk_person_id' },
	);

} 1

__END__

=head1 NAME

Test::DBIx::Class::Example::Schema::Result::Phone - The base result class

=head1 SYNOPSIS

	TBD
	
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
