use v6;

use Test;
use Pod::To::PDF::API6;
use PDF::API6;

plan 1;

my $xml = q{<Document Lang="en">
  <P>
    asdf
  </P>
  <L>
    <LI>
      <Lbl>
        •
      </Lbl>
      <LBody>
        <P>
          Abbreviated 1
        </P>
      </LBody>
    </LI>
    <LI>
      <Lbl>
        •
      </Lbl>
      <LBody>
        <P>
          Abbreviated 2
        </P>
      </LBody>
    </LI>
  </L>
  <P>
    asdf
  </P>
  <L>
    <LI>
      <Lbl>
        •
      </Lbl>
      <LBody>
        <P>
          Top Item
        </P>
        <L>
          <LI>
            <Lbl>
              ·
            </Lbl>
            <LBody>
              <P>
                First sub-item
              </P>
            </LBody>
          </LI>
          <LI>
            <Lbl>
              ·
            </Lbl>
            <LBody>
              <P>
                Second sub-item
              </P>
            </LBody>
          </LI>
        </L>
      </LBody>
    </LI>
    <LI>
      <Lbl>
        •
      </Lbl>
      <LBody>
        <P>
          Paragraph item
        </P>
      </LBody>
    </LI>
  </L>
  <P>
    asdf
  </P>
  <L>
    <LI>
      <Lbl>
        •
      </Lbl>
      <LBody>
        <P>
          Block item
        </P>
      </LBody>
    </LI>
  </L>
  <P>
    asdf
  </P>
  <L>
    <LI>
      <Lbl>
        •
      </Lbl>
      <LBody>
        <P>
          Abbreviated
        </P>
      </LBody>
    </LI>
    <LI>
      <Lbl>
        •
      </Lbl>
      <LBody>
        <P>
          Paragraph item
        </P>
      </LBody>
    </LI>
    <LI>
      <Lbl>
        •
      </Lbl>
      <LBody>
        <P>
          Block item
        </P>
        <P>
          with multiple
        </P>
        <P>
          paragraphs
        </P>
      </LBody>
    </LI>
  </L>
  <P>
    asdf
  </P>
</Document>
};

my Pod::To::PDF::API6 $doc .= new: :$=pod;
my PDF::API6 $pdf = $doc.pdf;
$pdf.id = $*PROGRAM.basename.fmt('%-16.16s');
$pdf.save-as: "t/item.pdf", :!info;
my PDF::Tags $tags = $doc.tags;

is $tags[0].Str, $xml,
   'Various types of items convert correctly';


=begin pod
asdf

=item Abbreviated 1
=item Abbreviated 2

asdf

=begin item1
Top Item
=item2     First sub-item
=item2     Second sub-item
=end item1

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
