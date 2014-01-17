#!perl
package PkgConfigTest;
use strict;
use warnings;
use Test::More;
use File::Basename;
use Data::Dumper;
use Archive::Tar;
use File::Spec;
use File::Basename qw(fileparse);
use Config;
use Cwd qw( cwd chdir );
use FindBin ();
use base qw(Exporter);

use Fcntl qw(LOCK_EX LOCK_UN LOCK_SH LOCK_NB);

our @EXPORT = qw(
    expect_flags run_common $RV $S);

my @PC_PATHS = qw(usr/lib/pkgconfig usr/share/pkgconfig
                usr/local/lib/pkgconfig usr/local/share/pkgconfig);
                


my $TARBALL = File::Spec->catfile($FindBin::Bin, 'pc_files.tar.gz');
@PC_PATHS = map { $FindBin::Bin . "/$_" } @PC_PATHS;
@PC_PATHS = map {
    my @components = split(/\//, $_);
    $_ = File::Spec->catfile(@components);
    $_;
} @PC_PATHS;
    
print Dumper(\@PC_PATHS);

$ENV{PKG_CONFIG_PATH} = join(":", @PC_PATHS);

our $RV;
our $S;

my $SCRIPT = $FindBin::Bin . "/../script/ppkg-config";
sub run_common {
    my @args = @_;
    (my $ret = qx($^X $SCRIPT --env-only @args))
        =~ s/(?:^\s+)|($?:\s+$)//g;
    $RV = $?;
    $S = $ret;
}

sub expect_flags {
    my ($flags,$msg) = @_;
    like($S, qr/\Q$flags\E/, $msg);
}

# For concurrency, it is necessary to maintain a lock here. The
# lock should remain in place
sub extract_our_tarball
{
    open my $fh, "+<", $TARBALL or die "$TARBALL: $!";
    my $extract_dir = File::Spec->catfile($FindBin::Bin, 'usr');
    my $lock_status = flock($fh, LOCK_SH); # Block.
    
    # If we have a shared lock, let us check if the directory exists:
    if (-d $extract_dir) {
        return;
    }
    
    # Now, let's try to get an exclusive lock. The process to get such a lock
    # will be the one to extract the tarball:
    $lock_status = flock($fh, LOCK_EX|LOCK_NB);
    if (!$lock_status) {
        flock($fh, LOCK_UN);
        # Another process is extracting it. Wait until it's done.
        goto &extract_our_tarball;
    }
    my $tar = Archive::Tar->new($TARBALL);
    my $cwd = cwd();
    chdir $FindBin::Bin;
    $tar->extract;
    chdir $cwd;
}

sub import {
    extract_our_tarball();
    goto &Exporter::import;
}

sub get_my_file_list {
    my $pmfile = shift;
    my $needed = fileparse($pmfile, ".pm",".t");
    ($needed) = ($needed =~ /(FLIST.+)/);
    die "Invalid file $pmfile" unless $needed;
    my $file_list = File::Spec->catfile($FindBin::Bin, $needed);
    open my $fh, "<", $file_list or die "$file_list: $!";
    diag $file_list;
    my @lines = <$fh>;
    @lines = map { $_ =~ s/\s+$//g; $_ } @lines;
    @lines = map { File::Spec->catfile($FindBin::Bin, $_) } @lines;
    return \@lines;
}

sub run_exists_test {
    my ($flist,$pmfile) = @_;
    diag "$pmfile: Will perform --exist tests";
    foreach my $fname (@$flist) {
        next unless -f $fname;
        my ($base) = fileparse($fname, ".pc");
        run_common("$base");
        ok($RV == 0, "Package $base exists");
    }
}

sub _single_flags_test {
    my $fname = shift;
    return unless -f $fname;
    my ($base) = fileparse($fname, ".pc");
    run_common("--libs --cflags $base --define-variable=prefix=blah");
    ok($RV == 0, "Got OK for --libs and --cflags");
    if($S =~ /-(?:L|I)/) {
        if($S !~ /blah/) {
            
            #these files define $prefix, but don't actually use them for
            #flags:
            if($base =~ /^(?:glu?)$/) {
                diag("Skipping gl pcfiles which define but do not use 'prefix'");
                return;
            }
            
            #Check the file, see if it at all has a '$prefix'
            open my $fh, "<", $fname;
            if(!defined $fh) {
                diag "$fname: $!";
                return;
            }
            
            my @lines = <$fh>;
            if(grep /\$\{prefix\}/, @lines) {
                ok(0, "Expected substituted prefix for $base");
            } else {
                diag "File $fname has no \${prefix} directive";
            }
            return;
        }
        ok($S =~ /blah/, "Found modified prefix for $base");
    }
}

sub run_flags_test {
    my ($flist,$pmfile) = @_;
    diag "$pmfile: Will perform --prefix, --cflags, and --libs tests";
    foreach my $fname (@$flist) {
        _single_flags_test($fname);
    }
}

1;
