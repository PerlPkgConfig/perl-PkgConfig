#!/usr/bin/env perl

# lightweight no-dependency version of pkg-config. This will work on any machine
# with Perl installed.

# Copyright (C) 2012 M. Nunberg.
# You may use and distribute this software under the same terms and conditions
# as Perl itself.

package PkgConfig;

our $VERSION = '0.01_0';

use strict;
use warnings;
use File::Spec;
use Getopt::Long;
use Class::Struct; #in core since 5.004

#these only for debugging:
use Data::Dumper;
use Log::Fu { level => "warn" };

our @DEFAULT_SEARCH_PATH = split(/:/, $ENV{PKG_CONFIG_PATH} || "");
our @DEFAULT_EXCLUDE_CFLAGS = qw(-I/usr/include);

# don't include default link/search paths!
our @DEFAULT_EXCLUDE_LFLAGS = qw(
    -L/usr/lib -L/lib -L/lib64 -L/lib32
    -L/usr/lib32 -L/usr/lib64
);

struct(
    __PACKAGE__,
    [
     # .pc search paths, defaults to PKG_CONFIG_PATH in environment
     'search_path' => '@',
     
     # whether to also spit out static dependencies
     'static' => '$',
     
     # no recursion. set if we just want a version, or to see if the
     # package exists.
     'no_recurse' => '$',
     
     #list of cflags and ldflags to exclude
     'exclude_ldflags' => '@',
     'exclude_cflags' => '@',
     
     # what level of recursion we're at
     'recursion' => '$',
     
     # hash of libraries, keyed by recursion levels. Lower recursion numbers
     # will be listed first
     'libs_deplist' => '*%',
     
     # cummulative cflags and ldflags
     'ldflags'   => '*@',
     'cflags'    => '*@',
     
     # whether we print the c/ldflags
     'print_cflags' => '$',
     'print_ldflags' => '$',
     
     # information about our top-level package
     'pkg'  => '$',
     'pkg_exists' => '$',
     'pkg_version' => '$',
     'errmsg'   => '$',
    ]
);

sub find {
    my ($cls,$library,%options) = @_;        
    my @uspecs = (
        ['search_path', \@DEFAULT_SEARCH_PATH],
        ['exclude_ldflags', \@DEFAULT_EXCLUDE_LFLAGS],
        ['exclude_cflags', \@DEFAULT_EXCLUDE_CFLAGS]
    );
    
    foreach (@uspecs) {
        my ($basekey,$default) = @$_;
        my $list = [ @{$options{$basekey} ||= [] } ];
        if($options{$basekey . "_override"}) {
            @$list = @{ delete $options{$basekey."_override"} };
        } else {
            push @$list, @$default;
        }
        
        $options{$basekey} = $list;
        #print "$basekey: " . Dumper($list);
    }
    
    my $o = $cls->new(%options);
       
    #print Dumper(\%options);
    
    #print Dumper($o);
    $o->recursion(0);
    $o->find_pcfile($library);
    #print Dumper($o);
    return $o;
}

# notify us about extra linker flags
sub append_ldflags {
    my ($self,@flags) = @_;
    push @{($self->libs_deplist->{$self->recursion} ||=[])},
        _split_flags(@flags);
}

# notify us about extra compiler flags
sub append_cflags {
    my ($self,@flags) = @_;
    push @{$self->cflags}, _split_flags(@flags);
}

# figure out what our dependencies are
sub get_requires {
    my ($self,$requires) = @_;
    return () unless $requires;
    
    my @reqlist = split(/[\s,]+/, $requires);
    my @ret;
    while (defined (my $req = shift @reqlist) ) {
        my $reqlet = [ $req ];
        push @ret, $reqlet;
        last unless @reqlist;
        #check if we need some version scanning:
        
        my $cmp_op;
        my $want;
        
        GT_PARSE_REQ:
        {
            #all in one word:
            ($cmp_op) = ($req =~ /([<>=]+)/);
            if($cmp_op) {
                if($req =~ /[<>=]+$/) {
                    log_debug("comparison operator spaced ($cmp_op)");
                    ($want) = ($req =~ /([^<>=]+$)/);
                    $want ||= shift @reqlist;
                } else {
                    $want = shift @reqlist;
                }
                push @$reqlet, ($cmp_op, $want);
            } elsif ($reqlist[0] =~ /[<>=]+/) {
                $req = shift @reqlist;
                goto GT_PARSE_REQ;
            }
        }
    }
    #log_debug(@ret);
    return @ret;
}

