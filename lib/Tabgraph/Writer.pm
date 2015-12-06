package Tabgraph::Writer;

use warnings;
use strict;
use Carp;

our @ISA         = qw(Exporter);
our @EXPORT_OK   = qw(write_tbl);

our %EXPORT_TAGS = (
    default => [qw(write_tbl)],
    testing => \@EXPORT_OK
    );

#------------------------------------------------------------------------------
sub write_tbl {
    my $options = shift;
    my $tab_fh  = "";

    if (not defined $options->{out}) {
        $tab_fh = \*STDOUT;
    } else {
        $tab_fh = _open_fh($options->{out});
    }

    print_tabs($options, $tab_fh)
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
sub print_tabs {
    my $options = shift;
    my $fh      = shift;
    my $graph   = $options->{graph};
    my $attributes  = $options->{node_attr};
    my %printed = ();

    foreach my $parent (keys %{ $graph }) {

        if (not exists $printed{$parent} ) {
            print $fh $parent, "\t-\t";
            if ($attributes->{$parent}) {
                my @att = split /\|/, $attributes->{$parent};
                print $fh join("\t", @att);
            }
            print $fh "\n";
            $printed{$parent} = undef;
        } # printing node

        foreach my $child (keys %{ $graph->{$parent} }) {
            print $fh $parent, "\t", $child, "\t";
            my @edge_att = split /\|/, $graph->{$parent}->{$child}
                if $graph->{$parent}->{$child};
            print $fh join("\t", @edge_att) if @edge_att;
            print $fh "\n";
        } # printing edge

    } # foreach parent

    return;
}
