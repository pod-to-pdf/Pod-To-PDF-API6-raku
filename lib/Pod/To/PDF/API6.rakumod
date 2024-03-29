unit class Pod::To::PDF::API6:ver<0.0.1>;

use PDF::API6;
use PDF::Tags;
use PDF::Tags::Elem;
use PDF::Content;
use PDF::Content::Color :&color;
use PDF::Content::Tag :Tags;
use PDF::Content::Text::Box;
use Pod::To::PDF::API6::Style;
use File::Temp;
use URI;
use IETF::RFC_Grammar::URI;
# PDF::Class
use PDF::Action;
use PDF::Annot::Link;
use PDF::Destination :Fit, :DestRef;
use PDF::Page;
use PDF::StructElem;

subset Level of Int:D where 0..6;
my constant Gutter = 3;

### Attributes ###
has PDF::API6 $.pdf .= new;
has PDF::Tags $.tags .= create: :$!pdf;
has PDF::Tags::Elem $.root = $!tags.Document;
has Numeric $.width  = 612;
has Numeric $.height = 792;
has $.margin = 20;
has Bool $.contents = True;
has @.toc; # table of contents
has Str %!metadata;
has %.replace;
has %.index;
has Bool $.tag = True;
has PDF::Content::FontObj %.font-map;
has Bool $.page-numbers;

### Paging/Footnotes ###
has PDF::Page $!page;
has PDF::Content $!gfx;
has DestRef $!gutter-link;    # forward link to footnote area
has @!footnotes;
has DestRef @!footnotes-back; # per-footnote return links
has PDF::Tags::Elem @!footnotes-tag;

### Rendering State ###
has Pod::To::PDF::API6::Style $.style handles<font-size leading line-height bold italic mono underline lines-before link verbatim> .= new;
has $!tx = $!margin; # text-flow x
has $!ty; # text-flow y
has UInt $!indent = 0;
has UInt $!padding = 0;
has Numeric $!code-start-y;
has UInt:D $!level = 1;
has PDF::Tags::Elem @!tags;
has $!gutter = Gutter;

class DefaultLinker {
    method extension { 'pdf' }
    method resolve-link(Str $link) {
        if IETF::RFC_Grammar::URI.parse($link) {
            my URI() $uri = $link;
            if $uri.is-relative && $uri.path.segments.tail && ! $uri.path.segments.tail.contains('.') {
                $uri.path($uri.path ~ '.' ~ $.extension);
            }
            $uri.Str;
        }
        else {
            Str
        }
    }
}
has $.linker = DefaultLinker;

method !tag-begin($name) {
    if $!tag {
        $*tag .= add-kid: :$name;
        @!tags.push: $*tag;
    }
}

method !tag-end {
    if $!tag {
        @!tags.pop;
        $*tag = @!tags.tail // self.root;
    }
}

method !tag($tag, &codez) {
    self!tag-begin($tag);
    &codez();
    self!tag-end;
}

method !paginate($pdf) {
    my $page-count = $pdf.Pages.page-count;
    my $font = $pdf.core-font: "Helvetica";
    my $font-size := 9;
    my $align := 'right';
    my $page-num;
    for $pdf.Pages.iterate-pages -> $page {
        my PDF::Content $gfx = $page.gfx;
        my @position = $gfx.width - $!margin, $!margin - $font-size;
        my $text = "Page {++$page-num} of $page-count";
        $gfx.tag: Artifact, {
            .print: $text, :@position, :$font, :$font-size, :$align;
        }
        $page.finish;
    }
}

method read($pod, :$*tag is copy = self.root) {
    self.pod2pdf($pod);
    self!finish-page;
    self!paginate($!pdf)
        if $!page-numbers;
    .Lang = self.lang with $!root;
}

