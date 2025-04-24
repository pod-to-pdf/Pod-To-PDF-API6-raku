use v6;

use Test;
use Pod::To::PDF::API6;
use PDF::API6;

plan 1;

my $xml = q{<Document Lang="en">
  <H2>
    Outer
  </H2>
  <P>
    This is an outer paragraph
  </P>
  <H3>
    Inner1
  </H3>
  <P>
    This is the first inner paragraph
  </P>
  <H3>
    Inner2
  </H3>
  <P>
    This is the second inner paragraph
  </P>
</Document>
};

my Pod::To::PDF::API6 $doc .= new: :$=pod;
my PDF::API6 $pdf = $doc.pdf;
$pdf.id = $*PROGRAM.basename.fmt('%-16.16s');
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
