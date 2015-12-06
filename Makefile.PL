use ExtUtils::MakeMaker;
use strict;
use warnings FATAL => 'all';
use File::ShareDir::Install;

install_share dist => 'share';

    WriteMakefile(
        NAME            => 'graphcompare',
        VERSION_FROM    => 'bin/graphcompare',
        EXE_FILES => ['bin/graphcompare'],
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
