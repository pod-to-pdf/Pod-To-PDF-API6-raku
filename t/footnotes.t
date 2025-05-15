use v6;

use Test;
use Pod::To::PDF::API6;
use PDF::API6;

plan 1;

my $xml = q{<Document Lang="en">
  <P>
    sanity test of <Span><Reference>
        <Lbl>
          <Link>[1]</Link>
        </Lbl>
      </Reference></Span> footnotes.<Note role="FootNote">
      <Lbl>
        <Link>[1]</Link>
      </Lbl>
      if you click, here, you should got back to the paragraph</Note>
  </P>
</Document>
};

my Pod::To::PDF::API6 $doc .= new: :$=pod;
my PDF::API6 $pdf = $doc.pdf;
$pdf.id = $*PROGRAM.basename.fmt('%-16.16s');
$pdf.save-as: "t/footnotes.pdf", :!info;
my PDF::Tags $tags = $doc.tags;

is $tags[0].Str, $xml,
    'Paragraphs convert correctly.';

=begin pod

=para sanity test of N<if you click, here, you should got back to the paragraph> footnotes.

=end pod
