use v6;

use Test;
use Pod::To::PDF;
use PDF::API6;

plan 1;

my $markdown = q{module Asdf1
------------

asdf1

### sub asdf

```
sub asdf(
    Str $asdf1, 
    Str :$asdf2 = "asdf"
) returns Str
```

Sub asdf1

class Asdf2
-----------

Asdf2

### has Str $.t

t

### method asdf

```
method asdf(
    Str :$asdf = "asdf"
) returns Str
```

Method asdf2};

my $xml = q{<Blah>
         </Blah>};

my PDF::API6 $pdf = pod2pdf($=pod);
$pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');
$pdf.save-as: "t/definition.pdf", :!info;
my PDF::Tags $tags .= read: :$pdf;

is $tags[0].Str, $xml,
    'Converts definitions correctly';

#| This is a module
module Asdf1 {
    #| This is a sub
    sub asdf(Str $asdf1, Str :$asdf2? = 'asdf') returns Str {
	return '';
    }
}

#| This is a class
class Asdf2 does Positional  {
    #| This is an attribute
    has Str $.t = 'asdf';
    
    #| This is a method
    method asdf(Str :$asdf? = 'asdf') returns Str {
	
    }
}


