class Pod::To::PDF:ver<0.0.1> {

    use PDF::API6;
    use PDF::Tags;
    use PDF::Tags::Elem;
    use PDF::Content;
    use PDF::Content::Color :&color;
    use PDF::Content::Tag :Tags;
    use PDF::Content::Text::Box;
    use Pod::To::PDF::Style;
    use Pod::To::Text;
    use PDF::Page;

    subset Level of Int:D where 1..6;

    has PDF::API6 $.pdf .= new;
    has PDF::Tags $.tags .= create: :$!pdf;
    has PDF::Tags::Elem $.root = $!tags.Document;
    has PDF::Page $!page;
    has PDF::Content $!gfx;
    has UInt $!indent = 0;
    has Pod::To::PDF::Style $.style handles<font font-size leading line-height bold invisible italic mono> .= new;
    has $!x;
    has $!y;
    has $.margin = 10;
    has UInt $!pad = 0;
    has @.toc;

    submethod TWEAK {
        $!pdf.creator.push: "{self.^name}-{self.^ver}";
    }

    method render($class: $pod, |c) {
	pod2pdf($pod, :$class, |c).Str;
    }

    proto method pod2pdf($p, |) {
        {*}
    }

    sub pod2pdf($pod, :$class = $?CLASS, :$toc = True) is export {
        my $obj = $class.new;
        my $*tag = $obj.root;
        $obj.pod2pdf($pod);
        if $toc && $obj.toc {
            $obj.pdf.outlines.kids = $obj.toc;
        }
        $obj.pdf;
    }

