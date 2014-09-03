#!/usr/bin/perl
use strict;
use utf8;

use Test::Simple tests => 14;

use constant DEBUG => 0;
DEBUG && binmode STDOUT, ":utf8";
#binmode STDERR, ":utf8";

use XML::LibXML::DOMUtil;

use XML::LibXML;

# Parsing well-formed xml from string literal (here-doc) as a XML DOM document ---------
DEBUG && print "1.\n";
my $xml = parse_xml <<END;
<root>
	1
	<child>CHILD</child>
	2
	<unicode>Проверка</unicode>
	&#x00C9;
	<кириллический_тег кириллический_атрибут="кириллическое значение атрибута">кириллический текст</кириллический_тег>
</root>
END
#$xml->setEncoding( 'utf-8' );
my $unicode_string = toUnicodeString( $xml, 1 ); 
DEBUG && print "source xml unicode string: ".$unicode_string;
ok $xml->findvalue( '/root/кириллический_тег' ) eq 'кириллический текст'
	&& $xml->findvalue( '/root/кириллический_тег/@кириллический_атрибут' )
		eq 'кириллическое значение атрибута',
	'Basic sanity check of a parse_xml result';
DEBUG && print "\n";

# TODO: Problem or misunderstanding about docencoding!
$xml->setEncoding( 'utf-8' );
#$xml->setEncoding( 'ascii' );
#$xml->setEncoding( 'windows-1251' );
#DEBUG && print toUnicodeString( $xml, 0, 'us-ascii' );
#DEBUG && print toUnicodeString( $xml, 0, 'cp1251' );
#warn "encoding: ".$xml->getEncoding;
#warn "actual encoding: ".$xml->getEncoding;

#DEBUG && print "after setEncoding: ".toUnicodeString( $xml, 1);

#my $xml_byte_string = toByteString( $xml, 'ascii' => 2 );
#my $xml_byte_string = toByteString( $xml, 'latin1' => 1 );
my $xml_byte_string = toByteString( $xml, 'windows-1251' => 0 );
DEBUG && print "\n";

DEBUG && print "2.\n";
ok( ! utf8::is_utf8( $xml_byte_string ), 'toByteString lacks is_utf8 flag' );

DEBUG && print "3.\n";
ok( utf8::is_utf8( $unicode_string ), 'toUnicodeString sets is_utf8 flag' );
DEBUG && print "\n";

# Get 8-bit xml and parse it using XLDU
DEBUG && print "4.\n";
my $xml_1251 = "<?xml version='1.0' encoding='windows-1251'?>".$xml_byte_string; # XML in 8-bit encoding
my $dom_1251 = parse_xml $xml_1251;
my $xml_byte_string2 = toByteString( $dom_1251, 'windows-1251' => 0 );

ok( ! utf8::is_utf8( $xml_byte_string2 ), 'toByteString lacks is_utf8 flag (2)' );
DEBUG && print "\n";
DEBUG && print "5.\n";
my $xml_unicode_string2 = toUnicodeString( $dom_1251 );
DEBUG && print "Unicode representation of dom_1251: ".$xml_unicode_string2."\n";
ok( utf8::is_utf8( $xml_unicode_string2 ), 'toUnicodeString sets is_utf8 flag (2)' );
DEBUG && print "\n";

=pod
binmode STDOUT, ":raw";
print "---";
DEBUG && print "encoded string: [ $xml_byte_string  ], u:".utf8::is_utf8( $xml_byte_string );
print "---";
binmode STDOUT, ":utf8";
=cut
use Encode qw(decode);
my $xml_cp1251_string = decode cp1251 => $xml_byte_string;
DEBUG && print "encoded string decoded back to unicode: $xml_cp1251_string";

#DEBUG && "xml: ".print $xml->toString( 0 );
#DEBUG && print $xml->toString( 0 );

