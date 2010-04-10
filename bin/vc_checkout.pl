use strict;
use warnings;
use 5.010;

# **************************************************************************
# * This is the program "vc_checkout.pl", which is part of the larger package
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
use Storable qw(retrieve store);
use File::Slurp;

use Getopt::Std;
getopts('z', \my %opts);

# option '-z' ==> no headers are displayed ("-z ==> zero header")

# determine the shell quote $q ==> (") on Windows, (') everywhere else...
my $q = $^O eq 'MSWin32' ? q{"} : q{'};

my $cnst_workdir  = 'Work';
my $cnst_cmddir   = 'Cmd';
my $cnst_xmllist  = 'B_Flist.xml';
my $cnst_paramxml = 'vc_parameter.xml';
my $cnst_clist    = 'D_Coutlist.dat';
my $cnst_VcParam  = File::Spec->catfile(($ENV{'VCTOOLDIR'} || File::Spec->rel2abs(dirname($0))), $cnst_paramxml);
my $cnst_workabs  = File::Spec->catfile(File::Spec->rel2abs('.'), $cnst_workdir);
my $cnst_worklc   = lc $cnst_workabs;

unless ($opts{z}) {
    say '***************************';
    say '** Checking out programs **';
    say '***************************';
    say '';

    my $p_show = File::Spec->rel2abs('.');

    # d�but modif Klaus Eichner, 2010-02-19:
    $p_show =~ s/\A\Q$ENV{USERPROFILE}/~/xms if defined $ENV{USERPROFILE};
    # fin   modif Klaus Eichner, 2010-02-19:

    say "Project: $p_show";
    say '';
}

my $magic_file = File::Spec->catfile($cnst_cmddir, 'r_apply.pl');
unless (-f $magic_file) {
    die "Error-0010: Can't find '$magic_file' - Program stopped";
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
    ) or die "Error-0020: Can't XML::Reader->newhd('$cnst_VcParam') because $!";

    while ($rdr->iterate) {
        if ($rdr->rx == 0) { $VcArchDir   = $rdr->rvalue->[0]; }
        if ($rdr->rx == 1) { $DiffProgram = $rdr->rvalue->[0]; } # Don't worry about $DiffProgram
    }
}

unless (defined $VcArchDir) {
    die "Error-0030: Can't find '/vc/archive/\@path' in '$cnst_VcParam')";
}

my $pth_clist = File::Spec->rel2abs(File::Spec->catfile($VcArchDir, $cnst_clist));

# ****************************
# * reading 'D_Coutlist.dat' *
# ****************************

my $coutlist = {};

if (-f $pth_clist) {
    $coutlist = retrieve($pth_clist);
    unless (defined $coutlist) {
        die "Error-0040: retrieve('$pth_clist') returned undef";
    }
}

# *************************************************
# * check that each $dirlist exists in $archlist. *
# *************************************************

my %archlist = map  { lc $coutlist->{$_}{$cnst_worklc}{id} => $coutlist->{$_}{$cnst_worklc} }
               grep { exists $coutlist->{$_}{$cnst_worklc}; }
               keys %$coutlist;

my %dirlist  = -e $cnst_workdir ? map { lc $_ => 1 } read_dir $cnst_workdir : ();

delete $dirlist{lc $cnst_xmllist}; # don't look at the xml checkout list

my %stemlist = map { ($_ =~ m{\A (.*) \. [^\.]* \z}xms ? $1 : $_) => 1 } keys %dirlist;

# use Data::Dumper; print Dumper { coutlist => $coutlist, archlist => \%archlist, dirlist => \%dirlist };

for (keys %dirlist) {
    unless (exists $archlist{$_}) {
        die "Error-0050: Found directory file '$_' which does not exist in archive";
    }
}

# **********************************************************
# * Populating @flist with the filenames to be checked out *
# **********************************************************

my @flist;

