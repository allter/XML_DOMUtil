#!/usr/bin/perl
use strict;
use utf8;

use constant DEBUG => 0;

binmode STDOUT, ":utf8";
#binmode STDERR, ":utf8";

#BEGIN{
#require 'DOMUtil.pm';
#import XML::LibXML::DOMUtil;
#}
use XML::LibXML::DOMUtil;

use XML::LibXML;

my $xml = parse_xml <<END;
<root>
	1
	<child>CHILD</child>
	2
	<unicode>Проверка</unicode>
	<кириллический_тег кириллический_атрибут="кириллическое значение атрибута">кириллический текст</кириллический_тег>
</root>
END
DEBUG && print toUnicodeString( $xml, 1 );

# TODO: Problem or misunderstanding about docencoding!
#DEBUG && print toUnicodeString( $xml, 0, 'cp1251' );

#DEBUG && print $xml->toString( 0 );

my $imported_xml = importXML $xml, <<END;
<вложенный>
	<ещё>42</ещё>
	<и_ещё></и_ещё>
</вложенный>
END

$xml->ownerDocument->documentElement->appendChild( $imported_xml );
DEBUG && print toUnicodeString( $xml, 1 );

my $ohash = {
	Element => 19,
	'42_Element' => 42,
	'23_Element' => 23,
	'15_Element' => 15,
	#'>' => '<!-- конец ohash -->',
	'Inner' => {
	#	'<>' => '<ещё_вложенный>ещё вложенное значение</ещё_вложенный>',
	#	'<' => '<!-- начало ohash -->',
	},
};

#my $xml2 = dom_from_ordered_hash { root => { val => 'val', } };
my $xml2 = xml_dom_from_ordered_hash { root => $ohash };
DEBUG && print toUnicodeString( $xml2, 1 );
#print $xml2->toString( 1 );

$xml2->ownerDocument->documentElement->appendChild( importOrderedHash $xml2, {
	'10_element2' => 'element #2',
	'20_element3' => 'element #3',
} );
DEBUG && print toUnicodeString( $xml2, 1 );

my $node = ( $xml2->findnodes( '/root/Inner' ) )[0];
replaceInnerNodes( $node, importXML $node, <<END );
<inner_tag>inner_tag_value</inner_tag>
<!--<inner_tag2>inner_tag_value2</inner_tag2>-->
END
DEBUG && print 'node: '.toUnicodeString( $node, 1 );
DEBUG && print 'xml2: '.toUnicodeString( $xml2, 1 );

my $frag = parse_xml_fragment <<END;
	<some_node>some node value </some_node>
<some_node2>   some node #2 value </some_node2>
END
DEBUG && print "frag: ".toUnicodeString( $frag, 1 );

$node->appendChild( importXMLFragment( $node, <<END ) );
	<some_other_node>some other node value </some_other_node>
<some_other_node2>   some other node #2 value </some_other_node2>
END
DEBUG && print 'xml2: '.toUnicodeString( $xml2, 1 );

#-------------- namespaces -----------------------

my $dom3 = parse_xml <<END;
<root xmlns:ns="123">
</root>
END
DEBUG && print 'dom3: '.toUnicodeString( $dom3->documentElement, 1 );
my $tmp_dom = importOrderedHash( $dom3->documentElement, {
	'@' => {
		xmlns => '123',
		'xmlns:some' => '123',
	},
	child => 5,
	#'ns:child' => 42, # croaks
	'some:child' => 42,
	descent => {
		child => 5,
		#'ns:child' => 42, # croaks
		'some:child' => 42,
	},
} );
#use Data::Dumper;
#warn 'tmp_dom: '.Dumper $tmp_dom;
#print $tmp_dom->toString( 1 );
#print "tmpdom: ".toUnicodeString( $tmp_dom, 1 );
replaceInnerNodes( $dom3->documentElement, $tmp_dom );
#print "dom3: ".toUnicodeString( $dom3, 1 );
DEBUG && print "dom3 do: ".$dom3->toString(  1 );


