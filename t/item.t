use v6;

use Test;
use Pod::To::PDF;
use PDF::API6;

plan 1;

my $xml = q{<Document>
  <P>asdf</P>
  <LI>
    <Lbl>•</Lbl>
    <LBody>
      <P>Abbreviated 1</P>
    </LBody>
  </LI>
  <LI>
    <Lbl>•</Lbl>
    <LBody>
      <P>Abbreviated 2</P>
    </LBody>
  </LI>
  <P>asdf</P>
  <LI>
    <Lbl>•</Lbl>
    <LBody>
      <P>Paragraph item</P>
    </LBody>
  </LI>
  <P>asdf</P>
  <LI>
    <Lbl>•</Lbl>
    <LBody>
      <P>Block item</P>
    </LBody>
  </LI>
  <P>asdf</P>
  <LI>
    <Lbl>•</Lbl>
    <LBody>
      <P>Abbreviated</P>
    </LBody>
  </LI>
  <LI>
    <Lbl>•</Lbl>
    <LBody>
      <P>Paragraph item</P>
    </LBody>
  </LI>
  <LI>
    <Lbl>•</Lbl>
    <LBody>
      <P>Block item</P>
      <P>with multiple</P>
      <P>paragraphs</P>
    </LBody>
  </LI>
  <P>asdf</P>
</Document>
};

my PDF::API6 $pdf = pod2pdf($=pod);
$pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');
$pdf.save-as: "t/item.pdf", :!info;
my PDF::Tags $tags .= read: :$pdf;

is $tags[0].Str, $xml,
   'Various types of items convert correctly';


=begin pod
asdf

=item Abbreviated 1
=item Abbreviated 2

asdf

=for item
Paragraph
item

asdf

=begin item
Block
item
=end item

asdf

=item Abbreviated

=for item
Paragraph
item

=begin item
Block
item

with
multiple

paragraphs
=end item

asdf
=end pod
