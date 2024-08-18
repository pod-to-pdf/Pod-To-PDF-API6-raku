unit role Pod::To::PDF::API6::Podish;

my subset Level is export(:Level) of Int:D  where 0..6;
my subset PodMetaType of Str where 'title'|'subtitle'|'author'|'name'|'version';


has @.toc; # table of contents
has Str %!metadata;

method add-toc-entry(Hash $entry, @kids = @!toc, Level :$level!, Level :$cur = 1, ) {
    if $cur >= $level {
        @kids.push: $entry;
    }
    else {
        # descend
        @kids.push: { :Title(' '), } unless @kids;
        @kids.tail<kids> //= [];
        self.add-toc-entry($entry, :$level, :cur($cur+1), @kids.tail<kids>);
    }
}

method add-terms(%index, :$level is copy = 1) {
    $level++;

    for %index.sort(*.key.uc) {
        my $term = .key;
        my %kids = .value;
        my Hash @refs = .List with %kids<#refs>:delete;
        @refs[0] //= %( );
        for @refs {
            my %toci = %$_;
            %toci<Title> = $term;
            self.add-toc-entry: %toci, :$level;
            $term = ' ';
        }

        self.add-terms(%kids, :$level) if %kids;
    }
}

method !build-metadata-title {
    my @title = $_ with %!metadata<title>;
    with %!metadata<name> {
        @title.push: '-' if @title;
        @title.push: $_;
    }
    @title.push: 'v' ~ $_ with %!metadata<version>;
    @title.join: ' ';
}

method set-metadata(PodMetaType $key, $value) {

    %!metadata{$key.lc} = $value;

    my Str:D $pdf-key = do given $key {
        when 'title'|'version'|'name' { 'Title' }
        when 'subtitle' { 'Subject' }
        when 'author' { 'Author' }
    }

    my $pdf-value = $pdf-key eq 'Title'
        ?? self!build-metadata-title()
        !! $value;

    $pdf-key => $pdf-value;
}

multi method metadata { %!metadata }
multi method metadata(PodMetaType $t) is rw {
    Proxy.new(
        FETCH => { %!metadata{$t} },
        STORE => -> $, Str:D() $v {
            self.set-metadata($t, $v);
        }
    )
}

