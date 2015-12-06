package Graphs::Compare;


#===============================================================================
# MODULES
#===============================================================================
use warnings;
use strict;
use Data::Dumper;
use Dot::Parser qw(parse_dot);
use Dot::Writer qw(write_dot);
use Tabgraph::Reader qw(read_tabgraph);
use File::Share ':all';
use Getopt::Long qw(:config no_ignore_case);


#===============================================================================
# VARIABLES AND OPTIONS
#===============================================================================
our @ISA         = qw(Exporter);
our @EXPORT_OK   = qw(compare_dots);

our %EXPORT_TAGS = (
    default => [qw(compare_dots)],
    testing => \@EXPORT_OK
    );

#===============================================================================
# FUNCTIONS
#===============================================================================

# EXPORTED
#--------------------------------------------------------------------------------
sub compare_dots {
    my $files        = shift;
    my $options      = shift;
    my %nodes        = ();
    my %interactions = ();

    # READ GRAPH FILES
    my @files = sort @{$files};
    foreach my $file (@files) {
        my $graph;

        if ($file =~ m/\.(dot|gv)$/) {
            print STDERR "# Reading DOT file $file...  ";
            $graph = parse_dot($file);
        } elsif ($file =~ m/\.(tbl|txt)$/) {
            print STDERR "# Reading TBL file $file...  ";
            $graph = read_tabgraph($file);
        } else {
            error("Can't read $file\nDon't know what it is\n" .
                  "graphcompare only reads DOT (.dot|.gv) or ".
                  "tabular (.tbl|.txt) files", 1);
        }

        print STDERR "done\n";
        read_graph($graph, $file, \%nodes, \%interactions, $options);
    }


    # COLORS AND COUNTS
    my $groups = initialize_groups(\@files);
    my $colors;
    if (@files <= 5) {
        $colors = load_colors($options->{colors});
    } else {
        require AutoLoader;
        require Color::Spectrum::Multi;
        my $spect  = Color::Spectrum::Multi->new();
        my $number = keys %{$groups};
        @$colors = $spect->generate($number, "#d5482b", "#2b63d5", "#2bd59d", "#d5482b");
        array_shuffle($colors);
    }

    my $groups_to_colors = assign_colors($colors,$groups);

    # COUNT NODES AND INTERACTIONS IN GROUPS
    count_nodeints(\%nodes, $groups, "nodes");
    count_nodeints(\%interactions, $groups, "ints");


    # WRITE DOT FILE
    my ($graph, $node_attr) = prepare_data(\%nodes, \%interactions, $groups_to_colors);
    write_dot({graph => $graph, node_attr => $node_attr, out => $options->{output}});

    # OPTIONAL OUTPUTS
    if (defined $options->{table}) {
        results_table($options->{table}, $groups);
    }

    if (defined $options->{venn}) {
        if (@files <= 3) {
            print_venn($options->{venn}, $groups, \@files, $groups_to_colors);
        } elsif (@files == 1) {
            error("Only 1 file. Won't draw any venn diagram\n");
        } else {
            error("More than 3 files. Won't draw any venn diagram\n");
        }
    }

    if (defined $options->{web}) {
        my $json        = create_json(\%nodes, \%interactions, $groups_to_colors);
        my $color_table = create_ctable($groups_to_colors);
        print_html($options->{web}, $json, $color_table);
    }

    if (defined $options->{stats}) {
        require Graph::Directed;
        my $graph_objs = load_graphs(\%interactions, \%nodes);

        print STDERR "\n# GRAPH PROPERTIES:\n\n";
        foreach my $g_name (sort keys %{$graph_objs}) {
            next if $g_name eq "MERGED";
            print_attributes($g_name, $graph_objs->{$g_name});
        }

        print_attributes("MERGED", $graph_objs->{"MERGED"});
        print STDERR "\n";
    }

    # DEBUGGING
    if (defined $options->{debug}) {
        print STDERR Data::Dumper->Dump(
            [$groups,   $groups_to_colors, \%nodes, \%interactions],
            [("GROUPS", "GROUPS_2_COLORS", "NODES", "EDGES") ]
        ), "\n";
    }

    return;

}

