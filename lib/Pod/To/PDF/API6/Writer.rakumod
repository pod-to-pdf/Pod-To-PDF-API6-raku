unit class Pod::To::PDF::API6::Writer;

use Pod::To::PDF::API6::Metadata :Level;
also does Pod::To::PDF::API6::Metadata;

use PDF::API6;
use Pod::To::PDF::API6::Style;

use PDF::Content::Color :&color;
use PDF::Content::FontObj;
use PDF::Content::PageTree;
use PDF::Content::Text::Box;
use PDF::Content::Tag :Tags;

use PDF::Page;
use PDF::Annot::Link;
use PDF::Destination :Fit, :DestRef;
use PDF::Tags::Elem;
use PDF::Tags::Node;
use CSS::Properties;

use URI;
use IETF::RFC_Grammar::URI;

my constant Gutter = 3;

has PDF::API6:D $.pdf is required;
has Numeric $.margin-left;
has Numeric $.margin-right;
has Numeric $.margin-top;
has Numeric $.margin-bottom;
has Bool $.contents   is required;
has PDF::Content::FontObj %.font-map is required;
has PDF::Content::PageTree:D $.pages is required;
has Bool $.finish;

has %.index;

### Accessibilty
has Bool $.tag;
has PDF::Tags::Elem @!tags;

### Paging/Footnotes ###
has PDF::Page $!page;
has PDF::Content $!gfx;
has DestRef $!gutter-link;    # forward link to footnote area
my class PageFootNote {
    has @.contents is required;
    has Int:D $.num is rw is required;
    has PDF::Tags::Elem:D $.tag is required;
    has DestRef $.back is required;
    method ind { '[' ~ $!num ~ ']' }
}
has PageFootNote:D @!footnotes;

### Rendering State ###
has Pod::To::PDF::API6::Style $.styler handles<style font-size leading line-height bold italic mono underline lines-before link verbatim>;
has Pod::To::PDF::API6::Style $!footer-style;
has $!tx = $!margin-left; # text-flow x
has $!ty; # text-flow y
has Numeric $!indent = 0.0;
has Numeric $!padding = 0.0;
has Numeric $!code-start-y;
has UInt:D $!level = 1;
has $!gutter = Gutter;
has Bool $!float;

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

method write($pod, PDF::Tags::Elem $*root) {
    my $*tag = $*root;
    my CSS::Properties $style = $*tag.style;
    $!styler .= new: :$style;
    my $note-style = $*tag.root.styler.tag-style(FENote);
    $!footer-style .= new: :style($note-style), :lines-before(0);
    self.ast2pdf($pod);
    self!finish-page;
}

submethod TWEAK(Numeric:D :$margin = 20) {
    $!margin-top    //= $margin;
    $!margin-left   //= $margin;
    $!margin-bottom //= $margin;
    $!margin-right  //= $margin;
}

method !tag-begin($name, :%atts) {
    if $!tag {
        $*tag .= add-kid: :$name;
        $*tag.set-attributes: |%atts if %atts;
        @!tags.push: $*tag;
    }
}

method !tag-end {
    if $!tag {
        @!tags.pop;
        $*tag = @!tags.tail // $*root;
    }
}

