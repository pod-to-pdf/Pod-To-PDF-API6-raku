# Pod::To::PDF (Raku)

Render Pod as PDF. (Experimental)

## Installation

Using zef:
```
$ zef install Pod::To::PDF
```

## Usage:

From command line (currently a bit awkward):

    $ raku --doc=PDF lib/class.rakumod | raku -e'"class.pdf".IO.spurt: $*IN.slurp.encode("latin-1")'

From Raku:

```
use Pod::To::PDF;
use PDF::API6;

=NAME
foobar.raku

=SYNOPSIS
    foobarraku <options> files ...

my PDF::API6 $pdf = pod2pdf($=pod);
$pdf.save-as: "class.pdf";
```
