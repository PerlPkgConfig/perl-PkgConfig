use strict;
use warnings;
use Test::More tests => 1;

$ENV{PKG_CONFIG_PATH}   = '/foo:/bar';
$ENV{PKG_CONFIG_LIBDIR} = '/baz:/roger';

require PkgConfig;

no warnings 'once';
is_deeply \@PkgConfig::DEFAULT_SEARCH_PATH, [qw( /foo /bar /baz /roger )], "honors both PKG_CONFIG_PATH and PKG_CONFIG_LIBDIR";
