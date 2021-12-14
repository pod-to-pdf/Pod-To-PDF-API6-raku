use Pod::Load;
use Pod::To::PDF;
use PDF;

sub MAIN(
    Str $file = '-',         #= input Pod file
    Str $out-file = '-',     #= output PDF file
    Bool :$contents = True,  #= build table of contents
    UInt :$margin = 20,      #= margin size (points)
    Str  :$title,            #= title for the document
    Str  :$lang = 'en',      #= language code (default 'en')
    Str  :class($class-name) = 'Pod::To::PDF', # Pod rendering class
) {
    require ::($class-name);
    my $class = ::($class-name);
    my IO() $src = $file eq '-' ?? $*IN !! $file;
    my $pod = load($file);
    my PDF $pdf = pod2pdf($pod, :$class, :$contents, :$margin, :$title, :$lang);
    if $out-file eq '-' {
        $*OUT.write: $pdf.Blob;
    }
    else {
        $pdf.save-as: $out-file;
    }
}

=begin pod

=head1 NAME

pod2pdf.raku

=head1 SYNOPSIS

    pod2pdf my-class.pod > myclass.pdf

=head2 Options

    --/contents     disable table-of-contents
    --margin=n      set margin-size (points)
    --title=str     set a title (can also be set via =TITLE)
    --save-as=file  save PDF file; don't pipe to stdout
    --class=name    rendering class (default Pod::To::PDF)

=head2 DESCRIPTION

This is an experimental module to render code and documents that contain Raku
Pod6 to PDF.

It uses the Raku PDF::API6 module.

=end pod
