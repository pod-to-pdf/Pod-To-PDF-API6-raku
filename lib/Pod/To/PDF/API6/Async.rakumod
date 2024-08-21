#| multi-threaded rendering mode
unit class Pod::To::PDF::API6::Async;

use Pod::To::PDF::API6;
also is Pod::To::PDF::API6;

use Pod::To::PDF::API6::Async::Scheduler;
use PDF::Content::PageTree;
use PDF::Tags;

method read(@pod, |c) {

    my List @batches = Pod::To::PDF::API6::Async::Scheduler.divvy(@pod).map: -> $pod {
        ($pod, PDF::Content::PageTree.pages-fragment, $.tags.fragment);
    }
    my @results;
    my Lock $lock .= new;

    if +@batches == 1 {
        # avoid creating sub-trees
         @results[0] = self.read-batch: @pod, $.pdf.Pages, |c;
    }
    else {
        @batches.pairs.race(:batch(1)).map: {
            my $result = self.read-batch: |.value, |c;
            $lock.protect: { @results[.key] = $result };
        }
        $.pdf.add-pages(.[1]) for @batches;
    }

    $.merge-batch($_) for @results;
    
}

