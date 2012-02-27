#!perl
use strict;
use warnings;
use Test::More;
use File::Basename;
use Dir::Self qw(:static);
use Data::Dumper;
use Archive::Extract;
use File::Spec;
use Config;

my @PC_PATHS = qw(usr/lib/pkgconfig usr/share/pkgconfig
                usr/local/lib/pkgconfig usr/local/share/pkgconfig);
                


my $TARBALL = File::Spec->catfile(__DIR__, 'pc_files.tar.gz');
@PC_PATHS = map { __DIR__ . "/$_" } @PC_PATHS;
@PC_PATHS = map {
    my @components = split(/\//, $_);
    $_ = File::Spec->catfile(@components);
    $_;
} @PC_PATHS;
    
print Dumper(\@PC_PATHS);

$ENV{PKG_CONFIG_PATH} = join(":", @PC_PATHS);

my $RV;
my $S;

my $SCRIPT = __DIR__ . "/../script/pkg-config.pl";
sub run_common {
    my @args = @_;
    (my $ret = qx($SCRIPT --env-only @args))
        =~ s/(?:^\s+)|($?:\s+$)//g;
    $RV = $?;
    $S = $ret;
}

sub expect_flags {
    my ($flags,$msg) = @_;
    like($S, qr/\Q$flags\E/, $msg);
}

{
    my $ae = Archive::Extract->new(archive => $TARBALL);
    $ae->extract(to => __DIR__);
}

run_common("glib-2.0"); ok($RV == 0, "package name exists");

run_common("--exists glib-2.0"); ok($RV == 0, "package name (--exists)");

run_common("--libs glib-2.0"); like($S, qr/-lglib-2\.0/, "Got expected libs");
ok($S !~ /-L/, "No -L directive for standard search path");



run_common("--cflags glib-2.0");
expect_flags("-I/usr/include/glib-2.0 -I/usr/lib/glib-2.0/include",
             "Got expected include flags");


my @allfiles;
foreach my $path (@PC_PATHS) {
    push @allfiles, glob("$path/*.pc");
}

diag "Will perform basic --exist tests";
foreach my $fname (@allfiles) {
    next unless -f $fname;
    my ($base) = fileparse($fname, ".pc");
    run_common("$base");
    ok($RV == 0, "Package $base exists");
    #diag "Found $base";
}

diag "Will perform --prefix, cflags, and libs test";
foreach my $fname (@allfiles) {
    next unless -f $fname;
    my ($base) = fileparse($fname, ".pc");
    run_common("--libs --cflags $base --define-variable=prefix=blah");
    ok($RV == 0, "Got OK for --libs and --cflags");
    if($S =~ /-(?:L|I)/) {
        if($S !~ /blah/) {
            
            #these files define $prefix, but don't actually use them for
            #flags:
            if($base =~ /^(?:glu?)$/) {
                diag("Skipping gl pcfiles which define but do not use 'prefix'");
                next;
            }
            
            #Check the file, see if it at all has a '$prefix'
            open my $fh, "<", $fname;
            if(!defined $fh) {
                diag "$fname: $!";
                next;
            }
            
            my @lines = <$fh>;
            if(grep /\$\{prefix\}/, @lines) {
                ok(0, "Expected substituted prefix for $base");
            } else {
                diag "File $fname has no \${prefix} directive";
            }
            next;
        }
        ok($S =~ /blah/, "Found modified prefix for $base");
    }
}

done_testing();