use 5.008001;
use strict;
use warnings;

package Type::Library::Compiler;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.001';

use Type::Library::Compiler::Mite -all;
use B ();

has types => (
	is => ro,
	isa => 'ArrayRef[Object]',
	builder => sub { [] },
);

has destination_module => (
	is => ro,
	isa => 'Str',
	required => true,
);

has constraint_module => (
	is => ro,
	isa => 'Str',
	builder => sub {
		sprintf '%s::TypeConstraint', shift->destination_module;
	},
);

has destination_filename => (
	is => lazy,
	isa => 'Str',
	builder => sub {
		( my $module = shift->destination_module ) =~ s{::}{/}g;
		return sprintf 'lib/%s.pm', $module;
	},
);

sub compile_to_file {
	my $self = shift;

	open( my $fh, '>', $self->destination_filename )
		or croak( 'Could not open %s: %s', $self->destination_filename, $! );

	print { $fh } $self->compile_to_string;

	close( $fh )
		or croak( 'Could not close %s: %s', $self->destination_filename, $! );

	return;
}

sub compile_to_string {
	my $self = shift;

	my @types =
		sort { $a->display_name cmp $b->display_name }
		@{ $self->types or [] };

	my $code = '';
	$code .= $self->_compile_header;
	$code .= $self->_compile_type( $_ ) for @types;
	$code .= $self->_compile_footer;

	return $code;
}

sub _compile_header {
	my $self = shift;

	return sprintf <<'CODE', $self->destination_module, $self->constraint_module;
use 5.008001;
use strict;
use warnings;

package %s;

use Exporter ();
use Carp qw( croak );

our @ISA = qw( Exporter );
our @EXPORT;
our @EXPORT_OK;
our %%EXPORT_TAGS = (
	is     => [],
	types  => [],
	assert => [],
);

BEGIN {
	package %s;

	sub check {
		$_[0][0]->( $_[1] );
	}

	sub get_message {
		sprintf '%%s did not pass type constraint "%%s"',
			defined( $_[1] ) ? $_[1] : 'Undef',
			$_[0][1];
	}

	sub validate {
		$_[0][0]->( $_[1] )
			? undef
			: $_[0]->get_message( $_[1] );
	}

	sub assert_valid {
		$_[0][0]->( $_[1] )
			? 1
			: Carp::croak( $_[0]->get_message( $_[1] ) );
	}

	sub assert_return {
		$_[0][0]->( $_[1] )
			? $_[1]
			: Carp::croak( $_[0]->get_message( $_[1] ) );
	}

	sub DOES {
		return 1 if $_[1] eq 'Type::API::Constraint';
		shift->DOES( @_ );
	}
};

CODE
}

sub _compile_footer {
	my $self = shift;

	return <<'CODE';

1;

CODE
}

sub _compile_type {
	my ( $self, $type ) = ( shift, @_ );

	my $name = $type->name;
	my @code = ( "# $name", '{' );

	local $Type::Tiny::AvoidCallbacks = 1;
	local $Type::Tiny::SafePackage = '';

	push @code, sprintf <<'CODE', $name, $name, B::perlstring( $name ), B::perlstring( $self->constraint_module );
	my $type;
	sub %s () {
		$type ||= bless( [ \&is_%s, %s ], %s );
	}
CODE

	push @code, sprintf <<'CODE', $name, $type->inline_check( '$_[0]' );
	sub is_%s ($) {
		%s
	}
CODE

	push @code, sprintf <<'CODE', $name, $type->inline_check( '$_[0]' ), $name;
	sub assert_%s ($) {
		%s ? $_[0] : %s->get_message( $_[0] );
	}
CODE

	push @code, sprintf <<'CODE', $name, $name, $name, $name, $name, $name, $name, $name;
	$EXPORT_TAGS{"%s"} = [ qw( %s is_%s assert_%s ) ];
	push @EXPORT_OK, @{ $EXPORT_TAGS{"%s"} };
	push @{ $EXPORT_TAGS{"types"} },  "%s";
	push @{ $EXPORT_TAGS{"is"} },     "is_%s";
	push @{ $EXPORT_TAGS{"assert"} }, "assert_%s";
CODE

	push @code, "}", '', '';
	return join "\n", @code;
}

sub parse_list {
	shift;

	my @all =
		map {
			my ( $library, $type_names ) = split /=/, $_;
			do {
				local $@;
				eval "require $library; 1" or die $@;
			};
			if ( $type_names eq '*' or $type_names eq '-all' ) {
				map $library->get_type( $_ ), $library->type_names;
			}
			else {
				map $library->get_type( $_ ), split /\,/, $type_names;
			}
		}
		map { split /\s+/, $_ } @_;

	return \@all;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Type::Library::Compiler - compile a bunch of type constraints into a library with no non-core dependencies

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=Type-Library-Compiler>.

=head1 SEE ALSO

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2022 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.


=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

