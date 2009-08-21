package Test::DBIx::Class::Types; {

	use strict;
	use warnings;

	use Class::MOP;
	use MooseX::Types::Moose qw(Str ClassName ArrayRef HashRef);
	use MooseX::Types -declare => [qw/
		TestBuilder SchemaManagerClass ConnectInfo FixtureClass
	/];

	subtype TestBuilder,
	  as class_type('Test::Builder');

	subtype SchemaManagerClass,
	  as ClassName;

	coerce SchemaManagerClass,
	  from Str,
	  via {
		my $type = $_;
		Class::MOP::load_class($type);
    	$type;
	  };

	subtype FixtureClass,
	  as ClassName;

	coerce FixtureClass,
	  from Str,
	  via {
		my $type = $_;
		$type = "Test::DBIx::Class::FixtureCommand".$type if $type =~m/^::/;
		Class::MOP::load_class($type);
    	$type;
	  };

	## ConnectInfo cargo culted from "Catalyst::Model::DBIC::Schema::Types"
	subtype ConnectInfo,
	  as HashRef,
      where { exists $_->{dsn} },
      message { 'Does not look like a valid connect_info' };

	coerce ConnectInfo,
	  from Str,
      via(\&_coerce_connect_info_from_str),
	  from ArrayRef,
	  via(\&_coerce_connect_info_from_arrayref);


	sub _coerce_connect_info_from_arrayref {
		my %connect_info;

		# make a copy
		$_ = [ @$_ ];

		if (!ref $_->[0]) { # array style
			$connect_info{dsn}      = shift @$_;
			$connect_info{user}     = shift @$_ if !ref $_->[0];
			$connect_info{password} = shift @$_ if !ref $_->[0];

			for my $i (0..1) {
				my $extra = shift @$_;
				last unless $extra;
				die "invalid connect_info" unless reftype $extra eq 'HASH';

				%connect_info = (%connect_info, %$extra);
			}

			die "invalid connect_info" if @$_;
		} elsif (@$_ == 1 && reftype $_->[0] eq 'HASH') {
			return $_->[0];
		} else {
			die "invalid connect_info";
		}

		for my $key (qw/user password/) {
			$connect_info{$key} = ''
				if not defined $connect_info{$key};
		}

		\%connect_info;
	}

	sub _coerce_connect_info_from_str {
		+{ dsn => $_, user => '', password => '' }
	}


} 1

__END__

=head1 NAME

Test::DBIx::Class::Types - Type Constraint Library

=head1 DESCRIPTION

L<MooseX::Types> based type constraint library

=head1 AUTHOR

John Napiorkowski C<< <jjnapiork@cpan.org> >>

Code gratuitously cargo culted from L<Catalyst::Model::DBIC::Schema::Types>

=head1 COPYRIGHT & LICENSE

Copyright 2009, John Napiorkowski C<< <jjnapiork@cpan.org> >>

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

