#!/usr/bin/perl
use warnings;
use strict;
use Cwd 'abs_path';
use Dot::Parser qw(parse_dot);
use Test::More tests => 14;

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



my @test_files = qw(simple comments attributes subgraphs nospaces hard);

foreach my $testf (@test_files) {
    my ($nodes, $edges) = parse_dot("$path/$testf.dot");
    my $got_nodes = join("||", sort @{$nodes});
    my $got_edges = join("||", sort @{$edges});
    ok($exp_nodes eq $got_nodes, "Testing dot parser. ". uc($testf). ". Nodes.");
    ok($exp_edges eq $got_edges, "Testing dot parser. ". uc($testf). ". Edges.");
}


# YET ANOTHER UNRELATED TEST

my @sym_exp_nodes = (
    '%$&', "%;&/", 
    ";;;;", "I=Z", 
    "[AAA]", "[BBB]", 
    "graph", "strict", 
    "digraph", "node", 
    "edge", "subgraph"
);
my $sym_exp_nodes = join("||", sort @sym_exp_nodes);

my @sym_exp_edges = (
    '%$&->%;&/', ";;;;->I=Z", 
    "[AAA]->[BBB]", "graph->strict", 
    "digraph->node", "edge->subgraph"
);
my $sym_exp_edges = join("||", sort @sym_exp_edges);

my ($nodes, $edges) = parse_dot("$path/symbols.dot");
my $got_nodes = join("||", sort @{$nodes});
my $got_edges = join("||", sort @{$edges});

ok($sym_exp_nodes eq $got_nodes, "Testing dot parser. SYMBOLS. Nodes.");
ok($sym_exp_edges eq $got_edges, "Testing dot parser. SYMBOLS. Edges.");