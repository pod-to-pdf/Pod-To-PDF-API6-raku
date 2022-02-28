unit class Pod::To::PDF::API6:ver<0.0.1>;

use PDF::API6;
use PDF::Tags;
use PDF::Tags::Elem;
use PDF::Content;
use PDF::Content::Color :&color;
use PDF::Content::Tag :Tags;
use PDF::Content::Text::Box;
use Pod::To::PDF::API6::Style;
use Pod::To::Text;
use File::Temp;
# PDF::Class
use PDF::Action;
use PDF::Annot::Link;
use PDF::Destination :Fit, :DestRef;
use PDF::Page;
use PDF::StructElem;

subset Level of Int:D where 1..6;
my constant Gutter = 3;

has PDF::API6 $.pdf .= new;
has PDF::Tags $.tags .= create: :$!pdf;
has PDF::Tags::Elem $.root = $!tags.Document;
has PDF::Page $!page;
has PDF::Content $!gfx;
has UInt $!indent = 0;
has Pod::To::PDF::API6::Style $.style handles<font font-size leading line-height bold italic mono underline lines-before link> .= new;
has $.margin = 20;
has $!gutter = Gutter;
has $!tx = $!margin; # text-flow x
has $!ty = self!top; # text-flow y
has UInt $!pad = 0;
has Bool $.contents = True;
has @.toc; # table of contents
has @!footnotes;
has DestRef $!gutter-link;    # forward link to footnote area
has DestRef @!footnotes-back; # per-footnote return links
has Str %!metadata;

method read($pod, :$*tag is copy = self.root) {
    self.pod2pdf($pod);
    self!finish-page;
}

method pdf {
    if @!toc {
        $!pdf.outlines.kids = @!toc;
    }
    $!pdf;
}

submethod TWEAK(Str :$lang = 'en', :$pod, :%metadata) {
    self.lang = $_ with $lang;
    $!pdf.creator.push: "{self.^name}-{self.^ver}";
    self.metadata(.key.lc) = .value for %metadata.pairs;
    self.read($_) with $pod;
}

method render($class: $pod, |c) {
    state %cache{Any};
    %cache{$pod} //= do {
        # render method may be called more than once: Rakudo #2588
        my $renderer = $class.new(|c, :$pod);
        my PDF::API6 $pdf = $renderer.pdf;
        # save to a temporary file, since PDF is a binary format
        my (Str $file-name, IO::Handle $fh) = tempfile("pod2pdf-api6-****.pdf", :!unlink);
        $pdf.save-as: $fh;
        $file-name;
    }
}

our sub pod2pdf($pod, :$class = $?CLASS, |c) is export {
    $class.new(|c, :$pod).pdf;
}

my constant vpad = 2;
my constant hpad = 10;

# a simple algorithm for sizing table column widths
sub fit-widths($width is copy, @widths) {
    my $cell-width = $width / +@widths;
    my @idx;

    for @widths.pairs {
        if .value <= $cell-width {
            $width -= .value;
        }
        else {
            @idx.push: .key;
        }
    }

    if @idx {
        if @idx < @widths {
            my @over;
            my $i = 0;
            @over[$_] := @widths[ @idx[$_] ]
                for  ^+@idx;
            fit-widths($width, @over);
        }
        else {
            $_ = $cell-width
                  for @widths;
        }
    }
}

sub dest-name(Str:D $_) {
    .trim
    .subst(/\s+/, '_', :g)
    .subst('#', '', :g);
}

method !table-row(@row, @widths, Bool :$header) {
    if +@row -> \cols {
        my @overflow;
        # simple fixed column widths, for now
        self!gfx;
        my $tab = self!indent;
        my $row-height = 0;
        my $height = $!ty - $!margin;
        my $name = $header ?? TableHeader !! TableData;
        my $head-space = $.line-height - $.font-size;

        for ^cols {
            my $width = @widths[$_];
            temp $*tag = $*tag[$_] // $*tag.add-kid: :$name;

            if @row[$_] -> $tb is rw {
                if $tb.width > $width || $tb.height > $height {
                    $tb .= clone: :$width, :$height;
                }
                self!mark: {
                    $!gfx.print: $tb, :position[$tab, $!ty];
                    if $header {
                        # draw underline
                        my $y = $!ty + $tb.underline-position - $head-space;
                        self!draw-line: $tab, $y, $tab + $width;
                    }
                }
                given $tb.content-height {
                    $row-height = $_ if $_ > $row-height;
                }
                if $tb.overflow -> $overflow {
                    my $text = $overflow.join;
                    @overflow[$_] = $tb.clone: :$text, :$width, :height(0);
                }
            }
            $tab += $width + hpad;
        }
        if @overflow {
            # continue table
            self!style: :lines-before(3), {
                self!table-row(@overflow, @widths, :$header);
            }
        }
        else {
            $!ty -= $row-height + vpad;
            $!ty -= $head-space if $header;
        }
    }
}

