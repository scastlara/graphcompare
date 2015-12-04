use ExtUtils::MakeMaker;
use strict;
use warnings FATAL => 'all';
use File::ShareDir::Install;

install_share dist => 'share';

    WriteMakefile(
        NAME            => 'Dot::Compare',
        VERSION_FROM    => 'bin/dotcompare',
        EXE_FILES => ['bin/dotcompare'],
        PREREQ_PM => {
            "File::Share"  => 0,
            "Pod::Usage"   => 0,
            "Getopt::Long" => 0, 
        },
        BUILD_REQUIRES => {
            'Test::More' => 0,
            'File::ShareDir::Install' => 0,
        }
    );

package MY;
use File::ShareDir::Install 'postamble';