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

    if +@batches == 1 {
        # avoid creating sub-trees
         @results[0] = self.read-batch: @pod, $.pdf.Pages, |c;
    }
    else {
        @results = @batches.hyper(:batch(1)).map: {
            self.read-batch: |$_, |c;
        }
        $.pdf.add-pages(.[1]) for @batches;
    }

    $.merge-batch($_) for @results;
    
}