method !table-cell($pod) {
    my $text = pod2text($pod);
    self!text-box: $text, :width(0), :height(0), :indent(0);
}

method !build-table($pod, @table) {
    my $x0 = self!indent;
    my \total-width = self!gfx.canvas.width - $x0 - $!margin;
    @table = ();

    self!style: :bold, :lines-before(3), {
        my @row = $pod.headers.map: { self!table-cell($_) }
        @table.push: @row;
    }

    $pod.contents.map: {
        my @row = .map: { self!table-cell($_) }
        @table.push: @row;
    }

    my $cols = @table.max: *.Int;
    my @widths = (^$cols).map: -> $col { @table.map({.[$col].?width // 0}).max };
   fit-widths(total-width - hpad * (@widths-1), @widths);
   @widths;
}

multi method pod2pdf(Pod::Block::Table $pod) {
    my @widths = self!build-table: $pod, my @table;

    self!style: :lines-before(3), :pad, {
        temp $*tag .= Table;
        if $pod.caption -> $caption {
            temp $*tag .= Caption;
            temp $.italic = True;
            $.say: $caption;
        }
        self!pad-here;
        my PDF::Content::Text::Box @header = @table.shift.List;
        if @header {
            temp $*tag .= TableHead;
            $*tag .= TableRow;
            self!table-row: @header, @widths, :header;
        }

        if @table {
            temp $*tag .= TableBody;
            for @table {
                my @row = .List;
                if @row {
                    temp $*tag .= TableRow;
                    self!table-row: @row, @widths;
                }
            }
        }
    }
}

multi method pod2pdf(Pod::Block::Named $pod) {
    $.pad: {
        given $pod.name {
            when 'pod'  { $.pod2pdf($pod.contents)     }
            when 'para' {
                $.pod2pdf: $pod.contents;
            }
            when 'config' { }
            when 'nested' {
                self!style: :indent, {
                    $.pod2pdf: $pod.contents;
                }
            }
            default     {
                given $pod.name {
                    when 'TITLE'|'VERSION'|'SUBTITLE'|'NAME'|'AUTHOR'|'VERSION' {
                        self!heading( node2text($pod.contents), :level(1))
                            if $_ ~~ 'TITLE';
                        self.metadata(.lc) ||= pod2text-inline($pod.contents);
                    }
                    default {
                        warn "unrecognised POD named block: $_";
                        $.say($_);
                        $.pod2pdf($pod.contents);
                    }
                }
            }
        }
    }
}

multi method pod2pdf(Pod::Block::Code $pod) {
    $.pad: {
        self!code: $pod.contents.join;
    }
}

multi method pod2pdf(Pod::Heading $pod) {
    $.pad: {
        my Level $level = min($pod.level, 6);
        self!heading( node2text($pod.contents), :$level);
    }
}

multi method pod2pdf(Pod::Block::Para $pod) {
    $.pad: {
        self!style: :tag(Paragraph), {
            $.pod2pdf($pod.contents);
        }
    }
}

multi method pod2pdf(Pod::FormattingCode $pod) {
    given $pod.type {
        when 'B' {
            self!style: :bold, {
                $.pod2pdf($pod.contents);
            }
        }
        when 'C' {
            self!code: pod2text($pod), :inline;
        }
        when 'T' {
            self!style: :mono, {
                $.pod2pdf($pod.contents);
            }
        }
        when 'K' {
            self!style: :italic, :mono, {
                $.pod2pdf($pod.contents);
            }
        }
        when 'I' {
            self!style: :italic, {
                $.pod2pdf($pod.contents);
            }
        }
        when 'N' {
            $!gutter-link //= self!make-dest: :left(0), :top($!margin + (Gutter + 2) * $.line-height);
            my $ind = '[' ~ @!footnotes+1 ~ ']';
            my PDF::Action $link = $!pdf.action: :destination($!gutter-link);
            self!style: :tag(Label), :$link, {  $.pod2pdf($ind); }
            my @contents = $ind, $pod.contents.Slip;
            @!footnotes.push: @contents;
            @!footnotes-back.push: self!make-dest;
            do {
                # pre-compute footnote size
                temp $!style .= new;
                temp $!tx = $!margin;
                temp $!ty = $!page.height;
                my $draft-footnote = $ind ~ pod2text-inline($pod.contents);
                $!gutter += self!text-box($draft-footnote).lines;
            }
        }
        when 'U' {
            temp $.underline = True;
            $.pod2pdf($pod.contents);
        }
        when 'Z' {
            # invisable
        }
        when 'X' {
            warn "indexing (X) not yet handled";
            $.pod2pdf($pod.contents);
        }
        when 'L' {
            my $text = pod2text($pod.contents);
            given $pod.meta.head // $text -> $uri {
                temp $.link = $uri.starts-with('#')
                    ?? $!pdf.action: :destination(dest-name($uri))
                    !! $!pdf.action: :$uri;
                $.print: $text;
            }
        }
        default {
            warn "todo: POD formatting code: $_";
            $.pod2pdf($pod.contents);
        }
    }
}

multi method pod2pdf(Pod::Defn $pod) {
    $.pad;
    self!style: :bold, {
        $.pod2pdf($pod.term);
    }
    $.pod2pdf($pod.contents);
}

multi method pod2pdf(Pod::Item $pod) {
    $.pad: {
        self!style: :tag(ListItem), {
            {
                my constant BulletPoints = ("\c[BULLET]",
                                            "\c[WHITE BULLET]",
                                            '-');
                my Level $list-level = min($pod.level // 1, 3);
                my $bp = BulletPoints[$list-level - 1];
                temp $*tag .= Label;
                $.print: $bp;
            }

            # slightly iffy $!ty fixup
            $!ty += 2 * $.line-height;

            self!style: :tag(ListBody), :indent, {
                $.pod2pdf($pod.contents);
            }
        }
    }
}

multi method pod2pdf(Pod::Block::Declarator $pod) {
    my $w := $pod.WHEREFORE;
    my Level $level = 3;
    my ($type, $code, $name, $decl) = do given $w {
        when Method {
            my @params = .signature.params.skip(1);
            @params.pop if @params.tail.name eq '%_';
            (
                (.multi ?? 'multi ' !! '') ~ 'method',
                .name ~ signature2text(@params, .returns),
            )
        }
        when Sub {
            (
                (.multi ?? 'multi ' !! '') ~ 'sub',
                .name ~ signature2text(.signature.params, .returns)
            )
        }
        when Attribute {
            my $gist = .gist;
            my $name = .name.subst('$!', '');
            $gist .= subst('!', '.')
                if .has_accessor;

            ('attribute', $gist, $name, 'has');
        }
        when .HOW ~~ Metamodel::EnumHOW {
            ('enum', .raku() ~ signature2text($_.enums.pairs));
        }
        when .HOW ~~ Metamodel::ClassHOW {
            $level = 2;
            ('class', .raku, .^name);
        }
        when .HOW ~~ Metamodel::ModuleHOW {
            $level = 2;
            ('module', .raku, .^name);
        }
        when .HOW ~~ Metamodel::SubsetHOW {
            ('subset', .raku ~ ' of ' ~ .^refinee().raku);
        }
        when .HOW ~~ Metamodel::PackageHOW {
            ('package', .raku)
        }
        default {
            '', ''
        }
    }

    $name //= $w.?name // '';
    $decl //= $type;

    self!style: :tag(Section), :lines-before(3), :pad, {
        self!heading($type.tclc ~ ' ' ~ $name, :$level);

        if $code {
            $.pad(1);
            self!code($decl ~ ' ' ~ $code);
        }

        if $pod.contents {
            $.pad;
            self!style: :tag(Paragraph), {
                $.pod2pdf($pod.contents);
            }
        }
    }
}

multi method pod2pdf(Pod::Block::Comment) {
    # ignore comments
}

sub signature2text($params, Mu $returns?) {
    my constant NL = "\n    ";
    my $result = '(';

    if $params.elems {
        $result ~= NL ~ $params.map(&param2text).join(NL) ~ "\n";
    }
    $result ~= ')';
    unless $returns<> =:= Mu {
        $result ~= " returns " ~ $returns.raku
    }
    $result;
}
sub param2text($p) {
    $p.raku ~ ',' ~ ( $p.WHY ?? ' # ' ~ $p.WHY !! '')
}

multi method pod2pdf(Array $pod) {
    for $pod.list {
        $.pod2pdf($_);
    };
}

multi method pod2pdf(Str $pod) {
    $.print: $pod;
}

multi method pod2pdf($pod) {
    warn "fallback render of {$pod.WHAT.raku}";
    $.say: pod2text($pod);
}

multi method say {
    $!tx = $!margin;
    $!ty -= $.line-height;
}
multi method say(Str $text, |c) {
    @.print($text, :nl, |c);
}

multi method pad(&codez) { $.pad; &codez(); $.pad}
multi method pad($!pad = 2) { }

method !height-remaining {
    $!ty - $!margin - $!gutter * $.line-height;
}

method !text-box(
    Str $text,
    :$width = self!gfx.canvas.width - self!indent - $!margin,
    :$height = self!height-remaining,
    |c) {
    PDF::Content::Text::Box.new: :$text, :indent($!tx - $!margin), :$.leading, :$.font, :$.font-size, :$width, :$height, |c;
}

method !pad-here {
    $.say for ^$!pad;
    $!pad = 0;
}

method print(Str $text, Bool :$nl, :$reflow = True, |c) {
    self!pad-here;
    my PDF::Content::Text::Box $tb = self!text-box: $text, |c;
    my $w = $tb.content-width;
    my $h = $tb.content-height;
    my Pair $pos = self!text-position();
    my $gfx = self!gfx;
    temp $*tag;
    if $.link {
        use PDF::Content::Color :ColorName;
        $gfx.Save;
        $gfx.FillColor = color Blue;
        self!link: $tb;
        $*tag = $_ with $*tag.kids.tail;
    }

    self!mark: {
        $gfx.print: $tb, |$pos, :$nl, |c;
        self!underline: $tb
            if $.underline;
    }

    $gfx.Restore if $.link;

    # calculate text bounding box and advance x, y
    my $lines = +$tb.lines;
    my $x0 = $pos.value[0];
    if $nl {
        # advance to next line
        $!tx = $!margin;
    }
    else {
        $!tx = $!margin if $tb.lines > 1;
        $x0 += $!tx;
        # continue this line
            with $tb.lines.pop {
                $w = .content-width - .indent;
                $!tx += $w + $tb.space-width;
            }
    }
    $!ty -= $tb.content-height;
    my Str $overflow = $tb.overflow.join;
    if $overflow && $reflow {
        $.say() unless $nl;
        @.print: $overflow, :$nl, |c;
        $overflow = Nil;
    }
    ($x0, $!ty, $w, $h, $overflow);
}

method !text-position {
    :position[self!indent, $!ty]
}

method !mark(&action, |c) {
    given $!gfx {
        if .open-tags.first(*.mcid.defined) {
            # caller is already marking
            .tag: $*tag.name, &action, |$*tag.attributes;
        }
        else {
            $*tag.mark: $_, &action, |c;
        }
    }
}

method !style(&codez, Bool :$indent, Str :tag($name) is copy, Bool :$pad, |c) {
    temp $!style .= clone: |c;
    temp $!indent;
    temp $*tag;
    if $name.defined {
        $*tag .= add-kid: :$name;
    }
    $!indent += 1 if $indent;
    $pad ?? $.pad(&codez) !! &codez();
}

method !add-toc-entry(Hash $entry, Level $level, @kids = @!toc, Level :$cur = 1, ) {
    if $cur >= $level {
        @kids.push: $entry;
    }
    else {
        # descend
        @kids.push: {} unless @kids;
        @kids.tail<kids> //= [];
        self!add-toc-entry($entry, $level, :cur($cur+1), @kids.tail<kids>);
    }
}

method !heading(Str:D $Title, Level :$level = 2, :$underline = $level == 1) {
    self!style: :tag('H' ~ $level), :$underline, {
        my constant HeadingSizes = 20, 16, 13, 11.5, 10, 10;
        $.font-size = HeadingSizes[$level - 1];
        if $level == 1 {
            self!new-page;
        }
        elsif $level == 2 {
            $.lines-before = 3;
        }

        if $level < 5 {
            $.bold = True;
        }
        else {
            $.italic = True;
        }

        $*tag.cos.title = $Title;
        my (\x, \y, \w, \h) = @.print: $Title;
        $.say();

        if $!contents {
            # Register in table of contents
            my $name = self!gen-dest-name($Title);
            my DestRef $dest = self!make-dest: :$name, :fit(FitBoxHoriz), :top(y+h + $.line-height);
            my PDF::StructElem $SE = $*tag.cos;
            self!add-toc-entry: { :$Title, :$dest, :$SE  }, $level;
        }
    }
}

has UInt %!dest-collision;
method !gen-dest-name($title, $seq = '') {
    my $name = dest-name($title ~ $seq);
    if %!dest-collision{$name}++ {
        self!gen-dest-name($title, ($seq||0) + 1);
    }
    else {
        $name;
    }
}

method !make-dest(
    :$fit = FitXYZoom,
    :$page = $!page,
    :$left is copy = $!tx - hpad,
    :$top  is copy  = $!ty + $.line-height + vpad,
    |c,
) {
    ($left, $top) = $!gfx.base-coords: $left, $top;
    $!pdf.destination: :$page, :$fit, :$left, :$top, |c;
}

method !code(Str $code is copy, :$inline) {
    $code .= chomp;
    self!style: :mono, :indent(!$inline), :tag(CODE), {
        while $code {
            $.lines-before = min(+$code.lines, 3)
                unless $inline;
            $.font-size *= .8;
            my (\x, \y, \w, \h, \overflow) = @.print: $code, :verbatim, :!reflow;
            $code = overflow;

            unless $inline {
                # draw code-block background
                my constant pad = 5;
                my $x0 = self!indent;
                my $width = $!gfx.canvas.width - $!margin - $x0;
                $!gfx.graphics: {
                    .FillColor = color 0;
                    .StrokeColor = color 0;
                    .FillAlpha = 0.1;
                    .StrokeAlpha = 0.25;
                    .Rectangle: $x0 - pad, y - pad, $width + pad*2, h + pad*2;
                    .paint: :fill, :stroke;
                }
            }
        }
    }
}

method !draw-line($x0, $y0, $x1, $y1 = $y0, :$linewidth = 1) {
    given $!gfx {
        .Save;
        .SetLineWidth: $linewidth;
        .MoveTo: $x0, $y0;
        .LineTo: $x1, $y1;
        .Stroke;
        .Restore;
    }
}

method !underline(PDF::Content::Text::Box $tb, :$tab = self!indent, ) {
    my $y = $!ty + $tb.underline-position;
    my $linewidth = $tb.underline-thickness;
    for $tb.lines {
        my $x0 = $tab + .indent;
        my $x1 = $tab + .content-width;
        self!draw-line($x0, $y, $x1, :$linewidth);
        $y -= .height * $tb.leading;
    }
}

method !link(PDF::Content::Text::Box $tb, :$tab = $!margin, ) {
    my constant pad = 2;
    my $y = $!ty + $tb.underline-position;
    for $tb.lines {
        my $x0 = $tab + .indent;
        my $x1 = $tab + .content-width;
        my @rect = $!gfx.base-coords: $x0, $y, $x1, $y + $.line-height;
        @rect Z+= [-pad, -pad, pad, pad];
        my @Border = 0, 0, 0;
        my Str $content = $tb.text;

        my PDF::Annot::Link $link = $!pdf.annotation(
            :$!page,
            :action($.link),
            :@rect,
            :@Border,
            :$content,
        );

        $y -= .height * $tb.leading;
        $*tag.Link($!gfx, $link);
    }
}

method !gfx {
    if self!height-remaining <  $.lines-before * $.line-height {
        self!new-page;
    }
    elsif $!tx > $!margin && $!tx > $!gfx.canvas.width - self!indent {
        self.say;
    }
    $!gfx;
}

method !top { $!margin + ($!gutter-2) * $.line-height; }

method !finish-page {
    if @!footnotes {
        temp $!style .= new: :lines-before(0); # avoid current styling
        $!tx = $!margin;
        $!ty = self!top;
        $!gutter = 0;
        self!draw-line($!margin, $!ty, $!gfx.canvas.width - 2*$!margin, $!ty);
        while @!footnotes {
            $.pad(1);
            my $footnote = @!footnotes.shift;
            my $destination = @!footnotes-back.shift;
            self!style: :tag(Note), {
                my PDF::Action $link = $!pdf.action: :$destination;
                self!style: :tag(Label), :$link, {
                    $.print($footnote.shift);
                } # [n]
                $.pod2pdf($footnote);
            }
        }
    }
}

method !new-page {
    self!finish-page();
    $!gutter = Gutter;
    $!page = $!pdf.add-page;
    $!gfx = $!page.gfx;
    $!tx = $!margin;
    $!ty = $!page.height - 2 * $!margin;
    # suppress whitespace before significant content
    $!pad = 0;
}

method !indent {
    $!margin  +  10 * $!indent;
}

multi sub node2text(Pod::Block $_) { node2text(.contents) }
multi sub node2text(@pod) { @pod.map(&node2text).join: ' ' }
multi sub node2text(Str() $_) { $_ }

method lang is rw { $!pdf.catalog.Lang; }

subset PodMetaType of Str where 'title'|'subtitle'|'author'|'name'|'version';

method !build-metadata-title {
    my @title = $_ with %!metadata<title>;
    with %!metadata<name> {
        @title.push: '-' if @title;
        @title.push: $_;
    }
    @title.push: 'v' ~ $_ with %!metadata<version>;
    @title.join: ' ';
}

method !set-metadata(PodMetaType $key, $value) {

    %!metadata{$key} = $value;

    my Str:D $pdf-key = do given $key {
        when 'title'|'version'|'name' { 'Title' }
        when 'subtitle' { 'Subject' }
        when 'author' { 'Author' }
    }

    my $pdf-value = $pdf-key eq 'Title'
        ?? self!build-metadata-title()
        !! $value;

    my $info = ($!pdf.Info //= {});
    $info{$pdf-key} = $pdf-value;
}

multi method metadata(PodMetaType $t) is rw {
    Proxy.new(
        FETCH => { %!metadata{$t} },
        STORE => -> $, Str:D() $v {
            self!set-metadata($t, $v);
        }
    )
}

sub pod2text-inline($pod) {
    pod2text($pod).subst(/\s+/, ' ', :g);
}

=NAME
Pod::To::PDF::API6 - Render Pod as PDF

=begin SYNOPSIS
From command line:

    $ raku --doc=PDF lib/to/class.rakumod | raku -e'"class.pdf".IO.spurt: $*IN.slurp.encode("latin-1")' > to-class.pdf

From Raku:
    =begin code :lang<raku>
    use Pod::To::PDF::API6;

    =NAME
    foobar.pl

    =SYNOPSIS
        foobar.pl <options> files ...

    pod2pdf($=pod).save-as: "foobar.pdf";
    =end code
=end SYNOPSIS

=begin EXPORTS
    class Pod::To::PDF::API6;
    sub pod2pdf; # See below
=end EXPORTS

=begin DESCRIPTION
This is an experimental module for rendering POD to PDF.

From command line:
    =begin code :lang<shell>
    $  raku --doc=PDF lib/class.rakumod | xargs xpdf
    =end code
From Raku code, the C<pod2pdf> function returns a PDF::API6 object which can
be further manipulated, or saved to a PDF file.

    =begin code :lang<raku>
    use Pod::To::PDF::API6;
    use PDF::API6;
 
    =NAME
    foobar.raku

    =SYNOPSIS
        foobarraku <options> files ...

    my PDF::API6 $pdf = pod2pdf($=pod);
    $pdf.save-as: "class.pdf"
    =end code

=end DESCRIPTION