# READING DOT FILES
#--------------------------------------------------------------------------------
sub read_graph {
    my $graph        = shift;
    my $file          = shift;
    my $nodes        = shift;
    my $edges        = shift;
    my $options      = shift;
    my $file_symbol   = clean_name($file);
    my $escaped_file = quotemeta($file_symbol);

    foreach my $node (keys %{$graph}) {
        # ADDING NODES
        my $node_to_add = defined $options->{insensitive} ? uc($node) : $node;
        add_elements($graph, $nodes, $node_to_add, $file_symbol, $escaped_file);

        # ADDING EDGES
        foreach my $child (keys %{ $graph->{$node} }) {
            my $edge = $node . "::->::" . $child;
            my $edge_to_add =  defined $options->{insensitive} ? uc($edge) : $edge;
            add_elements($graph, $edges, $edge_to_add, $file_symbol, $escaped_file);
        }
    }

    return;
}


#--------------------------------------------------------------------------------
sub add_elements {
    my $input_graph   = shift;
    my $elements_hash = shift;
    my $node_or_edge  = shift;
    my $filename      = shift;
    my $escaped_file  = shift;

    if (exists $elements_hash->{$node_or_edge}) {
        $elements_hash->{$node_or_edge} .= ":$filename"
            unless $elements_hash->{$node_or_edge} =~ m/\b$escaped_file\b/;
    } else {
        $elements_hash->{$node_or_edge} = $filename;
    }

    return;
}

#--------------------------------------------------------------------------------
sub clean_name {
    my $file_name = shift;
    my $cleaned   = $file_name;

    $cleaned =~ s/\.|(dot|gv|tbl|graphml)//g;
    $cleaned =~ s/.+\///;

    return($cleaned);
}


# COLORS AND GROUPS
#--------------------------------------------------------------------------------
sub initialize_groups {
    my $files_array = shift;
    my %count_hash  = ();

    @{$files_array} = map {clean_name($_)} @{$files_array};


    foreach my $idx (1..@{$files_array} ) {
        my @combinations = combinations($files_array, $idx);

        foreach my $combi (@combinations) {
            my @sorted = @$combi;
            $count_hash{join ":",@sorted}->{nodes} = 0;
            $count_hash{join ":",@sorted}->{ints}  = 0;
        } # while

    } # foreach

    return (\%count_hash);

}

