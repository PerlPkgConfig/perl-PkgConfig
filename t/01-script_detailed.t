use strict;
use warnings;
use Test::More;
use FindBin;
use lib $FindBin::Bin;
use PkgConfigTest;

run_common("glib-2.0"); ok($RV == 0, "package name exists");

run_common(qw(--exists glib-2.0)); ok($RV == 0, "package name (--exists)");

run_common(qw(--libs glib-2.0)); like($S, qr/-lglib-2\.0/, "Got expected libs");
ok($S !~ /-L/, "No -L directive for standard search path");

run_common(qw(--cflags glib-2.0));
expect_flags("-I/usr/include/glib-2.0 -I/usr/lib/glib-2.0/include",
             "Got expected include flags");

if (eval { symlink("",""); 1 }) {
  # symlink to simulate place-with-space
  require File::Temp;
  require File::Spec;
  require Text::ParseWords;
  my $dir = File::Temp::tempdir( CLEANUP => 1 );
  my $sub = File::Spec->catdir($dir, 'in space');
  symlink File::Spec->rel2abs(File::Spec->catdir(qw(t data strawberry c lib pkgconfig))), $sub;
  local $ENV{PKG_CONFIG_PATH} = $sub;
  run_common(qw(--cflags freetype2));
  chomp(my $out = $PkgConfigTest::S);
  ($out) = Text::ParseWords::shellwords($out);
  my $exp = "-I".File::Spec->rel2abs($sub)."/../../include/freetype2";
  $exp =~ s|\\|/|g; # standard behaviour of this module
  is $out, $exp, "survived being in space";
}

done_testing();
