#!/usr/bin/perl
#
#################################################################################
#                               dotcompare.pl									#
#################################################################################
#
# This script compares interactions in different dot files.
#

use warnings;
use strict;
use Getopt::Long;
use Algorithm::Combinatorics qw(combinations);
use Cwd 'abs_path';

#===============================================================================
# VARIABLES 
#===============================================================================
our $INSTALL_PATH  = get_installpath(); 

die "Error trying to find Installpath through \$0\n\n"
	unless $INSTALL_PATH;

my $dot_files     = "";
my $color_profile = "SOFT";
my $help          = "";
my $debug         = "";
my $venn          = "";
my $out_name      = "STDOUT";
my %nodes         = ();
my %interactions  = ();

my $options = GetOptions (
	'help'     => \$help,
	"files=s"  => \$dot_files,    
	"colors=s" => \$color_profile,
	"out=s"    => \$out_name,
	"venn=s"   => \$venn,
	"debug"    => \$debug
);

my @files = split /,/, $dot_files;

help() if $help;

help(
	"\nYou have to introduce at least 2 dot files separated by commas \",\"\n\n". 
    "\tperl DOTCompare.pl -f file1,file2,file3..."
    ) unless @files >= 2;


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

# RESULTS TO TERMINAL
results_table($groups);

# WRITE DOT FILE
my $out_fh = get_fh($out_name);

#print $out_fh "digraph ALL {\n";
#write_dot($out_fh, \%nodes, $groups_to_colors, "NODES");
#write_dot($out_fh, \%interactions, $groups_to_colors, "INTERACTIONS");
#print $out_fh "}";


if ($venn) {
	print_venn($venn, $groups);
}

# END TIME
my $end_time  = time();
my $run_time = sprintf("%.2f", (($end_time - $start_time) / 3600));
print_status($run_time, "PROGRAM FINISHED");
#--

if ($debug) {
	use Data::Dumper;
	print STDERR "GROUPS:  ", Dumper($groups);
	print STDERR "COLORS:  ", Dumper($colors);
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
		or die "\n\n## ERROR\n", 
		       "Can't open dot file $dot: $!\n";

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
		or die "Can't open $INSTALL_PATH/data/colors.txt\n", 
		       "Are you sure your install path is correct?\n";

	while (<$fh>) {
		chomp;
		my ($name, @prof_colors) = split /\n/;
		next unless $profile eq $name;
		@colors = @prof_colors;
	}

	help(
		"\nYour profile \"$profile\" doesn't exist!\n".
		"Choose one of the following:\n\n". 
   		"\t- SOFT\n".
   		"\t- HARD\n\n"
    ) unless @colors;

   	return \@colors;
}

#--------------------------------------------------------------------------------
sub assign_colors {
	my $colors = shift;
	my $groups = shift;
	my %g_to_c = ();

	help("There are more groups than colors!")
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
		or die "Can't create results.tbl\n";

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
	$path =~ s/\/dotcompare\.pl$/\//;
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
			or die "Can't write to $filename : $!\n";
	}

	return($out_fh);
}

#--------------------------------------------------------------------------------
sub print_venn {
	my $out_file      = shift;
	my $groups        = shift;
	my $venn_template = "";
	my @keywords      = ();
	my @group_keys    = keys %{$groups}; 
	use Data::Dumper;

	if (@group_keys == 3) {
		# We have 2 dotfiles -> venn with 2 circles
		$venn_template = "$INSTALL_PATH/data/v2_template.svg";
		push @keywords, "G11n", "G11i", "G12n", "G12i", "G22n", "G22i";
	} elsif (@group_keys == 6) {
		# We have 3 dotfiles -> venn with 3 circles
		$venn_template = "$INSTALL_PATH/data/v3_template.svg";
	} else {
		print STDERR "You have more than 3 dot files, ", 
		             "I won't draw any venn diagram.\n", 
		             "I suggest you to use the option -t to print a ",
		             "table with the results\n";
		return;
	}
	print Dumper(\@keywords);
}
#--------------------------------------------------------------------------------
sub help {
	my $err = shift;
	print STDERR << 'EOF';



||                  dotcompare                    ||
||------------------------------------------------||
||  This script compares two or more DOT files    ||
||  and prints the resulting merged DOT file      ||
||  with different colors.                        ||
||                                                ||
||                                                ||
||  Usage:                                        ||
||  	dotcompare <options>                      ||
||                                                ||
||                                                ||
||  Options:                                      ||
||                                                ||
||  	REQUIRED:                                 ||
||  	--files file1,file2...                    ||
||              Graph files in DOT format, sepa-  ||
||              rated by commas (no spaces).      ||
||                                                ||
||      --dot filename.dot                        ||
||              Path and name of the output DOT.  ||
||              Default: STDOUT                   ||
||                                                ||
||  	OPTIONAL:                                 ||
||      --help                                    ||
||                                                ||
||  	--colors <string>                         ||
||              Color profile: SOFT (default),    ||
||              HARD or LARGE.                    ||
||                                                ||
||      --venn filename.svg                       ||
||              Path and name of the output venn  ||
||              diagram image (svg format).       ||
||                                                ||
||      --cyt filename.html                       ||
||              Path and name of the graph web-   || 
||              page. It uses cytoscape.js to     ||
||              draw the graph. You can include   ||
||              it on your website by copying the ||
||              files inside js/ on your server   ||
||              and changing the path on the html ||
||              file generated by dotcompare.     ||
||                                                ||
||                                                ||   
||  Example:                                      ||
||                                                ||
||      dotcompare --files file1.dot,file2.dot \  ||
||                 --colors HARD               \  || 
||                 --dot output.dot            \  ||             
||                 --venn venn.svg             \  ||
||                 --cyt graph.html               ||
||                                                ||
||------------------------------------------------||

EOF
;

	print "\n\n### ERROR\n", $err, "\n\n" if $err;
	exit(0);
}



__DATA__
./
