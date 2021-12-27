# Pod::To::PDF::API6 (Raku)

Render Pod as PDF via PDF::API6. (Experimental)

## Installation

Using zef:
```
$ zef install Pod::To::PDF::API6
```

## Usage:

From command line:

    $ raku --doc=PDF::API lib/class.rakumod | xargs xpdf

From Raku:

```
use Pod::To::PDF::API6;
use PDF::API6;

=NAME
foobar.raku

=SYNOPSIS
    foobarraku <options> files ...

my PDF::API6 $pdf = pod2pdf($=pod);
$pdf.save-as: "class.pdf";
```
