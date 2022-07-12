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

has pod => (
	is => rw,
	isa => 'Bool',
	coerce => true,
	default => true,
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

	if ( $self->pod ) {
		$code .= $self->_compile_pod_header;
		$code .= $self->_compile_pod_type( $_ ) for @types;
		$code .= $self->_compile_pod_footer;
	}

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

	use overload (
		fallback => !!1,
		bool     => sub { !! 1 },
		'""'     => sub { shift->[1] },
		'&{}'    => sub {
			my $self = shift;
			return sub { $self->assert_return( @_ ) };
		},
	);

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

	sub to_TypeTiny {
		my ( undef, $name, $library ) = @{ +shift };
		local $@;
		eval "require $library; 1" or die $@;
		$library->get_type( $name );
	}

	sub DOES {
		return 1 if $_[1] eq 'Type::API::Constraint';
		return 1 if $_[1] eq 'Type::Library::Compiler::TypeConstraint';
		shift->DOES( @_ );
	}
};

CODE
}

sub _compile_footer {
	my $self = shift;

	return <<'CODE';

1;
__END__

CODE
}

sub _compile_type {
	my ( $self, $type ) = ( shift, @_ );

	my $name = $type->name;
	my @code = ( "# $name", '{' );

	local $Type::Tiny::AvoidCallbacks = 1;
	local $Type::Tiny::SafePackage = '';

	push @code, sprintf <<'CODE', $name, $name, B::perlstring( $name ), B::perlstring( $type->library ), B::perlstring( $self->constraint_module );
	my $type;
	sub %s () {
		$type ||= bless( [ \&is_%s, %s, %s ], %s );
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

sub _compile_pod_header {
	my $self = shift;

	return sprintf <<'CODE', $self->destination_module;
#=head1 NAME

%s - type constraint library

#=head1 TYPES

CODE
}

sub _compile_pod_type {
	my ( $self, $type ) = ( shift, @_ );

	my $name = $type->name;

	return sprintf <<'CODE', $name, $type->library, $name, $name, $name, $self->destination_module, $name;
#=head2 B<< %s >>

As originally defined in L<%s>.

The C<< %s >> constant returns a blessed type constraint object.
C<< is_%s($value) >> checks a value against the type and returns a boolean.
C<< assert_%s($value) >> checks a value against the type and throws an error.

To import all of these functions:

  use %s qw( :%s );

CODE
}

sub _compile_pod_footer {
	my $self = shift;

	return <<'CODE';
#=cut

CODE
}

around qw( _compile_pod_header _compile_pod_type _compile_pod_footer ) => sub {
	my ( $next, $self ) = ( shift, shift );
	my $pod = $self->$next( @_ );
	$pod =~ s{^#=}{=}gsm;
	return $pod;
};

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

  type-library-compiler --module=MyApp::Types Types::Standard=-all

=head1 DESCRIPTION

This class performs the bulk of the work for F<type-library-compiler>.

=head2 Constructor

=head3 C<< new( %attributes ) >>

=head2 Attributes

=head3 C<types> B<< ArrayRef[Object] >>

Required array of L<Type::Tiny> objects.

=head3 C<pod> B<< Bool >>

Should the generated module include pod? Defaults to true.

=head3 C<destination_module> B<< Str >>

Required Perl module name to produce.

=head3 C<constraint_module> B<< Str >>

Leave this as the default.

=head3 C<destination_filename> B<< Str >>

Leave this as the default.

=head2 Object Methods

=head3 C<< compile_to_file() >>

Writes the module to C<destination_filename>.

=head3 C<< compile_to_string() >>

Returns the module as a string of Perl code.

=head2 Class Methods

=head3 C<< parse_list( @argv ) >>

Parses a list of strings used to specify type constraints on the command line,
and returns an arrayref of L<Type::Tiny> objects, suitable for the C<types>
attribute.

=head1 BUGS

Please report any bugs to
<https://github.com/tobyink/p5-type-library-compiler/issues>.

=head1 SEE ALSO

L<Mite>, L<Type::Library>, L<Type::Tiny>.

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

