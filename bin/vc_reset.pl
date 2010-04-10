use strict;
use warnings;
use 5.010;

# **************************************************************************
# * This is the program "vc_reset.pl", which is part of the larger package
# * File::Vctools (Simple Version Control Tools using diff)
# *
# * AUTHOR
# * Klaus Eichner, klaus03@gmail.com, March 2010
# *
# * COPYRIGHT AND LICENSE
# * Copyright (C) 2010 by Klaus Eichner
# *
# * All rights reserved. This program is free software; you can redistribute
# * it and/or modify it under the terms of the artistic license,
# * see http://www.opensource.org/licenses/artistic-license-1.0.php
# **************************************************************************

use File::Spec;
use File::Basename;
use File::Copy;
use XML::Reader;
use Storable qw(retrieve);
use File::Slurp;

# determine the shell quote $q ==> (") on Windows, (') everywhere else...
my $q = $^O eq 'MSWin32' ? q{"} : q{'};

my $cnst_paramxml = 'vc_parameter.xml';
my $cnst_clist    = 'D_Coutlist.dat';
my $cnst_VcParam  = File::Spec->catfile(($ENV{'VCTOOLDIR'} || File::Spec->rel2abs(dirname($0))), $cnst_paramxml);

# *********************************
# * checking Commandline argument *
# *********************************

if (@_) {
    local $" = "', '";
    die "Error-0020: Found extra parameters ('@_')";
}

# ******************************
# * reading 'vc_parameter.xml' *
# ******************************

my $VcArchDir;
my $DiffProgram;
{
    my $rdr = XML::Reader->newhd($cnst_VcParam, {filter => 5},
      {root => '/vc/archive',  branch => ['/@path']},
      {root => '/vc/difftool', branch => ['/@prog']},
    ) or die "Error-0030: Can't XML::Reader->newhd('$cnst_VcParam') because $!";

    while ($rdr->iterate) {
        if ($rdr->rx == 0) { $VcArchDir   = $rdr->rvalue->[0]; }
        if ($rdr->rx == 1) { $DiffProgram = $rdr->rvalue->[0]; } # Don't worry about $DiffProgram
    }
}

unless (defined $VcArchDir) {
    die "Error-0040: Can't find '/vc/archive/\@path' in '$cnst_VcParam')";
}

my $pth_clist = File::Spec->rel2abs(File::Spec->catfile($VcArchDir, $cnst_clist));

# *************************
# * Chdir into $VcArchDir *
# *************************

chdir $VcArchDir or die "Error-0060: Can't chdir '$VcArchDir' because $!";

# ****************************
# * reading 'D_Coutlist.dat' *
# ****************************

my $coutlist = {};

if (-f $cnst_clist) {
    $coutlist = retrieve($cnst_clist);
    unless (defined $coutlist) {
        die "Error-0070: retrieve('$cnst_clist') returned undef";
    }
}

my %memlist;

for my $fname (keys %$coutlist) {
    for my $dirname (keys %{$coutlist->{$fname}}) {
        my $p_orig = $coutlist->{$fname}{$dirname}{orig};
        my $p_arch = $coutlist->{$fname}{$dirname}{arch};
        if (defined $p_orig and defined $p_arch) {
            $memlist{lc $p_arch} = { orig => $p_orig, arch => $p_arch };
        }
    }
}

my $mem_max = keys %memlist;

my $mem_ct;
for (sort keys %memlist) {
    $mem_ct++;

    my $p_orig = $memlist{$_}{orig};
    my $p_arch = $memlist{$_}{arch};

    unless (-f $p_arch) {
        die "Error-0080: Archive file '$p_arch' does not exist";
    }

    my $action = '';
    if (-f $p_orig) {
        my $content_arch = read_file($p_arch);
        my $content_orig = read_file($p_orig);
        if ($content_arch ne $content_orig) {
            $action = 'rewrite';
        }
    }
    else {
        $action = 'create';
    }

    # début modif Klaus Eichner, 2010-02-19:
    my $showporig = $p_orig;
    $showporig =~ s/\A\Q$ENV{USERPROFILE}/~/xms if defined $ENV{USERPROFILE};
    # fin   modif Klaus Eichner, 2010-02-19:

    printf "Reset [%3d/%3d] %-7s ==> %s\n",
      $mem_ct,
      $mem_max,
      $action,
      $showporig,
    ;

    unless ($action eq '') {
        if (-e $p_orig) {
            unlink $p_orig or die "Error-0090: Can't unlink '$p_orig' because $!";
        }
        copy $p_arch, $p_orig or die "Error-0100: Can't copy('$p_arch', '$p_orig') because $!";
    }
}
