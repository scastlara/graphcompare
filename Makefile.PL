use ExtUtils::MakeMaker;
use strict;
use warnings FATAL => 'all';
use File::ShareDir::Install;

install_share dist => 'share';

    WriteMakefile(
        NAME            => 'Dot::Parser',
        VERSION_FROM    => 'bin/dotcompare',
        EXE_FILES => ['bin/dotcompare'],
        BUILD_REQUIRES => {
            'Test::More' => 0,
        }
    );

package MY;
use File::ShareDir::Install 'postamble';