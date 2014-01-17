use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'PkgConfig',
    AUTHOR              => q{M. Nunberg <mnunberg@haskalah.org>},
    VERSION_FROM        => 'lib/PkgConfig.pm',
    ABSTRACT_FROM       => 'lib/PkgConfig.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    EXE_FILES           => [ 'script/ppkg-config', $^O ne 'MSWin32' ? 'script/pkg-config.pl' : () ],
    PREREQ_PM => {
        'Test::More' => 0,
    },
    BUILD_REQUIRES => {
        'Archive::Tar' => 0,
        'Fcntl' => 0
    },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources => {
            repository => {
                type => 'git',
                url  => 'https://github.com/mnunberg/perl-PkgConfig.git',
                web  => 'https://github.com/mnunberg/perl-PkgConfig',
            },
        },
    },
    
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'PkgConfig-*' },
);
