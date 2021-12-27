use v6;

use Test;
use Pod::To::PDF::API6;
use PDF::Tags;
use PDF::API6;

plan 1;

my $xml = q{<Document>
  <P>
    This text is of minor significance.
  </P>
  <P>
    This text is of major significance.
  </P>
  <P>
    This text is of fundamental significance.
  </P>
  <P>
    This text is verbatim C<with> B<disarmed> Z<formatting>.
  </P>
  <P>
    This text is to be replaced.
  </P>
  <P>
    This text is invisible.
  </P>
  <P>
    This text contains a link to <Link>http://www.google.com/</Link>.
  </P>
  <P>
    This text contains a link with label to <Link>google</Link>.
  </P>
  <P>
    A tap on an on demand supply will initiate the production of values, and tapping the supply again may result in a new set of values. For example, Supply.interval produces a fresh timer with the appropriate interval each time it is tapped. If the tap is closed, the timer simply stops emitting values to that tap.
  </P>
</Document>
};

my Pod::To::PDF::API6 $doc .= new: :$=pod;
my PDF::API6 $pdf = $doc.pdf;
$pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');
$pdf.save-as: "t/formatted.pdf", :!info;
my PDF::Tags $tags = $doc.tags;

is $tags[0].Str, $xml,
   'Various types of code blocks convert correctly.';

=begin pod
This text is of U<minor significance>.

This text is of I<major significance>.

This text is of B<fundamental significance>.

This text is V<verbatim C<with> B<disarmed> Z<formatting>>.

This text is R<to be replaced>.

This text is Z<blabla>invisible.

This text contains a link to L<http://www.google.com/>.

This text contains a link with label to L<google|http://www.google.com/>.

A tap on an C<on demand> supply will initiate the production of values, and
tapping the supply again may result in a new set of values. For example,
C<Supply.interval> produces a fresh timer with the appropriate interval each
time it is tapped. If the tap is closed, the timer simply stops emitting values
to that tap.

=end pod
