use v6;

use Test;
use Pod::To::PDF::API6;
use PDF::API6;

plan 1;

my $xml = q{<Document>
  <P>
    This is all a paragraph.
  </P>
  <P>
    This is the next paragraph.
  </P>
  <P>
    This is the third paragraph.
  </P>
  <P>
    Abbreviated paragraph
  </P>
  <P>
    Paragraph paragraph
  </P>
  <P>
    Block
  </P>
  <P>
    paragraph
  </P>
  <P>
    spaces and tabs are ignored
  </P>
  <P>
    sanity test of <Span><Reference>
        <Lbl>
          <Link>[1]</Link>
        </Lbl>
      </Reference><Note>
        <Lbl>
          <Link>[1]</Link>
        </Lbl>
        <P>
          if you click, here, you should got back to the paragraph
        </P>
      </Note></Span> footnotes.
  </P>
  <P>
    Paragraph with formatting, <Code>code</Code> and <Link href="#blah">links</Link>.
  </P>
  <P>
    aaaaabbbbbcccccdddddeeeeefffffggggghhhhhiiiiijjjjjkkkkklllllmmmmmnnnnnooooopppppqqqqqrrrrrssssstttttuuuuuvvvvvwwwwwxxxxxyyyyyzzzzz
  </P>
</Document>
};

my Pod::To::PDF::API6 $doc .= new: :$=pod;
my PDF::API6 $pdf = $doc.pdf;
$pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');
$pdf.save-as: "t/paragraph.pdf", :!info;
my PDF::Tags $tags = $doc.tags;

is $tags[0].Str, $xml,
    'Paragraphs convert correctly.';

=begin pod
This is all
a paragraph.

This is the
next paragraph.

This is the
third paragraph.
=end pod

=para Abbreviated paragraph

=for para
Paragraph
paragraph

=begin para
Block

paragraph
=end para

=para spaces  and	tabs are ignored

=para sanity test of N<if you click, here, you should got back to the paragraph> footnotes.

=para Paragraph with B<formatting>, C<code> and L<links|#blah>.

=comment a single word that exceeds the line width

=para aaaaabbbbbcccccdddddeeeeefffffggggghhhhhiiiiijjjjjkkkkklllllmmmmmnnnnnooooopppppqqqqqrrrrrssssstttttuuuuuvvvvvwwwwwxxxxxyyyyyzzzzz
