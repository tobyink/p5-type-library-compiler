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

ok(   $Str->check( ""      ) );
ok(   $Str->check( "Hello" ) );
ok( ! $Str->check( []      ) );

ok   Local::Library1::assert_Any( 1 );
ok ! Local::Library1::assert_Any( 0 );

is(
	$Local::Library1::EXPORT_TAGS{'Str'},
	[ qw( Str is_Str assert_Str ) ],
);

is(
	$Local::Library1::EXPORT_TAGS{'types'},
	[ sort qw( Any Int Str Num ArrayRef HashRef Object Undef ) ],
);

done_testing;
