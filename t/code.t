use v6;

use Test;
use Pod::To::PDF;
use PDF::Tags;
use PDF::API6;

plan 1;

my $xml = q{<Document>
  <P>asdf</P>
  <Code>indented</Code>
  <P>asdf</P>
  <Code>indented
multi
line</Code>
  <P>asdf</P>
  <Code>indented
multi
line

    nested
and
broken
up</Code>
  <P>asdf</P>
  <Code>Abbreviated</Code>
  <P>asdf</P>
  <Code>Paragraph
code</Code>
  <P>asdf</P>
  <Code>Delimited
code</Code>
  <P>asdf</P>
</Document>
};

my Pod::To::PDF $doc .= new: :$=pod;
my PDF::API6 $pdf = $doc.pdf;
$pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');
$pdf.save-as: "t/code.pdf", :!info;
my PDF::Tags $tags = $doc.tags;

is $tags[0].Str(:omit<Span>), $xml,
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
=end pod