method !tag($tag, &codez) {
    self!tag-begin($tag);
    self!gfx.&codez();
    self!tag-end;
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

method !table-row(@row, @widths, :@border!, Bool :$header) {
    if +@row -> \cols {
        my @overflow;
        # simple fixed column widths, for now
        self!gfx;
        my $tab = self!indent;
        my $row-height = 0;
        my $height = $!ty - $!margin-bottom;
        my $head-space = $.line-height - $.font-size;

        for ^cols {
            my Numeric $width = @widths[$_];
            my Pair $row = @row[$_];

            if $row.value -> $tb is copy {
                my $*tag = $row.key;
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
            $tab += $width + @border[0];
        }
        if @overflow {
            # continue table
            self!style: :lines-before(3), {
                self!table-row(@overflow, @widths, :$header);
            }
        }
        else {
            $!ty -= $row-height + @border[1];
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

    @table = ();

    if $pod.headers {
        self!style: :tag(TableHead), :bold, {
            $*tag .= TableRow;
            my @row = $pod.headers.map: {
                temp $*tag .= TableHeader;
                $*tag => self!table-cell($_)
            }
            @table.push: @row;
        }
    }
    else {
        @table.push: [];
    }

    temp $*tag .= TableBody;

    $pod.contents.map: {
        temp $*tag .= TableRow;
        my @row = .map: {
            temp $*tag .= TableData;
            $*tag => self!table-cell($_);
        }
        @table.push: @row;
    }

    my $cols = @table.max: *.elems;
    (^$cols).map: -> $col {
        @table.map({
            do with .[$col] { with .value { .width }  } // 0
        }).max
    };
}

proto method pod2pdf(|) is DEPRECATED<ast2pdf> {*}

multi method pod2pdf(Pod::Block::Table $pod) {

    self!style: :tag(Table), :block, {
        my Numeric @border = $.style.measure(:border-spacing);
        @border[1] //= @border[0];

        my \total-width = self!gfx.canvas.width - self!indent - $!margin-right;
        self!pad-here;
        if $pod.caption -> $caption {
            self!style: :tag(Caption), {
                $.say: $caption;
            }
        }

        my @widths = self!build-table: $pod, my @table;
        fit-widths(total-width - @border[0] * (@widths-1), @widths);
        my Pair @headers = @table.shift.List;
        if @headers {
            self!table-row: @headers, @widths, :header, :@border;
        }

        if @table {
            for @table {
                my @row = .List;
                if @row {
                    self!table-row: @row, @widths, :@border;
                }
            }
        }
    }
}

multi method pod2pdf(Pod::Block::Named $pod) {
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
            my Bool $toc = $_ eq 'TITLE';
            my $level = $toc ?? 0 !! 2;
            self.metadata(.lc) ||= $.pod2text-inline($pod.contents);
            self!heading($pod.contents, :$toc, :$level);
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

multi method pod2pdf(Pod::Block::Code $pod) {
    self!code: $pod.contents;
}

multi method pod2pdf(Pod::Heading $pod) {
    $!level = min($pod.level, 6);
    self!heading: $pod.contents;
}

multi method pod2pdf(Pod::Block::Para $pod) {
    self!style: :tag(Paragraph), {
        $.pod2pdf($pod.contents);
    }
}

method !make-link(Str $url) {
    my %style = :!block;
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

multi method pod2pdf(Pod::FormattingCode $pod) {
    given $pod.type {
        when 'B' {
            self!style: :tag(Strong), {
                $.pod2pdf($pod.contents);
            }
        }
        when 'C' {
            self!style: :tag(CODE), {
                $.print: $.pod2text($pod);
            }
        }
        when 'T' {
            self!style: :mono, :!block, {
                $.pod2pdf($pod.contents);
            }
        }
        when 'K' {
            self!style: :italic, :mono, :!block, {
                $.pod2pdf($pod.contents);
            }
        }
        when 'I' {
            self!style: :tag(Emphasis), {
                $.pod2pdf($pod.contents);
            }
        }
        when 'N' {
            ...
        }
        when 'U' {
            self!style: :underline, :!block, {
                $.pod2pdf($pod.contents);
            }
        }
        when 'E' { # Unicode; already converted.
            $.pod2pdf($pod.contents);
        }
        when 'Z' {
            # invisable
        }
        when 'X' {
            if $.pod2text-inline($pod.contents) -> $term {
                my Str $name = dest-name($term);

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
                else {
                    %!index{$term}<#refs>.push: %ref;
                }
            }
            # otherwise X<|> ?
        }
        when 'L' {
            my $text = $.pod2text-inline($pod.contents);
            my %style = self!make-link: $pod.meta.head // $text;
            self!style: |%style, {
                $.print: $text;
            }
        }
        when 'P' {
            # todo insertion of placed text
            if $.pod2text-inline($pod.contents) -> $url {
                my %style = self!make-link: $url;
                $.pod2pdf('(see: ');
                self!style: |%style, {
                    $.print: $url;
                }
                $.pod2pdf(')');
            }
        }
        when 'R' {
            ...
        }
        default {
            warn "unhandled: POD formatting code: $_\<\>";
            $.pod2pdf($pod.contents);
        }
    }
}

multi method pod2pdf(Pod::Defn $pod) {
    self!tag: ListItem, {
        self.block: :padding($.line-height), {
            self!style: :tag(Label), :bold, {
                $.pod2pdf($pod.term);
            }
            self!style: :tag(ListBody), :!block, {
                $.pod2pdf($pod.contents);
            }
        }
    }
}

multi method pod2pdf(Pod::Item $pod) {
...
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

    if $pod.leading || $code || $pod.trailing {
        $.block: :padding($.line-height), {
            self!heading($type.tclc ~ ' ' ~ $name, :$level);

            if $pod.leading -> $pre-pod {
                self!style: :tag(Paragraph), {
                    $.pod2pdf($pre-pod);
                }
            }

            if $code {
                self!style: :tag(Paragraph), {
                    self!code([$decl ~ ' ' ~ $code]);
                }
            }

            if $pod.trailing -> $post-pod {
                self!style: :tag(Paragraph), {
                    $.pod2pdf($post-pod);
                }
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

multi method ast2pdf('Code', @content, *%atts where .<Placement> ~~ 'Block') {
dd (:@content, :$!ty);
    self!style: :indent, :tag(CODE), :lines-before(3), :%atts, {
       self!pad-here;
       $!code-start-y //= $!ty;
       self.ast2pdf: @content;
       self!finish-code;
   }
}

multi sub text-content(@content) {
    @content.map: {
        when Str { $_ }
        when Pair {
            my :(@content, %atts) := .value.&get-content;
            @content.&text-content;
        }
        default { die "unexpected node: {.raku}" }
    }
}

multi sub text-content($) { '' }

multi method ast2pdf('FENote', @contents, *%atts) {
    my PageFootNote:D $footnote .= new(
        :@contents,
        :num(@!footnotes+1),
        :$*tag,
        :back(self!make-dest),
    );
    my UInt:D $footnote-lines = do {
        # pre-compute footnote size
        temp $!styler = $!footer-style;
        temp $!tx = $!margin-left;
        temp $!ty = $!page.height;
        temp $!indent = 0;
        given $footnote {
            my $draft-text = .ind ~ @contents.&text-content;
            +self!text-box($draft-text).lines;
        }
    }
    unless self!height-remaining > ($footnote-lines+1) * $!footer-style.line-height {
        # force a page break, unless there's room for both the reference and
        # the footnote on the current page
        self!new-page;
        $footnote.num = 1;
    }
    @!footnotes.push: $footnote;
    $!gutter += $footnote-lines;
    $!gutter-link //= self!make-dest: :left(0), :top($!margin-bottom + (Gutter + 2) * $.line-height);

    self!tag: Artifact, {
        self!tag: Reference, {
            my PDF::Action $link = PDF::API6.action: :destination($!gutter-link);
            self!style: :tag(Label), :$link, {  $.ast2pdf($footnote.ind); }
        }
    }
}

multi method ast2pdf('Link', @content, Str:D :$href!) {
    my %style = self!make-link: $href;
    self!style: |%style, {
        self.ast2pdf: @content;
    }
}

multi method ast2pdf('L', @content,) {
    $!level++;
    self!style: :tag(LIST), {
        self.ast2pdf: @content;
    }
    $!level--;
}

multi method ast2pdf('LI', @content,) {
    my Level $level = min($!level, 5);
    temp $!indent = $level + $.style.measure(:margin-left) / 10 - 1;
    temp $!padding = $.line-height * 2;

    self!style: :tag(ListItem), :bold, :block, {
        my subset LabelAst of Pair where .key eq 'Lbl';
        if (@content.head ~~ LabelAst)  {
            self.ast2pdf: @content.shift;
        }

        # omit any leading vertical padding in the list-body
        $!float = True;
        $!tx = self!indent;

        $.ast2pdf: @content;
    }
}

multi method ast2pdf(Str:D $tag, @content, *%atts) {
    self!style: :$tag, :%atts, {
        self.ast2pdf: @content;
    }
}

sub get-content(@content) {
    my subset AttContent of Pair where .value ~~ Str;
    my %atts;

    while @content.head ~~ AttContent {
        %atts{.key} = .value given @content.shift;
    }

    (@content, %atts);
}

multi method ast2pdf(@content) {
    for @content {
        when Str { self.ast2pdf: $_ }
        when Pair {
            my $tag := .key;
            my :(@content, %atts) := .value.&get-content;
            self.ast2pdf: $tag, @content, |%atts;
        }
        default { die "unexpected node: {.raku}" }
    }
}

multi method ast2pdf(Str $ast) {
    $.print: $ast;
}

multi method ast2pdf(Pair:D $_) {
    $.ast2pdf(.key, .value);
}

multi method ast2pdf($_) {
   die .raku;
}

multi method say {
    $!tx = $!margin-left;
    $!ty -= $.line-height;
}
multi method say(Str $text, |c) {
    @.print($text, :nl, |c);
}

method font { $!styler.font: :%!font-map }

method block(&codez, Numeric :$padding) {
       if $.style.page-break-before ne 'auto' || ($!ty.defined && self!height-remaining < $.lines-before * $.line-height) {
           self!new-page;
       } else {
           $!padding += $padding // $.style.measure(:margin-top);
      }

       &codez();

       $!padding = $padding // $.style.measure(:margin-bottom);
}

method !text-box(
    Str $text,
    :$width  = self!gfx.canvas.width - self!indent - $!margin-right,
    :$height = self!height-remaining,
    |c) {
    my $indent = $!tx - $!margin-left;
    my Bool $kern = !$.mono;
    PDF::Content::Text::Box.new: :$text, :$indent, :$.leading, :$.font, :$.font-size, :$width, :$height, :$.verbatim, :$kern, |c;
}

method !pad-here {
    if $!padding && !$!float {
        $!tx  = $!margin-left;
        $!ty -= $!padding;
    }
    $!float = False;
    $!padding = 0;
}

has $!last-chunk-height = 0;
method print(Str $text, Bool :$nl, |c) {
    self!pad-here;
    my $gfx = self!gfx;
    my PDF::Content::Text::Box $tb = self!text-box: $text, |c;
    my Pair $pos = self!text-position();

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
                .print: $tb, |$pos, :$nl, :shape, |c;
                $!tx = $!margin-left;
                $!tx += .text-position[0] - self!indent
                    unless $nl;

            }
            self!underline: $tb
                if $.underline;
        }

        $gfx.Restore if $.link;

        $tb.lines.pop unless $nl;
        my $h = $tb.content-height;
        $!ty -= $h;
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
            &action($_);
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

method !style(&codez, Numeric :$indent, Str :tag($name), :%atts, Bool :$block is copy, |c) {
    self!tag-begin($_, :%atts) with $name;
    my $style = $*tag.style;
    $block //= $style.display ~~ 'block';
    temp $!styler .= new: :$style, |c;
    temp $!indent += $indent if $indent;
    my $rv := $block ?? $.block(&codez) !! &codez();
    self!tag-end() with $name;
    $rv;
}

method !pod2dest($pod, Str :$name) {
    my $y0 := $!ty;

    $.pod2pdf($pod);

    my \y = $!ty;
    my \h = max(y - $y0, $!last-chunk-height);
    my DestRef $ = self!make-dest: :$name, :fit(FitBoxHoriz), :top(y+h);
}

method !heading($pod is copy, Level:D :$level = $!level, Bool :$toc = True) {
    $pod .= &strip-para;

    my $tag =  $level ?? 'H' ~ $level !! Title;
    self!style: :$tag, {

        my Str $Title = $.pod2text-inline($pod);
        $*tag.cos.title = $Title;

        if $!contents && $toc {
            # Register in table of contents
            my $name = dest-name($Title);
            my DestRef $dest = self!pod2dest($pod, :$name);
            my PDF::StructElem $SE = $*tag.cos;
            self.add-toc-entry: { :$Title, :$dest, :$SE  }, :$level;
        }
        else {
            $.pod2pdf($pod);
        }
    }
}

# to reduce the common case <Hn><P>Xxxx<P></Hn> -> <Hn>Xxxx</Hn>
multi sub strip-para(Array $_ where +$_ == 1) {
    .map(&strip-para).List;
}
multi sub strip-para(Pod::Block::Para $_) {
    .contents;
}
multi sub strip-para($_) { $_ }

method !make-dest(
    :$fit = FitXYZoom,
    :$left is copy = $!tx - hpad,
    :$top  is copy  = $!ty + $.line-height + vpad,
    |c,
) {
    ($left, $top) = $!gfx.base-coords: $left, $top;
    $!pdf.destination: :$!page, :$fit, :$left, :$top, |c;
}

method !finish-code {
    my constant pad = 5;
    with $!code-start-y -> $y0 {
        my $x0 = self!indent;
        my $width = self!gfx.canvas.width - $!margin-right - $x0;
        self!gfx.tag: Artifact, {
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
    use PDF::COS:::Name;
    sub prefix:</>($s) { PDF::COS::Name.COERCE($s) };

    @contents.pop if @contents.tail ~~ "\n";

    self!gfx;

    self!style: :indent, :tag(CODE), :lines-before(3), :block, {
        $*tag.set-attribute('Placement', /'Block');
        self!pad-here;

        my @plain-text;
        for @contents {
            $!code-start-y //= $!ty;
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
    self!tag: Artifact, {
        for $tb.lines {
            my $x0 = $tab + .indent;
            my $x1 = $tab + .content-width;
            self!draw-line($x0, $y, $x1, :$linewidth);
            $y -= .height * $tb.leading;
        }
    }
}

method !link(PDF::Content::Text::Box $tb, :$tab = $!margin-left, ) {
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
        $*tag.Link($!gfx, $link)
             unless $!gfx.artifact;
    }
}

method !gfx {
    if !$!gfx.defined {
        self!new-page;
    }
    elsif $!tx > $!gfx.canvas.width - $!margin-right {
        self.say;
    }
    $!gfx;
}

method !bottom { $!margin-bottom + ($!gutter-2) * $!footer-style.line-height; }
method !height-remaining {
    $!ty - $!margin-bottom - $!padding - $!gutter * $!footer-style.line-height;
}

method !lines-remaining {
    (self!height-remaining / $!footer-style.line-height + 0.01).Int;
}

method !finish-page {
    self!finish-code
        if $!code-start-y;
    if @!footnotes {
        temp $!styler = $!footer-style;
        temp $!indent = 0;
        temp $!code-start-y = Nil;
        $!tx = $!margin-left;
        $!ty = self!bottom;
        $!gutter = 0;
        my $start-page = $!page;
        self!tag: Artifact, {
            self!draw-line($!margin-left, $!ty, $!gfx.canvas.width - $!margin-right, $!ty);
         }
         while @!footnotes {
            my PageFootNote:D $footnote := @!footnotes.shift;
            temp $*tag = $footnote.tag;
            my DestRef $destination = $footnote.back;
            $!padding = $.line-height;
            self!style: :tag(FENote), {
                self!tag: Artifact, {
                    my PDF::Action $link = $!pdf.action: :$destination;
                    self!style: :tag(Label), :$link, :italic, {
                        $.print($footnote.ind);
                    } # [n]
                }
                $!tx += 2;

                $.ast2pdf($footnote.contents);
            }
            unless $!page === $start-page {
                # page break in footnotes. draw closing underline
                $.say;
                my $y = $!ty + $.line-height / 2;
                self!tag: Artifact, {
                    self!draw-line($!margin-left, $y, $!gfx.canvas.width - $!margin-right, $y);
                }
            }
        }
    }
}

method !new-page {
    self!finish-page();
    $!page.finish if $!page.defined && $!finish;
    $!gutter = Gutter;
    $!page = $!pdf.add-page;
    $!gfx = $!page.gfx;
    $!tx = $!margin-left;
    $!ty = $!page.height - $!margin-top - 16;
    # suppress whitespace before significant content
    $!padding = 0;
}

method !indent {
    $!margin-left  +  10 * $!indent;
}

method pod2text-inline($pod) {
    $.pod2text($pod).subst(/\s+/, ' ', :g);
}

multi method pod2text(Pod::FormattingCode $pod) {
    given $pod.type {
        when 'N'|'Z' { '' }
        when 'R' { ... }
        default  { $.pod2text: $pod.contents }
    }
}

multi method pod2text(Pod::Block $pod) {
    $pod.contents.map({$.pod2text($_)}).join;
}
multi method pod2text(Str $pod) { $pod }
multi method pod2text($pod) { $pod.map({$.pod2text($_)}).join }

