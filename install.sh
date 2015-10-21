#!/usr/bin/env bash

# Set the install and executable directory to whatever you want

# BEWARE: DEPENDING ON YOUR CHOICE YOU MAY NEED ROOT PRIVILEGES!

echo "Where do you want to install dotcompare? Enter absolute path:"
read INSTALLDIR;
EXECDIR="/usr/local/bin"
mkdir $INSTALLDIR/dotcompare;
cp -r ./* $INSTALLDIR/dotcompare;
echo "$INSTALLDIR/dotcompare" >> $INSTALLDIR/dotcompare/dotcompare.pl;
ln -s $INSTALLDIR/dotcompare/dotcompare.pl /usr/local/bin/dotcompare;
echo "dotcompare INSTALLED on $INSTALLDIR";

