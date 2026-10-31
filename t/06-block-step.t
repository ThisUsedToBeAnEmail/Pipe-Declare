#!perl
use 5.014;
use strict;
use warnings;
use Test::More;
use Pipe::Declare;

# Milestone 4: block steps map / grep / tap.
#
# Lowering:  |> map  { B } -> Pipe::Declare::_map (sub { B }, $topic)
#            |> grep { B } -> Pipe::Declare::_grep(sub { B }, $topic)
#            |> tap  { B } -> Pipe::Declare::_tap (sub { B }, $topic)
#
# map/grep treat the topic as an arrayref and yield a fresh arrayref;
# tap aliases $_ to the topic inside B and yields the topic unchanged.

# --- map ------------------------------------------------------------------

{
    my $r = pipe { [1, 2, 3, 4] |> map { $_ * 2 } };
    is_deeply( $r, [2, 4, 6, 8], 'map { $_ * 2 } doubles every element' );
}

{
    my $r = pipe { [qw/a b c/] |> map { uc $_ } };
    is_deeply( $r, [qw/A B C/], 'map { uc $_ } uppercases' );
}

# --- grep -----------------------------------------------------------------

{
    my $r = pipe { [1..10] |> grep { $_ % 2 == 0 } };
    is_deeply( $r, [2, 4, 6, 8, 10], 'grep { $_ % 2 == 0 } keeps evens' );
}

{
    my $r = pipe { [qw/apple banana cherry date/] |> grep { length($_) > 4 } };
    is_deeply( $r, [qw/apple banana cherry/], 'grep by length' );
}

# --- tap ------------------------------------------------------------------

{
    my @seen;
    my $r = pipe { 42 |> tap { push @seen, $_ } };
    is( $r, 42,            'tap yields the topic unchanged' );
    is_deeply( \@seen, [42], 'tap block ran with $_ aliased to topic' );
}

# tap can be sprinkled mid-pipeline without disturbing values
{
    my @trace;
    sub double { $_[0] * 2 }
    sub inc    { $_[0] + 1 }
    my $r = pipe {
        3
            |> double
            |> tap { push @trace, "after double: $_" }
            |> inc
            |> tap { push @trace, "after inc: $_" }
    };
    is( $r, 7, 'tap does not alter the topic' );
    is_deeply(
        \@trace,
        ['after double: 6', 'after inc: 7'],
        'two tap blocks captured the intermediate topics',
    );
}

# --- map |> grep |> a count step --------------------------------------------

{
    sub count_aref { scalar @{ $_[0] } }
    my $r = pipe {
        [1..10]
            |> map  { $_ * $_ }
            |> grep { $_ > 20 }
            |> count_aref
    };
    # squares > 20 from 1..10 are 25, 36, 49, 64, 81, 100 -> 6
    is( $r, 6, 'map |> grep |> bareword count: end-to-end arrayref flow' );
}

# --- map block can refer to outer lexicals (closure) ----------------------

{
    my $factor = 10;
    my $r = pipe { [1, 2, 3] |> map { $_ * $factor } };
    is_deeply( $r, [10, 20, 30], 'map block closes over outer $factor' );
}

# --- chained map: arrayref in, arrayref out, arrayref in again ------------

{
    my $r = pipe {
        [1, 2, 3]
            |> map  { $_ + 1 }     # [2,3,4]
            |> map  { $_ * 10 }    # [20,30,40]
            |> grep { $_ > 25 }    # [30,40]
    };
    is_deeply( $r, [30, 40], 'two maps and a grep chain through arrayrefs' );
}

# --- mixed with method/deref steps ----------------------------------------

{
    my $deep = { items => [{n=>1},{n=>2},{n=>3},{n=>4}] };
    my $r = pipe {
        $deep
            |> ->{items}              # arrayref of hashes
            |> map  { $_->{n} }       # extract n
            |> grep { $_ % 2 == 1 }   # keep odd
    };
    is_deeply( $r, [1, 3], 'method/deref |> map |> grep chain' );
}

# --- empty input -----------------------------------------------------------

{
    is_deeply( (pipe { [] |> map  { $_ } }),  [], 'empty map  yields empty arrayref' );
    is_deeply( (pipe { [] |> grep { $_ } }),  [], 'empty grep yields empty arrayref' );
    my $v = pipe { "x" |> tap { 1 } };
    is( $v, "x", 'tap on a scalar passes the scalar through' );
}

done_testing;
