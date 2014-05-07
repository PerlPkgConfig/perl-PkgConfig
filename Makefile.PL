use strict;
use warnings;
use ExtUtils::MakeMaker 6.48;
use Getopt::Long;
require 5.006;

### Makefile.PL commandline params
# e.g. Makefile.PL --script=ppkg-config --script=pkg-config
Getopt::Long::GetOptions("script=s" => \my @scripts);
if (@scripts) {
  @scripts = map { "script/$_" } @scripts;
  -f $_ or die "non-existing '$_'" for (@scripts);
}
else {
  @scripts = ( 'script/ppkg-config', $^O ne 'MSWin32' ? 'script/pkg-config.pl' : () );
}

WriteMakefile(
    NAME                => 'PkgConfig',
    AUTHOR              => q{M. Nunberg <mnunberg@haskalah.org>},
    VERSION_FROM        => 'lib/PkgConfig.pm',
    ABSTRACT_FROM       => 'lib/PkgConfig.pm',
    LICENSE             => 'perl',
    MIN_PERL_VERSION    => '5.006000',
    PL_FILES            => {},
    EXE_FILES           => \@scripts,
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
