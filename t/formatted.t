use v6;

use Test;
use Pod::To::PDF;
use PDF::Tags;
use PDF::API6;

plan 1;

my $markdown = q{This text is of _minor significance_.

This text is of *major significance*.

This text is of **fundamental significance**.

This text is verbatim C<with> B<disarmed> Z<formatting>.

This text is <var>to be replaced</var>.

This text is invisible.

This text contains a link to [http://www.google.com/](http://www.google.com/).

This text contains a link with label to [google](http://www.google.com/).};

my PDF::API6 $pdf = pod2pdf($=pod);
$pdf.save-as: "/tmp/formatted.pdf";
my PDF::Tags() $tags = $pdf;

##is $tags[0].Str, $xml,
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
