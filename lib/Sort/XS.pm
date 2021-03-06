package Sort::XS;
use strict;
use warnings;
use base Exporter::;
our @EXPORT = qw(xsort ixsort sxsort);

our $VERSION = '0.20';
require XSLoader;
XSLoader::load( 'Sort::XS', $VERSION );
use Carp qw/croak/;

use constant ERR_MSG_NOLIST           => 'Need to provide a list';
use constant ERR_MSG_UNKNOWN_ALGO     => 'Unknown algorithm : ';
use constant ERR_MSG_NUMBER_ARGUMENTS => 'Bad number of arguments';
my $_mapping = {
    quick     => \&Sort::XS::quick_sort,
    heap      => \&Sort::XS::heap_sort,
    merge     => \&Sort::XS::merge_sort,
    insertion => \&Sort::XS::insertion_sort,
    perl      => \&_perl_sort,

    # string sorting
    quick_str     => \&Sort::XS::quick_sort_str,
    heap_str      => \&Sort::XS::heap_sort_str,
    merge_str     => \&Sort::XS::merge_sort_str,
    insertion_str => \&Sort::XS::insertion_sort_str,
    perl_str      => \&_perl_sort_str,
};

# API to call XS subs

sub xsort {

    # shortcut to speedup API usage, we first advantage preferred usage
    # ( we could avoid it... but we want to provide an api as fast as possible )
    my $argc = scalar @_;
    if ( $argc == 1 ) {
        croak ERR_MSG_NOLIST unless ref $_[0] eq ref [];
        return Sort::XS::quick_sort( $_[0] );
    }

    # default parameters
    my %params;
    $params{algorithm} = 'quick';

    # default list
    $params{list} = $_[0];

    croak ERR_MSG_NOLIST unless $params{list};
    my %args;
    unless ( ref $params{list} eq ref [] ) {

        # hash input
        croak ERR_MSG_NUMBER_ARGUMENTS if $argc % 2;
        (%args) = @_;
        croak ERR_MSG_NOLIST
          unless defined $args{list} && ref $args{list} eq ref [];
        $params{list} = $args{list};
    }
    else {

        # first element was the array, then hash option
        croak ERR_MSG_NUMBER_ARGUMENTS unless scalar @_ % 2;
        my $void;
        ( $void, %args ) = @_;
    }
    map { $params{$_} = $args{$_} || $params{$_}; } qw/algorithm type/;

    my $type =
      ( defined $params{type} && $params{type} eq 'string' ) ? '_str' : '';
    my $sub = $_mapping->{ $params{algorithm} . $type };
    croak( ERR_MSG_UNKNOWN_ALGO, $params{algorithm} ) unless defined $sub;

    return $sub->( $params{list} );
}

# shortcut to xsort with integers
sub ixsort {
    xsort(@_);
}

# shortcut to xsort with strings
sub sxsort {
    xsort( @_, type => 'string' );
}

sub _perl_sort {
    my $list = shift;
    my @sorted = sort { $a <=> $b } @{$list};
    return \@sorted;
}

sub _perl_sort_str {
    my $list = shift;
    my @sorted = sort { $a cmp $b } @{$list};
    return \@sorted;
}

1;

__END__

=head1 NAME

Sort::XS - a ( very ) fast XS sort alternative for one dimension list

=head1 SYNOPSIS

  use Sort::XS qw/xsort/;

  # use it simply
  my $sorted = xsort([1, 5, 3]);
  $sorted = [ 1, 3, 5 ];
  
  # personalize your xsort with some options
  my $list = [ 1..100, 24..42 ]
  my $sorted = xsort( $list ) or ixsort( $list )
            or xsort( list => $list )
            or xsort( list => $list, algorithm => 'quick' )
            or xsort( $list, algorithm => 'quick', type => integer )
            or xsort( list => $list, algorithm => 'heap', type => 'integer' ) 
            or xsort( list => $list, algorithm => 'merge', type => 'string' );
   
   # if you [ mainly ] use very small arrays ( ~ 10 rows ) 
   #    prefer using directly one of the XS subroutines
   $sorted = Sort::XS::quick_sort( $list )
        or Sort::XS::heap_sort($list)
        or Sort::XS::merge_sort($list)
        or Sort::XS::insertion_sort($list);
    
    # sorting array of strings
    $list = [ 'kiwi', 'banana', 'apple', 'cherry' ];
    $sorted = sxsort( $list )
        or sxsort( [ $list ], algorithm => 'quick' )
        or sxsort( [ $list ], algorithm => 'heap' )
        or sxsort( [ $list ], algorithm => 'merge' );
    
    # use direct XS subroutines to sort array of strings 
    $sorted = Sort::XS::quick_sort_str( $list )
        or Sort::XS::heap_sort_str($list)
        or Sort::XS::merge_sort_str($list)
        or Sort::XS::insertion_sort_str($list);
            
    
