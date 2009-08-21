package Test::DBIx::Class::Example::Schema::Result::CD; {
	use base 'Test::DBIx::Class::Example::Schema::Result';

	__PACKAGE__->table('cd');

	__PACKAGE__->add_columns(
 		cd_id => {
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

	__PACKAGE__->set_primary_key('cd_id');
	__PACKAGE__->uuid_columns('cd_id');

	__PACKAGE__->has_many(
		cd_artist_rs => 'Test::DBIx::Class::Example::Schema::Result::CD::Artist',
		{ 'foreign.fk_cd_id' => 'self.cd_id'}
	);

	__PACKAGE__->has_many(
		track_rs => 'Test::DBIx::Class::Example::Schema::Result::CD::Track',
		{ 'foreign.fk_cd_id' => 'self.cd_id'},
		{ 'order_by' => {-asc=>'me.position'} },
	);

	__PACKAGE__->many_to_many(
		artists => 'cd_artist_rs', 'person_artist',
	);

} 1

__END__

=head1 NAME

Test::DBIx::Class::Example::Schema::Result::CD - A cd

=head1 DESCRIPTION

A cd has tracks and has artists

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
