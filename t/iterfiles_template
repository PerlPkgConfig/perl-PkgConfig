#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Dir::Self;
use lib __DIR__;
use PkgConfigTest;

my $flist = PkgConfigTest::get_my_file_list(__FILE__);
PkgConfigTest::run_exists_test($flist, __FILE__);
PkgConfigTest::run_flags_test($flist, __FILE__);
done_testing();