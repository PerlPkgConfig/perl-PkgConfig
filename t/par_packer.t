use strict;
use warnings;
use Test::More;
BEGIN { delete $ENV{PKG_CONFIG_PATH} }
use PkgConfig;
use Config;
use File::Temp qw( tempdir );


plan skip_all => "Test only for MSWin32" unless $^O eq 'MSWin32';
plan skip_all => "Test only for strawberry MSWin32" unless $Config{myuname} =~ /strawberry-perl/;
plan skip_all => "Test needs PAR::Packer to be installed" unless 'require PAR::Packer';
plan tests => 1;

my $dir = tempdir( CLEANUP => 1);
my $exe_file = "$dir/a.exe";
my $test_text = "executable worked";

my $code = qq{pp -e "use PkgConfig; print qq|$test_text|" -o $exe_file};

#diag $code;

system $code;
my $result = `$exe_file`;

is $result, $test_text, "PAR packed executable includes functional PkgConfig";

#diag $result;
