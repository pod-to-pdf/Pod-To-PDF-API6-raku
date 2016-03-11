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

class Pod::To::PDF {

    use Pod::TreeWalker;
    use Pod::TreeWalker::Listener;
    use PDF::Content::Doc;

    class Listener does Pod::TreeWalker::Listener {
	has $.pdf;
	has @.events;

	multi method start (Pod::Block::Code $node) {
	    @.events.push( { :start, :type('code') :allowed($node.allowed) } );
	    return True;
	}
	multi method end (Pod::Block::Code $node) {
	    @.events.push( { :end, :type('code'), :allowed($node.allowed) } );
	}

	multi method start (Pod::Block::Comment $node) {
	    @.events.push( { :start, :type('comment') } );
	    return True;
	}
	multi method end (Pod::Block::Comment $node) {
	    @.events.push( { :end, :type('comment') } );
	}

	multi method start (Pod::Block::Declarator $node) {
	    @.events.push( { :start, :type('declarator'), :wherefore($node.WHEREFORE) } );
	    return True;
	}
	multi method end (Pod::Block::Declarator $node) {
	    @.events.push( { :end, :type('declarator'), :wherefore($node.WHEREFORE) } );
	}

	multi method start (Pod::Block::Named $node) {
	    @.events.push( { :start, :type('named'), :name($node.name) } );
	    return True;
	}
	multi method end (Pod::Block::Named $node) {
	    @.events.push( { :end, :type('named'), :name($node.name) } );
	}

	multi method start (Pod::Block::Para $node) {
	    @.events.push( { :start, :type('para') } );
	    return True;
	}
	multi method end (Pod::Block::Para $node) {
	    @.events.push( { :end, :type('para') } );
	}

	multi method start (Pod::Block::Table $node) {
	    my @h = $node.headers.map({ .contents[0].contents[0] });
	    @.events.push(
		{
		    :start,
		    :type('table'),
		    :caption( $node.caption ),
		    :headers(@h),
		}
	    );
	    return True;
	}
	method table-row (Array $row) {
	    my @r = $row.map({ .contents[0].contents[0] });
	    @.events.push( { :table-row(@r) } );
	}
	multi method end (Pod::Block::Table $node) {
	    @.events.push( { :end, :type('table') } );
	}

	multi method start (Pod::FormattingCode $node) {
	    @.events.push( { :start, :type('formatting-code'), :code-type($node.type), :meta($node.meta) } );
	    return True;
	}
	multi method end (Pod::FormattingCode $node) {
	    @.events.push( { :end, :type('formatting-code'), :code-type($node.type), :meta($node.meta) } );
	}

	multi method start (Pod::Heading $node) {
	    @.events.push( { :start, :type('heading'), :level($node.level) } );
	    return True;
	}
	multi method end (Pod::Heading $node) {
	    @.events.push( { :end, :type('heading'), :level($node.level) } );
	}

	method start-list (Int :$level, Bool :$numbered) {
	    @.events.push( { :start, :type('list'), :level($level), :numbered($numbered) } );
	}
	method end-list (Int :$level, Bool :$numbered) {
	    @.events.push( { :end, :type('list'), :level($level), :numbered($numbered) } );
	}

	multi method start (Pod::Item $node) {
	    @.events.push( { :start, :type('item'), :level($node.level) } );
	    return True;
	}
	multi method end (Pod::Item $node) {
	    @.events.push( { :end, :type('item'), :level($node.level) } );
	}

	multi method start (Pod::Raw $node) {
	    @.events.push( { :start, :type('raw'), :target($node.target) } );
	    return True;
	}
	multi method end (Pod::Raw $node) {
	    @.events.push( { :end, :type('raw'), :target($node.target) } );
	}

	method config (Pod::Config $node) {
	    @.events.push( { :config-type($node.type), :config($node.config) } );
	}

	method text (Str $text) {
	    my $gfx = $.pdf.page[0].gfx;
	    my $block = $gfx.print($text, :width(500), :stage);
	    @.events.push( { :$text, :$block } );
	}
    }

    has $.pdf = PDF::Content::Doc.new;
    has Listener $.listener .= new: :$!pdf;
    
    has UInt $!indent = 0;
    has Bool $!in-code-block = False;

    sub pod2pdf(|c) is export {
	$?CLASS.render(|c)
    }
    method render(|c) {
	my $obj = self.defined ?? self !! self.new;
	$obj.pod2pdf(|c);
    }
    method pod2pdf($pod) {
	Pod::TreeWalker.new( :$.listener ).walk-pod( $pod );
	warn :events( $.listener.events ).perl;
	self!publish( $.listener.events );
	~ $.pdf;
    }
    method !publish( @events ) {
	my $page = $.pdf.page[0];
	my $gfx = $page.gfx;
	$gfx.text: -> $_ {
	    .text-position = [10, 600];
	    for @events.grep( *.<block> ) {
		$gfx.say: .<block>;
		$gfx.say: '';
	    }
	}
    }

}
