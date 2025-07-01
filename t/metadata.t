use v6;

use Test;
use Pod::To::PDF::API6 :&pod-render;
use PDF::API6;

plan 2;

my PDF::API6 $pdf .= new;
my %replace = :where<POD>;
my $renderer = pod-render($=pod, :%replace, :$pdf);
$pdf.id = $*PROGRAM.basename.fmt('%-16.16s');
lives-ok {$pdf.save-as: "t/metadata.pdf", :!info}

subtest 'Metadata verification', {
    plan 2;
    $pdf .= open: "t/metadata.pdf";
    my $info = $pdf.Info;
    is $info.Title, 'Main Title v1.2.3', 'PDF Title (POD title + version)';
    is $info.Subject, 'Subtitle from POD', 'PDF Subject (POD subtitle)';
}

=begin pod
=TITLE Main Title
=SUBTITLE Subtitle from R<where>
=VERSION 1.2.3

=head2 Head2 from R<where>

a paragraph.
=end pod