    multi method pod2pdf(Pod::Block::Table $pod) {
        $.pad: {
            if $pod.caption -> $caption {
                $.say: $caption;
            }
            # stub
            $.say: $pod.headers.map({node2text($_)}).join: '|';
            $.say('------------------');
            for $pod.contents -> $row {
                $.say: $row.map({node2text($_)}).join: '|';
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
            default     {
                warn $pod.WHAT.raku;
                $.say($pod.name);
                $.pod2pdf($pod.contents)
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
            when 'I' {
                temp $.italic = True;
                $.pod2pdf($pod.contents);
            }
            when 'B' {
                temp $.bold = True;
                $.pod2pdf($pod.contents);
            }
            when 'Z' {
                temp $.invisible = True;
                $.pod2pdf($pod.contents);
            }
            when 'L' {
                my $x = $!x;
                my $y = $!y;
                my $text = $pod.contents.join;
                # avoid line spanning, for now
                self!mark: :name<Link>, {
                    $.print($text);
                }
                if $!y > $y {
                    # got line break.
                    # Todo /QuadPoint regions for line-spanning links
                    # see PDF ISO32000 14.8.4.4.2 Link Elements
                    $x = 0;
                }

                my @bbox = [$x + $!margin - 2, $!y - 2, $!x + $!margin, $!y + $.font-size];
                given $pod.meta.head // $text -> $uri {
                    my $action = $!pdf.action: :$uri;
                    $!page = self!gfx.canvas;
                    my @rect = self!gfx.base-coords: |@bbox;
                    $!pdf.annotation(
                        :$!page,
                        :$action,
                        :@rect,
                    );
                }
            }
            default {
                warn "todo: POD formatting code: $_";
                $.pod2pdf($pod.contents);
            }
        }
    }

    multi method pod2pdf(Pod::Item $pod) {
        $.pad: {
            self!style: :tag(ListItem), {
                $*tag.Lbl.mark: self!gfx, {
                    my constant BulletPoints = ("\c[BULLET]", "\c[WHITE BULLET]", '-');
                    my Level $list-level = min($pod.level // 1, 3);
                    my $bp = BulletPoints[$list-level - 1];
                    .print: $bp, |self!text-position;
                }

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

        $.pad: {
            self!style: :tag(Section), {
                self!heading($type.tclc ~ ' ' ~ $name, :$level);

                if $code {
                    $.pad(1);
                    self!code($decl ~ ' ' ~ $code);
                }

                if $pod.contents {
                    $.pad(1);
                    self!style: :tag(Paragraph), {
                        $.pod2pdf($pod.contents);
                    }
                }
            }
        }
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
        $p.raku ~ ',' ~ ( $p.WHY ?? ' # ' ~ $p.WHY !! ' ')
    }

    multi method pod2pdf(Array $pod) {
        for $pod.list {
            $.pod2pdf($_);
        };
    }

    multi method pod2pdf(Str $pod) {
        $.print($pod);
    }

    multi method pod2pdf($pod) {
        warn "fallback render of {$pod.WHAT.raku}";
        $.say: pod2text($pod);
    }

    multi method say {
        $!x = 0;
        $!y -= $.line-height;
    }
    multi method say(Str $text, |c) {
        @.print($text, :nl, |c);
    }

    multi method pad(&codez) { $.pad; &codez(); $.pad}
    multi method pad($!pad = 2) { }
    method !text-box(Str $text, |c) {
        PDF::Content::Text::Box.new: :$text, :indent($!x), :$.leading, :$.font, :$.font-size, |c;
    }

    method print(Str $text, Bool :$nl, |c) {
        $.say for ^$!pad;
        $!pad = 0;
        my $gfx = self!gfx;
        my $width = $!gfx.canvas.width - self!indent - $!margin - $!x;
        my $height = $!y - $!margin;
        my PDF::Content::Text::Box $tb = self!text-box: $text, :$width, :$height, |c;
        self!mark: {
            $gfx.print: $tb, |self!text-position(), :$nl
                unless $.invisible;
        }

        if $tb.overflow {
            $.say() unless $nl;
            @.print: $tb.overflow.join;
        }
        else {
            # calculate text bounding box and advance x, y
            my $lines = +$tb.lines;
            my $x0 = $!margin + self!indent;
            $x0 += $!x if $lines <= 1;
            if $nl {
                # advance to next line
                $!x = 0;
            }
            else {
                # continue this line
                my $last-line = $tb.lines.pop;
                $!x += $last-line.content-width + $tb.space-width;
            }
            $!y -= $tb.content-height;
            my $y0 = $!y + $.line-height;

            ($x0, $y0, $tb.content-width, $tb.content-height);
        }
    }

    method !text-position {
        :position[$!margin + self!indent, $!y]
    }

    method !mark(&action, |c) {
        given self!gfx {
            if .open-tags.first(*.mcid.defined) {
                # caller is already marking
                action($_);
            }
            else {
                $*tag.mark: $_, &action, |c;
            }
        }
    }

    method !style(&codez, Bool :$indent, Str :$tag, |c) {
        temp $!style .= clone: |c;
        temp $!indent;
        temp $*tag;
        $*tag .= add-kid: :name($_) with $tag;
        $!indent += 1 if $indent;
        &codez();
    }

    method !add-toc-entry(Hash $entry, Level $level, @kids = @!toc, Level :$cur = 1, ) {
        if $level == $cur {
            @kids.push: $entry;
        }
        else {
            # descend
            @kids.push({}) unless @kids;
            @kids.tail<kids> //= [];
            self!add-toc-entry($entry, $level, :cur($cur+1), @kids.tail<kids>);
        }
    }

    method !heading(Str:D $Title, Level :$level = 2) {
        self!style: :tag('H' ~ $level), {
            my constant HeadingSizes = 20, 16, 13, 11.5, 10, 10;
            $.font-size = HeadingSizes[$level - 1];

            given $level {
                when 1 { self!new-page }
                when 2 { $!pad++ }
            }

            if $level < 5 {
                $.bold = True;
            }
            else {
                $.italic = True;
            }

            my @bbox = @.say: $Title;

            # Register in table of contents
            my @rect = $!gfx.base-coords: |@bbox;
            my PDF::Destination $dest = $!pdf.destination: :$!page, :@rect;
            self!add-toc-entry: { :$Title, :$dest  }, $level;
        }
    }

    method !code(Str $raw) {
        self!style: :mono, :indent, :tag(CODE), {
            my constant \pad = 3;
            $.font-size *= .8;
            my $gfx = self!gfx;
            my (\x0, \y0, \w, \h) = @.say($raw, :verbatim);

            $gfx.graphics: {
                constant \pad = 2;
                my @rect = (x0 - pad, y0 - pad, w + 2*pad, h + 2*pad);
                .FillColor = color 0;
                .FillAlpha = 0.1;
                .Rectangle: |@rect;
                .Fill;
            }
        }
    }

    method !gfx {
        if !$!page.defined || $!y <= 2 * $!margin {
            self!new-page;
        }
        elsif $!x > 0 && $!x > $!gfx.canvas.width - self!indent - $!margin {
            self.say;
        }
        $!gfx;
    }

    method !new-page {
        $!page = $!pdf.add-page;
        $!gfx = $!page.gfx;
        $!x = 0;
        $!y = $!page.height - 2 * $!margin;
        # suppress whitespace before significant content
        $!pad = 0;
    }

    method !indent {
        10 * $!indent;
    }

    multi sub node2text(Pod::Block $_) { node2text(.contents) }
    multi sub node2text(@pod) { @pod.map(&node2text).join: ' ' }
    multi sub node2text(Str() $_) { .trim }
}

=NAME
Pod::To::PDF - Render Pod as PDF

=begin SYNOPSIS
From command line:

    $ raku --doc=PDF lib/to/class.rakumod >to-class.pdf

From Raku:
    =begin code :lang<raku>
    use Pod::To::PDF;

    =NAME
    foobar.pl

    =SYNOPSIS
        foobar.pl <options> files ...

    pod2pdf($=pod).save-as: "foobar.pdf";
    =end code
=end SYNOPSIS

=begin EXPORTS
    class Pod::To::PDF;
    sub pod2pdf; # See below
=end EXPORTS

=begin DESCRIPTION
This is a fully featured module for rendering POD to PDF.

The pdf2pdf() function returns a PDF::API6 object which can be further
manipulated, or saved to a PDF file.

    use PDF::API6;
    my PDF::API6 $pdf = pod2pdf($=pod);
    $pdf.save-as: "class.pdf"
                
The render() method returns a byte string which can be written to a
`latin-1` encoded file.

    "class.pdf".IO.spurt: Pod::To::PDF.render($=pod), :enc<latin-1>;

=end DESCRIPTION
