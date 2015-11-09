#!/usr/bin/env bash

# Set the install and executable directory to whatever you want
# You will need root privileges to install dotcompare using this 
# script. If you don't have them, you may need to copy the files
# wherever you want manually.

echo "Where do you want to install dotcompare? Enter absolute path:";
read INSTALLDIR;
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
EXECDIR="/usr/local/bin";

# INSTALLING PROGRAM
mkdir $INSTALLDIR/dotcompare;
cp -r $DIR/* $INSTALLDIR/dotcompare;
ln -s $INSTALLDIR/dotcompare/dotcompare.pl /usr/local/bin/dotcompare;
echo "dotcompare INSTALLED on $INSTALLDIR";

# CREATING AND SAVING MANPAGE
MANDIR="/usr/share/man/man1";
pod2man ./dotcompare.pl | gzip > $MANDIR/dotcompare.1.gz
echo "man page added to $MANDIR";