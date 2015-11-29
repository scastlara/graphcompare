#!/usr/bin/perl
use warnings;
use strict;
use lib '/home/sergio/code/dotcompare/lib';
use Dot::Parser qw(parse_dot);

my $file = shift @ARGV;

my ($graph) = parse_dot("$file", 1);

use Data::Dumper;
print Dumper($graph);
