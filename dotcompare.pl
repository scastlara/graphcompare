#!/usr/bin/perl
#################################################################################
#                               dotcompare                                      #
#################################################################################
# Copyright (C) 2015 - Sergio CASTILLO LARA
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.


#===============================================================================
# MODULES
#===============================================================================
use warnings;
use strict;
use Getopt::Long;
use Algorithm::Combinatorics qw(combinations);
use Cwd 'abs_path';


#===============================================================================
# VARIABLES AND OPTIONS
#===============================================================================
our $PROGRAM       = "dotcompare";
our $VERSION       = 'v0.1.0';
our $USER          = $ENV{ USER };
our $INSTALL_PATH  = get_installpath(); 
our $MAIL          = 's.cast.lara@gmail.com';

error("Error trying to find Installation path through \$0 : $INSTALL_PATH")
    unless $INSTALL_PATH;

my $dot_files     = "";
my $help          = "";
my $venn          = "";
my $table         = "";
my $debug         = "";
my $web           = "";
my $color_profile = "SOFT";
my $out_name      = "STDOUT";
my %nodes         = ();
my %interactions  = ();

my $options = GetOptions (
    'help'     => \$help,
    "files=s"  => \$dot_files,    
    "colors=s" => \$color_profile,
    "out=s"    => \$out_name,
    "table=s"  => \$table,
    "venn=s"   => \$venn,
    "web=s"    => \$web,
    "debug"    => \$debug
);

my @files = split /,/, $dot_files;

help() if $help;

unless (@files > 0) {
    error("You have to introduce at least 1 dot file \n\n\t" . 
          'perl DOTCompare.pl -f file1,file2,file3...'
         );
}


#===============================================================================
# MAIN
#===============================================================================

# START REPORT
my $start_time   = time();
my $current_time = localtime();
print STDERR "\nPROGRAM STARTED\n",
             "\tProgram         $PROGRAM\n",
             "\tVersion         $VERSION\n",
             "\tUser            $USER\n",
             "\tInstallpath     $INSTALL_PATH\n",
             "\tColor Profile   $color_profile\n",
             "\tInput files     ", join("\n\t\t\t", @files), "\n\n",
             "\tStart time      $current_time\n\n";
#--

# READ DOT FILES
@files = sort @files;
foreach my $file (@files) {
    read_dot($file, \%nodes, \%interactions);
}

# COLORS AND COUNTS
my $groups           = initialize_groups(\@files);
my $colors           = load_colors($color_profile);
my $groups_to_colors = assign_colors($colors,$groups);

# COUNT NODES AND INTERACTIONS IN GROUPS
count_nodeints(\%nodes, $groups, "nodes");
count_nodeints(\%interactions, $groups, "ints");

# WRITE DOT FILE
my $out_fh = get_fh($out_name);
print $out_fh "digraph ALL {\n";
write_dot($out_fh, \%nodes, $groups_to_colors, "NODES");
write_dot($out_fh, \%interactions, $groups_to_colors, "INTERACTIONS");
print $out_fh "}";

# OPTIONAL OUTPUTS
if ($table) {
    results_table($table, $groups);
}

if ($venn) {
    print_venn($venn, $groups, \@files, $groups_to_colors);
}

if ($web) {
    my $json        = create_json(\%nodes, \%interactions, $groups_to_colors); 
    my $color_table = create_ctable($groups_to_colors);
    print_html($web, $json, $color_table);
}

# END REPORT
my $end_time  = time();
$current_time = localtime();
my $run_time  = sprintf("%.2f", (($end_time - $start_time) / 3600));
my @out_files = grep {$_} ($out_name, $table, $venn, $web);
print STDERR "PROGRAM FINISHED\n",
             "\tOutput files \t", join("\n\t\t\t", @out_files), "\n\n",
             "\tEnd time \t$current_time\n\n",
             "\tJob took ~ $run_time hours\n\n"; 
#--

# DEBUGGING
if ($debug) {
    use Data::Dumper;
    print STDERR Data::Dumper->Dump([$groups,   $groups_to_colors], 
                                    [("GROUPS", "GROUPS_2_COLORS") ]), "\n";
}


#===============================================================================
# FUNCTIONS 
#===============================================================================

