package Test::DBIx::Class::Example::Schema; {
	use base 'DBIx::Class::Schema';
	__PACKAGE__->load_namespaces(default_resultset_class => 'DefaultRS');
} 1

__END__

=head1 NAME

Test::DBIx::Class::Example::Schema - A basic schema you can use for testing

=head2 SYNOPSIS

	my $schema = Test::DBIx::Class::Example::Schema->connect($dsn);

=head1 DESCRIPTION

This Schema has two purposes.  First, we need one in order to properly test
this distribution.  Secondly, we'd like to offer a useful and simple schema
that component authors can use to test their code.  This way you don't have
to keep rolling your own example database and we can concentrate effort on
making one that is solid.

=head1 SEE ALSO

The following modules or resources may be of interest.

L<DBIx::Class::Schema>

=head1 AUTHOR

John Napiorkowski C<< <jjnapiork@cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009, John Napiorkowski  C<< <jjnapiork@cpan.org> >>

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

