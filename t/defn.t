use v6;

use Test;
use Pod::To::PDF::API6;
use PDF::API6;

plan 2;

my PDF::API6 $pdf = pod2pdf($=pod);
$pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');
lives-ok {$pdf.save-as: "t/defn.pdf", :!info}

my $xml = q{<Document>
  <H2>
    pod2pdf() Options
  </H2>
  <Lbl>
    PDF::API6 :$pdf
  </Lbl>
  <P>
    A PDF object to render to.
  </P>
</Document>
};

try require ::('PDF::Tags::Reader');
if ::('PDF::Tags::Reader') ~~ Failure {
    skip-rest "PDF::Tags::Reader is required to perform structural PDF testing";
    exit 0;
}

subtest 'document structure', {
    plan 1;

    # PDF::Class is an indirect dependency of PDF::Tags::Reader
    require ::('PDF::Class');
    my $pdf  = ::('PDF::Class').open: "t/defn.pdf";
    my $tags = ::('PDF::Tags::Reader').read: :$pdf;
    is $tags[0].Str, $xml, 'PDF Structure is correct';
}

=begin pod

=head2 pod2pdf() Options

=defn PDF::API6 :$pdf
A PDF object to render to.

=end pod
