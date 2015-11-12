#!/usr/bin/env bash

# Set the install and executable directory to whatever you want
# You will need root privileges to install dotcompare using this 
# script. If you don't have them, you may need to copy the files
# wherever you want manually.

echo "Where do you want to install dotcompare?";
echo "Enter ABSOLUTE path:";
read INSTALLDIR;

# Directory where the program and all its files are.
# This allows you to run the installer from anywhere
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
EXECDIR="/usr/local/bin";

# INSTALLING PROGRAM

echo;
echo "# INSTALLING dotcompare in $INSTALLDIR";

# Does the directory already exist?
[ -d $INSTALLDIR/dotcompare ] \
&& ( echo && echo "    $INSTALLDIR/dotcompare already exists! Updating program..." ) \
|| mkdir $INSTALLDIR/dotcompare;

# Update or create files
cp -r $DIR/* $INSTALLDIR/dotcompare;
chmod a+x $INSTALLDIR/dotcompare/dotcompare.pl;

echo;
echo "# CREATING SYMLINK";
# Does the symlink already exist?
[ -L /usr/local/bin/dotcompare ] \
&& ( echo && echo "    Updating symlink to (possibly) new location" && rm /usr/local/bin/dotcompare ) \
|| echo "    Creating symlink in /usr/local/bin";
# Create symlink
ln -s $INSTALLDIR/dotcompare/dotcompare.pl /usr/local/bin/dotcompare;

echo;
echo "# dotcompare INSTALLED on $INSTALLDIR";
echo;

# TESTING
echo "# TESTING dotcompare";
chmod a+x $INSTALLDIR/dotcompare/tests/test.sh;
$INSTALLDIR/dotcompare/tests/test.sh;

# CREATING AND SAVING MANPAGE
MANDIR="/usr/share/man/man1";
pod2man $DIR/dotcompare.pl | gzip > $MANDIR/dotcompare.1.gz;

echo;
echo "man page added to $MANDIR";
echo "use \"man dotcompare\" to see the manual page";
echo;