sub parse_pcfile {
    my ($self,$pcfile,$version) = @_;
    #log_warn("Requesting $pcfile");
    open my $fh, "<", $pcfile or die "$pcfile: $!";
    
    #This hash only for debugging:
    my %h;

    #predeclare a bunch of used variables:
    my ($prefix,$exec_prefix,$libdir,$includedir);
    my ($Libs,$LibsDOTprivate,$Cflags,$Requires,$RequiresDOTprivate);
    my ($Name,$Version);
    
    my @lines = (<$fh>);
    close($fh);
    
    foreach my $line (@lines) {
        my $toktype;
        no strict 'vars';
        
        $line =~ s/#[^#]+$//g; # strip comments
        
        my ($field,$value) = split(/:/, $line, 2);
        $toktype = ':';
        if(!defined $value) {
            ($field,$value) = split(/=/, $line, 2);
            $toktype = '=';
        }

        next unless defined $value;
        $field =~ s/\./DOT/g;
        $field =~ s/(^\s+)|(\s+)$//msg;
        
        $value =~ s/(^\s+)|(\s+$)//msg;
        
        # pkg-config escapes a '$' with a '$$'. This won't go in perl:
        $value =~ s/[^\\]\$\$/\\\$/g;
                
        $value = "\"$value\"";
        my $evalstr = "\$$field=$value";
        log_debug("EVAL", $evalstr);
        
        my $expanded = eval($evalstr);
        if($@) {
            log_err($@);
        }
        
        if($expanded) {
            $h{$field} = $expanded;
        }
    }
    
    $self->append_cflags($Cflags);
    $self->append_ldflags($Libs);
    if($self->static) {
        $self->append_ldflags($LibsDOTprivate);
    }
    
    my @deps;
    my @deps_dynamic = $self->get_requires($Requires);
    my @deps_static = $self->get_requires($RequiresDOTprivate);
    @deps = @deps_dynamic;
    
    
    if($self->static) {
        push @deps, @deps_static;
    }
        
    if($self->recursion == 1) {
        $self->pkg_version($Version);
        $self->pkg_exists(1);
    }
    
    unless ($self->no_recurse) {
        foreach (@deps) {
            my ($dep,$cmp_op,$version) = @$_;
            $self->find_pcfile($dep);
        }
    } else {
    }
}

sub find_pcfile {
    my ($self,$libname,$version) = @_;
    
    $self->recursion($self->recursion + 1);
    
    my $pcfile = "$libname.pc";
    my $found = 0;
    my @found_paths = (grep {
        -e File::Spec->catfile($_, $pcfile)
        } @{$self->search_path});
    
    if(!@found_paths) {
        my @search_paths = @{$self->search_path};
        $self->errmsg(
            join("\n",
                 "Can't find $pcfile in any of @search_paths",
                 "use the PKG_CONFIG_PATH environment variable, or",
                 "specify extra search paths via 'search_paths'",
                 ""
                )
        ) unless $self->errmsg();
        return;
    }
    
    $pcfile = File::Spec->catfile($found_paths[0], $pcfile);
    
    $self->parse_pcfile($pcfile);
    
    $self->recursion($self->recursion - 1);
}

################################################################################
################################################################################
### Public Getters                                                           ###
################################################################################
################################################################################

sub get_cflags {
    my $self = shift;
    my @cflags = @{$self->cflags};
    
    filter_omit(\@cflags, $self->exclude_cflags);
    filter_dups(\@cflags);
    return @cflags;
}

sub get_ldflags {
    my $self = shift;
    my @ordered_libs;
    my @lib_levels = sort keys %{$self->libs_deplist};
    my @ret;
    
    @ordered_libs = @{$self->libs_deplist}{@lib_levels};
    foreach my $liblist (@ordered_libs) {
        my $lcopy = [ @$liblist ];
        filter_dups($lcopy);
        filter_omit($lcopy, $self->exclude_ldflags);
        push @ret, @$lcopy;
    }
    
    @ret = reverse @ret;
    filter_dups(\@ret);
    @ret = reverse(@ret);
    return @ret;
}



################################################################################
################################################################################
### Utility functions                                                        ###
################################################################################
################################################################################

#split a list of tokens by spaces
sub _split_flags {
    my @flags = @_;
    if(!@flags) {
        return @flags;
    }
    if(@flags == 1) {
        my $str = shift @flags;
        return () if !$str;
        @flags = split(/\s+/, $str);
    }
    @flags = grep $_, @flags;
    return @flags;
}



