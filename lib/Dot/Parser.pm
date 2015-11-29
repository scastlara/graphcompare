package Dot::Parser;

=head1 NAME

Dot::Parser

=head1 SYNOPSIS

    use Dot::Parser qw(parse_dot); 
    my ($nodes, $edges) = parse_dot("dotfile.dot");

=head1 METHODS

Dot::Parser only exports one function: parse_dot(). This function takes a string with
the name of a file written in DOT format and returns:

=over 8

=item Nodes

A reference to an array with all the nodes in the file

=item Edges

A reference to an array with all the edges, written as "A->B".

=back

=cut



use warnings;
use strict;q
use Exporter qw(import);
use Carp;

#===============================================================================
# VARIABLES AND OPTIONS
#===============================================================================
our @ISA         = qw(Exporter);
our @EXPORT_OK   = qw(parse_dot);
our %EXPORT_TAGS = ( DEFAULT => [qw(parse_dot)]);


#===============================================================================
# METHODS AND FUNCTIONS 
#===============================================================================

sub parse_dot {
    my $file    = shift;
    my $debug   = shift;
    my $node_id = "A-Za-z0-9_";
    my @nodes   = ();
    my @edges   = ();
    my $buffer  = ""; # This will store what has been read in each state

    # ALL POSSIBLE STATES OF THE PARSER
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


    # INITIAL STATE
    my $state  = "none";

    # READ DOT FILE
    my $dotdata = slurp($file);

    # START PARSING
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
            \@edges,
            $debug
        );

    }

    # Remove repeated nodes from stack
    my %nodes = map {$_ => 1} @nodes;
    @nodes = keys %nodes;
    return(\@nodes, \@edges);
}


# INTERNAL SUBROUTINES
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
    my $debug      = shift;

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
    my $debug      = shift;

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
    my $debug      = shift;

    if ($$char =~ m/[$node_id\->_]/ig) {
        $$buffer .= $$char 
    }

    print STDERR "BUFFER: $$buffer\n" if $debug;

    # BUFFER KEYWORDS!
    if ($$buffer =~ m{ ^ (di|sub)? graph | ^ strict }x) {
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
        if ($$buffer =~ m/[$node_id]/) {
            # There is a node in the buffer
            print STDERR "\tNODE added in state: $$state at line ", __LINE__, ": $$buffer\n" if $debug;
            push @{$node_stack}, $$buffer;
        } elsif ($$buffer) {
            croak "We have something not allowed in buffer, with state $state. Buffer: $$buffer\n";
        }
        $$buffer = "";
    } elsif ($$char =~ m/[\s\n;]/) {
        # End of node statement, probably
        if ($$buffer =~ m/^[$node_id]+$/i) {
            # We have a node
            print STDERR "\tNODE added in state: $$state at line ", __LINE__, ": $$buffer\n" if $debug;
            push @{$node_stack}, $$buffer;
            $$buffer = "";
       }

    } elsif ($$buffer eq "->") {
        $$state  = "edge";
        $$buffer = "";
    } elsif( $$char eq "/" and substr($dotdata, $$i+1, 1) eq "/") {
        # WE HAVE A COMMENT!
        if ($$buffer =~ m/^[$node_id]+$/i) {
            print STDERR "\tNODE added in state: $$state at line ", __LINE__, ": $$buffer\n" if $debug;
            push @{$node_stack}, $$buffer;          
        }
        $$state  = "comment";
        $$buffer = ""; 
    } elsif ($$char eq "/" and substr($dotdata, $$i+1, 1) eq "*") {
        # WE HAVE A POSSIBLY MULTILINE COMMENT
        if ($$buffer =~ m/^[$node_id]+$/i) {
            # We have a node in the buffer
            print STDERR "NODE-MULTI-COMMENT HERE : $$buffer\n" if $debug;
            push @{$node_stack}, $$buffer;          
        } # else the buffer is empty or full of crap

        $$state  = "multicomment";
        $$i++; # so we will skip * and it won't be added to buffer
        $$buffer = ""; 
    } elsif ($$char eq "\"") {
        if ($$buffer =~ /[^"]/) {
            croak "PROBLEM HERE\n";
        } else {
            # We have the beginning of a quoted node!
            $$buffer = ""; # remove quote from buffer
            $$state = "quoted_node";

        }
    } elsif ($$char =~ m/[^$node_id\->}{]/) {
        croak "Not allowed character! $$char \n";
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
    my $debug      = shift;

    if ($$char =~ m/^[$node_id]$/i) {
        # REGULAR EDGE
        $$buffer .= $$char;
    } elsif ($$char =~ m/"/) {
        if ($$buffer) {
            croak "You can't use quotes inside node strings. BUFF: $$buffer CHAR: $$char\n";
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
                croak "Found $$char that is not a comment\n";
            }

        } else {
            $$state = "inside"; 
        }

        print STDERR "\tINT HERE: $node_stack->[-1] -> $$buffer : char $$char at line ", __LINE__, "\n" if $debug;
        push @{$edges}, $node_stack->[-1] . "->" . $$buffer;
        push @{$node_stack}, $$buffer;
        print STDERR "\tNODE added in state: $$state at line ", __LINE__, ": $$buffer\n" if $debug;
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
    my $debug      = shift;

    if ($$char eq "\"") {
        # end of quoted edge
        print STDERR "\tQ_INT HERE: $node_stack->[-1] -> $$buffer\n" if $debug;
        push @{$edges}, $node_stack->[-1] . "->" . $$buffer;
        push @{$node_stack}, $$buffer;
        print STDERR "\tNODE added in state: $$state at line ", __LINE__, ": $$buffer\n" if $debug;
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
    my $debug      = shift;

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
    my $debug      = shift;

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
    my $debug      = shift;

    print STDERR "BUFF: $$buffer\n" if $debug;

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
    my $debug      = shift;

    $$buffer .= $$char if $$char =~ m/[\/\*]/;
    print STDERR "BUFF: $$buffer\n" if $debug;
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
    my $debug      = shift;

    if ($$char eq "\"") {
        # end of quoted node
        push @{$node_stack}, $$buffer;
        print STDERR "\tNODE added in state: $$state at line ", __LINE__, ": $$buffer\n" if $debug;
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
        or croak "Can't open $file:$!\n";

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