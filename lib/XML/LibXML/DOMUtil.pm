package XML::LibXML::DOMUtil;

use warnings;
use strict;

=head1 NAME

XML::LibXML::DOMUtil - The great new XML::LibXML::DOMUtil!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use XML::LibXML::DOMUtil;

    my $foo = XML::LibXML::DOMUtil->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 FUNCTIONS

=head2 function1

=cut

sub function1 {
}

=head2 function2

=cut

sub function2 {
}

=head1 AUTHOR

Andrey Smirnov, C<< <allter at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-xml-libxml-domutil at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=XML-LibXML-DOMUtil>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc XML::LibXML::DOMUtil


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=XML-LibXML-DOMUtil>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/XML-LibXML-DOMUtil>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/XML-LibXML-DOMUtil>

=item * Search CPAN

L<http://search.cpan.org/dist/XML-LibXML-DOMUtil/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2012 Andrey Smirnov, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

use base 'Exporter';
our @EXPORT = qw(
	parse_xml
	parse_xml_fragment
	importXML
	importXMLFragment
	importOrderedHash
	toUnicodeString
	toByteString
	xml_fragment_from_hash
	xml_from_hash
	xml_dom_from_ordered_hash
	replaceInnerNodes
);

use XML::LibXML;

# parse_xml( $xml ) - Parses xml
sub parse_xml ( $ )
{
	# TODO xml string check
	my $doc = XML::LibXML->load_xml( string => $_[0] );
	$doc->setEncoding( 'utf-8' );
	return $doc;
};

# parse_xml_fragment( $xml ) - Parses xml fragment
sub parse_xml_fragment ( $ )
{
	# TODO xml string check
	my $document = parse_xml "<fake_root>".$_[0]."</fake_root>";
	my $root = $document->documentElement;
	my $new_document = XML::LibXML::Document->new();
	my $df = $new_document->createDocumentFragment();
	return $df unless $root->hasChildNodes;

	my $c = $root->firstChild;
	do
	{
		$df->appendChild( $new_document->importNode( $c ) );
		$c = $c->nextSibling;
	} while $c;
	return $df;
}

# importXMLFragment( $dom, $xml ) - Parses and imports $xml fragment to the document of $dom
sub importXMLFragment ( $ $ )
{
	my ( $dom, $xml ) = @_;
	# TODO xml string check

	my $fragment = parse_xml_fragment( $xml );
	return $dom->ownerDocument->importNode( $fragment );
}

# importXML( $dom, $xml ) - Parses and imports $xml to the document of $dom
sub importXML( $ $ )
{
	my ( $dom, $xml ) = @_;
	# TODO xml string check

	my $xml_document = XML::LibXML->load_xml( string => $xml );
	my $xml_root_element = $xml_document->documentElement();

	return $dom->ownerDocument()->importNode( $xml_root_element );
}

# replaceInnerNodes( $node, $replacement_node ) - Replaces inner child nodes
# (which is not attribute or some specific nodes)
# Somewhat like innerXML property in some frameworks, but works with DOM instead of strings.
sub replaceInnerNodes( $ $ )
{
	my ( $node, $replacement_node ) = @_;

	if ( $node->hasChildNodes )
	{
		my @nodes_to_delete;
		my $first_child = $node->firstChild;
		my $last_child = $node->lastChild;

		my $c = $first_child;
		do
		{
			my $nt = $c->nodeType;
			push @nodes_to_delete, $c
				unless $nt == XML::LibXML::XML_ATTRIBUTE_NODE
					|| $nt == XML::LibXML::XML_DTD_NODE
					|| $nt == XML::LibXML::XML_ENTITY_DECL
					|| $nt == XML::LibXML::XML_NAMESPACE_DECL
					;
			$c = $c->nextSibling();
		} until ! $c || $c->isSameNode( $last_child );

		foreach ( @nodes_to_delete )
		{
			$node->removeChild( $_ );
		}
	}

	$node->appendChild( $replacement_node );
}

sub _get_document_fragment_from_ordered_hash ( $ @ );

