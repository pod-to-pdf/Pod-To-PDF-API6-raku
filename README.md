# Pod::To::PDF (Perl6)

[![Build Status](https://travis-ci.org/p6-pdf/Pod-To-PDF-p6.svg?branch=master)](https://travis-ci.org/p6-pdf/Pod-To-PDF-p6)

Render Pod as PDF.

## Installation

Using zef:
```
$ zef install Pod::To::PDF
```

## Usage:

From command line:

    $ perl6 --doc=PDF lib/class.pm > class.pdf

From Perl6:

```
use Pod::To::PDF;

=NAME
foobar.pl

=SYNOPSIS
    foobar.pl <options> files ...
	
"class.pdf".IO.spurt( pod2pdf($=pod), :enc<latin-1> );
```