sub filter_dups {
    my $array = shift;
    my @ret;
    my %seen_hash;
    #@$array = reverse @$array;
    foreach my $elem (@$array) {
        if(exists $seen_hash{$elem}) {
            next;
        }
        $seen_hash{$elem} = 1;
        push @ret, $elem;
    }
    #print Dumper(\%seen_hash);
    @$array = @ret;
}

sub filter_omit {
    my ($have,$exclude) = @_;
    my @ret;
    #print Dumper($have);
    foreach my $elem (@$have) {
        #log_warn("Checking '$elem'");
        if(grep { $_ eq $elem } @$exclude) {
            #log_warn("Found illegal flag '$elem'");
            next;
        }
        push @ret, $elem;
    }
    @$have = @ret;
}

sub version_2_array {
    my $string = shift;
    my @chunks = split(/\./, $string);
    my @ret;
    my $chunk;
    while( ($chunk = pop @chunks)
        && $chunk =~ /^\d+$/) {
        push @ret, $chunk;
    }
    return @ret;
}


sub version_check {
    my ($want,$have) = @_;
    my @a_want = version_2_array($want);
    my @a_have = version_2_array($have);

    my $max_elem = scalar @a_want > scalar @a_have
        ? scalar @a_have
        : scalar @a_want;

    for(my $i = 0; $i < $max_elem; $i++) {
        if($a_want[$i] > $a_have[$i]) {
            return 0;
        }
    }
    return 1;
}


if(caller) {
    return 1;
}

### 'main' ###
package PkgConfig::Script;
use strict;
use warnings;
use Getopt::Long;

my $quiet_errors = 1;

GetOptions(
    'libs' => \my $PrintLibs,
    'static' => \my $UseStatic,
    'cflags' => \my $PrintCflags,
    'exists' => \my $PrintExists,
    'silence-errors' => \my $SilenceErrors,
    'print-errors' => \my $PrintErrors,
    'modversion'    => \my $PrintVersion,
    'version',      => \my $PrintAPIversion,
    'real-version' => \my $PrintRealVersion,
    'debug'         => \my $Debug,
);

if($Debug) {
    Log::Fu::set_log_level('PkgConfig', 'DEBUG');
}

if($PrintAPIversion) {
    print "0.26\n";
    exit(0);
}

if($PrintRealVersion) {
    
    printf STDOUT ("pkg-config.pl - cruftless pkg-config\n" .
            "Version: %s\n", $PkgConfig::VERSION);
    exit(0);
}

my $LIB = $ARGV[0] or die "Must have library!";

if($PrintErrors) {
    $quiet_errors = 0;
}
if($SilenceErrors) {
    $quiet_errors = 1;
}

my $WantFlags = ($PrintCflags || $PrintLibs || $PrintVersion);

if($WantFlags) {
    $quiet_errors = 0 unless $SilenceErrors;
}

my %pc_options;
if($PrintExists) {
    $pc_options{no_recurse} = 1;
}


$pc_options{static} = $UseStatic;

my $o = PkgConfig->find($LIB, %pc_options);

if($o->errmsg) {
    print STDERR $o->errmsg unless $quiet_errors;
    exit(1);
}

if(!$WantFlags) {
    exit(0);
}

if($PrintVersion) {
    print $o->pkg_version . "\n";
    exit(0);
}

if($PrintCflags) {
    print join(" ", $o->get_cflags) . " ";
}

if($PrintLibs) {
    print join(" ", $o->get_ldflags) . " ";
}

print "\n";
exit(0);

__END__

=head1 NAME

PkgConfig - Pure-Perl Core-Only replacement for C<pkg-config>


=head1 NOTE