# Adding xml fragment to existing xml DOM
my $imported_xml = importXML $xml, <<END;
<вложенный>
	<ещё>42</ещё>
	<и_ещё></и_ещё>
</вложенный>
END

$xml->ownerDocument->documentElement->appendChild( $imported_xml );
DEBUG && print toUnicodeString( $xml, 1 );

# Creating a XML DOM from 'ordered hash structure' ----------
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

# replaceInnerNodes - which implements innerHTML/innerXML on the level of XML DOM ----------
my $node = ( $xml2->findnodes( '/root/Inner' ) )[0];
replaceInnerNodes( $node, importXML $node, <<END );
<inner_tag>inner_tag_value</inner_tag>
<!--<inner_tag2>inner_tag_value2</inner_tag2>-->
END
DEBUG && print 'node: '.toUnicodeString( $node, 1 );
DEBUG && print 'xml2: '.toUnicodeString( $xml2, 1 );

# Parse string literal as a standalone and import "xml fragment" DOM structures ----------
# (not well-formed XML chunks suitable for being a content of elements)
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
DEBUG && print "\n";

# Handling text-only xml fragments (no elements at all)
DEBUG && print "6.\n";
my $x = parse_xml_fragment "&#x413;&#x440;&#x438;&#x433;&#x43E;&#x440;&#x44C;&#x435;&#x432;&#x438;&#x447;";
DEBUG && print 'text-only XML fragment: '.toUnicodeString($x, 1), "\n";
ok toUnicodeString( $x ) eq 'Григорьевич', 'Text-only XML fragments';
DEBUG && print "\n";

#------------------- templating XMLs using ohashs -------------------
DEBUG && print "7.\n";
my $xml3 = xml_dom_from_ordered_hash +{
	inner_root_element => 'test',
};
my $xml4 = xml_dom_from_ordered_hash +{
	root_element => $xml3, # inner_root_element inside root_element
};
DEBUG && print "constructed xml4: ".toUnicodeString( $xml4, 1 ), "\n";
ok $xml4->findvalue( '/root_element/inner_root_element' ) eq 'test',
	'Constructing XMLs using ohashs';
DEBUG && print "\n";

DEBUG && print "8.\n";
my $xml5 = xml_dom_from_ordered_hash +{
	root_element => +{
		'@' => {
			'attribute' => '42',
			'p2:type' => "PaymentParameter",
		},
		'@xmlns:p2' => "http://www.w3.org/2001/XMLSchema-instance",
		'inner_element2' => {
			'@' => {
				'xmlns:p3' => "http://www.w3.org/2001/XMLSchema-instance",
			},
			'@p3:type' => "PaymentParameter",
		},
		'42_@attribute2' => 149,
		'45_@атрибут' => 'значение',

		'25_innermost_element' => {
			'@p2:type' => "Cash",
			'p2:element' => "Bar", #TODO namespaced elements
		},
		'149_inner_element' => ( $xml3->findnodes( '/inner_root_element/text()' ) )[0],
	}
};
DEBUG && print "constructed xml5: ".toUnicodeString( $xml5, 1 ), "\n";
#DEBUG && print "xxx: ".$xml5->toString(1), "\n";
ok $xml5->findvalue( '/root_element/inner_element' ) eq 'test',
	'Constructing XMLs using ohashs (2)';
DEBUG && print "\n";

DEBUG && print "9.\n";
use XML::LibXML::XPathContext;
my $xpc = XML::LibXML::XPathContext->new();
$xpc->registerNs( 'prefix', 'http://www.w3.org/2001/XMLSchema-instance' );
ok $xpc->findvalue( '/root_element/innermost_element/@prefix:type', $xml5 ) eq 'Cash',
	'Namespaces in attributes and (TODO) elements';
DEBUG && print $xpc->findvalue( '/root_element/innermost_element/prefix:element', $xml5 ), 'Bar'; #TODO!!!
#ok $xml5->findvalue( '/root_element/inner_element' ) eq 'test',
#	'Constructing XMLs using ohashs - 2';
DEBUG && print "\n";

