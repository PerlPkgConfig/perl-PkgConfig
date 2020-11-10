use strict;
use warnings;
use lib 't/lib';
use PkgConfig::Capture;
use Test::More;
use PkgConfig;

note "DEFAULT_SEARCH_PATH = $_" for @PkgConfig::DEFAULT_SEARCH_PATH;

# adjust to test with real pkg-config
my @pkg_config = ( $^X, $INC{'PkgConfig.pm'} );
#my @pkg_config = ( 'pkg-config' );


my $nonexistent_lib = 'rubbish-no-exists';

subtest 'ppkg-config --print-errors with non-existent lib' => sub {

  my @command = ( @pkg_config, '--print-errors', $nonexistent_lib );

  note "% @command";
  my($out, $err, $ret) = capture {
    system @command;
    $?;
  };

  is $ret, 256;
  is $out, "";
  like $err,
    qr/^Can't find $nonexistent_lib.pc in any of /,
    "errors went to stderr";
  note "out: $out" if defined $out;
  note "err: $err" if defined $err;

};

subtest 'ppkg-config --silence-errors with non-existent lib' => sub {

  my @command = ( @pkg_config, '--silence-errors', $nonexistent_lib );

  note "% @command";
  my($out, $err, $ret) = capture {
    system @command;
    $?;
  };

  is $ret, 256;
  is $out, "", "no errors to stdout";
  is $err, "", "no errors to stderr";
  note "out: $out" if defined $out;
  note "err: $err" if defined $err;

};

subtest 'ppkg-config --errors-to-stdout with non-existent lib' => sub {

  my @command = ( @pkg_config, '--errors-to-stdout', $nonexistent_lib );

  note "% @command";
  my($out, $err, $ret) = capture {
    system @command;
    $?;
  };

  is $ret, 256;
  like $out,
    qr/^Can't find $nonexistent_lib.pc in any of /,
    "errors went to stdout";
  is $err, "";
  note "out: $out" if defined $out;
  note "err: $err" if defined $err;

};


done_testing;
