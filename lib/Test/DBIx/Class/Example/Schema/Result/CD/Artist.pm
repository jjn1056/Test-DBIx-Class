package Test::DBIx::Class::Example::Schema::Result::CD::Artist; {
	use base 'Test::DBIx::Class::Example::Schema::Result';

	__PACKAGE__->table('cd_artist');

	__PACKAGE__->add_columns(
 		fk_artist_id => {
			data_type => 'varchar', 
			size => '36', 
			is_nullable => 0, 
		},
 		fk_cd_id => {
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

	__PACKAGE__->set_primary_key('fk_artist_id','fk_cd_id');

	__PACKAGE__->belongs_to(
		cd => 'Test::DBIx::Class::Example::Schema::Result::CD',
		{ 'foreign.cd_id' => 'self.fk_cd_id'},
	);

	__PACKAGE__->belongs_to(
		person_artist => 'Test::DBIx::Class::Example::Schema::Result::Person::Artist',
		{ 'foreign.artist_id' => 'self.fk_artist_id'},
	);
} 1

__END__

=head1 NAME

Test::DBIx::Class::Example::Schema::Result::CD::Artist - Artist Role
	
=head1 DESCRIPTION

Some CDs are artists.  Each Artist works contributes to one or more CDs.

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
