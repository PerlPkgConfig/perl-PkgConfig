package PkgConfig::Capture;

use strict;
use warnings;
use Test::More ();
use Exporter 'import';

eval {
  require Capture::Tiny;
  Capture::Tiny->import(qw( capture ));
};

if($@)
{
  Test::More::plan(skip_all => 'Test requires Capture::Tiny');
}

our @EXPORT = qw( capture );

1;
