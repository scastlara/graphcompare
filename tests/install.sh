#!/usr/bin/env bash

# Set this directory to whatever you want
# BEWARE: DEPENDING ON YOUR CHOICE YOU MAY NEED ROOT PRIVILEGES!
# ALSO: YOU HAVE TO SET THIS VARIABLE IN dotcompare.pl


INSTALLDIR = "/home/sergio/CULO";
mkdir $INSTALLDIR;
cp ./* $INSTALLDIR;
echo "dotcompare INSTALLED on $INSTALLDIR";

