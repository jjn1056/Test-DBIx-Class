package Test::DBIx::Class::Example::Schema::ResultSet; {
	
	use strict;
	use warnings;

	use base 'DBIx::Class::ResultSet';

	sub hri_dump {
		(shift)->search ({}, {
			result_class => 'DBIx::Class::ResultClass::HashRefInflator'
		});
	}
} 1

__END__

=head1 NAME

Test::DBIx::Class::Example::Schema::ResultSet - A base ResultSet Class

=head1 SYNOPSIS

	use base 'Test::DBIx::Class::Example::Schema::ResultSet';
		
=head1 DESCRIPTION

All ResultSet classes will inherit from this.

=head1 SEE ALSO

The following modules or resources may be of interest.

L<DBIx::Class::ResultSet>

=head1 AUTHOR

John Napiorkowski C<< <jjnapiork@cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009, John Napiorkowski C<< <jjnapiork@cpan.org> >>

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