if (@ARGV) {
    @flist = @ARGV;
}
else {
    my $xmlflist = File::Spec->catfile($cnst_workdir, $cnst_xmllist);

    my $rdr = XML::Reader->newhd($xmlflist, {filter => 5},
      {root => '/checkout/file',  branch => ['/@name']},
    );

    if ($rdr) {
        while ($rdr->iterate) {
            if ($rdr->rx == 0) { push @flist, $rdr->rvalue->[0]; }
        }
    }
}

my $updctr = 0;

my $line_max = @flist;
my $line_ctr = 0;

for my $name_rel (@flist) {
    $line_ctr++;

    my $name_abs = File::Spec->rel2abs($name_rel);
    my $name_lc  = lc $name_abs;

    if ($name_abs =~ m{[%=]}xms) {
        die "Error-0060: Found characters /[%=]/ in \$name_abs = '$name_abs'";
    }

    my @name_ele = File::Spec->splitdir($name_abs);

    my $name_drive;
    if (@name_ele and $name_ele[0] =~ m{\A (.*) : \z}xms) {
        shift @name_ele;
        $name_drive = $1;
    }

    unless (@name_ele) {
        die "Error-0070: No filename in argument '$name_abs'";
    }

    my $name_short = $name_ele[-1];

    my ($name_stem, $name_ext) = $name_short =~ m{\A (.*) (\. [^\.]*) \z}xms ? ($1, $2) : ($name_short, '');

    my $name_arch = 'F_'.(defined $name_drive ? $name_drive.'%' : '').join '=', @name_ele;
    my $name_afull = File::Spec->catfile($VcArchDir, $name_arch);

    # ***************************
    # * Allocate a new $name_id *
    # ***************************

    my $name_id;

    for (1..999) {
        my $name_st = sprintf 'F_%s_Z%03d', $name_stem, $_;
        unless (exists $stemlist{lc $name_st}) {
            $name_id = $name_st.$name_ext;
            last;
        }
    }

    unless (defined $name_id) {
        die "Error-0080: Unable to allocate name for '$name_short' in dir '$cnst_workdir' after 1000 attempts";
    }

    # d�but modif Klaus Eichner, 2010-02-19:
    my $showname = $name_abs;
    $showname =~ s/\A\Q$ENV{USERPROFILE}/~/xms if defined $ENV{USERPROFILE};
    # fin   modif Klaus Eichner, 2010-02-19:

    if (exists $coutlist->{$name_lc}{$cnst_worklc}{id}) {
        printf "Ckout [%3d/%3d]             %-30s -- %s\n",
          $line_ctr, $line_max, $coutlist->{$name_lc}{$cnst_worklc}{id}, $showname;
        next;
    }

    unless (-e $name_abs) {
        printf "Ckout [%3d/%3d] --          %-30s -- %s\n",
          $line_ctr, $line_max, '** not found **', $showname;
        next;
    }

    # ****************************************
    # * Here we are commited to checking out *
    # ****************************************

    printf "Ckout [%3d/%3d] ** Write ** %-30s << %s\n",
      $line_ctr, $line_max, $name_id, $showname;

    my $stamp = localtime;

    unless (-e $cnst_workdir) {
        mkdir $cnst_workdir or die "Error-0090: Can't mkdir '$cnst_workdir' because $!";
    }

    my $block = {
       orig  => $name_abs,
       id    => $name_id,
       stamp => $stamp,
       path  => $cnst_workabs,
       arch  => $name_arch,
    };

    $coutlist->{$name_lc}{$cnst_worklc} = $block;
    $updctr++;

    unless (-e $name_afull) {
        copy $name_abs, $name_afull or die "Error-0100: Can't copy('$name_abs', '$name_afull') because $!";
    }

    my $name_ifull = File::Spec->catfile($cnst_workdir, $name_id);
    copy $name_afull, $name_ifull or die "Error-0110: Can't copy('$name_afull', '$name_ifull') because $!";
}

if ($updctr) {
    store $coutlist, $pth_clist or die "Error-0120: Can't store into '$pth_clist'";
}

unless ($opts{z}) {
    say '';
}