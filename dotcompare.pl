#!/usr/bin/perl
#################################################################################
#                               dotcompare.pl                                   #
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
our $INSTALL_PATH  = get_installpath(); 
our $VERSION       = 'v0.1.0';
our $MAIL          = 's.cast.lara@gmail.com';

error("Error trying to find Installation path through \$0 : $INSTALL_PATH")
	unless $INSTALL_PATH;

my $dot_files     = "";
my $help          = "";
my $venn          = "";
my $table         = "";
my $debug         = "";
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
	"debug"    => \$debug
);

my @files = split /,/, $dot_files;

help() if $help;

unless (@files >= 2) {
	error("\n" .
		  'You have to introduce at least 2 dot files ' .
		  'separated by commas.' . "\n\n\t" . 
          'perl DOTCompare.pl -f file1,file2,file3...'
          );
}


#===============================================================================
# MAIN
#===============================================================================


# START TIME
my $start_time = time();
print_status(0, "PROGRAM STARTED");
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
#print $out_fh "digraph ALL {\n";
#write_dot($out_fh, \%nodes, $groups_to_colors, "NODES");
#write_dot($out_fh, \%interactions, $groups_to_colors, "INTERACTIONS");
#print $out_fh "}";

# OPTIONAL OUTPUTS
if ($table) {
	results_table($groups);
}

if ($venn) {
	print_venn($venn, $groups, \@files);
}

# END TIME
my $end_time  = time();
my $run_time = sprintf("%.2f", (($end_time - $start_time) / 3600));
print_status($run_time, "PROGRAM FINISHED");
#--

if ($debug) {
	use Data::Dumper;
	print STDERR "GROUPS:  ",        Dumper($groups);
	print STDERR "COLORS:  ",        Dumper($colors);
	print STDERR "GROUPS-COLORS:  ", Dumper($groups_to_colors);
}


#===============================================================================
# FUNCTIONS 
#===============================================================================
#--------------------------------------------------------------------------------
sub read_dot {
	my $dot          = shift;
	my $nodes        = shift;
	my $interactions = shift;
	my $dot_symbol   = clean_name($dot);

	open my $dot_fh, "<", $dot
		or error("\n\n## ERROR\n". 
		       "Can't open dot file $dot: $!");

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
		or error("Can't open $INSTALL_PATH/data/colors.txt\n". 
		       "Are you sure your install path is correct?");

	while (<$fh>) {
		chomp;
		my ($name, @prof_colors) = split /\n/;
		next unless $profile eq $name;
		@colors = @prof_colors;
	}

	error(
		"\nYour profile \"$profile\" doesn't exist!\n".
		"Choose one of the following:\n\n". 
   		"\t- SOFT\n".
   		"\t- HARD\n"
    ) unless @colors;

   	return \@colors;
}

#--------------------------------------------------------------------------------
sub assign_colors {
	my $colors = shift;
	my $groups = shift;
	my %g_to_c = ();

	error("There are more groups than colors!")
		if (keys %{$groups} > @{$colors});

	
	foreach my $group (keys %{ $groups }) {
		$g_to_c{$group} = shift @{$colors};
	}

	return(\%g_to_c);
}

#--------------------------------------------------------------------------------
sub add_nodes {
	my $gene_list  = shift;
	my $nodes      = shift;
	my $dot_symbol = shift;

	foreach my $gene (@{$gene_list}) {
		if (exists $nodes->{$gene}) {
			$nodes->{$gene} .= ":$dot_symbol"
				unless $nodes->{$gene} =~ m/$dot_symbol/;
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
				unless $interactions->{$string} =~ m/$dot_symbol/;
				 # What will happen if one name is inside the other?
				 # Maybe I should use \b$dotsymbol\b. If I compare
				 # a file name FILE1ASDF with a file named FILE1
				 # this program will not work properly.

		} else {
			$interactions->{$string} = $dot_symbol;
		}
		
	} # #foreach

	return;
}

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
sub results_table {
	my $groups = shift;

	# REMEMBER: THIS FILENAME HAS TO CHANGE TO results_dotfilename.tbl
	# DO NOT FORGET IT!

	open my $fh, '>', "results.tbl"
		or error("Can't create results.tbl : $!");

	print $fh "GROUP\tNODES\tINTERACTIONS\n";
	foreach my $group (keys %{$groups}) {
		print $fh    $group, "\t", 
	                 $groups->{$group}->{nodes}, "\t", 
	                 $groups->{$group}->{ints}, "\n";
	}

	return;
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

#--------------------------------------------------------------------------------
sub print_status {
	my $run_time      = shift;
	my $string        = shift;
	my $current_time  = localtime();

	print STDERR "#\n####### $string #######\n", 
                 "# Local time: $current_time\n#\n";

	if ($string eq "PROGRAM FINISHED") {
		print STDERR "# Job took ~ $run_time hours\n#\n";
		# Add all the filenames here! 
	}

	return;
}

#--------------------------------------------------------------------------------
sub get_installpath {
	my $path = abs_path($0);
	$path =~ s/(.+)\/.*?$/$1\//;
	return($path);
}

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
sub print_venn {
	my $out_file      = shift;
	my $groups        = shift;
	my $filenames     = shift;
	my @group_keys    = keys %{$groups}; 
	my $venn_template = "";

	my ($grp_to_alias, $alias_to_grp) = assign_aliases($filenames, \@group_keys);

	if (@group_keys == 3) {
		# We have 2 dotfiles -> venn with 2 circles
		$venn_template = "$INSTALL_PATH/data/v2_template.svg";
	} elsif (@group_keys == 7) {
		# We have 3 dotfiles -> venn with 3 circles
		$venn_template = "$INSTALL_PATH/data/v3_template.svg";
	} else {
		print STDERR "You have more than 3 dot files, ", 
		             "I won't draw any venn diagram.\n", 
		             "I suggest you to use the option -t to print a ",
		             "table with the results\n";
		return;
	}

	parse_svg($venn_template, $grp_to_alias, $alias_to_grp);
	return;
}

#--------------------------------------------------------------------------------
sub parse_svg {
	# UNDER CONSTRUCTION

}

#--------------------------------------------------------------------------------
sub assign_aliases {
	my $principal_grps = shift;
	my $group_names    = shift;
	my @group_aliases  = qw(GR1 GR2 GR3);
	my %grp_to_alias   = ();
	my %alias_to_grp   = ();

	# Initialie groups
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
sub error {
	my $string = shift;

	die "$string\n",
	    "\nUse dotcompare -h to get help.\n\n";
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

    --help          Shows this help.                       
    --files         <file#,file#> REQUIRED. Input DOT files, separated by commas.            
    --dot           <filename.dot> Creates a merged dot file. Default to STDOUT.
    --colors        <profile> Color profile to use: SOFT (default), HARD or LARGE.
    --venn          <filename.svg> Creates venn diagram with the results. 
    --cyt           <filename.html> Writes html file with the graph using cytoscape.js

EXAMPLE                                      
                                                
    dotcompare --files file1.dot,file2.dot \\  
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



__DATA__
./
