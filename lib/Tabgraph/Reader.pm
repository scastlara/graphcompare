package Tabgraph::Reader;

use warnings;
use strict;
use Carp;

our @ISA         = qw(Exporter);
our @EXPORT_OK   = qw(read_tabgraph);

our %EXPORT_TAGS = (
    default => [qw(read_tabgraph)],
    testing => \@EXPORT_OK
    );



sub read_tabgraph {
    my $file      = shift;
    my %out_graph = ();

    open my $fh, "<", $file
        or croak "Can't open $file : $!\n";

    while (<$fh>) {
        chomp;
        my ($par, $chi) = split /\t/;

        $out_graph{$par} = {} unless exists $out_graph{$par};

        if (defined $chi and $chi ne "") {
            $out_graph{$chi} = {} unless exists $out_graph{$chi};
            $out_graph{$par}->{$chi} = undef;
        }
    }

    return(\%out_graph);

}
