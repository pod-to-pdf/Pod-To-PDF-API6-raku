unit class Pod::To::PDF::API6:ver<0.0.1>;

use Pod::To::PdfAST;
use PdfAST::Render::API6;
use PdfAST::Render::API6::Writer;
use File::Temp;
use PDF::Content::PageTree;
use PDF::API6;

sub read-batch($renderer, $section, PDF::Content::PageTree:D $pages, $frag, :%replace, |c) is hidden-from-backtrace {
    my Pod::To::PdfAST $pod-reader .= new: :%replace;
    my PdfAST::Render::API6::Writer $writer = $renderer.writer: :$pages, :$frag;
    my Pair:D $doc-ast = $pod-reader.render($section);
    my Pair:D @content = $writer.process-root(|$doc-ast);
    $writer.write-batch(@content, $frag);
    my Hash:D $info  = $pod-reader.info;
    my Hash:D $index = $writer.index;
    my @toc = $writer.toc;

    %( :@toc, :$index, :$frag, :$info);
}

sub get-opts(%opts) {
    my Bool $show-usage;
    for @*ARGS {
        when /^'--'('/')?(page\-numbers|async|index)$/         { %opts{$1} = ! $0.so }
        when /^'--'('/')?[toc|['table-of-']?contents]$/        { %opts<contents>  = ! $0.so }
        when /^'--'(page\-style|stylesheet|save\-as)'='(.+)$/  { %opts{$0} = $1.Str }
        when /^'--'(width|height|margin[\-[top|bottom|left|right]]?)'='(\d+)$/
                                                               { %opts{$0}  = $1.Int }
        default {  $show-usage = True; note "ignoring $_ argument" }
    }
    note '(valid options are: --save-as= --page-numbers --width= --height= --margin[-left|-right|-top|-bottom]= --stylesheet= --page-style=)'
        if $show-usage;
    %opts;
}

# asynchronous pod processing
multi sub process-pod($renderer, @pod, :$async! where .so, |c) {
    need Pod::To::PDF::API6::Async::Scheduler;
    my List @batches = Pod::To::PDF::API6::Async::Scheduler.divvy(@pod).map: -> $pod {
        ($pod, PDF::Content::PageTree.pages-fragment, $renderer.root.fragment);
    }

    nextsame if @batches == 1;

    {
        my PDF::API6 $pdf = $renderer.pdf;
        my @results;
        my Lock $lock .= new;
        @batches.pairs.race(:batch(1)).map: {
            my $result = $renderer.&read-batch: |.value, |c;
            $lock.protect: { @results[.key] = $result };
        }
        $pdf.add-pages(.[1]) for @batches;
        $renderer.merge-batch($_) for @results;
    }
}

# synchronous pod processing
multi sub process-pod($renderer, @pod, :%replace, |c) {
    my %batch = $renderer.&read-batch(@pod, $renderer.pdf.Pages, $renderer.root.fragment, :%replace);
    $renderer.merge-batch: %batch;
}

our sub pod-render(
    @pod,
    :$class = PdfAST::Render::API6,
    IO() :$save-as,
    Numeric:D :$width  = 612,
    Numeric:D :$height = 792,
    Numeric:D :$margin = 20,
    Numeric   :$margin-left,
    Numeric   :$margin-right,
    Numeric   :$margin-top,
    Numeric   :$margin-bottom,
    Bool :$index    = True,
    Bool :$contents = True,
    Bool :$page-numbers,
    Bool :$async,
    Str  :$page-style,
    IO() :$stylesheet,
    :%replace,
    |c,
) is export(:pod-render) {
    my $renderer = $class.new: |c,  :$width, :$height, :$margin, :$margin-top, :$margin-bottom, :$margin-left, :$margin-right, :$contents, :$page-numbers, :$page-style, :$stylesheet;

    $renderer.pdf.media-box = 0, 0, $width, $height;
    $renderer.&process-pod(@pod, :$async, :%replace, |c);
    $renderer.build-index
    if $index && $renderer.index;
    $renderer.pdf.save-as: $_, :!unlink with $save-as;
    $renderer;
}

sub pod2pdf(|c --> PDF::API6:D) is export {
    my $renderer = pod-render(|c);
    $renderer.pdf;
}

method render(|c) {
    my %opts .= &get-opts;
    %opts<save-as> //= tempfile("pod2pdf-api6-****.pdf")[1];
    state $rendered //= pod-render(|%opts, |c);
    %opts<save-as>;
}

=begin pod

=TITLE Pod::To::PDF::API6
=SUBTITLE Render Pod as PDF (Experimental)

=head2 Description

Renders Pod to PDF documents via PDF::API6.

=head2 Usage

From command line:

    $ raku --doc=PDF::API6 lib/to/class.rakumod --save-as=class.pdf

From Raku:
    =begin code :lang<raku>
    use Pod::To::PDF::API6;
    use PDF::API6;

    =NAME foobar.pl
    =Name foobar.pl

    =Synopsis
        foobar.pl <options> files ...

    my PDF::API6 $pdf = pod2pdf($=pod);
    $pdf.save-as: "foobar.pdf";
    =end code

=head2 Exports

    class Pod::To::PDF::API6;
    sub pod2pdf; # See below

From command line:
    =begin code :lang<shell>
    $ raku --doc=PDF::API6 lib/class.rakumod --save-as=class.pdf
    =end code

=head2 Subroutines

### sub pod2pdf()

```raku
sub pod2pdf(
    Pod::Block $pod
) returns PDF::API6;
```

Renders the specified Pod to a PDF::API6 object, which can then be
further manipulated or saved.

=defn `PDF::API6 :$pdf`
An existing PDF::API6 object to add pages to.

=defn `UInt:D :$width, UInt:D :$height`
The page size in points (there are 72 points per inch).

=defn `UInt:D :$margin`
The page margin in points (default 20).

=defn `Hash :@fonts
By default, Pod::To::PDF::API6 uses core fonts. This option can be used to preload selected fonts.

Note: L<PDF::Font::Loader> must be installed, to use this option.

=begin code :lang<raku>
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
=end code

=head2 See Also

=item L<Pod::To::PDF|https://github.com/pod-to-pdf/Pod-To-PDF-raku> - PDF rendering via L<Cairo|https://github.com/timo/cairo-p6>
=item L<Pod::To::PDF::Lite|https://github.com/pod-to-pdf/Pod-To-PDF-Lite-raku> - PDF draft rendering via L<PDF::Lite|https://github.com/pod-to-pdf/PDF-Lite-raku>

=head3 Status

C<Pod::To::PDF::API6> is on a near equal footing to L<Pod::To::PDF|https://github.com/pod-to-pdf/Pod-To-PDF-raku>, with regard to general rendering, handling of internal and external links, table-of-contents, footnotes and indexing.

It out-performs it content tagging, with better handling  foot-notes and artifacts.

However

=item Both C<Pod::To::PDF> and C<Pod::To::PDF::Lite> modules currently render faster than this module (by about 2x).

=item `Pod::To::PDF` uses HarfBuzz for modern font shaping and placement. This module can only do basic horizontal kerning.

=item This module doesn't yet incorporate the experimental C<HarfBuzz::Subset> module, resulting in large PDF sizes due to full font embedding.

=item L<PDF::Lite|https://github.com/pod-to-pdf/PDF-Lite-raku>, also includes the somewhat experimental C<PDF::Lite::Async>, which has the ability to render large multi-page documents in parallel.

For these reasons L<Pod::To::PDF|https://github.com/pod-to-pdf/Pod-To-PDF-raku> is the currently recommended module for Pod to PDF rendering.

=end pod
