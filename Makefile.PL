use ExtUtils::MakeMaker;
    WriteMakefile(
        NAME            => 'Dot::Parser',
        VERSION_FROM    => 'lib/Dot/Parser.pm',
        EXE_FILES => ['bin/dotcompare']
    );