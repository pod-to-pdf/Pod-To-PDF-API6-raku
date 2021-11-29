# Pod::To::PDF (Raku)

Render Pod as PDF.

## Installation

Using zef:
```
$ zef install Pod::To::PDF
```

## Usage:

From command line:

    $ raku --doc=PDF lib/class.rakumod > class.pdf

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
