use v6;

use Test;
use Pod::To::PDF::API6;
use PDF::API6;
use PDF::Tags;

plan 1;

my $xml = q{<Document Lang="en">
  <P>
    asdf
  </P>
  <Code Placement="Block">
    indented
  </Code>
  <P>
    asdf
  </P>
  <Code Placement="Block">
    indented
    multi
    line
  </Code>
  <P>
    asdf
  </P>
  <Code Placement="Block">
    indented
    multi
    line
    
        nested
    and
    broken
    up
  </Code>
  <P>
    asdf
  </P>
  <Code Placement="Block">
    Abbreviated
  </Code>
  <P>
    asdf
  </P>
  <Code Placement="Block">
    Paragraph
    code
  </Code>
  <P>
    asdf
  </P>
  <Code Placement="Block">
    Delimited
    code
  </Code>
  <P>
    asdf
  </P>
  <Code Placement="Block">
    <Strong>Formatted</Strong>
    code
  </Code>
</Document>
};

my Pod::To::PDF::API6 $doc .= new: :$=pod;
my PDF::API6 $pdf = $doc.pdf;
$pdf.id = $*PROGRAM.basename.fmt('%-16.16s');
$pdf.save-as: "t/code.pdf", :!info;
my PDF::Tags $tags = $doc.tags;

is $tags[0].Str, $xml,
   'Various types of code blocks convert correctly.';

=begin pod
asdf

    indented

asdf

    indented
    multi
    line

asdf

    indented
    multi
    line
    
        nested
    and
    broken
    up

asdf

=code Abbreviated

asdf

=for code
Paragraph
code

asdf

=begin code
Delimited
code
=end code

asdf

=begin code :allow<B>
B<Formatted>
code
=end code

=end pod
