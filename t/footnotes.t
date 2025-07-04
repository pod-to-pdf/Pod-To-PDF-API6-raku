use v6;

use Test;
use Pod::To::PDF::API6 :&pod-render;
use PDF::API6;
use PDF::Tags;

plan 1;

my $xml = q{<Document Lang="en">
  <P>
    sanity test of  footnotes.
    <FENote>
      if you click, here, you should got back to the paragraph
    </FENote>
  </P>
</Document>
};

my $renderer = pod-render($=pod);
my PDF::API6 $pdf = $renderer.pdf;
$pdf.id = $*PROGRAM.basename.fmt('%-16.16s');
$pdf.save-as: "t/footnotes.pdf", :!info;
my PDF::Tags $tags = $renderer.tags;

is $tags[0].Str, $xml,
    'Paragraphs convert correctly.';

=begin pod

=para sanity test of N<if you click, here, you should got back to the paragraph> footnotes.

=end pod
