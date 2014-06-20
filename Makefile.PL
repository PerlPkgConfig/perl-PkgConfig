use strict;
use warnings;
use ExtUtils::MakeMaker 6.56;
use Getopt::Long;
use Config;
require 5.006;

### Makefile.PL commandline params
# e.g. Makefile.PL --script=ppkg-config --script=pkg-config
Getopt::Long::GetOptions("script=s" => \my @scripts);

if (@scripts == 0 && defined $ENV{PERL_PKG_CONFIG_SCRIPTS})
{
  @scripts = ($ENV{PERL_PKG_CONFIG_SCRIPTS});
}

if (@scripts) {
  @scripts = map { split /,/ } @scripts;
  if (grep /^none$/, @scripts) {
    @scripts = ();
  } else {
    @scripts = map { "script/$_" } @scripts;
    -f $_ or die "non-existing '$_'" for (@scripts);
  }
}
else {
  @scripts = ( 'script/ppkg-config', $^O ne 'MSWin32' ? 'script/pkg-config.pl' : () );
  if($^O eq 'MSWin32' && $Config{myuname} =~ /strawberry-perl/) {
    if(eval q{ require 5.020 }) {
      push @scripts, 'script/pkg-config';
    
      print "\n\n";
      print "!!! Note that script will be installed as pkg-config  !!!\n";
      print "!!! in addition to ppkg-config since you are using    !!!\n";
      print "!!! Strawberry Perl 5.20 or better.  This is probably !!!\n";
      print "!!! What you want                                     !!!\n";
      print "\n\n";
      
      if($Config{myuname} =~ /strawberry-perl 5\.20\.0\.1/)
      {
        print "\n\n";
        print "!!! Some of the .pc files that come with your version !!!\n";
        print "!!! of Strawberry Perl may not work correctly with    !!!\n";
        print "!!! this version of PkgConfig.  You should consider   !!!\n";
        print "!!! patching them.  See README.win32 for details.     !!!\n";
        print "\n\n";
      }
      
    } else {
      print "\n\n";
      print "!!! You may want to consider installing the script as !!!\n";
      print "!!! pkg-config as it can then be used by              !!!\n";
      print "!!! ExtUtils::PkgConfig (This is how it works in      !!!\n";
      print "!!! Strawberry 5.20 and better in fact).  Please see  !!!\n";
      print "!!! details in README.win32 if you are interested.    !!!\n";
      print "\n\n";
    }
  }
}

eval { require Test::More }; # to get $Test::More::VERSION

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
        # subtest Test::More >= 0.90 && Test::More != 0.92
        'Test::More' => '0.94',
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
