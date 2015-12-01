# NAME

dotcompare - A program to compare DOT files

# VERSION

v0.4.1

# SYNOPSIS

    dotcompare  --files file1.dot,file2.dot \\  
                --stats                     \\
                --colors HARD               \\   
                --dot output.dot            \\   
                --table table.tbl           \\ 
                --venn venn.svg             \\ 
                --web graph.html               

# DESCRIPTION

This script compares two or more DOT (graphviz) files and 
prints the resulting merged DOT file with different 
colors for each group. To read the dotfiles, dotcompare uses the module
Dot::Parser, located in lib/

By default, dotcompare will print the resulting graph to
STDOUT, but you can change it with the option -o (see options below).

Dotcompare has some optional outputs, each one specified by one 
option.

- **Venn diagram** 

    If given the option -v, dotcompare will create an
    svg file containing a venn diagram. In this image, you will be able to see
    a comparison of the counts of nodes and relationships in each input DOT file,
    and those nodes/relationships common to more than one file. The colors will be
    chosen using one of the profiles in data/colors.txt. By default, the color palette
    is set to be "SOFT". To change it, use the option -c (see options below).

- **Table**. 

    Complementary to the venn diagram, one can choose to create a 
    table containing all the counts (so it can be used to create other plots or tables). The 
    table is already formated to be used by R. Load it to a dataframe using:

            df <-read.table(file="yourtable.tbl", header=TRUE)

- **Webpage with the graph**. 

    With the option -w, one can create a webpage
    with a representation of the merged graph (with different colors for nodes and 
    relationships depending on their presence in each DOT file). To make this representation,
    dotcompare uses the Open Source library cytoscape.js. All the cytoscape.js code is
    embedded in the html file to allow maximum portability: the webpage and the graph work
    without any external file/script dependencies. This allows for an easy upload of the graph
    to any website.

# INSTALLATION

    perl Makefile.PL
    make
    make test
    make install

It is important to note that if you decide to install dotcompare manually, the script needs to use File::Share to find
the templates. If you choose to not use the Makefile.PL installer, you may encounter some bugs, as dotcompare will be unable to open
the templates.

# DIRECTORIES

These are the directories and the files inside the distribution:

- **bin/**

    This directory contains the main script: dotcompare.

- **lib/**

    Here we can find the module Dot::Parser. To see an explanation about how it works, refer to the POD documentation
    in the script using:

        perldoc lib/Dot/Parser.pm

- **share/**

    Here we can find the templates dotcompare uses to create the svg venn diagrams and the html output. We can also find
    some test files, test1.dot, test2.dot and test3.dot to try out the program.

- **t/** 

    This is the directory with the test files and the script that runs the tests (parser.t).

- **Makefile.PL**

    This is the script that uses ExtUtils::MakeMaker to create a Makefile to install the distribution.

- **MANIFEST**

    List of all the files of the distribution.

# OPTIONS

- **-h**, **--help**               

    Shows this help. 

- **-i**, **--insensitive** 

    Makes dotocompare case insensitive. By default, dotcompare is case sensitive.  

- **-s**, **--stats** 

    Prints to STDERR some graph properties for each DOT file. It can be time consuming if the
    input graphs are very big.

- **-f**, **--files** &lt;file1,file2,...>

    REQUIRED. Input DOT files, separated by commas.    

- **-o**, **--out** &lt;filename.dot>

    Saves the merged dot file to the specified file. Default to STDOUT.

- **-c**, **--colors** &lt;profile>

    Color profile to use: SOFT (default), HARD, LARGE or CBLIND.

- **-v**, **--venn** &lt;filename.svg>

    Creates a venn diagram with the results. 

- **-w**, **--web** &lt;filename.html>

    Writes html file with the graph using cytoscape.js

# BUGS AND PROBLEMS

## Current Limitations

- _Undirected\_graphs_ 

    Only works with directed graphs. If undirected, 
    dotcompare considers them to be directed.

- _Clusters_ 

    Still no clusters support e.g. {A B C} -> D

- _Multiline\_IDs_ 

    No support for multiline IDs.

- _No\_escaped\_quotes_

    No support for quotes in node IDs (even if properly escaped).

- _Compass\_ports_ 

    No support for compass ports.

# DEPENDENCIES

- File::ShareDir::Install
- File::Share
- Test::More
- Pod::Usage
- Cwd
- Graph (only if using option -s)
- AutoLoader (if comparing more than 5 files)    
- Color::Spectrum::Multi (if comparing more than 5 files)    

# AUTHOR

Sergio Castillo Lara - s.cast.lara@gmail.com

## Reporting Bugs

Report Bugs at _https://github.com/scastlara/dotcompare/issues_ (still private)

# COPYRIGHT 

    (C) 2015 - Sergio CASTILLO LARA

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