# importOrderedHash( $dom, $ohash ) - imports to $dom the document fragment
# or element constructed from ohash
# Note that namespaces prefixes are taken at the $dom level of tree
sub importOrderedHash( $ $ )
{
	my ( $dom, $ohash ) = @_;

	my $ohash_attr = $ohash->{ '@' } || {};
	my %namespace_by_prefix = (
		map
		{
			/^xmlns(?:|:([A-Za-z0-9]+))$/
				? ( $1 || '' => $ohash_attr->{ $_ } )
				: ();
		}
			keys %$ohash_attr
	);
	$ohash = { map { $_ => $ohash->{$_}; } grep !/^\@$/, keys %$ohash };
	my $df = _get_document_fragment_from_ordered_hash( $dom, $ohash, \%namespace_by_prefix );
#warn 'importOrderedHash: $df='.$df->toString( 1 );
#warn $df->firstChild->isSameNode( $df->lastChild );
#warn $df->lastChild->toString(1);
	my $fc = $df->firstChild;
#warn $fc->toString( 1 );

	if ( $df->hasChildNodes()
		&& $fc->nodeType == XML::LibXML::XML_ELEMENT_NODE
		&& $fc->isSameNode( $df->lastChild )
	)
	{
		$fc->unbindNode();
		return $fc;
	}

	return $df;
}

# Recursively construct XML DOM documentFragment from ohash
sub _get_document_fragment_from_ordered_hash ( $ @ )
{
	my ( $dom, $ohash, $namespace_by_prefix ) = @_;
	my $document = $dom->nodeType() == XML::LibXML::XML_DOCUMENT_NODE
		? $dom
		: $dom->ownerDocument;
	my $df = $document->createDocumentFragment();

#use Data::Dumper;
#warn 'namespace_by_prefix: '.Dumper $namespace_by_prefix;

	# Get parsed and sorted elements -> key mappings
	my @keys
		=
		sort
		{
			( defined $a->[0]
				? ( 0 + $a->[0] ).$a->[1]
				: $a->[1] )
				cmp ( defined $b->[0]
					? ( 0 + $b->[0] ).$b->[1]
					: $b->[1]
				);
		}
		map
		{
			#    1          2          3
			/^(?:(\d+)_)?(?:([^:]+)\:)?(.+)$/
				#  [ ord, elt, key, ns ]
				? ( [ $1, $3, $_, $2 ] )
				: ();
		}
			keys %$ohash;

	foreach ( @keys )
	{
		my ( $key, $element_name, $ns ) = ( $_->[2], $_->[1], $_->[3] );

		# Особый случай - включение сырого XML или xml dom
		if ( $element_name eq '<>' )
		{
			if ( UNIVERSAL::isa( $ohash->{ $key }, 'XML::LibXML::Node' ) )
			{
				$df->appendChild( $document->importNode( _get_element( $ohash->{ $key } ) ) );
			}
			else
			{
				my $xml = parse_xml_fragment $ohash->{ $key };
				$df->appendChild( $document->importNode( $xml ) );
			}
			next;
		};

		# Create element. If needed, use namespace
		my $el;
		if ( defined $ns && length $ns )
		{
			if ( $namespace_by_prefix->{ $ns } )
			{
				$el = $document->createElementNS( $namespace_by_prefix->{ $ns }, $ns.":".$element_name );
			}
			else
			{
				my $uri = $dom->lookupNamespaceURI( $ns );
				unless ( defined $uri )
				{
					require Carp;
					Carp::croak "Uri not defined for namespace prefix $ns neither in hash nor in the dom";
				}
				$el = $document->createElementNS( $uri, $ns.":".$element_name );
			}
		}
		else
		{
			if ( $namespace_by_prefix->{ '' } )
			{
				$el = $document->createElementNS( $namespace_by_prefix->{ '' }, $element_name );
			}
			else
			{
				$el = $document->createElement( $element_name );
			}
		}

		# Populate the created element
		if ( ! ref $ohash->{ $key } )
		{
			my $text = $document->createTextNode( $ohash->{ $key } );
			$el->appendChild( $text );
		}
		elsif ( ref $ohash->{ $key } eq 'HASH' )
		{
			# Recursively append fragment for the ohash value
			my $df2 = _get_document_fragment_from_ordered_hash( $document,
				_extract_inner_hash_and_namespace_by_prefix(
					$document, $el, $ohash->{ $key }, $namespace_by_prefix
				)
			);
			$el->appendChild( $df2 );
		}
		elsif ( UNIVERSAL::isa( $ohash->{ $key }, 'XML::LibXML::Node' ) )
		{
			$el->appendChild( $document->importNode( _get_element( $ohash->{ $key } ) ) );
		}
		else
		{
			die "Unsupported type of hash value";
		}

		# Actually append
		$df->appendChild( $el );
	}

	return $df;
}

