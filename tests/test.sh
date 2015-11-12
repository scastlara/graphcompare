#!/usr/bin/env bash

# Directory of the test script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";

# Create new tables
    # 2table
perl $DIR/../dotcompare.pl -f $DIR/iHOP.dot,$DIR/Sparser.dot -t $DIR/2table.tmp >/dev/null 2> /dev/null;
    # 3table
perl $DIR/../dotcompare.pl -f $DIR/AllGraphs.dot,$DIR/iHOP.dot,$DIR/Sparser.dot -t $DIR/3table.tmp >/dev/null 2> /dev/null;


# TESTING
echo "";
echo "Testing dotcompare counts...";
echo "";
ERROR=0;

# TWO DOT FILES
if diff -q $DIR/2table.tmp $DIR/2table > /dev/null ; then
    echo "Two DOT files... ok";
else
    ((ERROR++));
    echo "Two DOT files... not ok"
fi;

# THREE DOT FILES
if diff -q $DIR/3table.tmp $DIR/3table > /dev/null ; then
    echo "Three DOT files... ok";
else
    ((ERROR++));
    echo "Three DOT files... not ok"
fi;
echo "";

# Remove temp files
rm $DIR/2table.tmp;
rm $DIR/3table.tmp;

if [ $ERROR -ne 0 ]; then
    echo "Something is wrong: $ERROR number of errors";
else 
    echo "Everything is fine: $ERROR number of errors";
fi;
echo "";