=head1 DESCRIPTION

This module provides several common sort algorithms implemented as XS.
Sort can only be used on one dimension list of integers or strings.

It's goal is not to replace the internal sort subroutines, but to provide a better alternative in some specifics cases :

=over 2

=item - no need to specify a comparison operator

=item - sorting a mono dimension list

=back


=head1 ALGORITHMS

Quicksort has been chosen as the default method ( even if it s not a stable algorithm ), you can also consider to use heapsort which provides a worst case in "n log n".

Choosing the correct algorithm depends on distribution of your values and size of your list.
Quicksort provides an average good solution, even if in some case it will be better to use a different choice.

=head2 quick sort

This is the default algorithm. 
In pratice it provides the best results even if in worst case heap sort will be a better choice.

read http://en.wikipedia.org/wiki/Quicksort for more informations

=head2 heap sort

A little slower in practice than quicksort but provide a better worst case runtime.

read http://en.wikipedia.org/wiki/Heapsort for more informations

=head2 merge sort

Stable sort algorithm, that means that in any case the time to compute the result will be similar.
It's still a better choice than the internal perl sort.

read http://en.wikipedia.org/wiki/Mergesort for more informations

=head2 insertion sort

Provide one implementation of insertion sort, but prefer using either any of the previous algorithm or even the perl internal sort.

read http://en.wikipedia.org/wiki/Mergesort for more informations

=head2 perl

this is not an algorithm by itself, but provides an easy way to disable all XS code by switching back to a regular sort.

Perl 5.6 and earlier used a quicksort algorithm to implement sort. 
That algorithm was not stable, so could go quadratic. (A stable sort preserves the input order of elements that compare equal. 
Although quicksort's run time is O(NlogN) when averaged over all arrays of length N, the time can be O(N**2), 
quadratic behavior, for some inputs.) 

In 5.7, the quicksort implementation was replaced with a stable mergesort algorithm whose worst-case behavior is O(NlogN). 
But benchmarks indicated that for some inputs, on some platforms, the original quicksort was faster. 

5.8 has a sort pragma for limited control of the sort. Its rather blunt control of the underlying algorithm may not persist into future Perls, 
but the ability to characterize the input or output in implementation independent ways quite probably will.

use default perl version

=head1 METHODS

=head2 xsort

API that allow you to use one of the XS subroutines. Prefer using this method. ( view optimization section for tricks )

=over 4

=item list

provide a reference to an array
if only one argument is provided can be ommit

    my $list = [ 1, 3, 2, 5, 4 ];
    xsort( $list ) or xsort( list => $list )

=item algorithm [ optional, default = quick ]

default value is quick
you can use any of the following choices

    quick # quicksort
    heap  # heapsort
    merge
    insertion # not recommended ( slow )
    perl # use standard perl sort method instead of c implementation

=item type [ optional, default = integer ]

You can specify which kind of sort you are expecting ( i.e. '<=>' or 'cmp' ) by setting this attribute to one of these two values

    integer # <=>, is the default operator if not specified
    string  # cmp, do the compare on string

=back

=head2 ixsort

alias on xsort method but force type to integer comparison
same usage as xsort

=head2 sxsort

alias on xsort method but force type to string comparison
same usage as xsort

=head2  quick_sort   

XS subroutine to perform the quicksort algorithm. No type checking performed.
Accept only one single argument as input.

    my $list = [1, 6, 4, 2, 3, 5 ]
    Sort::XS::quick_sort($list);
    
=head2  heap_sort

XS subroutine to perform the heapsort algorithm. No type checking performed.
Accept only one single argument as input.    

    my $list = [1, 6, 4, 2, 3, 5 ]
    Sort::XS::heap_sort($list);
    
=head2  merge_sort

XS subroutine to perform the mergesort algorithm. No type checking performed.
Accept only one single argument as input.    
    
    my $list = [1, 6, 4, 2, 3, 5 ]
    Sort::XS::merge_sort($list)
    
=head2  insertion_sort    

XS subroutine to perform the insertionsort algorithm. No type checking performed.
Accept only one single argument as input.    

    my $list = [1, 6, 4, 2, 3, 5 ]
    Sort::XS::insertion_sort($list);

