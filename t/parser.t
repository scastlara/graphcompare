#!/usr/bin/perl
use warnings;
use strict;
use Cwd 'abs_path';
use Dot::Parser qw(parse);
use Test::More tests => 2;

# Get where testfile is...
my $path = abs_path($0);
$path =~ s/(.+)\/.*?$/$1\//;


# Degine expected nodes
my @exp_nodes = ("A","B" ,"C" ,"D E", "F" ,"G" ,"H%","K" ,"W" ,"Z" ,"a");
my $exp_nodes = join("||", sort @exp_nodes);

# Define expected edges
my @exp_edges = (
    "A->B", "A->K", "A->Z", "B->C",
    "B->D E", "C->D E", "D E->F", "F->A",
    "F->H%", "G->H%","H%->a"
);
my $exp_edges = join("||", sort @exp_edges);

# Parse Dot file
my ($nodes, $edges) = parse("$path/Thehard.dot");

my $got_nodes = join("||", sort @{$nodes});
my $got_edges = join("||", sort @{$edges});

# NODES
ok($exp_nodes eq $got_nodes, "Testing dot parser: nodes");

# EDGES
ok($exp_edges eq $got_edges, "Testing dot parser: edges");
