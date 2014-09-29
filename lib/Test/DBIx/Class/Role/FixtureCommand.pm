package Test::DBIx::Class::Role::FixtureCommand; {

	use Moo::Role;
	requires qw/install_fixtures/;

	has 'schema_manager' => (
		is=>'ro',
		required=>1,
		weak_ref=>1,
	);

} 1;

__END__

=head1 NAME

Test::DBIx::Class::Role::FixtureCommand - Role that a FixtureCommand must consume

=head1 DESCRIPTION

If you need to make your own custom Fixture Commands, please consume this role.

=head1 AUTHOR

John Napiorkowski C<< <jjnapiork@cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009, John Napiorkowski C<< <jjnapiork@cpan.org> >>

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
