use 5.006;
use strict;
use warnings;

package isa;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '2.000';

BEGIN {
	*HAS_XS = eval { require Type::Tiny::XS; 1 }
		? sub(){!!1}
		: sub(){!!0};
	
	eval { require Mouse::Util; } unless HAS_XS();
	*HAS_MOUSE = eval { Mouse::Util::MOUSE_XS() and 'Mouse::Util'->can('generate_isa_predicate_for') }
		? sub(){!!1}
		: sub(){!!0};
	
	*HAS_NATIVE = ($] ge '5.032')
		? sub(){!!1}
		: sub(){!!0};
	
	*perlstring = eval { require B; 'B'->can('perlstring') }
		|| sub { sprintf '"%s"', quotemeta($_[0]) };
	
	*is_coderef = HAS_XS()
		? Type::Tiny::XS::get_coderef_for('CodeRef')
		: sub { 'CODE' eq ref $_[0] };
};

sub import {
	my ( $caller, $me ) = ( scalar(caller), shift );
	
	my $imports;
	if ( @_==1 and ref($_[0]) eq 'HASH' ) {
		$imports = $_[0];
	}
	else {
		my %imports = map { $me->subname_for($_) => $_ } @_;
		$imports = \%imports;
	}
	
	$me->setup_for($caller, $imports);
}

sub subname_for {
	my ( $me, $class ) = ( shift, @_ );
	$class =~ s/\W+/_/g;
	'isa_' . $class;
}

my %cache;
sub setup_for {
	my ( $me, $caller, $imports ) = ( shift, @_ );
	
	while ( my ($subname, $class) = each %$imports ) {
		no strict 'refs';
		no warnings 'redefine';
		*{"$caller\::$subname"} = (
			$cache{$class} ||= $me->generate_coderef($class)
			or die("Problem generating coderef for $class")
		);
	}
}

sub generate_coderef {
	my ( $me, $class ) = ( shift, @_ );
	
	my $coderef;
	if ( HAS_XS ) {
		my $native_will_be_faster = 0;
		
		if ( HAS_NATIVE ) {
			my $class_isa = eval { $class->can('isa') };
			if ( $class_isa and $class_isa != \&UNIVERSAL::isa ) {
				$native_will_be_faster = 1;
			}
		}
		
		unless ($native_will_be_faster) {
			my $typename = sprintf('InstanceOf[%s]', $class);
			$coderef = Type::Tiny::XS::get_coderef_for($typename);
			return $coderef if is_coderef($coderef);
		}
	}
	
	if ( HAS_MOUSE ) {
		$coderef = Mouse::Util::generate_isa_predicate_for($class);
		return $coderef if is_coderef($coderef);
	}	
	
	my $code;
	if ( HAS_NATIVE ) {
		$code = sprintf(
			q{ package isa::__NATIVE__; use feature q[isa]; no warnings q[experimental::isa]; sub { $_[0] isa %s } },
			perlstring($class),
		);
	}
	else {
		require Scalar::Util;
		$code = sprintf(
			q{ package isa::__LEGACY__; sub { Scalar::Util::blessed($_[0]) and $_[0]->isa(%s) } },
			perlstring($class),
		);
	}
	
	$coderef = eval $code;
	is_coderef($coderef) ? $coderef : undef;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

isa - isn't the isa operator

=head1 SYNOPSIS

  use isa 'HTTP::Tiny';
  
  my $obj = MyApp->get_user_agent;
  
  if ( isa_HTTP_Tiny $obj ) {
    my $response = $obj->get( 'https://www.example.com/' );
    MyApp->do_something( $response );
  }

=head1 DESCRIPTION

The new C<isa> operator in Perl 5.32 is pretty great, but if you need to
support legacy versions of Perl, you can't use it yet. This module gives
you isa-like functions you can use in Perl 5.6 and above.

If you've got L<Type::Tiny::XS> installed, you will probably find that
this module is I<faster> than the native C<isa> operator!

=head1 IMPORT

You need to list the classes you'll be using on the C<use> line.

  use isa 'HTTP::Tiny', 'MyApp::Person';

This module will replace the "::" bits with underscores, and prefix
"isa_" to each name to create functions like C<isa_HTTP_Tiny> and
C<isa_MyApp_Person>.

=head2 Alternative Style

If you'd prefer to pick your own names for the imported functions,
you can use a hashref in the import:

  use isa {
    isa_Browser => 'HTTP::Tiny',
    isa_Person  => 'MyApp::Person',
  };

You can't mix and match styles within one import, but you can
C<< use isa >> more than once.

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=isa>.

=head1 SEE ALSO

L<perlop>, L<Scalar::Util>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2020 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

