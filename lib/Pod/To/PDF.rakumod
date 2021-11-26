class Pod::To::PDF:ver<0.0.1> {

    use PDF::API6;
    use PDF::Tags;
    use PDF::Tags::Elem;
    use PDF::Content;
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
    has Pod::To::PDF::Style $.style handles<line-height font font-size leading bold invisible italic mono> .= new;
    has $!x;
    has $!y;
    has $.margin = 10;
    has $!collapse;
    has @.toc;

    submethod TWEAK {
        $!pdf.creator.push: "{self.^name}-{self.^ver}";
        self!new-page()
    }

    method render($class: $pod, |c) {
	pod2pdf($pod, :$class, |c);
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

    multi method pod2pdf(Pod::Block::Named $pod) {
        given $pod.name {
            when 'pod'  { $.pod2pdf($pod.contents)     }
            when 'para' {
                self!nest: {
                    $.pod2pdf: $pod.contents;
                }
            }
            when 'config' { }
            when 'nested' {
                self!nest: {
                    $!indent++;
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
        $.say;
        self!code: $pod.contents.join;
    }

    multi method pod2pdf(Pod::Heading $pod) {
        $.say;
        my Level $level = min($pod.level, 6);
        self!heading( node2text($pod.contents), :$level);
    }

    multi method pod2pdf(Pod::Block::Para $pod) {
        $.say;
        self!nest: {
            $*tag .= Paragraph;
            $.pod2pdf($pod.contents);
        }
        $.say;
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
                my $pad = 2;
                my $x2 = $!margin + $!x;
                my @bbox = [$x + $!margin, $!y, $!x + $!margin, $!y + $.font-size];
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
        $.say;
        self!nest: {
            $*tag .= ListItem;

            $*tag.Lbl.mark: self!gfx, {
                my constant BulletPoints = ("\c[BULLET]", "\c[WHITE BULLET]", '-');
                my Level $list-level = min($pod.level // 1, 3);
                my $bp = BulletPoints[$list-level - 1];
                .print: $bp, |self!text-position;
            }

            $*tag .= ListBody;
            $!collapse = True;
            $!indent++;
            $.pod2pdf($pod.contents);
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

        self!nest: {
            $*tag .= Section;

            self!heading($type.tclc ~ ' ' ~ $name, :$level);

            if $code {
                self!code($decl ~ ' ' ~ $code);
            }

            if $pod.contents {
                self!nest: {
                    $.say;
                    $*tag .= Paragraph;
                    $.pod2pdf($pod.contents);
                }
            }
        }

        $.say;
        $.say;
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

    multi method pod2pdf(List $pod) {
        for $pod.list {
            $.pod2pdf($_);
        };
    }

    multi method pod2pdf(Str $pod) {
        $.print($pod);
    }

    multi method pod2pdf($pod) is default {
        warn "fallback render of {$pod.WHAT.raku}";
        $.say: pod2text($pod);
    }

    multi method say {
        $!x = 0;
        $!y -= $.line-height
            unless $!collapse;
    }
    multi method say(Str $text, |c) {
        $.print($text, :nl, |c);
    }

    method print(Str $text, Bool :$nl, |c) {
        my $gfx = self!gfx;
        my $width = $!gfx.canvas.width - self!indent - $!margin - $!x;
        my $height = $!y - $!margin;
        
        $!collapse = False;
        my PDF::Content::Text::Box $tb .= new: :$text, :$width, :$height, :indent($!x), :$.leading, :$.font, :$.font-size, |c;
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
            my @bbox = $!x + $!margin, $!y + $tb.content-height, $!x + $!margin, $tb.content-width;
            @bbox[0] = $!margin if $lines > 1;
            $lines-- if $lines && !$nl;
            $!y -= $lines * $.line-height;
            if $lines {
                $!x = 0;
            }
            $!x += $tb.lines.tail.content-width + $tb.space-width
                unless $nl;
            @bbox;
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

    method !nest(&codez) {
        temp $!style .= clone;
        temp $!indent;
        temp $*tag;
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
        constant HeadingSizes = 20, 16, 13, 11.5, 10, 10; 
        $.say if $level <= 2;
        self!nest: {
            $*tag .= add-kid: :name('H' ~ $level);
            $.font-size = HeadingSizes[$level - 1];
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
        $.say;
        self!nest: {
            $.mono = True;
            $.font-size *= .8;
            $!indent++;
            $*tag .= Code;
            self!mark: {
                $.say($raw, :verbatim);
            }
        }
    }

    method !gfx {
        if $!y <= 2 * $!margin {
            self!new-page;
        }
        elsif $!x > 0 && $!x > $!gfx.canvas.width - self!indent - $!margin {
            $!collapse = False;
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
        $!collapse = True;
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
=begin code
use Pod::To::PDF;

=NAME
foobar.pl

=SYNOPSIS
    foobar.pl <options> files ...
	
say pod2pdf($=pod);
=end code
=end SYNOPSIS

=begin EXPORTS
    class Pod::To::PDF;
    sub pod2pdf; # See below
=end EXPORTS

=DESCRIPTION

