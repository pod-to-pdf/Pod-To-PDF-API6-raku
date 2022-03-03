use v6;

use Test;
use Pod::To::PDF::API6;
use PDF::API6;


plan 2;

my $xml = q{<Document>
  <Sect>
    <H>
      Outer
    </H>
    <P>
      This is an outer paragraph
    </P>
    <Sect>
      <H>
        Inner1
      </H>
      <P>
        This is the first inner paragraph
      </P>
    </Sect>
    <Sect>
      <H>
        Inner2
      </H>
      <P>
        This is the second inner paragraph
      </P>
    </Sect>
  </Sect>
</Document>
};

my Pod::To::PDF::API6 $doc .= new: :$=pod;
my PDF::API6 $pdf = $doc.pdf;
$pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');
$pdf.save-as: "t/subsections.pdf", :!info;
my PDF::Tags $tags = $doc.tags;

is $tags[0].Str, $xml,
   'Various types of paragraphs nest correctly';


=begin pod
=begin Outer

This is an outer paragraph

=begin Inner1

This is the first inner paragraph

=end Inner1

    =begin Inner2

    This is the second inner paragraph

    =end Inner2
=end Outer
=end pod
