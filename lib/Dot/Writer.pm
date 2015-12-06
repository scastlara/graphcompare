package Dot::Writer;

=head1 NAME

Dot::Writer

=head1 SYNOPSIS

    use Dot::Writer qw(write_dot);

    write_dot({
        name   => "MyGraph",
        graph  => \%graph,
        colors => \%colors,
        out    => "outfile"
    });


    # Or you can use a hash
    my $options = {
        name      => "MyGraph",
        graph     => \%graph,
        node_attr => \%colors,
        out       => "outfile"
    };

    write_dot($options);

=head1 DESCRIPTION

This module writes DOT files. To do it, it needs at least two arguments (graph and
out). The "colors" and "name" arguments are optional.

=over 8

=item B<name>

Name of the graph to write on the graph initialization statement.

    digraph MyGraph {
        ...
    }

=item B<graph>

A hash reference with the graph. It should have the following structure:

    %hash = (
        parent1 => child1 = "color|attr1|attr2|..."
                => child2 = "color|attr1|attr2|..."

        parent2 => child3 = "color|attr1|attr2|..."
                => child4 = "color|attr1|attr2|..."
        ...
    )


=item B<colors>

A hash ref with the colors for each node.The keys should be the node IDs of your nodes.
This argument is optional. If not set, no color will be specified.

=item B<out>

A file to write it

=back

=cut

use warnings;
use strict;
use Carp;

our @ISA         = qw(Exporter);
our @EXPORT_OK   = qw(write_dot);

our %EXPORT_TAGS = (
    default => [qw(write_dot)],
    );

#------------------------------------------------------------------------------
sub write_dot {
    my $options = shift;
    my $dot_fh  = "";

    if (not defined $options->{out}) {
        $dot_fh = \*STDOUT;
    } else {
        $dot_fh = _open_fh($options->{out});
    }

    _print_init($options,  $dot_fh);
    _print_elements($options, $dot_fh);
    print $dot_fh "}\n";

    return;
}

#------------------------------------------------------------------------------
sub _open_fh {
    my $outfile = shift;

    croak "You have to give me an output filename!\n"
        unless defined $outfile;

    open my $fh, ">", $outfile
        or croak "Can't write to $outfile : $!\n";

    return $fh;
}

#------------------------------------------------------------------------------
sub _print_init {
    my $options = shift;
    my $dot_fh  = shift;
    my $name    = "";

    if (defined $options->{name}) {
        $name = $options->{name};
    } else {
        $name = "MyGraph";
    }

    print $dot_fh "digraph $name {\n";

    return;
}

#------------------------------------------------------------------------------
sub _print_elements {
    my $options     = shift;
    my $dot_fh      = shift;
    my $graph       = $options->{graph};
    my $attributes  = $options->{node_attr};
    my %added_nodes = ();

    foreach my $node (keys %{ $graph }) {
        if (not exists $added_nodes{$node}) {
            _print_node(
                $dot_fh,
                $node,
                exists $attributes->{$node} ? $attributes->{$node} : undef
            );
            $added_nodes{$node} = undef;
        }

        foreach my $c_node ( keys %{ $graph->{$node} } ) {
            _print_edge( $dot_fh, $node, $c_node, $graph->{$node}->{$c_node} );
        }
    }

    return;
}

#------------------------------------------------------------------------------
sub _print_node {
    my $fh         = shift;
    my $node       = shift;
    my $attributes = shift;
    my ($color, $other) = undef;
    ($color, $other) = parse_attributes($attributes) if $attributes;

    print $fh "\t$node ";
    print $fh "[ color = \"$color\" ] " if $color;
    print $fh "//", join(" ", @{$other}) if $other;
    print $fh "\n";

    return;
}

#------------------------------------------------------------------------------
sub parse_attributes {
    my $attr_string = shift;

    my ($color, @other) = split /\|/, $attr_string;

    return($color, \@other);
}


#------------------------------------------------------------------------------
sub _print_edge {
    my $fh         = shift;
    my $parent     = shift;
    my $child      = shift;
    my $attributes = shift;
    my ($color, $other) = undef;
    ($color, $other) = parse_attributes($attributes) if $attributes;

    print $fh "\t$parent -> $child ";
    print $fh "[ color = \"$color\" ] " if $color;
    print $fh "//", join(" ", @{$other}) if $other;
    print $fh "\n";

    return;
}

1;
