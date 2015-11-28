#!/usr/bin/perl
use warnings;
use strict;

my $file = shift @ARGV;
my $dotdata = slurp($file);

my $buffer = "";
my $state  = "";
my @nodes;
my @interactions;

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
    } elsif ($state eq "comment") {
        state_comment(\$i, \$buffer, \$char, \$state);
    } elsif ($state eq "multicomment") {
        state_multicomment(\$i, \$buffer, \$char, \$state);
    }

    print STDERR "STATE: $state\tCHAR: $char \n\n";

}

print join(":", @nodes), "\n";
print join("  ", @interactions), "\n";

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

    if ($$char =~ /[A-Z]/i) {
        # graph name
    } elsif ($$char eq "{") {
        $$state  = "inside";
        $$buffer = "";
    }

    return;
}




sub state_inside {
    my $i       = shift;
    my $dotdata = shift;
    my $buffer  = shift;
    my $char    = shift;
    my $state   = shift;

    $$buffer .= $$char unless $$char =~ m/[\s\n\/]/;
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
        push @nodes, $$buffer;
        $$buffer = "";
    } elsif ($$buffer =~ m/^[A-Z0-9]+$/i and $$char eq " ") {
        # We have a node
        print "NODE HERE : $$buffer\n";
        push @nodes, $$buffer;
        $$buffer = "";
    } elsif ($$buffer eq "->") {
        $$state  = "edge";
        $$buffer = "";
    } elsif( $$char eq "/" and substr($dotdata, $$i+1, 1) eq "/") {
        # WE HAVE A COMMENT!
        $$state  = "comment";
        if ($$buffer =~ m/^[A-Z0-9]+$/i) {
            print "NODE-COMMENT HERE : $$buffer\n";
            push @nodes, $$buffer;          
        }
        $$buffer = ""; 
    } elsif ($$char eq "/" and substr($dotdata, $$i+1, 1) eq "*") {
        # WE HAVE A POSSIBLY MULTILINE COMMENT
        if ($$buffer =~ m/^[A-Z0-9]+$/i) {
            print "NODE-MULTI-COMMENT HERE : $$buffer\n";
            push @nodes, $$buffer;          
        }
        $$state  = "multicomment";
        $$i++; # so we will skip * and it won't be added to buffer
        $$buffer = ""; 
    }

    return;
}

sub state_edge {
    my $i      = shift;
    my $buffer = shift;
    my $char   = shift;
    my $state  = shift;

    if ($$char =~ m/^[A-Z0-9]$/i) {
        $$buffer .= $$char;

    } elsif ($$char =~ m/[\s\n]/ and $$buffer =~ m/^[A-Z0-9]+$/) {
        print "INT HERE: $$buffer with char $nodes[-1]\n";
        push @interactions, $nodes[-1] . "->" . $$buffer;
        push @nodes, $$buffer;
        $$buffer = "";
        $$state = "inside";
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
    print STDERR "BUFF: $$buffer\n";
    if ($$buffer eq "*/") {
        $$state = "inside";
        $$buffer = "";
    }

    return;
}




sub slurp {
    my $file = shift;
    my $string = "";

    open my $fh, "<", $file
        or die "Can't open $file:$!\n";

    while (<$fh>) {
        $string .= "$_ ";
    }

    return $string;
}