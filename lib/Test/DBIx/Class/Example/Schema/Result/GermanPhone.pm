package Test::DBIx::Class::Example::Schema::Result::GermanPhone; {
	use base 'Test::DBIx::Class::Example::Schema::Result';

    __PACKAGE__->table_class('DBIx::Class::ResultSource::View');
	__PACKAGE__->table('german_phone');

    __PACKAGE__->result_source_instance->is_virtual(1);
    __PACKAGE__->result_source_instance->view_definition(
        q{SELECT * FROM phone WHERE number LIKE '+49%'}
    );
    __PACKAGE__->result_source_instance->deploy_depends_on(
        ['Test::DBIx::Class::Example::Schema::Result::Phone']
    );

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

Test::DBIx::Class::Example::Schema::Result::GermanPhone - Example of virtual view

=head1 SYNOPSIS

	TBD

=head1 DESCRIPTION

Sample result class for testing and for other component authors

=head1 SEE ALSO

The following modules or resources may be of interest.

L<DBIx::Class>

=head1 AUTHOR

Vadim Pushtaev C<< <pushtaev@cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2016, Vadim Pushtaev C<< <pushtaev@cpan.org> >>

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
