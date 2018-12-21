use v6;
use lib <blib/lib lib>;

use Test;
use Pod::To::PDF;

plan 1;

my $markdown = q{asdf

    indented

asdf

    indented
    multi
    line

asdf

    indented
    multi
    line

    and
    broken
    up

asdf

    Abbriviated

asdf

    Paragraph
    code

asdf

    Delimited
    code

asdf};

is pod2pdf($=pod).trim, $markdown.trim,
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
