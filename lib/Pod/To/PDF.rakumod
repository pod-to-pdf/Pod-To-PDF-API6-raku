class Pod::To::PDF {

    use PDF::API6;
    use PDF::Tags;
    use PDF::Tags::Elem;
    use PDF::Content;
    use PDF::Content::Text::Box;
    use Pod::To::PDF::Style;
    use PDF::Page;
    has PDF::API6 $.pdf .= new;
    has PDF::Content $.gfx = self!new-page;
    has PDF::Tags $!tags .= create: :$!pdf;
    has PDF::Tags::Elem $.root is built = $!tags.Document;
    has UInt $!indent = 0;
    has Pod::To::PDF::Style $!style handles<line-height font font-size leading> .= new;
    has $!x;
    has $!y;
    has $.margin = 10;

    method render($class: $pod) {
	pod2pdf($pod, :$class);
    }

    sub pod2pdf($pod, :$class = $?CLASS) is export {
        my $obj = $class.new;
        my $*tag = $obj.root;
        $obj.pod2pdf($pod);
        $obj.pdf;
    }

    multi method pod2pdf(Pod::Block::Named $pod) {
        given $pod.name {
            when 'pod'  { $.pod2pdf($pod.contents)     }
            when 'para' {
                $.say;
                temp $*tag .= Paragraph;
                $.pod2pdf($_) for $pod.contents;
            }
            when 'config' { }
            when 'nested' { }
            default     {
                warn $pod.WHAT.raku;
                $.say($pod.name);
                $.pod2pdf($pod.contents)
            }
        }
    }

    multi method pod2pdf(Pod::Block::Code $pod) {
        $.say;
        $.say;
        temp $!style.mono = True;
        temp $!style.font-size *= .8;
        temp $!indent += 1;
        temp $*tag .= Code;
        self!mark: {
            # todo syntax hightlighting
            $.say($pod.contents.join, :verbatum);
        }
    }

    multi method pod2pdf(Pod::Heading $pod) {
        $.say;
        temp $!style.bold = True;
        temp $!indent += min($pod.level, 2);
        temp $*tag .= Header;
        $.pod2pdf($pod.contents);
    }

    multi method pod2pdf(Pod::Block::Para $pod) {
        $.say;
        temp $*tag .= Paragraph;
        $.pod2pdf($pod.contents);
    }

    multi method  pod2pdf(Pod::FormattingCode $pod) {
        given $pod.type {
            when 'I' {
                temp $!style.italic = True;
                $.pod2pdf($pod.contents);
            }
            when 'B' {
                temp $!style.bold = True;
                $.pod2pdf($pod.contents);
            }
            when 'Z' {
                temp $!style.invisible = True;
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
                    # see 14.8.4.4.2 Link Elements
                    $x = 0;
                }
                my $pad = 2;
                my $x2 = $!margin + $!x;
                my @bbox = [$x + $!margin, $!y, $!x + $!margin, $!y + $.font-size];
                given $pod.meta.head // $text -> $uri {
                    my $action = $!pdf.action: :$uri;
                    my PDF::Page $page = self!gfx.canvas;
                    my @rect = self!gfx.base-coords: |@bbox;
                    $!pdf.annotation(
                        :$page,
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
        $.print($pod.raku);
    }

    multi method say {
        $!x = 0;
        $!y -= $.line-height;
    }
    method !gfx {
        self!new-page if $!y <= 20;
        $!gfx;
    }
    multi method say(Str $text, |c) {
        $.print($text, :nl, |c);
    }
    method !mark(&action, |c) {
        given self!gfx {
            if .open-tags.first(*.mcid.defined) {
                # caller is already marking
                action();
            }
            else {
                $*tag.mark: $_, &action, |c;
            }
        }
    }
    method print(Str $text, Bool :$nl, |c) {
        my $width = $!gfx.canvas.width - self!indent - $!margin;
        my $height = $!y - $!margin;
        my @bbox;
        self!new-page if $width <= 0 || $height <= 0;
        my PDF::Content::Text::Box $tb .= new: :$text, :$width, :$height, :indent($!x), :$.leading, :$.font, :$.font-size, |c;
        unless $!style.invisible {
            self!mark: {
                self!gfx.print($tb, :position[$!margin + self!indent, $!y], :$nl)
            }
        }
        my $lines = +$tb.lines;
        $lines-- if $lines && !$nl;
        $!x = $nl ?? 0 !! $tb.lines.tail.content-width + $tb.space-width;
        $!y -= $lines * $.line-height;
        if $tb.overflow {
            $.say() unless $nl;
            $.print: $tb.overflow.join;
        }
    }

    method !new-page {
        $!x = 0;
        $!y = 720;
        my $page = $!pdf.add-page;
        $!gfx = $page.gfx;
    }

    method !indent {
        10 * $!indent;
    }
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

