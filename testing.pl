#!/usr/bin/perl
use warnings;
use strict;
use lib '/home/sergio/code/dotcompare/lib';
use Dot::Parser qw(parse_dot);

my $file = shift @ARGV;

my ($nodes, $edges) = parse_dot("$file", 1);

print join("|", @$nodes), "\n";
print join("|", @$edges), "\n";

