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


#===============================================================================
# VARIABLES 
#===============================================================================
our $INSTALL_PATH  = "./"; # SET THIS TO YOUR INSTALLPATH


my $dot_files     = "";
my $color_profile = "SOFT";
my $help          = "";
my %nodes         = ();
my %interactions  = ();

my $options = GetOptions (
	'help'     => \$help,
	"files=s"  => \$dot_files,    
	"colors=s" => \$color_profile,
);

my @files = split /,/, $dot_files;

help() if $help;

help(
	"\nYou have to introduce at least 2 dot files separated by commas \",\"\n\n". 
    "\tperl DOTCompare.pl -f file1,file2,file3..."
    ) unless @files >= 2;


#===============================================================================
# MAIN LOOP 
#===============================================================================

# READ DOT FILES
@files = sort @files;
foreach my $file (@files) {
	read_dot($file, \%nodes, \%interactions);
}

# COLORS AND COUNTS
my %groups = initialize_hash(\@files);
my $colors = load_colors($color_profile);
my $g_to_c = assign_colors($colors,\%groups);


# COUNT NODES AND INTERACTIONS IN GROUPS
count_nodeints(\%nodes, \%groups, "nodes");
count_nodeints(\%interactions, \%groups, "ints");

print STDERR "GROUP\tNODES\tINTERACTIONS\n";
foreach my $group (keys %groups) {
	print STDERR $group, "\t", 
	             $groups{$group}->{nodes}, "\t", 
	             $groups{$group}->{ints}, "\n";
}


# WRITE DOT FILE
print "digraph ALL {\n";

write_dot(\%nodes, $g_to_c, "NODES");
write_dot(\%interactions, $g_to_c, "INTERACTIONS");

print "}";

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
sub initialize_hash {
	
	my $files_array = shift;
	my %count_hash  = ();
	my @g_list = ();

	@{$files_array} = map {clean_name($_)} @{$files_array};

	foreach my $idx (1..@{$files_array} ) {
		my $iter = combinations($files_array, $idx);

		while (my $c = $iter->next) {
			my @sorted = sort @$c;
			$count_hash{join ":",@sorted}->{nodes} = 0;
			$count_hash{join ":",@sorted}->{ints} = 0;
		} # while

	} # foreach

	return (%count_hash);

} # sub initialize_hash


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
sub write_dot {
	my $in_data = shift;
	my $g_to_c  = shift;
	my $string  = shift;

	print "// $string\n";

	foreach my $datum (keys %{ $in_data }) {
		print "\t", $datum, "\t", 
		      "[color=\"$g_to_c->{ $in_data->{$datum} }\"]", "\t", 
		      "// $in_data->{$datum}", "\n";
	}

	return;
}


#--------------------------------------------------------------------------------
sub help {
	my $err = shift;
	print STDERR << 'EOF';

||--------------------------------------------------------------------------------||
||  This script compares two or more DOT files and prints the resulting merged    ||
||  DOT file with different colors (to STDOUT).                                   ||
||                                                                                ||
||                                                                                ||
||  Usage:                                                                        ||
||  	perl DOTCompare.pl <options>                                              ||
||                                                                                ||
||  Options:                                                                      ||
||                                                                                ||
||  	REQUIRED:                                                                 ||
||  	--files<file>          - Graph files in DOT format, separated by commas   ||
||                                                                                ||
||  	OPTIONAL:                                                                 ||
||  	--colors <string>      - Color profile: SOFT (default), HARD or LARGE     ||
||                                                                                ||
||--------------------------------------------------------------------------------||

EOF
;

	print "\n\n### ERROR\n", $err, "\n\n" if $err;
	exit(0);
} # sub help



