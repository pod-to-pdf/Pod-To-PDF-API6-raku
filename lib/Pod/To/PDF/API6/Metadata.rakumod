unit role Pod::To::PDF::API6::Metadata;

my subset Level is export(:Level) of Int:D  where 0..6;

has @.toc; # table of contents

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