# Returns refs to inner hash and prefix mappings for recursive processing ohashes
# Attributes that are removed from the original are appended into current element
sub _extract_inner_hash_and_namespace_by_prefix
{
	my ( $document, $current_element, $original_hash, $outer_namespace_by_prefix ) = @_;

	my %inner_hash = %$original_hash;
	my %inner_namespace_by_prefix = %$outer_namespace_by_prefix;

	# Process special '@'-key: sort into namespace and ordinary attrs
	my $ahash = $inner_hash{ '@' } || {};
	my @attrs;
	foreach ( keys %$ahash )
	{
		if ( /^xmlns(?:|:([A-Za-z0-9]+))$/ )
		{
			$inner_namespace_by_prefix{ $1 || '' } = $ahash->{ $_ };
#warn 'aaa', $1, $ahash->{ $_ };
		}
		else
		{
			push @attrs, $_;
		}
	}

	# Remove namespace attrs from @keys
	my @nskeys = grep /^(?:(\d+)_)?\@xmlns/, keys %inner_hash;
	foreach ( @nskeys )
	{
		if ( /\@xmlns(?:|:([A-Za-z0-9]+))$/ )
		{
			# add namespace
			$inner_namespace_by_prefix{ $1 || '' } = $inner_hash{ $_ };
		}
		else
		{
			die "Unsupported namespace declaration $_";
		}
	}
	delete @inner_hash{ @nskeys };

	# Process attribute nodes from '@'-key
	if ( @attrs )
	{
		unless ( $current_element->nodeType == XML::LibXML::XML_ELEMENT_NODE )
		{
			require Carp;
			croak( "Attributes only supported on ELEMENT nodes" );
		}
		foreach ( @attrs )
		{
#warn $_;
			_setAttributeSmart( $current_element, \%inner_namespace_by_prefix, $_, $inner_hash{ '@' }{ $_ } );
#warn "$_, $inner_hash{ '@' }{ $_ }";
#warn $current_element->toString();
		}
	}

	# Delete '@'-key from inner_hash
	delete $inner_hash{ '@' };

	# Process attribute nodes from other @keys
	my @akeys = grep /^(?:(\d+)_)?\@/, keys %inner_hash;
#use Data::Dumper;
#warn Dumper \@akeys;
	if ( @akeys )
	{
		unless ( $current_element->nodeType == XML::LibXML::XML_ELEMENT_NODE )
		{
			require Carp;
			croak( "Attributes only supported on ELEMENT nodes" );
		}
		foreach ( @akeys )
		{
			my ( $aname ) = /\@(.+)$/;
			_setAttributeSmart( $current_element, \%inner_namespace_by_prefix, $aname, $inner_hash{ $_ } );
#warn 'ce::: '.$current_element->toString();
		}
	}

	# Delete @keys from inner_hash
	delete @inner_hash{ @akeys };
#use Data::Dumper;
#warn 'inner_hash: '.Dumper \%inner_hash;
#warn 'inner_namespace_by_prefix: '.Dumper \%inner_namespace_by_prefix;

	return ( \%inner_hash, \%inner_namespace_by_prefix );
}

# Sets attribute in a smart way (either by setAttribute or by setAttributeNS
sub _setAttributeSmart
{
	my ( $element, $namespace_by_prefix, $key, $value ) = @_;
	if ( $key =~ /^([^:]+):(.+)$/ )
	{
		return $element->setAttributeNS(
			$namespace_by_prefix->{ $1 }, $key, $value
		);
	}
	else
	{
		return $element->setAttribute( $key, $value );
	}
}

# xml_fragment_from_hash( $ohash ) - construct XML DocumentFragment from ohash
sub xml_fragment_from_hash( $ )
{
	my $ohash = shift;
	my $document = XML::LibXML::Document->new();

	my $df = _get_document_fragment_from_ordered_hash( $document, $ohash, +{} );

	return $df;
}

# xml_from_hash ( $ohash ) - construct XML Document from a ohash
sub xml_from_hash ( $ )
{
}

