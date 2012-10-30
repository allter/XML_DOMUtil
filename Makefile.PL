use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'XML::LibXML::DOMUtil',
    AUTHOR              => 'Andrey Smirnov <allter@gmail.com>',
    VERSION_FROM        => 'lib/XML/LibXML/DOMUtil.pm',
    ABSTRACT_FROM       => 'lib/XML/LibXML/DOMUtil.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'XML-LibXML-DOMUtil-*' },
);
