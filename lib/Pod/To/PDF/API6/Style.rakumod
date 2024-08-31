#| Basic core-font styler
unit class Pod::To::PDF::API6::Style;

use PDF::Content::Font::CoreFont;
use PDF::Content::FontObj;
use PDF::Action;
use CSS::Properties;

has CSS::Properties $.style .= new;
has Numeric $.font-size = $!style.measure(:font-size);
has Bool $.bold      = $!style.measure(:font-weight) >= 600;
has Bool $.italic    = $!style.font-style eq 'italic';
has Bool $.underline = $!style.text-decoration eq 'underline';
has Bool $.mono      = $!style.font-family ~~ 'monospace';
has Bool $.verbatim  = $!style.white-space eq 'pre';
has UInt $.lines-before = $!style.page-break-after eq 'avoid' ?? 3 !! 1;
has PDF::Action $.link;
has PDF::Content::FontObj $.font;

submethod TWEAK {
}
method leading { 1.1 }
method line-height {
    $.leading * $!font-size;
}
constant %CoreFont = %(
    # Normal Fonts              # Mono Fonts
    :n-n-n<times>,             :n-n-M<courier>,  
    :B-n-n<times-bold>,        :B-n-M<courier-bold>,
    :n-I-n<times-italic>,      :n-I-M<courier-oblique>,
    :B-I-n<times-bolditalic>,  :B-I-M<courier-boldoblique>
);
my subset FontKey of Str where %CoreFont{$_}:exists;
method font-key {
    join(
        '-', 
        ($!bold ?? 'B' !! 'n'),
        ($!italic ?? 'I' !! 'n'),
        ($!mono ?? 'M' !! 'n'),
    );
}

method clone { warn %_.raku; nextwith :font(PDF::Content::FontObj), |%_; }

method font(:%font-map) {
    $!font //= do {
        my FontKey:D $key = self.font-key;
        %font-map{$key} // do {
            my Str:D $font-name = %CoreFont{$key};
            PDF::Content::Font::CoreFont.load-font($font-name);
        }
    }
}
