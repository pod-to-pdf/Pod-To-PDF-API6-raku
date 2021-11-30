use v6;

use Test;
use Pod::To::PDF;
use PDF::API6;
use PDF::Tags;
plan 1;

my $xml = q{<Blah></Blah>};

my PDF::API6 $pdf = pod2pdf($=pod);
$pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');
$pdf.save-as: "t/table.pdf", :!info;
my PDF::Tags $tags .= read: :$pdf;

is $tags[0].Str, $xml,
    'Converts tables correctly';

=begin pod
asdf
=begin table :caption('Table 1')
A A    B B       C C
1 1    2 2       3 3
=end table
asdf
=begin table :caption('Table 2')
H 1 | H 2 | H 3
====|=====|====
A A | B B | C C
1 1 | 2 2 | 3 3
=end table
asdf

=begin table :caption('Table 3')
       HHH
  H11  222  H 3
  ===  ===  ===
  AAA  BB   C C
            C C

  1 1  2 2  3 3
       2 2
=end table
asdf
=end pod
