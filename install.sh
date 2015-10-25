#!/usr/bin/env bash

# Set the install and executable directory to whatever you want
# BEWARE: DEPENDING ON YOUR CHOICE YOU MAY NEED ROOT PRIVILEGES!

echo "Where do you want to install dotcompare? Enter absolute path:";
read INSTALLDIR;
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
EXECDIR="/usr/local/bin";
mkdir $INSTALLDIR/dotcompare;
cp -r $DIR/* $INSTALLDIR/dotcompare;
ln -s $INSTALLDIR/dotcompare/dotcompare.pl /usr/local/bin/dotcompare;
echo "dotcompare INSTALLED on $INSTALLDIR";