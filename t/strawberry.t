use strict;
use warnings;
use Test::More;
BEGIN { delete $ENV{PKG_CONFIG_PATH} }
use PkgConfig;
use Config;

plan skip_all => "Test only for MSWin32" unless $^O eq 'MSWin32';
plan skip_all => "Test only for strawberry MSWin32" unless $Config{myuname} =~ /strawberry-perl/;
plan tests => 1;

# this assumes that zlib comes with Strawberry,
# which seems a fairly safe assumption.
my $pkg = PkgConfig->find('zlib');
is $pkg->errmsg, undef, 'found zlib';
diag $pkg->errmsg if $pkg->errmsg;
