# Pod::To::PDF (Perl6)

[![Build Status](https://travis-ci.org/p6-pdf/perl6-Pod-To-PDF.svg?branch=master)](https://travis-ci.org/p6-pdf/perl6-Pod-To-PDF)

Render Pod as PDF.

## Installation

Using panda:
```
$ panda update
$ panda install Pod::To::PDF
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