The script is not actually installed yet (i haven't settled on a good name), but
will decide based on input in a future version.

Additionally, some dependencies are superficially included for debugging, and
will be sanitized in a future 'release/stable' version.

=head1 SYNOPSIS

=head2 As a replacement for C<pkg-config>

    $ pkg-config.pl --libs --cflags --static gio-2.0
    
    #outputs (lines artifically broken up for readability):
    # -I/usr/include/glib-2.0 -I/usr/lib/glib-2.0/include
    # -pthread -lgio-2.0 -lz -lresolv -lgobject-2.0
    # -lgmodule-2.0 -ldl -lgthread-2.0 -pthread -lrt -lglib-2.0 


Compare to:
    $ pkg-config --libs --cflags --static gio-2.0
    
    #outputs ( "" ):
    # -pthread -I/usr/include/glib-2.0 -I/usr/lib/glib-2.0/include
    # -pthread -lgio-2.0 -lz -lresolv -lgobject-2.0 -lgmodule-2.0
    # -ldl -lgthread-2.0 -lrt -lglib-2.0  


=head2 From another Perl module

    use PkgConfig;
    
    my $o = PkgConfig->find('gio');
    if($o->errmsg) {
        #handle error
    } else {
        my @cflags = $o->get_cflags;
        my @ldflags = $o->get_ldflags;
    }
    
=head1 DESCRIPTION

C<PkgConfig> provides a pure-perl, core-only replacement for the C<pkg-config>
utility.

This is not a description of the uses of C<pkg-config> but rather a description
of the differences between the C version and the Perl one.

While C<pkg-config> is a compiled binary linked with glib, the pure-perl version
has no such requirement, and will run wherever Perl ( >= 5.04 ) does.

The main supported options are the common C<--libs>, C<--cflags>,
C<--static>, C<--exists> and C<--modversion>.

=head2 SCRIPT OPTIONS

By default, a library name must be supplied unless one of L<--version>,
or L<--real-version> is specified.

The output should normally be suitable for passing to your favorite compiler.

=head4 I<--libs>

(Also) print linker flags. Dependencies are traverse in order. Top-level dependencies
will appear earlier in the command line than bottom-level dependencies.

=head4 I<--cflags>

(Also) print compiler and C preprocessor flags.

=head4 I<--static>

Use extra dependencies and libraries if linking against a static version of the
requested library

=head4 I<--exists>

Return success (0) if the package exists in the search path.

=head3 ENVIRONMENT

the C<PKG_CONFIG_PATH> variable is honored and used as a colon-delimited list
of directories with contain C<.pc> files.

=head2 MODULE OPTIONS

=head4 I<<PkgConfig->find>>

    my $result = PkgConfig->find($libary, %options);
    
Find a library and return a result object.

The options are in the form of hash keys and values, and the following are
recognized:

=over

=item C<search_path>

=item C<search_path_override>

Prepend search paths in addition to the paths specified in C<$ENV{PKG_CONFIG_PATH}>
The value is an array reference.

the C<_override> variant ignores defaults (like c<PKG_CONFIG_PATH).

=item C<exclude_cflags>

=item C<exclude_ldflags>

=item C<exclude_cflags_override>

=item C<exclude_ldflags_override>


Some C<.pc> files specify default compiler and linker search paths, e.g.
C<-I/usr/include -L/usr/lib>. Specifying them on the command line can be
problematic as it drastically changes the search order.

The above options will either append or replace the options which are excluded
and filtered.

The default excluded linker and compiler options can be obtained via
C<@PkgConfig::DEFAULT_EXCLUDE_LFLAGS> and C<@PkgConfig::DEFAULT_EXCLUDE_CFLAGS>,
respectively.

=item C<static>

Also specify static libraries.

=item C<no_recurse>

Do not recurse dependencies. This is useful for just doing version checks.

=back

A C<PkgConfig> object is returned and may be queried about the results:

=head4 I<< $o->errmsg >>

An error message, if any. This is a string and indicates an error.

=head4 I<< $o->pkg_exists >>

Boolean value, true if the package exists.

=head4 I<< $o->pkg_version >>

The version of the package

=head4 I<< $o->get_cflags >>

=head4 I<< $o->get_ldflags >>

Returns a list of compiler and linker flags, respectively.

=head2 BUGS

The order of the flags is not exactly matching to that of C<pkg-config>. From my
own observation, it seems this module does a better job, but I might be wrong.

Version checking is not yet implemented.

There is currently a dependency on a debugging module, just to preserve my sanity.
This will be removed in a future release.

While C<pkg-config> allows definition of arbitrary variables, only the following
variables are currently recognized by Perl:

    Variables:
    my ($prefix,$exec_prefix,$libdir,$includedir);
    
    Sections: (e.g. LibsDOTprivate is a .pc 'Libs.private:')
    my ($Libs,$LibsDOTprivate,$Cflags,$Requires,$RequiresDOTprivate);
    my ($Name,$Version);
    
Module tests are missing.

=head1 SEE ALSO

L<ExtUtils::PkgConfig>, a wrapper around the C<pkg-config> binary

L<pkg-config|http://www.freedesktop.org/wiki/Software/pkg-config>

=head1 AUTHOR & COPYRIGHT

Copyright (C) 2012 M. Nunberg

You may use and distribute this software under the same terms and conditions as
Perl itself.