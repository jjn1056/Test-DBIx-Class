package Test::DBIx::Class::Example::Schema::Result::CD::Track; {
	use base 'Test::DBIx::Class::Example::Schema::Result';

	__PACKAGE__->table('cd_track');

	__PACKAGE__->add_columns(
 		track_id => {
			data_type => 'varchar', 
			size => '36', 
			is_nullable => 0, 
		},
 		fk_cd_id => {
			data_type => 'varchar', 
			size => '36', 
			is_nullable => 0, 
		},
		position => {
			data_type => 'integer',
			is_nullable => 0,
		},
		title => {
			data_type => 'varchar',
			size => '50',
			is_nullable => 0,
		},
		created => {
			data_type => 'timestamp', 
			set_on_create => 1, 
			is_nullable => 0,
		},
	);

	__PACKAGE__->set_primary_key('track_id');
	__PACKAGE__->uuid_columns('track_id');


	__PACKAGE__->belongs_to(
		cd => 'Test::DBIx::Class::Example::Schema::Result::CD',
		{ 'foreign.cd_id' => 'self.fk_cd_id'},
	);
} 1

__END__

=head1 NAME

Test::DBIx::Class::Example::Schema::Result::CD::Track - Tracks on a CD
	
=head1 DESCRIPTION

Each CD has one or more tracks that are unique to that CD
 
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
