use v6;

use Test;
use Pod::To::PDF;
use PDF::API6;

plan 1;

my $xml = q{<Document>
  <Sect>
    <H2>Module Asdf1</H2>
    <Code>module Asdf1</Code>
    <P>This is a module</P>
  </Sect>
  <Sect>
    <H3>Sub asdf</H3>
    <Code>sub asdf(
    Str $asdf1, 
    Str :$asdf2 = "asdf", 
) returns Str</Code>
    <P>This is a sub</P>
  </Sect>
  <Sect>
    <H2>Class Asdf2</H2>
    <Code>class Asdf2</Code>
    <P>This is a class</P>
  </Sect>
  <Sect>
    <H3>Attribute t</H3>
    <Code>has Str $.t</Code>
    <P>This is an attribute</P>
  </Sect>
  <Sect>
    <H3>Method asdf</H3>
    <Code>method asdf(
    Str :$asdf = "asdf", 
) returns Str</Code>
    <P>This is a method</P>
  </Sect>
</Document>
};

my PDF::API6 $pdf = pod2pdf($=pod);
$pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');
$pdf.save-as: "t/definition.pdf", :!info;
my PDF::Tags $tags .= read: :$pdf;

is $tags[0].Str(:omit<Span>), $xml,
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


