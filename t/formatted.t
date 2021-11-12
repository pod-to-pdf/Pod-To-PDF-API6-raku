use v6;

use Test;
use Pod::To::PDF;
use PDF::Tags;
use PDF::API6;

plan 1;

my $xml = q{<Document>
  <P>This text is of minor significance .</P>
  <P>This text is of major significance .</P>
  <P>This text is of fundamental significance .</P>
  <P>This text is verbatim C&lt;with&gt; B&lt;disarmed&gt; Z&lt;formatting&gt;.</P>
  <P>This text is to be replaced .</P>
  <P>This text is invisible.</P>
  <P>This text contains a link to http://www.google.com/ .</P>
  <P>This text contains a link with label to google .</P>
</Document>
};

my PDF::API6 $pdf = pod2pdf($=pod);
$pdf.save-as: "/tmp/formatted.pdf";
my PDF::Tags() $tags = $pdf;

is $tags[0].Str, $xml,
##   'Various types of code blocks convert correctly.';

=begin pod
This text is of U<minor significance>.

This text is of I<major significance>.

This text is of B<fundamental significance>.

This text is V<verbatim C<with> B<disarmed> Z<formatting>>.

This text is R<to be replaced>.

This text is Z<blabla>invisible.

This text contains a link to L<http://www.google.com/>.

This text contains a link with label to L<google|http://www.google.com/>.
=end pod
