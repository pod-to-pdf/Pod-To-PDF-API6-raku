use v6;

use Test;
use Pod::To::PDF;
use PDF::API6;

plan 1;

my $xml = q{<Document>
  <H1>
    Abbreviated heading1
  </H1>
  <P>
    asdf
  </P>
  <H1>
    Paragraph heading1
  </H1>
  <P>
    asdf
  </P>
  <H2>
    Subheading2
  </H2>
  <H1>
    Delimited heading1
  </H1>
  <H3>
    Heading3
  </H3>
  <P>
    asdf
  </P>
  <H2>
    Head2
  </H2>
  <P>
    asdf
  </P>
  <H3>
    Head3
  </H3>
  <P>
    asdf
  </P>
  <H4>
    Head4
  </H4>
  <P>
    asdf
  </P>
</Document>
};

my Pod::To::PDF $doc .= new: :$=pod;
my PDF::API6 $pdf = $doc.pdf;
$pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');
$pdf.save-as: "t/heading.pdf", :!info;
my PDF::Tags $tags = $doc.tags;

is $tags[0].Str, $xml,
   'Various types of headings convert correctly';

=begin pod
=head1 Abbreviated heading1

asdf

=for head1
Paragraph heading1

asdf

=head2 Subheading2

=begin head1
Delimited
	
heading1
=end head1

=head3 	Heading3

asdf

=head2 Head2

asdf

=head3 Head3

asdf

=head4 Head4

asdf

=end pod
