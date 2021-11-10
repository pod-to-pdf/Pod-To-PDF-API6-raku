class Pod::To::PDF {

    use PDF::API6;
    use PDF::Tags;
    use PDF::Tags::Elem;
    use PDF::Content;

    has PDF::API6 $.pdf .= new;
    has PDF::Content $.gfx = self!new-page;
    has PDF::Tags $!tags .= create: :$!pdf;
    has PDF::Tags::Elem $.root is built = $!tags.Document;
    has UInt $!indent = 0;
    has $!y;

    sub pod2pdf($pod, :$class = $?CLASS) is export {
        my $obj = $class.new;
        my $*elem = $obj.root;
        $obj.pod2pdf($pod);
        $obj.pdf;
    }

    method render($class: $pod) {
	$.pod2pdf($pod, :$class);
    }

    multi method pod2pdf(Pod::Block::Named $pod) {
        given $pod.name {
            when 'pod'  { $.pod2pdf($pod.contents)     }
            when 'para' {
                $.say;
                temp $*elem = $*elem.Paragraph: $!gfx, {
                    $.pod2pdf($_) for $pod.contents;
                }
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
        temp $*elem = $*elem.Code: $!gfx, {
            my @lines = $pod.contents.join.lines;
             $.pod2pdf(@lines);
        }
    }

    multi method pod2pdf(Pod::Heading $pod) {
        $!indent += min($pod.level, 2);
        temp $*elem = $*elem.Header: $!gfx, {
            $.pod2pdf($pod.contents);
        }
    }

    multi method pod2pdf(Pod::Block::Para $pod) {
        $.say;
        temp $*elem = $*elem.Paragraph: $!gfx, {
            $.pod2pdf($pod.contents);
        }
    }

    multi method pod2pdf(List $pod) {
        for $pod.list {
            $.pod2pdf($_);
        };
    }

    multi method pod2pdf(Str $pod) {
        $.say($pod);
    }

    multi method pod2pdf($pod) is default {
        warn "fallback render of {$pod.WHAT.raku}";
        $.say($pod.raku);
    }

    multi method say {
        $!y -= 20;
    }
    multi method say(Str $text) {
        self!new-page if $!y <= 20;
        my $width = $!gfx.canvas.width - self!indent - 10;
        my @p = $!gfx.say($text, :position[:left(10 + self!indent), :top($!y)], :$width);
        $!y = @p[1] - 15;
    }

    method !new-page {
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

