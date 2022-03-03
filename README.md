TITLE
=====

Pod::To::PDF::API6 - Render Pod as PDF (Experimental)

Pod::To::PDF::API6 - Render Pod as PDF (Experimental)
=====================================================

Synopsis
========

From command line:

$ raku --doc=PDF lib/to/class.rakumod | raku -e'"class.pdf".IO.spurt: $*IN.slurp.encode("latin-1")' > to-class.pdf

From Raku:

```raku
use Pod::To::PDF::API6;

=NAME foobar.pl
=Name foobar.pl

=Synopsis
    foobar.pl <options> files ...

pod2pdf($=pod).save-as: "foobar.pdf";
```

Exports
=======

class Pod::To::PDF::API6; sub pod2pdf; # See below

Description
===========

This is an experimental module for rendering POD to PDF.

From command line:

```shell
$  raku --doc=PDF lib/class.rakumod | xargs xpdf
```

From Raku code, the `pod2pdf` function returns a PDF::API6 object which can be further manipulated, or saved to a PDF file.

```raku
use Pod::To::PDF::API6;
use PDF::API6;

=NAME foobar.raku
=Name foobar.raku

=Synopsis
    foobarraku <options> files ...

my PDF::API6 $pdf = pod2pdf($=pod);
$pdf.save-as: "class.pdf"
```

Limitations
===========

**core fonts only.**



PDF::Font::Loader is also experimental and hasn't been integrated yet.

**performance**



This module is several times slower than Pod::To::PDF::Lite; mostly due to the handling and serialization of a large number of small StructElem tags for PDF tagging.

Possibly, PDF (and PDF::Class) need to implement faster serialization methods, which will most likely use PDF 1.5 Object Streams.

