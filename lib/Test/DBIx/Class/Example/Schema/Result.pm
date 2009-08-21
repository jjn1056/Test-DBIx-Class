package Test::DBIx::Class::Example::Schema::Result; {

	use base 'DBIx::Class';

	__PACKAGE__->load_components(qw/
		PK::Auto 
		UUIDColumns
		TimeStamp
		InflateColumn::DateTime
		Core 
	/);

	__PACKAGE__->uuid_class('::Data::UUID');
} 1

__END__

=head1 NAME

Test::DBIx::Class::Example::Schema::Result - The base result class

=head1 SYNOPSIS

	use base 'Test::DBIx::Class::Example::Schema::Result';
	
=head1 DESCRIPTION

All Result classes will inherit from this.  

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

