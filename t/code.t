use v6;

use Test;
use Pod::To::PDF::API6;
use PDF::API6;

plan 1;

my $xml = q{<Document Lang="en">
  <P>
    asdf
  </P>
  <P>
    <Code>indented</Code>
  </P>
  <P>
    asdf
  </P>
  <P>
    <Code>indented
multi
line</Code>
  </P>
  <P>
    asdf
  </P>
  <P>
    <Code>indented
multi
line

    nested
and
broken
up</Code>
  </P>
  <P>
    asdf
  </P>
  <P>
    <Code>Abbreviated</Code>
  </P>
  <P>
    asdf
  </P>
  <P>
    <Code>Paragraph
code</Code>
  </P>
  <P>
    asdf
  </P>
  <P>
    <Code>Delimited
code</Code>
  </P>
  <P>
    asdf
  </P>
  <P>
    <Code><Strong>Formatted</Strong>
code</Code>
  </P>
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