# Не-аски при конструировании из ohash
ok $xpc->findvalue( '/root_element/@атрибут', $xml5 ) eq 'значение',
	'Unicode names and values when constructing from ohash';
DEBUG && print "\n";

# Произвольный XML в ohash
DEBUG && print "11, 12. <> support";
my $xml6_inner = xml_dom_from_ordered_hash {
	'<>' => '<third_элемент>third значение</third_элемент>',
};
my $xml6 = xml_dom_from_ordered_hash {
	root_element => {
		'10_<>' => '<first_элемент>first значение</first_элемент>',
		'20_second_element' => 'second value',
		'30_<>' => $xml6_inner,
	},
};
DEBUG && print 'xml6: '.toUnicodeString( $xml6 ), "\n";
ok $xml6->findvalue( '/root_element/first_элемент' ) eq 'first значение'
	&& $xml6->findvalue( '/root_element/second_element' ) eq 'second value',
	'Inclusion of XML strings into ohashs';
ok $xml6->findvalue( '/root_element/third_элемент' ) eq 'third значение',
	'Inclusion of XML DOMs into ohashs';
DEBUG && print "\n";

DEBUG && print "13. constructing xml fragments from ohashs and including them\n";
my $xml7_inner = xml_fragment_from_hash {
	'10_<>' => 'текст',
	'20_<>' => '<xml>xml</xml>',
};
my $xml7 = xml_dom_from_ordered_hash {
	root_element => $xml7_inner,
};
DEBUG && print "xml7_inner: ".toUnicodeString( $xml7_inner ), "\n";
DEBUG && print "xml7: ".toUnicodeString( $xml7 ), "\n";
ok $xml7->findvalue( '/root_element/xml' ) eq 'xml'
	&& $xml7->findvalue( '/root_element/text()' ) eq "текст",
	'Constructing xml from ohash fragments';
DEBUG && print "\n";

# в toUnicodeString проверять кодировку для того, что бы можно было без
# "document->setEncoding" во время парсинга работать
# -похоже, всё нормально!
#my $xml_fragment8 = xml_fragment_from_hash { '<>' => "проверка", el => "кодировок", };
my $xml_fragment8 = parse_xml_fragment 'проверка<элт>кодировок</элт>';
#DEBUG && print toUnicodeString( $xml_fragment8 ), "\n";
#DEBUG && print $xml_fragment8->findvalue( 'элт' ), "\n";
use Encode qw(encode_utf8);
my $doc8 = XML::LibXML->load_xml( string => encode_utf8 '<?xml version="1.0" encoding="utf-8"?><элт>кодировок</элт>' );
DEBUG && print toUnicodeString( $doc8 ), "\n";
DEBUG && print $doc8->findvalue( '//элт' ), "\n";
ok utf8::is_utf8( $doc8->findvalue( '//элт' ) )
	&& utf8::is_utf8( $xml_fragment8->findvalue( 'элт' ) )
	, 'Correct encoding test';
# Попробовать ещё создать не utf8 документ, и добавить в него юникодные данные, а потом сделать toUnicodeString

# TODO change xml_dom_from_ordered_hash to xml_from_hash

=pod
DEBUG && print "8.\n";
my $xml6 = xml_dom_from_ordered_hash +{
	root_element => {
		'@' => {
			xmlns => 'urn:test',
		},
	},
};
DEBUG && print "constructed xml6: ".toUnicodeString( $xml6, 1 ), "\n";
DEBUG && print "\n";

DEBUG && print "9.\n";
my $xml6 = xml_dom_from_ordered_hash +{
	root_element => {
		'@xmlns' => 'urn:test',
	},
};
DEBUG && print "constructed xml6: ".toUnicodeString( $xml6, 1 ), "\n";
DEBUG && print "\n";
=cut