=head2 quick_sort_str

XS subroutine to perform quicksort on array of strings.

    Sort::XS::quick_sort_str( [ 'aa' .. 'zz' ] );
    
=head2 heap_sort_str

XS subroutine to perform heapsort on array of strings.

    Sort::XS::heap_sort_str( [ 'aa' .. 'zz' ] );

=head2 merge_sort_str

XS subroutine to perform mergesort on array of strings.

    Sort::XS::merge_sort_str( [ 'aa' .. 'zz' ] );

=head2 insertion_sort_str

XS subroutine to perform insertionsort on array of strings.

    Sort::XS::insertion_sort_str( [ 'aa' .. 'zz' ] );

=head1 OPTIMIZATION

xsort provides an api to call xs subroutines to easy change sort preferences and an easy way to use it ( adding minimalist type checking )
as it provides an extra layer on the top of xs subroutines it has a cost... and adds a little more slowness...
This extra cost cannot be noticed on large arrays ( > 100 rows ), but for very small arrays ( ~ 10 rows ) it will not a good idea to use the api ( at least at this stage ). 
In this case you will prefer to do a direct call to one of the XS methods to have pure performance.

Note that all the XS subroutines are not exported by default. 

    my $list = [1, 6, 4, 2, 3, 5 ]
    Sort::XS::quick_sort($list);
    Sort::XS::heap_sort($list);
    Sort::XS::merge_sort($list)
    Sort::XS::insertion_sort($list);

Once again, if you use large arrays, it will be better to use API calls :

    xsort([5, 7, 1, 4]);
    ixsort([1..10]);
    sxsort(['a'..'z']);

=head1 BENCHMARK

Here is a glance of what you can expect from this module :
These results have been computed on a set of multiple random arrays generated by the benchmark test included in the dist testsuite.

Results are splitted in two parts : integers and strings.
Here is a short definition for each label used for these benchmarks.

    [ integers ]
    * Perl                  : reference test with perl internal sort sub : sort { $a <=> $b } @array;
    * API Perl              : use native sort perl method thru API ; xsort(list => $array, algorithm => 'perl');      
    * API quick             : use quicksort via API ; xsort($array);         
    * API quick with hash   : use xsort method with additonnal parameters ; xsort(list => $array, algorithm => 'quick', type => 'integer');
    * ikeysort              : use ikeysort method from Key::Sort module ; ikeysort { $_ } @$array; 
    * XS heap               : direct call to the xs method ; Sort::XS::heap_sort($array);
    * XS merge              : direct call to the xs method ; Sort::XS::merge_sort($array);       
    * XS quick              : direct call to the xs method ; Sort::XS::quick_sort($array);
    * void                  : a void sub used as baseline

Comparing "Perl" vs "API Perl" or "API quick" vs "XS quick" gives an idea of the extra cost of the API
Perl and void bench are here as a baseline.
    
    [ strings ]
    * Perl          : native perl sort method : sort { $a cmp $b } @array;
    * API sxsort    : use sxsort method ; sxsort($array);    
    * keysort       : use keysort method from Key::Sort module ; keysort { $_ } @$array; 
    * XS heap       : direct call to the xs method ; Sort::XS::heap_sort_str($array);
    * XS merge      : direct call to the xs method ; Sort::XS::merge_sort_str($array);
    * XS quick      : direct call to the xs method ; Sort::XS::quick_sort_str($array);
    
=head2 Small arrays

Small arrays are arrays with around 10 elements.
benchmark with 1000 arrays of 10 rows

        [ integers ]         Rate       API quick with hash       API Perl       ikeysort    API quick          XS merge       Perl    XS heap       XS quick void
        API quick with hash 136/s                        --            -4%           -38%            -66%           -73%       -76%       -77%           -77% -81%
        API Perl            142/s                        5%             --           -35%            -64%           -72%       -75%       -76%           -76% -80%
        ikeysort            220/s                       62%            55%             --            -44%           -57%       -62%       -62%           -63% -69%
        API quick           394/s                      190%           177%            79%              --           -22%       -31%       -32%           -33% -44%
        XS merge            507/s                      273%           256%           130%             28%             --       -12%       -13%           -14% -28%
        Perl                575/s                      323%           304%           161%             46%            13%         --        -1%            -3% -18%
        heap                581/s                      328%           309%           164%             47%            15%         1%         --            -2% -17%
        XS quick            592/s                      336%           316%           169%             50%            17%         3%         2%             -- -16%
        void                701/s                      416%           393%           219%             78%            38%        22%        21%            18%   --

        
         [ sting ]  Rate       API sxsort       keysort       Perl       XS merge       XS heap       XS quick
        API sxsort 106/s               --           -8%       -59%           -59%          -62%           -63%
        keysort    116/s               9%            --       -55%           -55%          -58%           -60%
        Perl       260/s             145%          124%         --            -0%           -7%           -10%
        XS merge   260/s             145%          124%         0%             --           -7%           -10%
        XS heap    278/s             162%          140%         7%             7%            --            -4%
        XS quick   289/s             172%          149%        11%            11%            4%             --

