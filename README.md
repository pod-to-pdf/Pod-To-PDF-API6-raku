TITLE
=====

Pod::To::PDF::API6

SUBTITLE
========

Render Pod as PDF (Experimental)

Description
-----------

Renders Pod to PDF documents via PDF::API6.

Usage
-----

From command line:

    $ raku --doc=PDF::API6 lib/to/class.rakumod --save-as=class.pdf

From Raku:

```raku
use Pod::To::PDF::API6;
use PDF::API6;

=NAME foobar.pl
=Name foobar.pl

=Synopsis
    foobar.pl <options> files ...

my PDF::API6 $pdf = pod2pdf($=pod);
$pdf.save-as: "foobar.pdf";
```

Async Mode
---------

Even more experimental is Async mode, for faster parallel processing of larger documents:

    $ raku --doc=PDF::API6::Async lib/to/class.rakumod --save-as=class.pdf

To see a useful speed-up, he document needs to contain multiple sections, each starting with level-1 headers,
on a new page. 

Exports
-------

    class Pod::To::PDF::API6;
    sub pod2pdf; # See below

From command line:

```shell
$ raku --doc=PDF::API6 lib/class.rakumod --save-as=class.pdf
```

Subroutines
-----------

### sub pod2pdf()

```raku sub pod2pdf( Pod::Block $pod ) returns PDF::API6; ```

Renders the specified Pod to a PDF::API6 object, which can then be further manipulated or saved.

**`PDF::API6 :$pdf`**

An existing PDF::API6 object to add pages to.

**`UInt:D :$width, UInt:D :$height`**

The page size in points (there are 72 points per inch).

**`UInt:D :$margin`**

The page margin in points (default 20).

**`Hash :@fonts**

By default, Pod::To::PDF::API6 uses core fonts. This option can be used to preload selected fonts.

Note: [PDF::Font::Loader::HarfBuzz](https://pdf-raku.github.io/PDF-Font-Loader-HarfBuzz-raku/) must be installed, to use this option.

```raku
use PDF::API6;
use Pod::To::PDF::API6;
need PDF::Font::Loader::HarfBuzz; # needed to enable this option

my @fonts = (
    %(:file<fonts/Raku.ttf>),
    %(:file<fonts/Raku-Bold.ttf>, :bold),
    %(:file<fonts/Raku-Italic.ttf>, :italic),
    %(:file<fonts/Raku-BoldItalic.ttf>, :bold, :italic),
    %(:file<fonts/Raku-Mono.ttf>, :mono),
);

PDF::API6 $pdf = pod2pdf($=pod, :@fonts);
$pdf.save-as: "pod.pdf";
```

See Also
--------

  * [Pod::To::PDF](https://github.com/pod-to-pdf/Pod-To-PDF-raku) - PDF rendering via [Cairo](https://github.com/timo/cairo-p6)

  * [Pod::To::PDF::Lite](https://github.com/pod-to-pdf/Pod-To-PDF-Lite-raku) - PDF draft rendering via [PDF::Lite](https://github.com/pod-to-pdf/PDF-Lite-raku)

### Status

`Pod::To::PDF::API6` is on a near equal footing to [Pod::To::PDF](https://github.com/pod-to-pdf/Pod-To-PDF-raku), with regard to general rendering, handling of internal and external links, table-of-contents, footnotes and indexing.

It out-performs it content tagging, with better handling foot-notes and artifacts.

However

  * Both `Pod::To::PDF` and `Pod::To::PDF::Lite` modules currently render faster than this module (by about 2x).

  * `Pod::To::PDF` uses HarfBuzz for modern font shaping and placement. This module can only do basic horizontal kerning.

  * This module doesn't yet incorporate the experimental `HarfBuzz::Subset` module, resulting in large PDF sizes due to full font embedding.

  * [PDF::Lite](https://github.com/pod-to-pdf/PDF-Lite-raku), also includes the somewhat experimental `PDF::Lite::Async`, which has the ability to render large multi-page documents in parallel.

For these reasons [Pod::To::PDF](https://github.com/pod-to-pdf/Pod-To-PDF-raku) is the currently recommended module for Pod to PDF rendering.

