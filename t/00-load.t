#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'XML::LibXML::DOMUtil' );
}

diag( "Testing XML::LibXML::DOMUtil $XML::LibXML::DOMUtil::VERSION, Perl $], $^X" );
