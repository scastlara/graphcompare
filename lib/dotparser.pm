#!/usr/bin/perl
use warnings;
use strict;


#===============================================================================
# VARIABLES AND OPTIONS
#===============================================================================
my $file = shift @ARGV;
my $dotdata = slurp($file);

my $buffer = "";
my $state  = "";
my $node_id = "A-Z0-9_";
my @nodes;
my @interactions;


#===============================================================================
# MAIN
#===============================================================================

for (my $i = 0; $i < length($dotdata); $i++) {
    my $char = substr($dotdata, $i, 1);
    
    state_none($i, \$buffer, \$char, \$state)
        unless $state;

    if ($state eq "init") {
        state_init(\$i, \$buffer, \$char, \$state);
    } elsif ($state eq "inside") {
        state_inside(\$i, $dotdata, \$buffer, \$char, \$state);
    } elsif ($state eq "attribute") {
        state_attribute(\$i, \$buffer, \$char, \$state);
    } elsif ($state eq "edge") {
        state_edge(\$i, \$buffer, \$char, \$state);
    } elsif ($state eq "quoted_edge") {
        state_quoted_edge(\$i, \$buffer, \$char, \$state);
    } elsif ($state eq "comment") {
        state_comment(\$i, \$buffer, \$char, \$state);
    } elsif ($state eq "multicomment") {
        state_multicomment(\$i, \$buffer, \$char, \$state);
    } elsif ($state eq "quoted_node") {
        state_quoted_node(\$i, \$buffer, \$char, \$state);
    }

    print STDOUT "STATE: $state\tCHAR: $char \n\n";

}

print join(":", @nodes), "\n";
print join("  ", @interactions), "\n";



#===============================================================================
# METHODS AND FUNCTIONS 
#===============================================================================

sub state_none {
    my $i      = shift;
    my $buffer = shift;
    my $char   = shift;
    my $state  = shift;

    if ($$char ne " ") {
        $$buffer .= $$char
    } else {
        if ($$buffer =~ /^(di|sub)?graph/) {
            # graph init
            $$state  = "init";
            $$buffer = "";
        }
    }

    return;
}


sub state_init {
    my $i      = shift;
    my $buffer = shift;
    my $char   = shift;
    my $state  = shift;

    if ($$char =~ /[$node_id]/i) {
        # graph name
    } elsif ($$char eq "{") {
        $$state  = "inside";
        $$buffer = "";
    } elsif ($$char eq "[") {
        # we found a graph attribute statement
        # get back to previous position and return 
        # to normal state (so the attribute will be skipped)
        $$buffer = "";
        $$state = "attribute";
    }

    return;
}




sub state_inside {
    my $i       = shift;
    my $dotdata = shift;
    my $buffer  = shift;
    my $char    = shift;
    my $state   = shift;

    $$buffer .= $$char if $$char =~ m/[A-Z0-9\->_]/ig;
    print "BUFFER: $$buffer\n";
    if ($$buffer =~ /^(di|sub)?graph/) {
        # graph init
        $$state  = "init";
        $$buffer = "";
    }

    if ($$char eq "=") {
        # attribute assignment
        $$state = "ass_attribute";
        $$buffer = "";
    } elsif ($$char eq "[") {
        $$state  = "attribute";
        if ($$buffer =~ m/$node_id/) {
            # There is a node in the buffer
            print "\tNODE added in state: $$state at line ", __LINE__, ": $$buffer\n";
            push @nodes, $$buffer;
        }
        $$buffer = "";
    } elsif ($$buffer =~ m/^[$node_id]+$/i and $$char =~ m/[\s\n]/) {
        # We have a node
        print "\tNODE added in state: $$state at line ", __LINE__, ": $$buffer\n";
        push @nodes, $$buffer;
        $$buffer = "";
    } elsif ($$buffer eq "->") {
        $$state  = "edge";
        $$buffer = "";
    } elsif( $$char eq "/" and substr($dotdata, $$i+1, 1) eq "/") {
        # WE HAVE A COMMENT!
        $$state  = "comment";
        if ($$buffer =~ m/^[$node_id]+$/i) {
            print "\tNODE added in state: $$state at line ", __LINE__, ": $$buffer\n";
            push @nodes, $$buffer;          
        }
        $$buffer = ""; 
    } elsif ($$char eq "/" and substr($dotdata, $$i+1, 1) eq "*") {
        # WE HAVE A POSSIBLY MULTILINE COMMENT
        if ($$buffer =~ m/^[$node_id]+$/i) {
            print "NODE-MULTI-COMMENT HERE : $$buffer\n";
            push @nodes, $$buffer;          
        }
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
    } 

    return;
}

sub state_edge {
    my $i      = shift;
    my $buffer = shift;
    my $char   = shift;
    my $state  = shift;

    if ($$char =~ m/^[$node_id]$/i) {
        # REGULAR EDGE
        $$buffer .= $$char;
    } elsif ($$char =~ m/"/) {
        if ($$buffer) {
            die "You can't use quotes inside node strings :(\n";
        } else {
            # Edge statement with node starting with quote
            $$state = "quoted_edge";
        }
    } elsif ($$char =~ m/[\s\n\[]/ and $$buffer =~ m/^[A-Z0-9]+$/) {
        # END OF REGULAR EDGE STATEMENT
        if ($$char =~ m/\[/) {
            $$state = "attribute";
        } else {
            $$state = "inside"; 
        }

        print "\tINT HERE: $nodes[-1] -> $$buffer : char $$char at line ", __LINE__, "\n";
        push @interactions, $nodes[-1] . "->" . $$buffer;
        push @nodes, $$buffer;
        print "\tNODE added in state: $$state at line ", __LINE__, ": $$buffer\n";
        $$buffer = "";
    }

    return;

}

sub state_quoted_edge {
    my $i      = shift;
    my $buffer = shift;
    my $char   = shift;
    my $state  = shift;

    if ($$char eq "\"") {
        # end of quoted edge
        print "\tQ_INT HERE: $nodes[-1] -> $$buffer\n";
        push @interactions, $nodes[-1] . "->" . $$buffer;
        push @nodes, $$buffer;
        print "\tNODE added in state: $$state at line ", __LINE__, ": $$buffer\n";
        $$buffer = "";
        $$state = "inside";
    } else {
        $$buffer .= $$char;

    }
}


sub state_attribute {
    my $i      = shift;
    my $buffer = shift;
    my $char   = shift;
    my $state  = shift;

    if ($$char eq "]") {
        $$state = "inside";
        $$buffer = "";
    }

    return;
}

sub state_comment {
    my $i      = shift;
    my $buffer = shift;
    my $char   = shift;
    my $state  = shift;

    print "BUFF: $$buffer\n";

    if ($$char =~ /\n/) {
        $$state = "inside";
    }

    return;
}

sub state_multicomment {
    my $i      = shift;
    my $buffer = shift;
    my $char   = shift;
    my $state  = shift;

    $$buffer .= $$char if $$char =~ m/[\/\*]/;
    print STDOUT "BUFF: $$buffer\n";
    if ($$buffer eq "*/") {
        $$state = "inside";
        $$buffer = "";
    }

    return;
}

sub state_quoted_node {
    my $i      = shift;
    my $buffer = shift;
    my $char   = shift;
    my $state  = shift;

    if ($$char eq "\"") {
        # end of quoted node
        push @nodes, $$buffer;
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
        if ($_ =~ m/\s*=\s*/) {
            $_ =~ s/\s+=\s+/=/g;
        }


        $string .= "$_ ";
    }

    return $string;
}