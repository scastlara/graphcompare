package Dot::Parser;

=head1 NAME

Dot::Parser

=head1 DESCRIPTION

This module reads/parses DOT files. 

=head1 SYNOPSIS

    use Dot::Parser qw(parse_dot); 
    my $graph = parse_dot("dotfile.dot");

=head1 METHODS

=over 8

=item B<parse_dot>

Dot::Parser only exports one function: parse_dot(). This function takes a string with
the name of a file written in DOT format and returns a hash reference that contains 
an adjacency list of the graph.

    %hash => 
        {node1} => {node2} => undef
                   {node3} => undef
                   {node4} => undef

        {node2} => {node5} => undef
        ...

=back

=head2 INTERNAL FUNCTIONS

Dot::Parser uses two types of functions: STATES and REGULAR functions.


=head3 REGULAR FUNCTIONS

=over 8 

=item B<_slurp>

This function slurps the dotfile. It does some ugly modifications to it
to help the parser. these are adding spaces between edgeops and removing spaces between
'=' signs. Node ids with this symbols will be (obviously) altered, but I think it's not
a big deal to remove one or two spaces. Maybe in the future I could improve this. 

=item B<_add_node>

This function simply adds the node stored in the buffer to the node stack and to the graph
adjacency list. Then it removes everything in the buffer

=back

=head3 STATES


=over 8 

=item B<_none>

This is the initial state. It lasts until the parser reads a graph declaration.
If your file is not a dot file, you may end up forever in this state.

=item B<_init>

This defines the state in which the Parser has read a keyword.
It could be either a graph declaration (disubgraph) or a graph attribute declaration

=item B<_inside>

This is the "normal" state of the parser. Here, everything that looks normal
[A-Za-z0-9_]+ will be considered a node ID if it is not a keyword.
Thus, it is important to define the cases in which the Parser has to "get out"
of this state (for example, in the case of rank=id or an [attribute]).

Right now it works but it is very messy. It certainly needs a refactor.

=item B<_edge>

The parser read an edgeops -> and falls into this state. Here, it will look for another
node ID, and then it will return to the "normal/inside" state. The "ending" of a node ID
could be a whitespace, a semicolon, an attribute statement, a comment or a multicomment
If the second node is quoted, this state is not enough, so the parser will fall into the 
state quoted_edge, which can deal with special characters and symbols


=item B<_quoted_node>

This is a quoted node state, which is straightforward. If the parser (in state inside)
reads an opening double quote, it falls into this state. The parser will add everything 
to the buffer, and once it gets to a closing double quote it will save the buffer to the
nodes stack

=item B<_quoted_edge>

This is the state that allows special characters and symbols in the second node 
in an edge statement. It's similar to the state edge, but it will only end reading
the node ID when it gets to another double quote.

=item B<_attribute>

This is an attribute statement. Everything will be discarded until the parser
reads a closing square bracket.

=item B<_ass_attribute>

This funny name represents the state in which the parser reads something like rank=id
It's not a very well defined state and it may need further improvements.

=item B<_comment>

This is the state of a normal comment //comment that will end with a newline 
character

=item B<_multicomment>

This special comment /* comment */ ignores newline characters. It will only 
end when it gets to a closing comment symbol */





=back


=cut


use warnings;
use strict;
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
    my $file           = shift;
    my $debug          = shift;
    my $node_id        = "A-Za-z0-9_";
    my @nodes          = ();
    my %adjacency_list = ();
    my $buffer         = ""; 
        # This will store what has been read in each state

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
    my $dotdata = _slurp($file);

    # START PARSING
    for (my $i = 0; $i < length($dotdata); $i++) {
        my $char = substr($dotdata, $i, 1);
        
        print STDERR "STATE: $state\n" if $debug;

        $states{$state}->(
            \$i, 
            $dotdata, 
            \$buffer, 
            \$char, 
            \$state, 
            $node_id, 
            \@nodes, 
            \%adjacency_list,
            $debug
        );

    }
    print STDERR "---\n" if $debug;

    return(\%adjacency_list);
}


# INTERNAL SUBROUTINES
#===============================================================================

