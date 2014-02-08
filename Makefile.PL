use strict;
use warnings;
use ExtUtils::MakeMaker 6.48;
require 5.006;

WriteMakefile(
    NAME                => 'PkgConfig',
    AUTHOR              => q{M. Nunberg <mnunberg@haskalah.org>},
    VERSION_FROM        => 'lib/PkgConfig.pm',
    ABSTRACT_FROM       => 'lib/PkgConfig.pm',
    LICENSE             => 'perl',
    MIN_PERL_VERSION    => '5.006000',
    PL_FILES            => {},
    EXE_FILES           => [ 'script/ppkg-config', $^O ne 'MSWin32' ? 'script/pkg-config.pl' : () ],
    PREREQ_PM => {
        'Test::More' => 0,
    },
    BUILD_REQUIRES => {
        'Archive::Tar' => $^O eq 'MSWin32' ? '1.94' : 0,
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