=head2 Medium arrays

A mixed of arrays with 10, 100 and 1000 rows. ( 10 arrays of each size, maybe this should match most common usages ? ).

        [ integers ]          Rate       ikeysort       API Perl    Perl XS          merge       heap       API quick with hash       API quick       XS quick void
        ikeysort             224/s             --           -49%       -53%           -57%       -61%                      -63%            -66%           -67% -85%
        API Perl             439/s            96%             --        -7%           -16%       -24%                      -27%            -34%           -34% -70%
        Perl                 475/s           112%             8%         --            -9%       -18%                      -21%            -29%           -29% -68%
        XS merge             523/s           133%            19%        10%             --       -10%                      -13%            -22%           -22% -65%
        heap                 580/s           158%            32%        22%            11%         --                       -4%            -13%           -14% -61%
        API quick with hash  602/s           168%            37%        27%            15%         4%                        --            -10%           -10% -59%
        API quick            669/s           198%            52%        41%            28%        16%                       11%              --            -0% -55%
        XS quick             670/s           199%            53%        41%            28%        16%                       11%              0%             -- -55%
        void                1477/s           558%           236%       211%           182%       155%                      145%            121%           120%   --
        
        [ sting ]    Rate       keysort       API sxsort       Perl       XS heap       XS merge       XS quick
        keysort     770/s            --             -47%       -48%          -57%           -57%           -62%
        API sxsort 1450/s           88%               --        -2%          -19%           -20%           -28%
        Perl       1476/s           92%               2%         --          -18%           -18%           -27%
        XS heap    1790/s          132%              23%        21%            --            -1%           -11%
        XS merge   1806/s          135%              25%        22%            1%             --           -10%
        XS quick   2017/s          162%              39%        37%           13%            12%             --

=head2 Large arrays

A set of 10 random arrays of 100.000 rows.

        [ integers ]          Rate       ikeysort       Perl       API Perl       XS merge    XS heap       XS quick       API quick with hash       API quick void
        ikeysort            1.94/s             --       -35%           -36%           -53%       -56%           -66%                      -66%            -66% -89%
        Perl                2.99/s            54%         --            -2%           -27%       -32%           -47%                      -47%            -47% -82%
        API Perl            3.04/s            57%         2%             --           -26%       -30%           -46%                      -46%            -47% -82%
        XS merge            4.13/s           113%        38%            36%             --        -6%           -27%                      -27%            -27% -76%
        heap                4.37/s           126%        46%            44%             6%         --           -22%                      -23%            -23% -74%
        XS quick            5.62/s           190%        88%            85%            36%        28%             --                       -1%             -1% -67%
        API quick with hash 5.65/s           192%        89%            86%            37%        29%             1%                        --             -1% -66%
        API quick           5.69/s           193%        90%            87%            38%        30%             1%                        1%              -- -66%
        void                16.9/s           770%       463%           454%           309%       286%           200%                      198%            197%   --
        
        [ sting ]     Rate       keysort       Perl       XS heap       XS merge       XS quick       API sxsort
        keysort    0.683/s            --       -39%          -54%           -64%           -67%             -67%
        Perl        1.12/s           64%         --          -25%           -40%           -45%             -46%
        XS heap     1.49/s          118%        33%            --           -21%           -27%             -28%
        XS merge    1.88/s          175%        68%           26%             --            -8%              -9%
        XS quick    2.04/s          199%        82%           37%             9%             --              -1%
        API sxsort  2.06/s          201%        84%           39%            10%             1%               --


=head1 CONTRIBUTE

You can contribute to this project via GitHub :
    https://github.com/atoomic/Sort-XS

=head1 TODO

Implementation of float comparison...
At this time only implement sort of integers and strings

Improve API performance for small set of arrays : could use enum and array to speedup API.
C algorithms can be also tuned.

=head1 AUTHOR

Nicolas R., E<lt>me@eboxr.comE<gt>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by eboxr.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
