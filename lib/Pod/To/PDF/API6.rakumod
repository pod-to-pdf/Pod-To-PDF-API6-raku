unit class Pod::To::PDF::API6:ver<0.0.1>;

use PDF::Tags::Renderer;
also is PDF::Tags::Renderer;

use PDF::Tags::Renderer::Writer;
use Pod::To::PDF::AST;
use File::Temp;

has %.replace;

method read-batch($section, PDF::Content::PageTree:D $pages, $frag, |c) is hidden-from-backtrace {
    my @index;
    my Pod::To::PDF::AST $pod-reader .= new: :%!replace;
    my PDF::Tags::Renderer::Writer $writer = self.writer: :$pages, :$frag;
    my Pair:D $doc-ast = $pod-reader.render($section);
    my Pair:D @content = $writer.process-root(|$doc-ast);
    $writer.write-batch(@content, $frag);
    my Hash:D $info  = $pod-reader.info;
    my Hash:D $index = $writer.index;
    my @toc = $writer.toc;

    %( :@toc, :$index, :$frag, :$info);
}

method read($section, |c) {
    my %batch = $.read-batch: $section, $.pdf.Pages, $.root.fragment, |c;
    $.merge-batch: %batch;
}

submethod TWEAK(:$pod, |c) {
    self.read($_, |c) with $pod;
}

method render(
    $class: $pod,
    IO() :$save-as  is copy,
    Numeric:D :$width  is copy = 612,
    Numeric:D :$height is copy = 792,
    Numeric:D :$margin is copy = 20,
    Numeric   :$margin-left   is copy,
    Numeric   :$margin-right  is copy,
    Numeric   :$margin-top    is copy,
    Numeric   :$margin-bottom is copy,
    Bool :$index    is copy = True,
    Bool :$contents is copy = True,
    Bool :$page-numbers is copy,
    Str  :$page-style   is copy,
    IO() :$stylesheet   is copy,
    |c,
) {
    state %cache{Any};
    %cache{$pod} //= do {
        my Bool $show-usage;
        for @*ARGS {
            when /^'--page-numbers'$/  { $page-numbers = True }
            when /^'--/index'$/        { $index  = False }
            when /^'--/'[toc|['table-of-']?contents]$/ { $contents  = False }
            when /^'--width='(\d+)$/   { $width  = $0.Int }
            when /^'--height='(\d+)$/  { $height = $0.Int }
            when /^'--margin='(\d+)$/  { $margin = $0.Int }
            when /^'--margin-top='(\d+)$/     { $margin-top = $0.Int }
            when /^'--margin-bottom='(\d+)$/  { $margin-bottom = $0.Int }
            when /^'--margin-left='(\d+)$/    { $margin-left = $0.Int }
            when /^'--margin-right='(\d+)$/   { $margin-right = $0.Int }
            when /^'--page-style='(.+)$/      { $page-style = $0.Str }
            when /^'--stylesheet='(.+)$/  { $stylesheet = $0.Str }
            when /^'--save-as='(.+)$/  { $save-as = $0.Str }
            default {  $show-usage = True; note "ignoring $_ argument" }
        }
        note '(valid options are: --save-as= --page-numbers --width= --height= --margin[-left|-right|-top|-bottom]= --stylesheet= --page-style=)'
            if $show-usage;

        my $renderer = $class.new: |c,  :$pod, :$width, :$height, :$margin, :$margin-top, :$margin-bottom, :$margin-left, :$margin-right, :$contents, :$page-numbers, :$page-style, :$stylesheet;
        $renderer.build-index
            if $index && $renderer.index;
        my PDF::API6:D $pdf = $renderer.pdf;
        $pdf.media-box = 0, 0, $width, $height;
        # save to a file, since PDF is a binary format
        $save-as //= tempfile("pod2pdf-api6-****.pdf")[1];
        $pdf.save-as: $save-as, :!unlink;
        $save-as.path;
    }
}

our sub pod2pdf($pod, :$class = $?CLASS, Bool :$index = True, |c) is export {
    my $renderer = $class.new(|c, :$pod);
    $renderer.build-index
        if $index && $renderer.index;
    $renderer.pdf;
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
