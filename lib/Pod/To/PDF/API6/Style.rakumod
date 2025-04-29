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
has UInt $.lines-before = $!style.page-break-after eq 'auto' ?? 1 !! 3;
has PDF::Action $.link;
has PDF::Content::FontObj $.font;

submethod TWEAK {
}
method leading { 1.1 }
method line-height {
    $.leading * $!font-size;
}
constant %CoreFont = %(
    # Normal Fonts           # Mono Fonts
    :___<times>,             :__M<courier>,
    :B__<times-bold>,        :B_M<courier-bold>,
    :_I_<times-italic>,      :_IM<courier-oblique>,
    :BI_<times-bolditalic>,  :BIM<courier-boldoblique>
);
my subset FontKey of Str where %CoreFont{$_}:exists;
method font-key {
    (
        ($!bold   ?? 'B' !! '_'),
        ($!italic ?? 'I' !! '_'),
        ($!mono   ?? 'M' !! '_'),
    ).join;
}

method font(:%font-map) {
    $!font //= do {
        my FontKey:D $key = self.font-key;
        %font-map{$key} // do {
            my Str:D $font-name = %CoreFont{$key};
            PDF::Content::Font::CoreFont.load-font($font-name);
        }
    }
}
