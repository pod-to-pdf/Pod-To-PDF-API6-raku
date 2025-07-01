use v6;

use Test;
use Pod::To::PDF::API6 :&pod-render;
use PDF::API6;
use PDF::Tags;

plan 1;

my $xml = q{<Document Lang="en">
  <Div role="Declaration">
    <H2>
      Module Asdf1
    </H2>
    <P>
      This is a module
    </P>
    <Code Placement="Block" role="Raku">
      module Asdf1
    </Code>
  </Div>
  <Div role="Declaration">
    <H3>
      Sub asdf
    </H3>
    <P>
      This is a sub
    </P>
    <Code Placement="Block" role="Raku">
      sub asdf(
          Str $asdf1,
          Str :$asdf2 = "asdf",
      ) returns Str
    </Code>
  </Div>
  <Div role="Declaration">
    <H2>
      Class Asdf2
    </H2>
    <P>
      This is a class
    </P>
    <Code Placement="Block" role="Raku">
      class Asdf2
    </Code>
  </Div>
  <Div role="Declaration">
    <H3>
      Attribute t
    </H3>
    <P>
      This is an attribute
    </P>
    <Code Placement="Block" role="Raku">
      has Str $.t
    </Code>
  </Div>
  <Div role="Declaration">
    <H3>
      Method asdf
    </H3>
    <P>
      This is a method
    </P>
    <Code Placement="Block" role="Raku">
      method asdf(
          Str :$asdf = "asdf",
      ) returns Str
    </Code>
  </Div>
</Document>
};

my $renderer = pod-render($=pod);
my PDF::API6 $pdf = $renderer.pdf;
$pdf.id = $*PROGRAM.basename.fmt('%-16.16s');
$pdf.save-as: "t/definition.pdf", :!info;
my PDF::Tags $tags = $renderer.tags;

is $tags[0].Str, $xml,
    'Converts definitions correctly';

#| This is a module
module Asdf1 {
    #| This is a sub
    sub asdf(Str $asdf1, Str :$asdf2? = 'asdf') returns Str {
	return '';
    }
}

#| This is a class
class Asdf2 does Positional  {
    #| This is an attribute
    has Str $.t = 'asdf';
    
    #| This is a method
    method asdf(Str :$asdf? = 'asdf') returns Str {
	
    }
}


