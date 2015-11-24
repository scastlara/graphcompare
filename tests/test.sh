#!/usr/bin/env bash

# Directory of the test script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";

#-------------------------------------
# TESTING
ERROR=0;

# DOT PARSING
#-------------------------------------
echo;
echo "# Testing DOT parser...";

# Create dot
perl $DIR/../dotcompare.pl \
-f $DIR/Thehard.dot -T > $DIR/Thehard_result.tmp 2> /dev/null

# TWO DOT FILES
if diff -q $DIR/Thehard_result.tmp $DIR/Thehard_result.dot > /dev/null ; then
    echo "parsing DOT file... ok";
else
    ((ERROR++));
    echo "parsing DOT file... not ok";
fi;



# COUNTS
#-------------------------------------
echo;
echo "# Testing dotcompare counts...";

# CREATE NEW TABLES
# 2table
perl $DIR/../dotcompare.pl \
-f $DIR/test1.dot,$DIR/test2.dot \
-t $DIR/2table.tmp -T >/dev/null 2> /dev/null;
# 3table
perl $DIR/../dotcompare.pl \
-f $DIR/test1.dot,$DIR/test2.dot,$DIR/test3.dot \
-t $DIR/3table.tmp -T >/dev/null 2> /dev/null;


# TWO DOT FILES
if diff -q $DIR/2table.tmp $DIR/2table.tbl > /dev/null ; then
    echo "count 2 DOT files... ok";
else
    ((ERROR++));
    echo "count 2 DOT files... not ok"
fi;

# THREE DOT FILES
if diff -q $DIR/3table.tmp $DIR/3table.tbl > /dev/null ; then
    echo "count 3 DOT files... ok";
else
    ((ERROR++));
    echo "count 3 DOT files... not ok"
fi;


# SVGs
#-------------------------------------
echo;
echo "# Testing dotcompare venn svg output...";

# CREATE NEW SVGs
# 2svg
perl $DIR/../dotcompare.pl \
-f $DIR/test1.dot,$DIR/test2.dot \
-v $DIR/2svg.tmp -T >/dev/null 2> /dev/null;
# 3svg
perl $DIR/../dotcompare.pl \
-f $DIR/test1.dot,$DIR/test2.dot,$DIR/test3.dot \
-v $DIR/3svg.tmp -T >/dev/null 2> /dev/null;

# TWO DOT FILES
if diff -q $DIR/2svg.tmp $DIR/2svg.svg > /dev/null ; then
    echo "svg 2 DOT files... ok";
else
    ((ERROR++));
    echo "svg 2 DOT files... not ok"
fi;

# THREE DOT FILES
if diff -q $DIR/3svg.tmp $DIR/3svg.svg > /dev/null ; then
    echo "svg 3 DOT files... ok";
else
    ((ERROR++));
    echo "svg 3 DOT files... not ok"
fi;


# REMOVE FILES
#-------------------------------------
rm $DIR/2table.tmp;
rm $DIR/3table.tmp;
rm $DIR/2svg.tmp;
rm $DIR/3svg.tmp;
rm $DIR/Thehard_result.tmp;

echo;
if [ $ERROR -ne 0 ]; then
    echo "Something went wrong: $ERROR errors";
else 
    echo "Everything is fine: $ERROR errors";
fi;
echo;