=pod

=encoding utf-8

=head1 PURPOSE

Test that Type::Library::Compiler compiles.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2022 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

use Test2::V0;
use Test::Requires { 'Types::Standard' => '1.014' };

use Type::Library::Compiler;

my $compiler = 'Type::Library::Compiler'->new(
	destination_module => 'Local::Library1',
	types => [
		Types::Standard::Str,
		Types::Standard::Int,
		Types::Standard::Num,
		Types::Standard::ArrayRef,
		Types::Standard::HashRef,
		Types::Standard::Undef,
		Types::Standard::Object,
		Types::Standard::Any,
	],
);

{
	my $code = $compiler->compile_to_string;
	note( $code );
	local $@;
	eval( $code ) or die( $@ );
}

isa_ok( 'Local::Library1', 'Exporter' );

my $Str = Local::Library1::Str();

ok   $Str->check( ""      ), 'passing type check 1';
ok   $Str->check( "Hello" ), 'passing type check 2';
ok ! $Str->check( []      ), 'failing type check';

ok   Local::Library1::assert_Any( 1 ), 'assert_Any( true )';
ok ! Local::Library1::assert_Any( 0 ), 'assert_Any( false )';

is(
	$Local::Library1::EXPORT_TAGS{'Str'},
	[ qw( Str is_Str assert_Str ) ],
	q[$EXPORT_TAGS{'Str'}],
);

is(
	$Local::Library1::EXPORT_TAGS{'types'},
	[ sort qw( Any Int Str Num ArrayRef HashRef Object Undef ) ],
	q[$EXPORT_TAGS{'types'}],
);

is(
	$Str->to_TypeTiny->{uniq},
	Types::Standard::Str->{uniq},
	'Can upgrade to Type::Tiny',
);

is(
	"$Str",
	"Str",
	'String overload',
);

ok(
	!!$Str,
	'Bool overload',
);

is(
	$Str->( "Hello" ),
	"Hello",
	'Coderef overload',
);

like(
	do { local $@; eval { $Str->( [] ) }; $@ },
	qr/did not pass type constraint/,
	'Coderef overload (failing)',
);

done_testing;
