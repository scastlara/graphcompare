#!/usr/bin/env bash

# Directory of the test script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";

# TESTING
echo "";
ERROR=0;

# COUNTS
echo "Testing dotcompare counts...";
echo "";

# CREATE NEW TABLES
# 2table
perl $DIR/../dotcompare.pl \
-f $DIR/iHOP.dot,$DIR/Sparser.dot \
-t $DIR/2table.tmp >/dev/null 2> /dev/null;
# 3table
perl $DIR/../dotcompare.pl \
-f $DIR/AllGraphs.dot,$DIR/iHOP.dot,$DIR/Sparser.dot \
-t $DIR/3table.tmp >/dev/null 2> /dev/null;


# TWO DOT FILES
if diff -q $DIR/2table.tmp $DIR/2table > /dev/null ; then
    echo "count 2 DOT files... ok";
else
    ((ERROR++));
    echo "count 2 DOT files... not ok"
fi;

# THREE DOT FILES
if diff -q $DIR/3table.tmp $DIR/3table > /dev/null ; then
    echo "count 3 DOT files... ok";
else
    ((ERROR++));
    echo "count 3 DOT files... not ok"
fi;
echo;


# SVGs
echo;
echo "Testing dotcompare venn svg output...";
echo;

# CREATE NEW SVGs
# 2svg
perl $DIR/../dotcompare.pl \
-f $DIR/Sparser.dot,$DIR/iHOP.dot \
-v $DIR/2svg.tmp >/dev/null 2> /dev/null;
# 3svg
perl $DIR/../dotcompare.pl \
-f $DIR/AllGraphs.dot,$DIR/iHOP.dot,$DIR/Sparser.dot \
-v $DIR/3svg.tmp >/dev/null 2> /dev/null;

# TWO DOT FILES
if diff -q $DIR/2svg.tmp $DIR/2svg > /dev/null ; then
    echo "svg 2 DOT files... ok";
else
    ((ERROR++));
    echo "svg 2 DOT files... not ok"
fi;

# THREE DOT FILES
if diff -q $DIR/3svg.tmp $DIR/3svg > /dev/null ; then
    echo "svg 3 DOT files... ok";
else
    ((ERROR++));
    echo "svg 3 DOT files... not ok"
fi;



# Remove all temp files
rm $DIR/2table.tmp;
rm $DIR/3table.tmp;
rm $DIR/2svg.tmp;
rm $DIR/3svg.tmp;

echo;
if [ $ERROR -ne 0 ]; then
    echo "Something is wrong: $ERROR number of errors";
else 
    echo "Everything is fine: $ERROR number of errors";
fi;
echo;