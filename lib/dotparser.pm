#!/usr/bin/perl
use warnings;
use strict;


#===============================================================================
# VARIABLES AND OPTIONS
#===============================================================================
my $file = shift @ARGV;
my $dotdata = slurp($file);

my $buffer = "";
my $node_id = "A-Za-z0-9_";
my @nodes   = ();
my @edges   = ();


#===============================================================================
# MAIN
#===============================================================================

# ALL POSSIBLE STATES OF THE PARSER!
my %states = (
    none          => \&_state_none,
    init          => \&_state_init,
    inside        => \&_state_inside,
    edge          => \&_state_edge,
    attribute     => \&_state_attribute,
    quoted_edge   => \&_state_quoted_edge,
    comment       => \&_state_comment,
    multicomment  => \&_state_multicomment,
    quoted_node   => \&_state_quoted_node,
    ass_attribute => \&_state_ass_attribute
);


my $state  = "none";

for (my $i = 0; $i < length($dotdata); $i++) {
    my $char = substr($dotdata, $i, 1);
    
    $states{$state}->(
        \$i, 
        $dotdata, 
        \$buffer, 
        \$char, 
        \$state, 
        $node_id, 
        \@nodes, 
        \@edges
    );

    print STDOUT "STATE: $state\tCHAR: $char \n\n";

}

# Remove repeated nodes from stack
my %nodes = map {$_ => 1} @nodes;


print STDERR "digraph {\n";
foreach my $node (sort keys %nodes) {
    print STDERR "\"$node\"\n";
} 

foreach my $int (@edges) {
    my ($p, $c) = split /\->/, $int;
    print STDERR "\"$p\" -> \"$c\"\n";
}

print STDERR "}\n";
#print join(" | ", @nodes), "\n";
#print join(" | ", @edges), "\n";



#===============================================================================
# METHODS AND FUNCTIONS 
#===============================================================================

sub _state_none {
    my $i          = shift;
    my $dotdata    = shift;
    my $buffer     = shift;
    my $char       = shift;
    my $state      = shift;
    my $node_id    = shift;
    my $node_stack = shift;
    my $edges      = shift;

    if ($$char ne " ") {
        $$buffer .= $$char
    } else {
        if ($$buffer =~ /^(strict)?\s*?(di|sub)?graph/) {
            # graph init
            $$state  = "init";
            $$buffer = "";
        }
    }

    return;
}


sub _state_init {
    my $i          = shift;
    my $dotdata    = shift;
    my $buffer     = shift;
    my $char       = shift;
    my $state      = shift;
    my $node_id    = shift;
    my $node_stack = shift;
    my $edges      = shift;

    if ($$char =~ /[$node_id]/i) {
        # graph name
    } elsif ($$char eq "{") {
        $$state  = "inside";
        $$buffer = "";
    } elsif ($$char eq "[") {
        # we found a graph attribute statement
        # get back to normal state
        # (so the attribute will be skipped)
        $$buffer = "";
        $$state = "attribute";
    }

    return;
}




