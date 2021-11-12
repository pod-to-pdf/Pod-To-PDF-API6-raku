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

=NAME
foobar.raku

=SYNOPSIS
    foobarraku <options> files ...
	
"class.pdf".IO.spurt( pod2pdf($=pod), :enc<latin-1> );
```
