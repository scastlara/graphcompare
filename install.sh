#!/usr/bin/env bash

# Set the install and executable directory to whatever you want

# BEWARE: DEPENDING ON YOUR CHOICE YOU MAY NEED ROOT PRIVILEGES!
# ALSO: YOU HAVE TO SET INSTALLDIR VARIABLE IN dotcompare.pl (NASTY, I know)


INSTALLDIR="/home/sergio/CULO";
EXECDIR="/usr/local/bin"
mkdir $INSTALLDIR;
cp -r ./* $INSTALLDIR;
ln -s $INSTALLDIR/dotcompare.pl /usr/local/bin/dotcompare;
echo "dotcompare INSTALLED on $INSTALLDIR";

