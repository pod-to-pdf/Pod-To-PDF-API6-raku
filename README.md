TITLE
=====

Pod::To::PDF::API6

SUBTITLE
========

Render Pod as PDF (Experimental)

Description
-----------

Renders Pod to PDF draft documents via PDF::API6.

Usage
-----

From command line:

    $ raku --doc=PDF::API6 lib/to/class.rakumod | xargs evince

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

Exports
-------

    class Pod::To::PDF::API6;
    sub pod2pdf; # See below

From command line:

```shell
$ raku --doc=PDF::API6 lib/class.rakumod | xargs evince
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

Note: [PDF::Font::Loader](PDF::Font::Loader) must be installed, to use this option.

```raku
use PDF::API6;
use Pod::To::PDF::API6;
need PDF::Font::Loader; # needed to enable this option

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

Both of the above modules currently render faster than this module (by about 2x).

[Pod::To::PDF](https://github.com/pod-to-pdf/Pod-To-PDF-raku) is the most capable. Like this module, it is able to handle internal and external links, table-of-contents, footnotes and indexing.