#--------------------------------------------------------------------------------
sub _state_none {
    my $i          = shift;
    my $dotdata    = shift;
    my $buffer     = shift;
    my $char       = shift;
    my $state      = shift;
    my $node_id    = shift;
    my $node_stack = shift;
    my $graph      = shift;
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


#--------------------------------------------------------------------------------
sub _state_init {
    my $i          = shift;
    my $dotdata    = shift;
    my $buffer     = shift;
    my $char       = shift;
    my $state      = shift;
    my $node_id    = shift;
    my $node_stack = shift;
    my $graph      = shift;
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



#--------------------------------------------------------------------------------
sub _state_inside {
    my $i          = shift;
    my $dotdata    = shift;
    my $buffer     = shift;
    my $char       = shift;
    my $state      = shift;
    my $node_id    = shift;
    my $node_stack = shift;
    my $graph      = shift;
    my $debug      = shift;

    if ($$char =~ m/[$node_id\->]/ig) {
        $$buffer .= $$char 
    } 

    print STDERR "BUFFER: $$buffer\tCHAR: $$char\n" if $debug;

    if ($$char =~ m/[\s\n;=]/) {
        # ENDING CHARACTER

        if ($$buffer =~ m/^[$node_id]+$/) {
            # SOMETHING IN BUFFER

             if ($$buffer =~ m{ ^ (di|sub)? graph $ | ^ strict $}xi) {
                # GRAPH ATTRIBUTE/INITIALIZATION
                $$buffer = "";
                $$state  = "init";

            } elsif ($$buffer =~ m/^node$|^edge$/i) {
                # NODE/EDGE ATTRIBUTE
                $$buffer = "";

            } elsif ($$char eq "=") {
                # WHOLE GRAPH ATTRIBUTE

                $$state = "ass_attribute";
                $$buffer = "";
           
            } else {
                # NORMAL ENDING OF NODE ID
                _add_node($graph, $node_stack, $buffer, $state, $debug);
            }           
       
        } else {
            # WHITESPACE AND BUFFER EMPTY
            return;
        }

    } elsif ($$buffer eq "->" or $$buffer eq "--") {
        # EDGE STATEMENT
        $$state  = "edge";
        $$buffer = ""; 

    } elsif ($$char eq '"') {
        # QUOTED NODE BEGINNING
        $$buffer = ""; # remove quote from buffer
        $$state = "quoted_node";

    } elsif ($$char eq "[") {
        # ATTRIBUTE STATEMENT

         if ($$buffer =~ m/[$node_id]/) {
            # NODE IN BUFFER
            _add_node($graph, $node_stack, $buffer, $state, $debug);

        } elsif ($$buffer) {
            # BEGINNING OF ATTRIBUTE BUT WITH SOMETHING THAT IS NOT A NODE IN BUFFER
            # THIS IS NOT ALLOWED IN DOT LANGUAGE
            croak "We have something not allowed in buffer, with state $state. Buffer: $$buffer\n";
        }
        
        $$state  = "attribute";
        $$buffer = "";

    } elsif ($$char eq "/") {
        # COMMENT

        if ($$buffer =~ m/^[$node_id]+$/i) {
            # NODE IN THE BUFFER
            _add_node($graph, $node_stack, $buffer, $state, $debug);         
        }

        if (substr($dotdata, $$i+1, 1) eq "/") {
            # REGULAR COMMENT
            $$state  = "comment";
            $$buffer = ""; 

        } elsif (substr($dotdata, $$i+1, 1) eq "*") {
            # C++ COMMENT
            $$state  = "multicomment";
            $$i++; # so we will skip * and it won't be added to the buffer
            $$buffer = "";

        } else {
            # THERE IS A '/' THAT IS NOT A COMMENT
            croak("Not allowed character $$char found\n");
        }
    
    }

    return;
}


#--------------------------------------------------------------------------------
sub _state_edge {
    my $i          = shift;
    my $dotdata    = shift;
    my $buffer     = shift;
    my $char       = shift;
    my $state      = shift;
    my $node_id    = shift;
    my $node_stack = shift;
    my $graph      = shift;
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

        print STDERR "\tINT HERE: $node_stack->[-1] -> $$buffer : char $$char at line ", 
                     __LINE__, "\n" if $debug;
        $graph->{$node_stack->[-1]}->{$$buffer} = undef;
        _add_node($graph, $node_stack, $buffer, $state, $debug);
    }

    return;

}


#--------------------------------------------------------------------------------
sub _state_quoted_node {
    my $i          = shift;
    my $dotdata    = shift;
    my $buffer     = shift;
    my $char       = shift;
    my $state      = shift;
    my $node_id    = shift;
    my $node_stack = shift;
    my $graph      = shift;
    my $debug      = shift;

    if ($$char eq "\"") {
        # end of quoted node
        _add_node($graph, $node_stack, $buffer, $state, $debug);
        $$state = "inside";
    } else {
        $$buffer .= $$char;

    }

}


#--------------------------------------------------------------------------------
sub _state_quoted_edge {
    my $i          = shift;
    my $dotdata    = shift;
    my $buffer     = shift;
    my $char       = shift;
    my $state      = shift;
    my $node_id    = shift;
    my $node_stack = shift;
    my $graph      = shift;
    my $debug      = shift;

    if ($$char eq "\"") {
        # end of quoted edge
        print STDERR "\tQ_INT HERE: $node_stack->[-1] -> $$buffer\n" if $debug;
        $graph->{$node_stack->[-1]}->{$$buffer} = undef;
        _add_node($graph, $node_stack, $buffer, $state, $debug);
        $$state = "inside";
    } else {
        $$buffer .= $$char;

    }
}


#--------------------------------------------------------------------------------
sub _state_attribute {
    my $i          = shift;
    my $dotdata    = shift;
    my $buffer     = shift;
    my $char       = shift;
    my $state      = shift;
    my $node_id    = shift;
    my $node_stack = shift;
    my $graph      = shift;
    my $debug      = shift;

    if ($$char eq "]") {
        $$state = "inside";
        $$buffer = "";
    }

    return;
}


#--------------------------------------------------------------------------------
sub _state_ass_attribute {
    my $i          = shift;
    my $dotdata    = shift;
    my $buffer     = shift;
    my $char       = shift;
    my $state      = shift;
    my $node_id    = shift;
    my $node_stack = shift;
    my $graph      = shift;
    my $debug      = shift;

    if ($$char =~ m/[$node_id\."]/) {
        # good
    } else {
        # end of attribute
        $$state = "inside";
    }

    return;
}


#--------------------------------------------------------------------------------
sub _state_comment {
    my $i          = shift;
    my $dotdata    = shift;
    my $buffer     = shift;
    my $char       = shift;
    my $state      = shift;
    my $node_id    = shift;
    my $node_stack = shift;
    my $graph      = shift;
    my $debug      = shift;

    print STDERR "BUFF: $$buffer\n" if $debug;

    if ($$char =~ /\n/) {
        $$state = "inside";
    }

    return;
}


#--------------------------------------------------------------------------------
sub _state_multicomment {
    my $i          = shift;
    my $dotdata    = shift;
    my $buffer     = shift;
    my $char       = shift;
    my $state      = shift;
    my $node_id    = shift;
    my $node_stack = shift;
    my $graph      = shift;
    my $debug      = shift;

    $$buffer .= $$char if $$char =~ m/[\/\*]/;
    print STDERR "BUFF: $$buffer\n" if $debug;

    if ($$buffer eq "*/") {
        $$state = "inside";
        $$buffer = "";
    }

    return;
}


#--------------------------------------------------------------------------------
sub _slurp {
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
        if ($_ =~ m/\->|\-\-/) {
            $_ =~ s/(\->|\-\-)/ $1 /g;
        }

        $string .= "$_ ";
    }

    return $string;
}


#--------------------------------------------------------------------------------
sub _add_node {
    my $graph      = shift;
    my $node_stack = shift;
    my $buffer     = shift;
    my $state      = shift;
    my $debug      = shift;

    push @{ $node_stack }, $$buffer;

    print STDERR "\tNODE added in state: $$state at line ", __LINE__, 
                 ": $$buffer\n" if $debug; 

    $graph->{$$buffer} = () unless exists $graph->{$$buffer};
    $$buffer = "";

    return;
}

1;