class Pod::To::PDF {

    use PDF::API6;
    use PDF::Content;

    has PDF::API6 $.pdf .= new;
    has PDF::Content $.gfx = self!new-page;
    has UInt $!indent = 0;
    has $!y;

    sub pod2pdf($pod, :$class = $?CLASS) is export {
        my $obj = $class.new;
        $obj.pod2pdf($pod);
        $obj.pdf;
    }

    method render($pod) {
	$.pod2pdf($pod, :class(self));
    }

    multi method pod2pdf(Pod::Block::Named $pod) {
        given $pod.name {
            when 'pod'  { $.pod2pdf($pod.contents)     }
            when 'para' { $.say; $.pod2pdf($pod.contents[0]) }
            when 'config' { }
            when 'nested' { }
            default     {
                $.say($pod.name);
                $.pod2pdf($pod.contents)
            }
        }
    }

    multi method pod2pdf(Pod::Heading $pod) {
        $!indent += min($pod.level, 2);
        $.pod2pdf($pod.contents);
    }

    multi method pod2pdf(Pod::Block::Para $pod) {
        $.say;
        $.pod2pdf($pod.contents);
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
        warn "fallback render of {$pod.WHAT}";
        $.say($pod.perl);
    }

    method say(Str $text = '') {
        self!new-page if $!y <= 20;
        $!gfx.say(self!indent() ~ $text, :position[10, $!y]);
        $!y -= 10;
    }

    method !new-page {
        $!y = 720;
        $!gfx = $!pdf.add-page.gfx;
    }

    method !indent {
        constant nbsp = "\c[NO-BREAK SPACE]";
        nbsp x (2 * $!indent);
    }
}

=NAME
Pod::To::PDF - Render Pod as PDF

=begin SYNOPSIS
From command line:

    $ perl6 --doc=PDF lib/to/class.pm >to-class.pdf

From Perl6:
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

