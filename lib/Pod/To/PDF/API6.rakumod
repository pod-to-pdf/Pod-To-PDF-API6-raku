unit class Pod::To::PDF::API6:ver<0.0.1>;

use Pod::To::PDF::API6::Metadata :Level, :Roles;
also does Pod::To::PDF::API6::Metadata;

my constant %role-map = Roles.enums.Hash;

use PDF::API6;
use PDF::Tags;
use PDF::Tags::Elem;
use PDF::Tags::Node;
use PDF::Content;
use Pod::To::PDF::API6::Style;
use Pod::To::PDF::API6::Writer;
use CSS::TagSet::TaggedPDF;
use CSS::Stylesheet;
use File::Temp;
# PDF::Class
use PDF::Action;
use PDF::StructElem;

### Attributes ###
has PDF::API6 $.pdf .= new;
has CSS::TagSet::TaggedPDF $.styler .= new;
has PDF::Tags $.tags .= create: :$!pdf, :$!styler, :%role-map;
has PDF::Tags::Elem $.root = $!tags.Document;
has PDF::Content::FontObj %.font-map;
has Numeric $.width  = 612;
has Numeric $.height = 792;
has Bool $.contents = True;
has %.index;
has %.replace;
has Bool $.tag = True;
has Bool $.page-numbers;

method !paginate(
    $pdf,
    UInt:D :$margin = 20,
    Numeric :$margin-right is copy,
    Numeric :$margin-bottom is copy,
                ) {
    my $page-count = $pdf.Pages.page-count;
    my $font = $pdf.core-font: "Helvetica";
    my $font-size := 9;
    my $align := 'right';
    my $page-num;
    $margin-right //= $margin;
    $margin-bottom //= $margin;
    for $pdf.Pages.iterate-pages -> $page {
        my PDF::Content $gfx = $page.gfx;
        my @position = $gfx.width - $margin-right, $margin-bottom - $font-size;
        my $text = "Page {++$page-num} of $page-count";
        $gfx.tag: 'Artifact', {
            .print: $text, :@position, :$font, :$font-size, :$align;
        }
        $page.finish;
    }
}

method read-batch($section, PDF::Content::PageTree:D $pages, $frag, |c) is hidden-from-backtrace {
    $pages.media-box = 0, 0, $!width, $!height;
    my $finish = ! $!page-numbers;
    my @index;
    my Pod::To::PDF::API6::Writer $writer .= new: :%!font-map, :$pages, :$finish, :$!tag, :$!pdf, :%!replace, :$!contents, |c;
    $writer.write($section, $frag);
    my Hash:D $meta = $writer.metadata;
    my Hash:D $index = $writer.index;
    my @toc = $writer.toc;

    %( :@toc, :$index, :$frag, :$meta);
}

method merge-batch( % ( :@toc!, :%index!, :$frag!, :%meta! ) ) {
    @.toc.append: @toc;
    %.index ,= %index;
    for $frag.kids -> $node {
        $.root.add-kid: :$node;
    }
    if %meta {
        my $info = ($!pdf.Info //= {});
        for %meta.pairs.map({self.set-metadata(.key, .value)}) {
            $info{.key} = .value;
        }
    }
}

method read($section, |c) {
    my %batch = $.read-batch: $section, $!pdf.Pages, $!root.fragment, |c;
    $.merge-batch: %batch;
    self!paginate($!pdf, |c)
        if $!page-numbers;
    .Lang = self.lang with $!root;
}

method pdf {
    if @.toc {
        $!pdf.outlines.kids = @.toc;
    }
    $!pdf;
}

method !preload-fonts(@fonts) {
    my $loader = (require ::('PDF::Font::Loader'));
    for @fonts -> % ( Str :$file!, Bool :$bold, Bool :$italic, Bool :$mono ) {
        # font preload
        my Pod::To::PDF::API6::Style $style .= new: :$bold, :$italic, :$mono;
        if $file.IO.e {
            %!font-map{$style.font-key} = $loader.load-font: :$file;
        }
        else {
            warn "no such font file: $file";
        }
    }
}

method !init-pdf(Str :$lang) {
    $!pdf.media-box = 0, 0, $!width, $!height;
    self.lang = $_ with $lang;
}

sub apply-page-styling(CSS::Properties:D $css, %props) {
    %props{.key} = .value for $css.Hash;
}

submethod TWEAK(Str:D :$lang = 'en', :$pod, :%metadata, :@fonts, :$stylesheet, :$page-style, *%opts) {
    self!init-pdf(:$lang);
    self!preload-fonts(@fonts)
        if @fonts;

    $!pdf.creator.push: "{self.^name}-{self.^ver//'v0'}";
    if %metadata {
        my $info = ($!pdf.Info //= {});
        for %metadata.pairs.map({self.set-metadata(.key, .value)}) {
            $info{.key} = .value;
        }
    }

    with $stylesheet {
        # dig out any @page{...} styling from the stylesheet
        with $!styler.load-stylesheet($_) -> CSS::Stylesheet $_ {
            apply-page-styling($_, %opts)
                with .page-properties;
        }
    }

    with $page-style -> $style {
        # apply any command-line page styling at a higher precedence
        my CSS::Properties $css .= new: :$style;
        apply-page-styling($css, %opts);
    }

    $!width  = $_ with %opts<width>;
    $!height = $_ with %opts<height>;
    self.read($_, |%opts) with $pod;
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
         $save-as //= tempfile("pod2pdf-api6-****.pdf", :!unlink)[1];
        # render method may be called more than once: Rakudo #2588
        my $renderer = $class.new: |c, :$width, :$height, :$pod, :$margin, :$margin-top, :$margin-bottom, :$margin-left, :$margin-right, :$contents, :$page-numbers, :$page-style, :$stylesheet;
        $renderer.build-index
            if $index && $renderer.index;
        my PDF::API6 $pdf = $renderer.pdf;
        $pdf.media-box = 0, 0, $width, $height;
        # save to a file, since PDF is a binary format
        $pdf.save-as: $save-as;
        $save-as.path;
    }
}

our sub pod2pdf($pod, :$class = $?CLASS, Bool :$index = True, |c) is export {
    my $renderer = $class.new(|c, :$pod);
    $renderer.build-index
        if $index && $renderer.index;
    $renderer.pdf;
}

method build-index {
    self.add-toc-entry(%( :Title('Index')), :level(1));
    my %idx := %!index;
    %idx .= &categorize-alphabetically
        if %idx > 64;
    self.add-terms(%idx);
}

sub categorize-alphabetically(%index) {
    my %alpha-index;
    for %index.sort(*.key.uc) {
        %alpha-index{.key.substr(0,1).uc}{.key} = .value;
    }
    %alpha-index;
}


method lang is rw { $!pdf.catalog.Lang; }

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