#--------------------------------------------------------------------------------
sub combinations {
    my $list = shift;
    my $n    = shift;

    error("Something went wrong when getting the combinations of your files", 1)
        if $n > @$list;

    return map [$_], @$list if $n <= 1;

    my @comb;

    for (my $i = 0; $i+$n <= @$list; ++$i) {
        my $val  = $list->[$i];
        my @rest = @$list[$i+1..$#$list];
        push @comb, [$val, @$_] for combinations(\@rest, $n-1);
    }

    return @comb;
}

#--------------------------------------------------------------------------------
sub load_colors {
    my $profile = shift;
    my @colors  = ();
    local $/ = "//";
    my $colors_file = dist_file("Dot-Parser", "colors.txt");

    open my $fh, '<', "$colors_file"
        or error("Can't open $colors_file,".
                 " i can't find the distribution share/ directory :$!", 1);

    while (<$fh>) {
        last if @colors;
        chomp;
        my ($name, @prof_colors) = split /\n/;
        next unless $profile eq $name;
        @colors = @prof_colors;
    }

    unless (@colors) {
        error(
              "Your profile \"$profile\" doesn't exist!\n".
              "Choose one of the following:\n\n".
              "\t- SOFT\n".
              "\t- HARD\n" .
              "\t- LARGE\n" .
              "\t- CBLIND\n",
              1
              );
    }

    return \@colors;
}

#--------------------------------------------------------------------------------
sub array_shuffle { # F-Y shuffle
    my $array = shift;
    my $i     = @$array;
    while ( --$i ) {
        my $j = int rand( $i+1 );
        @$array[$i,$j] = @$array[$j,$i];
    }
    return;
}

#--------------------------------------------------------------------------------
sub assign_colors {
    my $colors = shift;
    my $groups = shift;
    my %g_to_c = ();

    error("There are more groups than colors!\nUse -c LARGE\n", 1)
        if (keys %{$groups} > @{$colors});

    foreach my $group (sort keys %{ $groups }) {
        $g_to_c{$group} = shift @{$colors};
    }

    return(\%g_to_c);
}


# COUNTING
#--------------------------------------------------------------------------------
sub count_nodeints {
    my $in_hash = shift;
    my $groups  = shift;
    my $string  = shift;

    foreach my $obj (keys %{ $in_hash }) {
        $groups->{ $in_hash->{$obj} }->{$string}++;
    }

    return;
}

#--------------------------------------------------------------------------------
sub prepare_data {
    my $nodes         = shift;
    my $edges         = shift;
    my $grps_2_colors = shift;
    my %output_graph  = ();
    my %node_attr     = ();

    foreach my $node (keys %{ $nodes }) {
        my $source = $nodes->{$node};
        $node_attr{$node} = "$grps_2_colors->{$source}|$source";
    }

    foreach my $edge (keys %{ $edges }) {
        my ($parent, $child) = split /::\->::/, $edge;
        my $source = $edges->{$edge};
        $output_graph{$parent}->{$child} = "$grps_2_colors->{$source}|$source";
    }

    return(\%output_graph, \%node_attr);
}


# TABLE OUTPUT
#--------------------------------------------------------------------------------
sub results_table {
    my $out_file = shift;
    my $groups   = shift;

    open my $fh, '>', "$out_file"
        or error("Can't create results.tbl : $!", 1);

    print $fh "GROUP\tNODES\tEDGES\n";
    foreach my $group (sort keys %{$groups}) {
        print $fh    $group, "\t",
                     $groups->{$group}->{nodes}, "\t",
                     $groups->{$group}->{ints}, "\n";
    }

    return;
}


# VENN OUTPUT
#--------------------------------------------------------------------------------
sub print_venn {
    my $out_file      = shift;
    my $groups        = shift;
    my $filenames     = shift;
    my $grp_to_colors = shift;
    my @group_keys    = keys %{$groups};
    my $venn_template = "";

    open my $out, ">", $out_file
        or error("Can't create $out_file :$!", 1);

    if (@group_keys == 3) {
        # We have 2 dotfiles -> venn with 2 circles
        $venn_template = dist_file("Dot-Parser", "v2_template.svg");
    } elsif (@group_keys == 7) {
        # We have 3 dotfiles -> venn with 3 circles
        $venn_template = dist_file("Dot-Parser", "v3_template.svg");
    } elsif (@group_keys > 7) {
        error("Oops! Something went wrong when doing all the combinations of " .
              "your files. Try changing the names of your files (lowercase, ".
              "remove symbols...)\n Also, consider reporting the bug at:\n" .
              "\thttps://github.com/scastlara/graphcompare/issues", 1);
    }

    my ($grp_to_alias, $alias_to_grp) = assign_aliases($filenames, \@group_keys);
    parse_svg($out, $venn_template, $grp_to_alias, $alias_to_grp, $groups, $grp_to_colors);
    return;
}

#--------------------------------------------------------------------------------
sub assign_aliases {
    my $principal_grps = shift;
    my $group_names    = shift;
    my @group_aliases  = qw(GR1 GR2 GR3);
    my %grp_to_alias   = ();
    my %alias_to_grp   = ();

    # Initialize groups
    foreach my $i (0..$#{$principal_grps}) {
        $grp_to_alias{$principal_grps->[$i]} = $group_aliases[$i];
        $alias_to_grp{$group_aliases[$i]}    = $principal_grps->[$i];

    }

    # Get group combinations
    foreach my $group (@{ $group_names }) {
        next unless $group =~ /\:/;
        my @grp_parts      = split /\:/, $group;
        my @aliases        = map { $grp_to_alias{$_} } @grp_parts;
        my $alias          = join(":", @aliases);

        $grp_to_alias{$group} = $alias;
        $alias_to_grp{$alias} = $group;
    }

    return(\%grp_to_alias, \%alias_to_grp);
}

#--------------------------------------------------------------------------------
sub parse_svg {
    my $out_filehandle = shift;
    my $template       = shift;
    my $grp_to_alias   = shift;
    my $alias_to_grp   = shift;
    my $grp_numbers    = shift;
    my $grp_to_colors  = shift;

    open my $t_fh, "<", "$template"
        or error ("Can't open $template, is your installpath correct? :$!");

    local $/ = ">DATAHERE";
    my $first = <$t_fh>;
    chomp $first;
    print $out_filehandle "$first\n";

    while (<$t_fh>) {
        chomp;
        my ($element, $code, $rest) = split /&&/;
        my $grp_name = $alias_to_grp->{$code};

        if ($element eq "NODES") {
            print $out_filehandle "$grp_numbers->{$grp_name}->{nodes} $rest";
        } elsif ($element eq "INTERACTIONS") {
            print $out_filehandle "$grp_numbers->{$grp_name}->{ints} $rest";
        } elsif ($element eq "NAME") {
            print $out_filehandle "$alias_to_grp->{$code} $rest";
        } else {
            print $out_filehandle "$grp_to_colors->{$grp_name}$rest";
        }
    }

    return;
}


# WEB OUTPUT
#--------------------------------------------------------------------------------
sub create_json {
    my $nodes          = shift;
    my $interactions   = shift;
    my $grps_to_colors = shift;
    my $json = "nodes: [\n";

    foreach my $node (keys %{$nodes}) {
        $json .= "\t{ data: { id: '$node', name: '$node', colorNODE: " .
                 "\'$grps_to_colors->{ $nodes->{$node} }\'}},\n";
    }

    $json .= "],\n edges: [\n";

    foreach my $int (keys %{$interactions}) {
        my ($source, $target) = split /::\->::/, $int;
        $json .= "\t{ data: { id: '$source-$target', " .
                 "source: '$source', target: '$target', ".
                 "colorEDGE: \'$grps_to_colors->{ $interactions->{$int} }\' }},\n";
    }

    $json .= "]\n";

    return(\$json);
}

#--------------------------------------------------------------------------------
sub create_ctable {
    my $grps_to_colors = shift;
    my $table          = "";

    foreach my $group (sort keys %{$grps_to_colors}) {
        $table .= "\t<tr><td bgcolor=\"$grps_to_colors->{$group}\">" .
                  "$group</td></tr>\n";
    }

    return($table);
}

#--------------------------------------------------------------------------------
sub print_html {
    my $filename       = shift;
    my $json           = shift;
    my $color_table    = shift;
    my $template       = dist_file("Dot-Parser", "cyt.template");

    local $/ = ">DATAHERE";

    open my $tt_fh, "<", $template
        or error("Can't open $template, is your installpath correct? :$!", 1);

    open my $out_fh, ">", $filename
        or error("Can't create $filename : $!", 1);

    foreach my $element ("", $$json, $color_table) {
        my $html = <$tt_fh>;
        chomp $html;
        print $out_fh $element, $html;
    }

    return;
}


# GRAPH CONNECTIVITY
#--------------------------------------------------------------------------------
sub load_graphs {
    my $interactions = shift;
    my $nodes        = shift;
    my %graphs       = ();

    # Initialized merged graph
    $graphs{"MERGED"} = Graph::Directed->new;

    # Fill graphs with nodes and edges
    foreach my $element ($interactions, $nodes) {
        foreach my $rel (keys %{$element}) {
            my ($src, $trg) = split /::\->::/, $rel;
            my @files = split /:/, $element->{$rel};

            foreach my $file (@files) {

                if (not exists $graphs{$file}) {
                    $graphs{$file} = Graph::Directed->new;
                }

                if ($trg) {
                    $graphs{$file}->add_edge($src, $trg);
                    $graphs{"MERGED"}->add_edge($src, $trg);
                } else {
                    $graphs{$file}->add_vertex($src);
                    $graphs{"MERGED"}->add_vertex($src) ;
                }

            }
        }
    }

    # It returns a hash of graph objects with
    # the names of the DOT files as keys
    return(\%graphs);
}

#--------------------------------------------------------------------------------
sub print_attributes {
    my $name  = shift;
    my $graph = shift;

    my $node_num    = $graph->unique_vertices;
    my $rel_num     = $graph->unique_edges;
    my $diameter    = $graph->diameter;
    my $avg_plength = sprintf("%.3f", $graph->average_path_length);
    my $gamma       = sprintf("%.3f", $graph->clustering_coefficient);
    my $avg_degree  = $graph->average_degree;

    print STDERR "#\t$name\n";
    print STDERR "#\t   Number of nodes                = $node_num\n";
    print STDERR "#\t   Number of edges                = $rel_num\n";
    print STDERR "#\t   Average degree                 = $diameter\n";
    print STDERR "#\t   Diameter (longest path)        = $diameter\n";
    print STDERR "#\t   Average shortest path          = $avg_plength\n";
    print STDERR "#\t   Clustering coefficient         = $gamma\n";
    print STDERR "\n";

    return;
}


# SCRIPT FUNCTIONS
#--------------------------------------------------------------------------------
sub error {
    my $string = shift;
    my $fatal  = shift;
    my @lines = split /\n/, $string;

    my $error_msg = $fatal ? "FATAL" : "MINOR";
    print STDERR "\n# [$error_msg ERROR]\n";
    print STDERR "# $_\n" foreach (@lines);

    if ($fatal) {
        print STDERR "\n\n# Use graphcompare -h to get help.\n\n";
        exit(1);
    } else {
        print STDERR "\n\n";
    }

}

__END__