method pdf {
    if @!toc {
        $!pdf.outlines.kids = @!toc;
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

submethod TWEAK(Str :$lang = 'en', :$pod, :%metadata, :@fonts) {
    $!pdf.media-box = 0, 0, $!width, $!height;
    self.lang = $_ with $lang;
    self!preload-fonts(@fonts)
        if @fonts;
    $!pdf.creator.push: "{self.^name}-{self.^ver}";
    self.metadata(.key.lc) = .value for %metadata.pairs;
    self.read($_) with $pod;
}

method render(
    $class: $pod,
    IO() :$save-as is copy = tempfile("pod2pdf-api6-****.pdf", :!unlink)[1],
    UInt:D :$width  is copy = 612,
    UInt:D :$height is copy = 792,
    UInt:D :$margin is copy = 20,
    Bool :$index    is copy = True,
    Bool :$contents is copy = True,
    Bool :$page-numbers is copy,
    |c,
) {
    state %cache{Any};
    %cache{$pod} //= do {
        for @*ARGS {
            when /^'--page-numbers'$/  { $page-numbers = True }
            when /^'--/index'$/        { $index  = False }
            when /^'--/'[toc|['table-of-']?contents]$/ { $contents  = False }
            when /^'--width='(\d+)$/   { $width  = $0.Int }
            when /^'--height='(\d+)$/  { $height = $0.Int }
            when /^'--margin='(\d+)$/  { $margin = $0.Int }
            when /^'--save-as='(.+)$/  { $save-as = $0.Str }
            default { note "ignoring $_ argument" }
        }
        # render method may be called more than once: Rakudo #2588
        my $renderer = $class.new: |c, :$width, :$height, :$pod, :$margin, :$contents, :$page-numbers;
        $renderer!build-index
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
    $renderer!build-index
        if $index && $renderer.index;
    $renderer.pdf;
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
    @widths;
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
    my $text = $.pod2text-inline($pod);
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
}

multi method pod2pdf(Pod::Block::Table $pod) {
    my @widths = self!build-table: $pod, my @table;

    self!style: :lines-before(3), :pad, {
        temp $*tag .= Table;
        if $pod.caption -> $caption {
            self!style: :tag(Caption), :italic, {
                $.say: $caption;
            }
        }
        self!pad-here;
        my PDF::Content::Text::Box @headers = @table.shift.List;
        if @headers {
            temp $*tag .= TableHead;
            $*tag .= TableRow;
            self!table-row: @headers, @widths, :header;
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
            when 'TITLE'|'SUBTITLE' {
                my $toc = $_ eq 'TITLE';
                $!level = $_ eq 'TITLE' ?? 0 !! 2;
                self.metadata(.lc) ||= $.pod2text-inline($pod.contents);
                self!heading($pod.contents, :$toc, :padding(1));
            }
            default {
                my $name = $_;
                temp $!level += 1;
                if $name eq $name.uc {
                    if $name ~~ 'VERSION'|'NAME'|'AUTHOR' {
                        self.metadata(.lc) ||= $.pod2text-inline($pod.contents);
                    }
                    $!level = 2;
                    $name = .tclc;
                }
                self!heading($name);
                $.pod2pdf($pod.contents);
            }
        }
    }
}

multi method pod2pdf(Pod::Block::Code $pod) {
    self!style: :pad, :tag(Paragraph), :lines-before(3), {
        self!code: $pod.contents;
    }
}

multi method pod2pdf(Pod::Heading $pod) {
    $.pad: {
        $!level = min($pod.level, 6);
        self!heading: $pod.contents;
    }
}

multi method pod2pdf(Pod::Block::Para $pod) {
    $.pad: {
        self!style: :tag(Paragraph), {
            $.pod2pdf($pod.contents);
        }
    }
}

method !resolve-link(Str $url) {
    my %style;
    with $url {
        if .starts-with('#') {
            # internal link
            my $destination = dest-name($_);
            %style<link> = $!pdf.action: :$destination;
            %style<tag> = Reference;
        }
        else {
            with $!linker.resolve-link($_) -> $uri {
                %style<link> = PDF::API6.action: :$uri;
            }
        }
    }
    %style;
}

has %!replacing;
method !replace(Pod::FormattingCode $pod where .type eq 'R', &continue) {
    my $place-holder = $.pod2text($pod.contents);

    die "unable to recursively replace R\<$place-holder\>"
         if %!replacing{$place-holder}++;

    my $new-pod = %!replace{$place-holder};
    without $new-pod {
        note "replacement not specified for R\<$place-holder\>";
        $_ = $pod.contents;
    }

    my $rv := &continue($new-pod);

    %!replacing{$place-holder}:delete;;
    $rv;
}

multi method pod2pdf(Pod::FormattingCode $pod) {
    given $pod.type {
        when 'B' {
            self!style: :bold, {
                $.pod2pdf($pod.contents);
            }
        }
        when 'C' {
            my $font-size = $.font-size * .85;
            self!style: :tag(CODE), :mono, :$font-size, {
                $.print: $.pod2text($pod);
            }
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
            my PDF::Action $link = PDF::API6.action: :destination($!gutter-link);

            temp $*tag .= Span;
            self!style: :tag(Reference), {
                self!style: :tag(Label), :$link, {  $.pod2pdf($ind); }
            }
            my @contents = $ind, $pod.contents.Slip;
            @!footnotes.push: @contents;
            @!footnotes-back.push: self!make-dest;
            @!footnotes-tag.push: $*tag;
            do {
                # pre-compute footnote size
                temp $!style .= new;
                temp $!tx = $!margin;
                temp $!ty = $!page.height;
                temp $!indent = 0;
                my $draft-footnote = $ind ~ $.pod2text-inline($pod.contents);
                $!gutter += self!text-box($draft-footnote).lines;
            }
        }
        when 'U' {
            self!style: :underline, {
                $.pod2pdf($pod.contents);
            }
        }
        when 'E' {
            $.pod2pdf($pod.contents);
        }
        when 'Z' {
            # invisable
        }
        when 'X' {
            my $term = $.pod2text-inline($pod.contents);
            my Str $name = self!gen-dest-name('index-' ~ $term)
                if $term;

            my DestRef $dest = self!pod2dest($pod.contents, :$name);
            my PDF::StructElem $SE = $*tag.cos;
            my %ref = %{ :$dest, :$SE  };

            if $pod.meta -> $meta {
                for $meta.List {
                    my $idx = %!index{.head} //= %();
                    $idx = $idx{$_} //= %() for .skip;
                    $idx<#refs>.push: %ref;
                }
            }
            elsif $term {
                %!index{$term}<#refs>.push: %ref;
            }
            # otherwise X<|> ?
        }
        when 'L' {
            my $text = $.pod2text-inline($pod.contents);
            my %style = self!resolve-link: $pod.meta.head // $text;
            self!style: |%style, {
                $.print: $text;
            }
        }
        when 'P' {
            # todo insertion of placed text
            if $.pod2text-inline($pod.contents) -> $url {
                my %style = self!resolve-link: $url;
                $.pod2pdf('(see: ');
                self!style: |%style, {
                    $.print: $url;
                }
                $.pod2pdf(')');
            }
        }
        when 'R' {
            self!replace: $pod, {$.pod2pdf($_)};
        }
        default {
            warn "unhandled: POD formatting code: $_\<\>";
            $.pod2pdf($pod.contents);
        }
    }
}

multi method pod2pdf(Pod::Defn $pod) {
    self!tag: Paragraph, {
        self!style: :bold, :tag(Quotation), {
            $.pod2pdf($pod.term);
        }
    }
    $.pod2pdf($pod.contents);
}

multi method pod2pdf(Pod::Item $pod) {
    $.pad: {
        my Level $list-level = min($pod.level // 1, 3);
        self!style: :tag(ListItem), :indent($list-level), {
            {
                my constant BulletPoints = (
                   "\c[BULLET]",  "\c[MIDDLE DOT]", '-'
                );
                my Str $bp = BulletPoints[$list-level - 1];
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

    self!style: :lines-before(3), :pad, {
        self!heading($type.tclc ~ ' ' ~ $name, :$level);

        if $pod.leading -> $pre-pod {
            self!style: :pad, :tag(Paragraph), {
                $.pod2pdf($pre-pod);
            }
        }

        if $code {
            self!style: :pad, :tag(Paragraph), {
                self!code([$decl ~ ' ' ~ $code]);
            }
        }

        if $pod.trailing -> $post-pod {
            self!style: :pad, :tag(Paragraph), {
                $.pod2pdf($post-pod);
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
    if $pod.WHAT.raku ~~ 'List'|'Array' {
        ## Huh?
        $.pod2pdf($_) for $pod.list;
    }
    else {
        warn "fallback render of {$pod.WHAT.raku}";
        $.say: $.pod2text($pod);
    }
}

multi method say {
    $!tx = $!margin;
    $!ty -= $.line-height;
}
multi method say(Str $text, |c) {
    @.print($text, :nl, |c);
}

method font { $!style.font: :%!font-map }

multi method pad { $!padding=2 }
multi method pad(&codez) { $.pad; &codez(); $.pad}

method !text-box(
    Str $text,
    :$width  = self!gfx.canvas.width - self!indent - $!margin,
    :$height = self!height-remaining,
    |c) {
    my Bool $kern = !$.mono;
    PDF::Content::Text::Box.new: :$text, :indent($!tx - $!margin), :$.leading, :$.font, :$.font-size, :$width, :$height, :$.verbatim, :$kern, |c;
}

method !pad-here {
    $.say for ^$!padding;
    $!padding = 0;
}

has $!last-chunk-height = 0;
method print(Str $text, Bool :$nl, :$reflow = True, |c) {
    self!pad-here;
    my PDF::Content::Text::Box $tb = self!text-box: $text, |c;
    my $w = $tb.content-width;
    my $h = $tb.content-height;
    my Pair $pos = self!text-position();
    my $gfx = self!gfx;

    {
        temp $*tag;
        if $.link {
            use PDF::Content::Color :ColorName;
            $gfx.Save;
            $gfx.FillColor = color Blue;
            self!link: $tb;
            $*tag = $_ with $*tag.kids.tail;
        }

        self!mark: {
            $gfx.text: {
                .print: $tb, |$pos, :$nl, |c;
                $!tx = $!margin;
                $!tx += .text-position[0] - self!indent
                    unless $nl;

            }
            self!underline: $tb
                if $.underline;
        }

        $gfx.Restore if $.link;

        $tb.lines.pop unless $nl;
        $!ty -= $tb.content-height;
        $!last-chunk-height = $h;
    }

    if $tb.overflow {
        my $in-code-block = $!code-start-y.defined;
        self!new-page;
        $!code-start-y = $!ty if $in-code-block;
        self.print($tb.overflow.join, :$nl);
    }
}

method !text-position {
    :position[self!indent, $!ty]
}

method !mark(&action, |c) {
    given $!gfx {
        if !$!tag {
            &action();
        }
        elsif .open-tags.first(*.mcid.defined) {
            # caller is already marking
            .tag: $*tag.name, &action, |$*tag.attributes;
        }
        else {
            $*tag.mark: $_, &action, |c;
        }
    }
}

method !style(&codez, Int :$indent, Str :tag($name) is copy, Bool :$pad, |c) {
    temp $!style .= clone: |c;
    temp $!indent;
    temp $*tag;
    if $name.defined {
        $*tag .= add-kid: :$name;
    }
    $!indent += $indent if $indent;
    $pad ?? $.pad(&codez) !! &codez();
}

method !add-toc-entry(Hash $entry, @kids = @!toc, Level :$level!, Level :$cur = 1, ) {
    if $cur >= $level {
        @kids.push: $entry;
    }
    else {
        # descend
        @kids.push: { :Title(' '), } unless @kids;
        @kids.tail<kids> //= [];
        self!add-toc-entry($entry, :$level, :cur($cur+1), @kids.tail<kids>);
    }
}

method !pod2dest($pod, Str :$name) {
    my $y0 := $!ty;

    $.pod2pdf($pod);

    my \y = $!ty;
    my \h = max(y - $y0, $!last-chunk-height);
    my DestRef $ = self!make-dest: :$name, :fit(FitBoxHoriz), :top(y+h);

}

method !heading($pod is copy, Level:D :$level = $!level, :$underline = $level <= 1, Bool :$toc = True, :$!padding=2) {
    my constant HeadingSizes = 28, 24, 20, 16, 14, 12, 12;
    my $font-size = HeadingSizes[$level];
    my Bool $bold = $level <= 4;
    my Bool $italic;
    my $lines-before = $.lines-before;

    given $level {
        when 0|1 { self!new-page; }
        when 2   { $lines-before = 3; }
        when 3   { $lines-before = 2; }
        when 5   { $italic = True; }
    }

    $pod .= &strip-para;

    my $tag = $level ?? 'H' ~ $level !! 'Title';
    self!style: :$tag, :$font-size, :$bold, :$italic, :$underline, :$lines-before, {

        my Str $Title = $.pod2text-inline($pod);
        $*tag.cos.title = $Title;
        self!pad-here;

        if $!contents && $toc {
            # Register in table of contents
            my $name = self!gen-dest-name($Title);
            my DestRef $dest = self!pod2dest($pod, :$name);
            my PDF::StructElem $SE = $*tag.cos;
            self!add-toc-entry: { :$Title, :$dest, :$SE  }, :$level;
        }
        else {
            $.pod2pdf($pod);
        }
    }
}

sub categorize-alphabetically(%index) {
    my %alpha-index;
    for %index.sort(*.key.uc) {
        %alpha-index{.key.substr(0,1).uc}{.key} = .value;
    }
    %alpha-index;
}

method !add-terms(%index, :$level is copy = 1) {
    $level++;

    for %index.sort(*.key.uc) {
        my $term = .key;
        my %kids = .value;
        my Hash @refs = .List with %kids<#refs>:delete;
        @refs[0] //= %( );
        for @refs {
            my %toci = %$_;
            %toci<Title> = $term;
            self!add-toc-entry: %toci, :$level;
            $term = ' ';
        }

        self!add-terms(%kids, :$level) if %kids;
    }
}

method !build-index {
    self!add-toc-entry(%( :Title('Index')), :level(1));
    my %idx := %!index;
    %idx .= &categorize-alphabetically
        if %idx > 64;
    self!add-terms(%idx);
}

# to reduce the common case <Hn><P>Xxxx<P></Hn> -> <Hn>Xxxx</Hn>
multi sub strip-para(Array $_ where +$_ == 1) {
    .map(&strip-para).List;
}
multi sub strip-para(Pod::Block::Para $_) {
    .contents;
}
multi sub strip-para($_) { $_ }

has UInt %!dest-used;
method !gen-dest-name($title, $seq = '') {
    my $name = dest-name($title ~ $seq);
    if %!dest-used{$name}++ {
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

method !finish-code {
    my constant pad = 5;
    with $!code-start-y -> $y0 {
        my $x0 = self!indent;
        my $width = self!gfx.canvas.width - $!margin - $x0;
        $!gfx.tag: Artifact, {
            .graphics: {
                my constant Black = 0;
                .FillColor = color Black;
                .StrokeColor = color Black;
                .FillAlpha = 0.1;
                .StrokeAlpha = 0.25;
                .Rectangle: $x0 - pad, $!ty - pad, $width + pad*2, $y0 - $!ty + pad*3;
                .paint: :fill, :stroke;
            }
        }
        $!code-start-y = Nil;
    }
}

method !code(@contents is copy) {
    @contents.pop if @contents.tail ~~ "\n";
    my $font-size = $.font-size * .85;

    self!gfx;

    self!style: :mono, :indent, :tag(CODE), :$font-size, :lines-before(0), :pad, :verbatim, {

        self!pad-here;

        my @plain-text;
        for ^@contents -> $i {
            $!code-start-y //= $!ty;
            given @contents[$i] {
                when Str {
                    @plain-text.push: $_;
                }
                default  {
                    # presumably formatted
                    if @plain-text {
                        $.print: @plain-text.join;
                        @plain-text = ();
                    }

                    $.pod2pdf($_);
                }
            }
        }
        if @plain-text {
            $.print: @plain-text.join;
        }
        self!finish-code;
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
    $!gfx.tag: Artifact, {
        for $tb.lines {
            my $x0 = $tab + .indent;
            my $x1 = $tab + .content-width;
            self!draw-line($x0, $y, $x1, :$linewidth);
            $y -= .height * $tb.leading;
        }
    }
}

method !link(PDF::Content::Text::Box $tb, :$tab = $!margin, ) {
    my constant pad = 2;
    my $y = $!ty + $tb.underline-position;
    for $tb.lines {
        my $x0 = $tab + .indent;
        my $x1 = $tab + .content-width;
        my @rect = $!gfx.base-coords: $x0, $y, $x1, $y + $.line-height;
        @rect Z+= [-pad, -pad, pad, 0];
        my @Border = 0, 0, 0;
        my Str $content = $tb.text;

        my PDF::Annot::Link $link = PDF::API6.annotation(
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
    if !$!gfx.defined || self!height-remaining < $.lines-before * $.line-height {
        self!new-page;
    }
    elsif $!tx > $!margin && $!tx > $!gfx.canvas.width - self!indent {
        self.say;
    }
    $!gfx;
}

method !bottom { $!margin + ($!gutter-2) * $.line-height; }
method !height-remaining {
    $!ty - $!margin - $!gutter * $.line-height;
}

method !lines-remaining {
    (self!height-remaining / $.line-height + 0.01).Int;
}

method !finish-page {
    self!finish-code
        if $!code-start-y;
    if @!footnotes {
        temp $!style .= new: :lines-before(0); # avoid current styling
        temp $!indent = 0;
        $!tx = $!margin;
        $!ty = self!bottom;
        $!gutter = 0;
        self!draw-line($!margin, $!ty, $!gfx.canvas.width - $!margin, $!ty);
        while @!footnotes {
            $!padding = 1;
            my $footnote = @!footnotes.shift;
            my $destination = @!footnotes-back.shift;
            temp $*tag = @!footnotes-tag.shift;
            self!style: :tag(Note), {
                my PDF::Action $link = $!pdf.action: :$destination;
                self!style: :tag(Label), :$link, {
                    $.print($footnote.shift);
                } # [n]
                $!tx += 2;
                $*tag .= Paragraph;
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
    $!ty = $!page.height - $!margin - 16;
    # suppress whitespace before significant content
    $!padding = 0;
}

method !indent {
    $!margin  +  10 * $!indent;
}

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

method pod2text-inline($pod) {
    $.pod2text($pod).subst(/\s+/, ' ', :g);
}

multi method pod2text(Pod::FormattingCode $pod) {
    given $pod.type {
        when 'N'|'Z' { '' }
        when 'R' { self!replace: $pod, { $.pod2text($_) } }
        default  { $.pod2text: $pod.contents }
    }
}

multi method pod2text(Pod::Block $pod) {
    $pod.contents.map({$.pod2text($_)}).join;
}
multi method pod2text(Str $pod) { $pod }
multi method pod2text($pod) { $pod.map({$.pod2text($_)}).join }

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