# READING DOT FILES
#--------------------------------------------------------------------------------
sub read_dot {
    my $dot          = shift;
    my $nodes        = shift;
    my $interactions = shift;
    my $dot_symbol   = clean_name($dot);

    open my $dot_fh, "<", $dot
        or error("Can't open dot file $dot: $!");

    while (<$dot_fh>) {
        chomp;
        next if ($_ =~ m/graph/ or $_=~ m/node/ or $_=~ m/{|}/);

        if ($_ =~ m/\->/g) { 
        # interactions "node1"->"node2"->"node3"
            $_ =~ s/\"//g;
            $_ =~ s/\;//g;
            $_ =~ s/\s?//g;
            $_ =~ s/\[.+//gi;

            my @genes = split /\->/, $_;

            add_nodes(\@genes, $nodes, $dot_symbol);
            add_interactions(\@genes,$interactions,$dot_symbol);
            
        } else { 
        # just defined nodes
            if ($_ =~ m/\"(\w+)\"/) {
                my @genes = ($1);
                add_nodes(\@genes, $nodes, $dot_symbol);
            } # if match
        
        } # if node or interaction

    } # while file

    return;
}

#--------------------------------------------------------------------------------
sub clean_name {
    my $file_name = shift;
    my $cleaned   = $file_name;

    $cleaned =~ s/\.dot//g; 
    $cleaned =~ s/.+\///; 

    return($cleaned);
} 

#--------------------------------------------------------------------------------
sub add_nodes {
    my $gene_list  = shift;
    my $nodes      = shift;
    my $dot_symbol = shift;

    foreach my $gene (@{$gene_list}) {
        if (exists $nodes->{$gene}) {
            $nodes->{$gene} .= ":$dot_symbol"
                unless $nodes->{$gene} =~ m/\b$dot_symbol\b/;
        } else {
            $nodes->{$gene} = $dot_symbol;
        }
    }

    return;
}

#--------------------------------------------------------------------------------
sub add_interactions {
    my $gene_list    = shift;
    my $interactions = shift;
    my $dot_symbol   = shift;

    foreach my $i (0..$#{$gene_list} - 1) {
        my $string = $gene_list->[$i]."->".$gene_list->[$i+1];

        if (exists $interactions->{$string}) {
            $interactions->{$string} .= ":$dot_symbol"
                unless $interactions->{$string} =~ m/\b$dot_symbol\b/;
        } else {
            $interactions->{$string} = $dot_symbol;
        }
        
    } # #foreach

    return;
}


# COLORS AND GROUPS
#--------------------------------------------------------------------------------
sub initialize_groups {
    my $files_array = shift;
    my %count_hash  = ();

    @{$files_array} = map {clean_name($_)} @{$files_array};

    foreach my $idx (1..@{$files_array} ) {
        my $iter = combinations($files_array, $idx);

        while (my $combi = $iter->next) {
            my @sorted = sort @$combi;
            $count_hash{join ":",@sorted}->{nodes} = 0;
            $count_hash{join ":",@sorted}->{ints} = 0;
        } # while

    } # foreach

    return (\%count_hash);

} 

#--------------------------------------------------------------------------------
sub load_colors {
    my $profile = shift;
    my @colors  = ();
    local $/ = "//";

    open my $fh, '<', "$INSTALL_PATH/data/colors.txt"
        or error("Can't open $INSTALL_PATH/data/colors.txt,". 
                 " is your installpath correct? :$!");

    while (<$fh>) {
        chomp;
        my ($name, @prof_colors) = split /\n/;
        next unless $profile eq $name;
        @colors = @prof_colors;
    }

    unless (@colors) {
        error(
              "\nYour profile \"$profile\" doesn't exist!\n".
              "Choose one of the following:\n\n". 
              "\t- SOFT\n".
              "\t- HARD\n" .
              "\t- LARGE\n"
              );
    }

    return \@colors;
}

#--------------------------------------------------------------------------------
sub assign_colors {
    my $colors = shift;
    my $groups = shift;
    my %g_to_c = ();

    error("There are more groups than colors!")
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


# DOT OUTPUT
#--------------------------------------------------------------------------------
sub get_fh {
    my $filename = shift;
    my $out_fh;

    if ($filename eq "STDOUT") {
        $out_fh =\*STDOUT
    } else {
        open $out_fh, ">", $filename
            or error("Can't write to $filename : $!");
    }

    return($out_fh);
}

#--------------------------------------------------------------------------------
sub write_dot {
    my $fhandle = shift;
    my $in_data = shift;
    my $g_to_c  = shift;
    my $string  = shift;

    print $fhandle "// $string\n";

    foreach my $datum (keys %{ $in_data }) {
        print $fhandle "\t", $datum, "\t", 
                       "[color=\"$g_to_c->{ $in_data->{$datum} }\"]", "\t", 
                       "// $in_data->{$datum}", "\n";
    }

    return;
}


# TABLE OUTPUT
#--------------------------------------------------------------------------------
sub results_table {
    my $out_file = shift;
    my $groups   = shift;

    open my $fh, '>', "$out_file"
        or error("Can't create results.tbl : $!");

    print $fh "GROUP\tNODES\tINTERACTIONS\n";
    foreach my $group (keys %{$groups}) {
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
        or error("Can't create $out_file :$!");

    if (@group_keys == 3) {
        # We have 2 dotfiles -> venn with 2 circles
        $venn_template = "$INSTALL_PATH/data/v2_template.svg";
    } elsif (@group_keys == 7) {
        # We have 3 dotfiles -> venn with 3 circles
        $venn_template = "$INSTALL_PATH/data/v3_template.svg";
    } else {
        print STDERR "You have more than 3 dot files (or less than 2), ", 
                     "I won't draw any venn diagram.\n", 
                     "I suggest you to use the option -t to print a ",
                     "table with the results\n";
        return;
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
    my $nodes        = shift;
    my $interactions = shift;
    my $grps_to_colors = shift;
    my $json = "nodes: [\n";

    foreach my $node (keys %{$nodes}) {
        $json .= "\t{ data: { id: '$node', name: '$node', colorNODE: " . 
                 "\'$grps_to_colors->{ $nodes->{$node} }\'}},\n";
    }

    $json .= "],\n edges: [\n";

    foreach my $int (keys %{$interactions}) {
        my ($source, $target) = split /\->/, $int;
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
    my $template       = "$INSTALL_PATH/data/cyt.template";

    local $/ = ">DATAHERE";

    open my $tt_fh, "<", $template
        or error("Can't open $template, is your installpath correct? :$!");

    open my $out_fh, ">", $filename
        or error("Can't create $filename : $!");

    foreach my $element ("", $$json, $color_table) {
        my $html = <$tt_fh>;
        chomp $html;
        print $out_fh $element, $html;
    }

    return;
}


# SCRIPT FUNCTIONS
#--------------------------------------------------------------------------------
sub error {
    my $string = shift;

    die "\n[ERROR] $string\n",
        "\nUse dotcompare -h to get help.\n\n";
}

#--------------------------------------------------------------------------------
sub get_installpath {
    my $path = abs_path($0);
    $path =~ s/(.+)\/.*?$/$1\//;
    return($path);
}

#--------------------------------------------------------------------------------
sub help {
    print STDERR << "EOF";


NAME            dotcompare

VERSION         $VERSION

SYNOPSIS        dotcompare [options]

DESCRIPTION     This script compares two or more DOT files    
                and prints the resulting merged DOT file      
                with different colors.        
                                   
OPTIONS

    --help      Shows this help.                       
    --files     <file#,file#> REQUIRED. Input DOT files, separated by commas.            
    --dot       <filename.dot> Creates a merged dot file. Default to STDOUT.
    --colors    <profile> Color profile to use: SOFT (default), HARD or LARGE.
    --venn      <filename.svg> Creates venn diagram with the results. 
    --web       <filename.html> Writes html file with the graph using cytoscape.js

EXAMPLE                                      
                                                
    dotcompare  --files file1.dot,file2.dot \\  
                --colors HARD               \\   
                --dot output.dot            \\               
                --venn venn.svg             \\  
                --cyt graph.html               
                                              
BUGS
    Report bugs to Sergio CASTILLO LARA: $MAIL

    Copyright (C) 2015 - S. CASTILLO LARA

EOF
;

    exit(0);
}
