use strict;
use warnings;
use 5.010;

# **************************************************************************
# * This is the program "vc_list.pl", which is part of the larger package
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
getopts('cdnz', \my %opts);

# option '-c' ==> perform cleanup operations
# option '-d' ==> show detailed checkouts
# option '-n' ==> show "normalized" detailed checkouts (similar to '-d')
# option '-z' ==> no headers are displayed ("-z ==> zero header")

# determine the shell quote $q ==> (") on Windows, (') everywhere else...
my $q = $^O eq 'MSWin32' ? q{"} : q{'};

my $cnst_workdir  = 'Work';
my $cnst_paramxml = 'vc_parameter.xml';
my $cnst_clist    = 'D_Coutlist.dat';
my $cnst_VcParam  = File::Spec->catfile(($ENV{'VCTOOLDIR'} || File::Spec->rel2abs(dirname($0))), $cnst_paramxml);
my $cnst_workabs  = File::Spec->catfile(File::Spec->rel2abs('.'), $cnst_workdir);
my $cnst_worklc   = lc $cnst_workabs;

unless ($opts{z}) {
    if ($opts{c}) {
        if ($opts{n}) {
            say '**************************';
            say '** List Files (Cleanup) **';
            say '**************************';
        }
        elsif ($opts{d}) {
            say '****************************';
            say '** List Details (Cleanup) **';
            say '****************************';
        }
        else {
            say '*****************************';
            say '** List Projects (Cleanup) **';
            say '*****************************';
        }
    }
    else {
        if ($opts{n}) {
            say '****************';
            say '** List Files **';
            say '****************';
        }
        elsif ($opts{d}) {
            say '******************';
            say '** List Details **';
            say '******************';
        }
        else {
            say '*******************';
            say '** List Projects **';
            say '*******************';
        }
    }

    say '';
}

# **************************
# reading 'vc_parameter.xml'
# **************************

my $VcArchDir;
my $DiffProgram;
{
    my $rdr = XML::Reader->newhd($cnst_VcParam, {filter => 5},
      {root => '/vc/archive',  branch => ['/@path']},
      {root => '/vc/difftool', branch => ['/@prog']},
    ) or die "Error-0010: Can't XML::Reader->newhd('$cnst_VcParam') because $!";

    while ($rdr->iterate) {
        if ($rdr->rx == 0) { $VcArchDir   = $rdr->rvalue->[0]; }
        if ($rdr->rx == 1) { $DiffProgram = $rdr->rvalue->[0]; } # Don't worry about $DiffProgram
    }
}

unless (defined $VcArchDir) {
    die "Error-0020: Can't find '/vc/archive/\@path' in '$cnst_VcParam')";
}

my $pth_clist = File::Spec->rel2abs(File::Spec->catfile($VcArchDir, $cnst_clist));

# début modif Klaus Eichner, 2010-02-19:
my $show_pth_clist = $pth_clist;
$show_pth_clist =~ s/\A\Q$ENV{USERPROFILE}/~/xms if defined $ENV{USERPROFILE};
# fin   modif Klaus Eichner, 2010-02-19:

unless ($opts{z}) {
    say "Reading $show_pth_clist";
    say '';
}

# ************************************
# reading 'D_Coutlist.dat' into $pmtab
# ************************************

my $pmtab = {};

if (-f $pth_clist) {
    $pmtab = retrieve($pth_clist);
    unless (defined $pmtab) {
        die "Error-0050: retrieve('$pth_clist') returned undef";
    }
}

#~ use Data::Dumper; print Dumper $pmtab;

# ********************
# constructing %pmxref
# ********************

my %pmxref;

for (read_dir $VcArchDir) {
    next if $_ eq $cnst_clist;

    unless (m{\A F_ (.*) \z}xms) {
        die "Error-0060: Can't decompose filename: '$_'";
    }

    my $nm_file = $1; $nm_file =~ s{%}':='xmsg;
    my $nm_real = File::Spec->catfile(split m{=}xms, $nm_file);
    my $nm_rlc  = lc $nm_real;

    $pmxref{$nm_rlc} = {
      real => $nm_real,
      code => $_,
      ref  => 0,
    };
}

# ***********************************************
# Calculate 'nep' ==> number of entries in $pmtab
# ***********************************************

my $nep_ctr = 0;
my $nep_max = 0;

for (keys %pmxref) {
    $nep_max += keys %{$pmtab->{$_}} if exists $pmtab->{$_};
}

my $g_empty      = 0;
my $g_upd_leaf   = 0;
my $g_upd_branch = 0;
my $g_upd_stem   = 0;
my $g_filectr    = 0;

# ******************************
# Loop over all files in %pmxref
# ******************************

for my $px_lcname (sort keys %pmxref) {
    next unless exists $pmtab->{$px_lcname};

    my $pmlist = $pmtab->{$px_lcname};

    $g_filectr++;

    # *******************************
    # Read "real-file" and "code-file
    # *******************************

    my $px_real     = $pmxref{$px_lcname}{real};
    my $px_code     = $pmxref{$px_lcname}{code};
    my $px_fullcode = File::Spec->catfile($VcArchDir, $px_code);

    my $px_ct_code  = -f $px_fullcode ? read_file($px_fullcode) : '';
    my $px_ct_real  = -f $px_real     ? read_file($px_real)     : '';

    my $px_status = '*';

    if (-f $px_fullcode) {
        if (-f $px_real) {
            $px_status = $px_ct_code eq $px_ct_real ? '-' : '+';
        }
        else {
            $px_status = '#';
        }
    }

    # *********************
    # Initialise %px_attrib
    # *********************

    my $px_count = 0;
    my $px_project;
    my %px_attrib;

    for my $py_name (sort keys %$pmlist) {
        my $py_path = $pmlist->{$py_name}{path};
        my $py_id   = $pmlist->{$py_name}{id};
        my $py_file = File::Spec->catfile($py_path, $py_id);
        my $py_ok   = -f $py_file ? 1 : 0;

        $px_count += $py_ok;

        my @py_ele = File::Spec->splitdir($py_path);
        my $py_dir = '';
        if (@py_ele > 2 and $py_ele[-1] eq $cnst_workdir) {
            pop @py_ele;
            $py_dir = pop @py_ele;
        }

        my $py_match = 'N';
        my $py_modif = 'N';
        if ($py_ok) {
            my $py_ct_file = read_file($py_file);

            $py_match = 'Y' if $py_ct_file eq $px_ct_real;
            $py_modif = 'Y' if $py_ct_file ne $px_ct_code;
        }

        if ($py_match eq 'Y') {
            if (defined $px_project) {
                $px_project = '>>Multi<<';
            }
            else {
                $px_project = $py_dir;
            }
        }

        $px_attrib{$py_name}{del}   = $py_ok == 0 ? ($opts{c} ? 'D' : 'Z') : 'O';
        $px_attrib{$py_name}{dir}   = $py_dir;
        $px_attrib{$py_name}{path1} = File::Spec->catfile(@py_ele);
        $px_attrib{$py_name}{match} = $py_match;
        $px_attrib{$py_name}{modif} = $py_modif;
    }

    unless (defined $px_project) {
        $px_project = '>>Dirty<<';
    }

    # ****************
    # Show header line
    # ****************

    unless ($opts{n}) {
        # début modif Klaus Eichner, 2010-02-19:
        my $show_real = $px_real;
        $show_real =~ s/\A\Q$ENV{USERPROFILE}/~/xms if defined $ENV{USERPROFILE};
        # fin   modif Klaus Eichner, 2010-02-19:

        my $info = $px_count == 0 ? ($opts{c} ? '<clear>' : '') : (sprintf '[CO=%3d]', $px_count);

        my $msg;
        given ($px_status) {
            when ('-') { $msg = '';            }
            when ('+') { $msg = $px_project;   }
            when ('#') { $msg = '?? Err 1 ??'; }
            default    { $msg = '?? Err 2 ??'; }
        }

        printf "%4d. %-8s %-15s %s\n", $g_filectr, $info, $msg, $show_real;
    }

    # ****************
    # Show detail line
    # ****************

    if ($opts{d} or $opts{n}) {

        for my $py_name (sort keys %$pmlist) {
            $nep_ctr++;

            my $py_path  = $pmlist->{$py_name}{path};
            my $py_id    = $pmlist->{$py_name}{id};
            my $py_stamp = $pmlist->{$py_name}{stamp}; $py_stamp =~ s{\s}'0'xmsg;
            my $py_file  = File::Spec->catfile($py_path, $py_id);
            my $py_ok    = -f $py_file ? 1 : 0;

            my $py_date = length($py_stamp) >= 24 ?
                substr($py_stamp,  8, 2).'-'.
                substr($py_stamp,  4, 3).'-'.
                substr($py_stamp, 20, 4).' '.
                substr($py_stamp, 11, 8)
              :
                '???';

            my $py_dir   = $px_attrib{$py_name}{dir};
            my $py_path1 = $px_attrib{$py_name}{path1};

            # début modif Klaus Eichner, 2010-02-19:
            my $show_name = $py_path1;
            $show_name =~ s/\A\Q$ENV{USERPROFILE}/~/xms if defined $ENV{USERPROFILE};
            # fin   modif Klaus Eichner, 2010-02-19:

            my $py_del   = $px_attrib{$py_name}{del};
            my $py_match = $px_attrib{$py_name}{match};
            my $py_modif = $px_attrib{$py_name}{modif};

            my $dlong  = $py_del eq 'D'   ? '** Del **' : $py_del eq 'Z'    ? 'not found' : '';
            my $dshort = $py_del eq 'D'   ? 'D'         : $py_del eq 'Z'    ? 'Z'         : '-';
            my $dexist = $py_ok           ? '-'                                           : '?';

            my $dmatch;
            if ($py_match eq 'Y') {
                $dmatch = $px_status eq '-' ? '' : '=>';
            }
            else {
                $dmatch = $py_modif eq 'Y' ? '+' : '';
            }

            if ($opts{n}) {
                printf "List  [%3d/%3d] %-30s %-2s %-15s %-9s %s\n",
                  $nep_ctr, $nep_max, $py_id, $dmatch, $py_dir, $dlong, $show_name;
            }
            else {
                printf "    %-2s %-15.15s -%-1s%-1s-> %-30s %-20s %s\n",
                  $dmatch, $py_dir, $dshort, $dexist, $py_id, $py_date, $show_name;
            }
        }
        unless ($opts{n}) {
            say '';
            $g_empty = 1;
        }
    }

    # ****************************************
    # Housekeeping: remove leaves and branches
    # ****************************************

    if ($opts{c}) {
        for my $py_name (sort keys %$pmlist) {
            if ($px_attrib{$py_name}{del} eq 'D') {
                delete $pmlist->{$py_name};
                $g_upd_leaf++;
            }
        }

        if ($px_count == 0) {
            if ($px_status ~~ ['+', '-']) {
                unlink $px_real             or die "Error-0070: Can't unlink '$px_real' because $!";
                move $px_fullcode, $px_real or die "Error-0080: Can't move '$px_fullcode', '$px_real' because $!";
            }
            elsif ($px_status eq '#') {
                move $px_fullcode, $px_real or die "Error-0090: Can't move '$px_fullcode', '$px_real' because $!";
            }
            delete $pmtab->{$px_lcname};
            $g_upd_branch++;
        }
    }
}

# ********************************************************************************
# Housekeeping: remove stems - those entries in $pmtab that don't exist in %pmxref
# ********************************************************************************

if ($opts{c}) {
    for (keys %$pmtab) {
        unless (exists $pmxref{$_}) {
            delete $pmtab->{$_};
            $g_upd_stem++;
        }
    }
}

unless ($opts{z}) {
    say '' unless $g_empty;
}

if ($opts{c} and $g_upd_leaf + $g_upd_branch + $g_upd_stem > 0) {
    unless ($opts{n}) {
        say "Writing (leaf=$g_upd_leaf, branch=$g_upd_branch, stem=$g_upd_stem) to $show_pth_clist";
        say '';
    }
    store $pmtab, $pth_clist or die "Error-0100: Can't store into '$pth_clist'";
}