# xml_dom_from_ordered_hash( $ohash ) - construct XML DOM from a ohash
sub xml_dom_from_ordered_hash( $ )
{
	my $ohash = shift;
	die "Ordered hash must have a single key"
		unless ref $ohash eq 'HASH' && scalar keys %$ohash == 1;

	my $document = XML::LibXML::Document->new();
	$document->setEncoding( 'utf-8' );

	my $key = ( keys %$ohash )[0];
	if ( $key =~ /(?:(\d+)_)?<>$/ )
	{
		if ( UNIVERSAL::isa( $ohash->{ $key }, 'XML::LibXML::Node' ) )
		{
			my $importedElement = $document->importNode( _get_element( $ohash->{ $key } ) );
			$document->setDocumentElement( $importedElement );
		}
		else
		{
			my $xml = parse_xml $ohash->{ $key };
			$document->setDocumentElement( $document->importNode( $xml->documentElement ) );
		}
	}
	else
	{
		my ( $element_name ) = $key =~ /^(?:\d+_)?(\D+)$/;

		# Create element
		my $el = $document->createElement( $element_name );
		$document->setDocumentElement( $el );

		# Populate element
		if ( ! ref $ohash->{ $key } )
		{
			my $text = $document->createTextNode( $ohash->{ $key } );
			$el->appendChild( $text );
		}
		elsif ( ref $ohash->{ $key } eq 'HASH' )
		{
			my $df = _get_document_fragment_from_ordered_hash( $document,
				_extract_inner_hash_and_namespace_by_prefix(
					$document, $el, $ohash->{ $key }, {}
				)
			);
			$el->appendChild( $df );
		}
		elsif ( UNIVERSAL::isa( $ohash->{ $key }, 'XML::LibXML::Node' ) )
		{
			$el->appendChild( $document->importNode( _get_element( $ohash->{ $key } ) ) );
		}
		else
		{
			die "Unsupported type of hash value";
		}
	}

	return $document;
}

# Returns element, even if an argument is a document
sub _get_element ( $ )
{
	return $_[0]->nodeType() == XML::LibXML::XML_DOCUMENT_NODE
		? $_[0]->documentElement
		: $_[0];
}

# toUnicodeString( $dom, $format ) Presents the specified dom hierarchy as a unicode string containing
# well-formed XML. No xml prologue (<?xml..>), DTD or ENTITY stuff is written.
sub toUnicodeString ( $ ; $ $ )
{
	$_[1] = 0 unless $_[1];
	return $_[0]->nodeType() == XML::LibXML::XML_DOCUMENT_NODE
		? $_[0]->ownerDocument->documentElement->toString( $_[1], $_[2] )
		: $_[0]->toString( $_[1], $_[2] );
}

# toByteString( $dom, $encoding [ , $format ] ) Presents the specified dom hierarchy as encoded byte string containing
# well-formed XML. No xml prologue (<?xml..>), DTD or ENTITY stuff is written.
# TODO: support for writing documentFragments
sub toByteString ( $ $ ; $ )
{
	my $xml = shift;
	my $encoding = shift;
	my $style = shift;

	my $new_document = XML::LibXML::Document->new();
	$new_document->setEncoding( $encoding );
	my $old_root_element = $xml->nodeType() == XML::LibXML::XML_DOCUMENT_NODE
		? $xml->ownerDocument->documentElement
		: $xml;
#warn $old_root_element;
	my $root_element = $new_document->adoptNode(
		$old_root_element->cloneNode( 1 )
	);
#use Data::Dumper;
#warn Dumper [
#$old_root_element->ownerDocument->actualEncoding,
#$old_root_element->ownerDocument->getEncoding,
#$root_element->ownerDocument->getEncoding,
#$root_element->ownerDocument->actualEncoding,
#$new_document->getEncoding
#];
	#return $root_element->toString( $style, $encoding );
	#return $root_element->toString( $style, 'ascii' );
#	$new_document->setEncoding( cp1251 => );

	$new_document->setDocumentElement( $root_element );
#	$new_document->setEncoding( cp1251 => );
	my $serialization = $new_document->toString( $style );
	$serialization =~ s|^<\?xml[^>]*>[^<]*||;
	return $serialization;
	#return $root_element->toString( $style, 'latin-1' );
}


1; # End of XML::LibXML::DOMUtil
