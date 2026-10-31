#!perl
use 5.014;
use strict;
use warnings;
use Test::More;
use Pipe::Declare;

# Milestone 3 / call-step: bareword call with arglist, with optional `_`
# placeholder for the topic position.

sub add  { $_[0] + $_[1] }
sub mul  { $_[0] * $_[1] }
sub max3 { my @s = sort { $b <=> $a } @_; $s[0] }
sub join3 { join '|', @_ }

# --- no placeholder: topic is prepended to the arglist --------------------

is( (pipe { 5 |> add(3) }),           8, 'add(3): topic prepended -> add(5, 3)' );
is( (pipe { 5 |> add(3) |> mul(2) }), 16, 'two arg-steps chain through topic' );
is( (pipe { 1 |> join3(2, 3) }),  '1|2|3', 'three positional args, topic first' );

# --- `_` placeholder: topic woven in at every occurrence ------------------

is( (pipe { 7 |> max3(_, 10, 3) }),     10, '_ in first position' );
is( (pipe { 7 |> max3(10, _, 3) }),     10, '_ in second position' );
is( (pipe { 7 |> max3(10, 3, _) }),     10, '_ in last position' );

is( (pipe { 5 |> join3(_, 9, _) }),  '5|9|5', 'multiple _ all see the same topic' );

# --- empty arglist: topic only --------------------------------------------

sub triple { $_[0] * 3 }
is( (pipe { 4 |> triple() }), 12, 'empty arglist == bareword nullary' );

# --- qualified bareword ---------------------------------------------------

package Foo::Bar;
sub quad { $_[0] * 4 }
sub seven { 7 }
sub clamp { my ($x, $lo, $hi) = @_; $x < $lo ? $lo : $x > $hi ? $hi : $x }
package main;

is( (pipe { 5 |> Foo::Bar::quad }),         20, 'qualified bareword, nullary' );
is( (pipe { 5 |> Foo::Bar::quad() }),       20, 'qualified bareword, empty args' );
is( (pipe { 5 |> Foo::Bar::clamp(0, 10) }),  5, 'qualified bareword + args, topic first' );
is( (pipe { -5 |> Foo::Bar::clamp(0, 10) }), 0, 'clamp negative -> 0' );
is( (pipe { 15 |> Foo::Bar::clamp(_, 0, 10) }), 10, 'qualified + _ placeholder' );

# --- args carry arbitrary expressions -------------------------------------

is( (pipe { 1 |> add(2 + 3) }),     6, 'arg can be an arithmetic expression' );
is( (pipe { 1 |> add(add(2, 3)) }), 6, 'arg can itself be a call' );

{
    my $n = 4;
    is( (pipe { 1 |> add($n) }), 5, 'arg can be a variable' );
}

# --- trailing comma allowed in arglist ------------------------------------

is( (pipe { 1 |> join3(2, 3,) }), '1|2|3', 'trailing comma in arglist is fine' );

done_testing;
