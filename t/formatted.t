use v6;

use Test;
use Pod::To::PDF::API6;
use PDF::Tags;
use PDF::API6;

plan 1;

my $xml = q{<Document Lang="en">
  <P>
    This text is of <Span TextDecorationType="Underline">minor significance</Span>.
  </P>
  <P>
    This text is of <Em>major significance</Em>.
  </P>
  <P>
    This text is of <Strong>fundamental significance</Strong>.
  </P>
  <P>
    This text is verbatim C&lt;with&gt; B&lt;disarmed&gt; Z&lt;formatting&gt;.
  </P>
  <P>
    This text has been replaced.
  </P>
  <P>
    This text is invisible.
  </P>
  <P>
    This text contains a link to <Link href="http://www.google.com/">http://www.google.com/</Link>.
  </P>
  <P>
    This text contains a link with label to <Link href="http://www.google.com/">google</Link>.
  </P>
  <P>
    A tap on an <Code>on demand</Code> supply will initiate the production of values, and tapping the supply again may result in a new set of values. For example, <Code>Supply.interval</Code> produces a fresh timer with the appropriate interval each time it is tapped. If the tap is closed, the timer simply stops emitting values to that tap.
  </P>
</Document>
};

my Pod::To::PDF::API6 $doc .= new: :$=pod, :replace{'is to be replaced' => 'has been replaced'};
my PDF::API6 $pdf = $doc.pdf;
$pdf.id = $*PROGRAM.basename.fmt('%-16.16s');
$pdf.save-as: "t/formatted.pdf", :!info;
my PDF::Tags $tags = $doc.tags;

is $tags[0].Str, $xml,
   'Various types of code blocks convert correctly.';

=begin pod
This text is of U<minor significance>.

This text is of I<major significance>.

This text is of B<fundamental significance>.

This text is V<verbatim C<with> B<disarmed> Z<formatting>>.

This text R<is to be replaced>.

This text is Z<blabla>invisible.

This text contains a link to L<http://www.google.com/>.

This text contains a link with label to L<google|http://www.google.com/>.

=comment a real-world sample, taken from Supply.pod6

A tap on an C<on demand> supply will initiate the production of values, and
tapping the supply again may result in a new set of values. For example,
C<Supply.interval> produces a fresh timer with the appropriate interval each
time it is tapped. If the tap is closed, the timer simply stops emitting values
to that tap.

=end pod
