use v6;

use Test;
use Pod::To::PDF::API6;
use PDF::API6;

plan 5;

my PDF::API6 $pdf .= new;
my %replace = :where<POD>;
my Pod::To::PDF::API6 $pod .= new(:$=pod, :$pdf, :metadata{ :title("Title as option") }, :%replace);

is $pod.metadata('title'), 'Title as option';
is $pod.metadata('subtitle'), 'Subtitle from POD';
is $pod.metadata('version'), '1.2.3';

$pdf.id = $*PROGRAM.basename.fmt('%-16.16s');
lives-ok {$pdf.save-as: "t/metadata.pdf", :!info}

subtest 'Metadata verification', {
    plan 2;
    $pdf .= open: "t/metadata.pdf";
    my $info = $pdf.Info;
    is $info.Title, 'Title as option v1.2.3', 'PDF Title (POD title + version)';
    is $info.Subject, 'Subtitle from POD', 'PDF Subject (POD subtitle)';
}

=begin pod
=SUBTITLE Subtitle from R<where>
=VERSION 1.2.3

=head2 Head2 from R<where>

a paragraph.
=end pod

