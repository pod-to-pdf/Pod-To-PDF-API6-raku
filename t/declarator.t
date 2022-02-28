use v6;

use Test;
use Pod::To::PDF::API6;
use PDF::Tags;
use PDF::API6;

plan 1;

my $xml = q{<Document>
  <Sect>
    <H2>
      Class Magician
    </H2>
    <Code>class Magician</Code>
    <P>
      Base class for magicians
    </P>
  </Sect>
  <Sect>
    <H3>
      Sub duel
    </H3>
    <Code>sub duel(
    Magician $a,
    Magician $b,
)</Code>
    <P>
      Fight mechanics
      Magicians only, no mortals.
    </P>
  </Sect>
</Document>
};

my Pod::To::PDF::API6 $doc .= new: :$=pod;
my PDF::API6 $pdf = $doc.pdf;
$pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');
$pdf.save-as: "t/declarator.pdf", :!info;
my PDF::Tags $tags = $doc.tags;

is $tags[0].Str, $xml,
   'Declarators convert correctly.';

## Example taken from docs.raku.org/language/pod#Declarator_blocks

#| Base class for magicians 
class Magician {
  has Int $.level;
  has Str @.spells;
}
 
#| Fight mechanics 
sub duel(Magician $a, Magician $b) {
}
#= Magicians only, no mortals. 

