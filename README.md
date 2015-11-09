### NAME

dotcompare - A program to compare DOT files

### VERSION

v0.1.3

### SYNOPSIS

    dotcompare  --files file1.dot,file2.dot \\  
                --colors HARD               \\   
                --dot output.dot            \\               
                --venn venn.svg             \\ 
                --sub subgraphs             \\ 
                --cyt graph.html               

### DESCRIPTION

This script compares two or more DOT files and 
prints the resulting merged DOT file with different 
colors for each group. 

Dotcompare has some optional outputs: an svg venn 
diagram, an html file that contains a 
representation of the resulting merged graph, a 
table with the counts and a plot with information
about the subgraphs within each DOT file.

### OPTIONS

- **-h**, **--help**               

    Shows this help. 

- **-f**, **--files** &lt;file1,file2,...>

    REQUIRED. Input DOT files, separated by commas.    

- **-d**, **--dot** &lt;filename.dot>

    Creates a merged dot file. Default to STDOUT.

- **-c**, **--colors** &lt;profile>

    Color profile to use: SOFT (default), HARD, LARGE or CBLIND.

- **-v**, **--venn** &lt;filename.svg>

    Creates a venn diagram with the results. 

- **-w**, **--web** &lt;filename.html>

    Writes html file with the graph using cytoscape.js

- **-s**, **--sub** &lt;filename>

    Creates an svg plot comparing the subgraphs in each DOT.

### AUTHOR

Sergio Castillo Lara - s.cast.lara@gmail.com

### BUGS AND PROBLEMS

#### Current Limitations

\- This program still can't handle multiple line comments in DOT files.

\- Only works with directed graphs.

\- Still no clusters support eg: {A B C} -> D

\- No support for multiline IDs.

#### Reporting Bugs

Report Bugs to https://github.com/scastlara/dotcompare or s.cast.lara@gmail.com

### COPYRIGHT 

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
