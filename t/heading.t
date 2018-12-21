use v6;
use lib 'lib';

use Test;
use Pod::To::PDF;

plan 1;

my $markdown = q{Abbreviated heading
===================

asdf

Paragraph heading
=================

asdf

Delimited heading
=================

asdf

Head2
-----

asdf

### Head3

asdf

#### Head4

asdf};

my $pdf;
##lives-ok {
$pdf = pod2pdf($=pod);##}
$pdf.save-as: "/tmp/out.pdf";

is pod2pdf($=pod).page(1).gfx.content-dump, $markdown.trim,
   'Various types of headings convert correctly';

		    

=begin pod
=head1 Abbreviated heading

asdf

=for head1
Paragraph heading

asdf

=begin head1
Delimited
	
heading
=end head1

	

asdf

=head2 Head2

asdf

=head3 Head3

asdf

=head4 Head4

asdf

=end pod