sub _state_inside {
    my $i          = shift;
    my $dotdata    = shift;
    my $buffer     = shift;
    my $char       = shift;
    my $state      = shift;
    my $node_id    = shift;
    my $node_stack = shift;
    my $edges      = shift;

    if ($$char =~ m/[$node_id\->_]/ig) {
        $$buffer .= $$char 
    }

    print "BUFFER: $$buffer\n";

    # BUFFER KEYWORDS!
    if ($$buffer =~ m/^(di|sub)?graph/) {
        # graph init
        $$state  = "init";
        $$buffer = "";
    } elsif ($$buffer =~ m/^(node|edge)/) {
        # We have a node/edge attribute statement. 
        $$buffer = "";
    }

    # WHAT AM I READING?
    if ($$char eq "=") {
        # Attribute assignment
        $$state = "ass_attribute";
        $$buffer = "";
    } elsif ($$char eq "[") {
        # Attributes
        $$state  = "attribute";
        if ($$buffer =~ m/$node_id/) {
            # There is a node in the buffer
            print "\tNODE added in state: $$state at line ", __LINE__, ": $$buffer\n";
            push @{$node_stack}, $$buffer;
        } elsif ($$buffer) {
            die "We have something not allowed in buffer: $$buffer\n";
        }
        $$buffer = "";
    } elsif ($$char =~ m/[\s\n;]/) {
        # End of node statement, probably
        if ($$buffer =~ m/^[$node_id]+$/i) {
            # We have a node
            print "\tNODE added in state: $$state at line ", __LINE__, ": $$buffer\n";
            push @{$node_stack}, $$buffer;
            $$buffer = "";
       }

    } elsif ($$buffer eq "->") {
        $$state  = "edge";
        $$buffer = "";
    } elsif( $$char eq "/" and substr($dotdata, $$i+1, 1) eq "/") {
        # WE HAVE A COMMENT!
        if ($$buffer =~ m/^[$node_id]+$/i) {
            print "\tNODE added in state: $$state at line ", __LINE__, ": $$buffer\n";
            push @{$node_stack}, $$buffer;          
        }
        $$state  = "comment";
        $$buffer = ""; 
    } elsif ($$char eq "/" and substr($dotdata, $$i+1, 1) eq "*") {
        # WE HAVE A POSSIBLY MULTILINE COMMENT
        if ($$buffer =~ m/^[$node_id]+$/i) {
            # We have a node in the buffer
            print "NODE-MULTI-COMMENT HERE : $$buffer\n";
            push @{$node_stack}, $$buffer;          
        } # else the buffer is empty or full of crap

        $$state  = "multicomment";
        $$i++; # so we will skip * and it won't be added to buffer
        $$buffer = ""; 
    } elsif ($$char eq "\"") {
        if ($$buffer =~ /[^"]/) {
            die "PROBLEM HERE\n";
        } else {
            # We have the beginning of a quoted node!
            $$buffer = ""; # remove quote from buffer
            $$state = "quoted_node";

        }
    } elsif ($$char =~ m/[^$node_id\->}{]/) {
        die "Not allowed character! $$char \n";
    }

    return;
}

sub _state_edge {
    my $i          = shift;
    my $dotdata    = shift;
    my $buffer     = shift;
    my $char       = shift;
    my $state      = shift;
    my $node_id    = shift;
    my $node_stack = shift;
    my $edges      = shift;

    if ($$char =~ m/^[$node_id]$/i) {
        # REGULAR EDGE
        $$buffer .= $$char;
    } elsif ($$char =~ m/"/) {
        if ($$buffer) {
            die "You can't use quotes inside node strings. BUFF: $$buffer CHAR: $$char\n";
        } else {
            # Edge statement with node starting with quote
            $$state = "quoted_edge";
        }
    } elsif ($$char =~ m/[\s\n\[;\/]/ and $$buffer =~ m/^[$node_id]+$/) {
        # END OF REGULAR EDGE STATEMENT
        if ($$char =~ m/\[/) {
            # edge stmt ends with attribute
            $$state = "attribute";
        } elsif ($$char =~ m/\//) {
            # edge stmt ends with comment
            if (substr($dotdata, $$i+1, 1) eq "*") {
                # multicomment!
                $$state = "multicomment";
                $$i++; # so we will skip * and it won't be added to buffer
            } elsif (substr($dotdata, $$i+1, 1) eq "/") {
                # regular comment
                $$state = "comment";
            } else {
                die "Found $$char that is not a comment\n";
            }

        } else {
            $$state = "inside"; 
        }

        print "\tINT HERE: $nodes[-1] -> $$buffer : char $$char at line ", __LINE__, "\n";
        push @{$edges}, $nodes[-1] . "->" . $$buffer;
        push @{$node_stack}, $$buffer;
        print "\tNODE added in state: $$state at line ", __LINE__, ": $$buffer\n";
        $$buffer = "";
    }

    return;

}

sub _state_quoted_edge {
    my $i          = shift;
    my $dotdata    = shift;
    my $buffer     = shift;
    my $char       = shift;
    my $state      = shift;
    my $node_id    = shift;
    my $node_stack = shift;
    my $edges      = shift;

    if ($$char eq "\"") {
        # end of quoted edge
        print "\tQ_INT HERE: $nodes[-1] -> $$buffer\n";
        push @{$edges}, $nodes[-1] . "->" . $$buffer;
        push @{$node_stack}, $$buffer;
        print "\tNODE added in state: $$state at line ", __LINE__, ": $$buffer\n";
        $$buffer = "";
        $$state = "inside";
    } else {
        $$buffer .= $$char;

    }
}


sub _state_attribute {
    my $i          = shift;
    my $dotdata    = shift;
    my $buffer     = shift;
    my $char       = shift;
    my $state      = shift;
    my $node_id    = shift;
    my $node_stack = shift;
    my $edges      = shift;

    if ($$char eq "]") {
        $$state = "inside";
        $$buffer = "";
    }

    return;
}

sub _state_ass_attribute {
    my $i          = shift;
    my $dotdata    = shift;
    my $buffer     = shift;
    my $char       = shift;
    my $state      = shift;
    my $node_id    = shift;
    my $node_stack = shift;
    my $edges      = shift;

    if ($$char =~ m/[$node_id\."]/) {
        # good
    } else {
        # end of attribute
        $$state = "inside";
    }

    return;
}

sub _state_comment {
    my $i          = shift;
    my $dotdata    = shift;
    my $buffer     = shift;
    my $char       = shift;
    my $state      = shift;
    my $node_id    = shift;
    my $node_stack = shift;
    my $edges      = shift;

    print "BUFF: $$buffer\n";

    if ($$char =~ /\n/) {
        $$state = "inside";
    }

    return;
}

sub _state_multicomment {
    my $i          = shift;
    my $dotdata    = shift;
    my $buffer     = shift;
    my $char       = shift;
    my $state      = shift;
    my $node_id    = shift;
    my $node_stack = shift;
    my $edges      = shift;

    $$buffer .= $$char if $$char =~ m/[\/\*]/;
    print STDOUT "BUFF: $$buffer\n";
    if ($$buffer eq "*/") {
        $$state = "inside";
        $$buffer = "";
    }

    return;
}

sub _state_quoted_node {
    my $i          = shift;
    my $dotdata    = shift;
    my $buffer     = shift;
    my $char       = shift;
    my $state      = shift;
    my $node_id    = shift;
    my $node_stack = shift;
    my $edges      = shift;

    if ($$char eq "\"") {
        # end of quoted node
        push @{$node_stack}, $$buffer;
        print "\tNODE added in state: $$state at line ", __LINE__, ": $$buffer\n";
        $$buffer = "";
        $$state = "inside";
    } else {
        $$buffer .= $$char;

    }

}


sub slurp {
    my $file   = shift;
    my $string = "";

    open my $fh, "<", $file
        or die "Can't open $file:$!\n";

    while (<$fh>) {
        next if $_ =~ m/^\s*#/;

        # Removes spaces between equal signs
        # we lose node info in IDs with =,
        # but it is worth the loss. Easier to parse
        # things like rank=same
        if ($_ =~ m/\s*=\s*/) {
            $_ =~ s/\s+=\s+/=/g;
        }

        # Add space between edges in edge stmts
        # makes everything easier to parse
        if ($_ =~ m/\->/) {
            $_ =~ s/\->/ \-> /g;
        }

        $string .= "$_ ";
    }

    return $string;
}