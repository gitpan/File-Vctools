use strict;
use warnings;
use 5.010;

# **************************************************************************
# * This is the program "vc_apply.pl", which is part of the larger package
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

use File::Vctools qw(get_difftool);
use File::Spec;
use File::Basename;
use File::Copy;
use XML::Reader;
use Storable qw(retrieve store);
use File::Slurp;

use Getopt::Std;
getopts('q', \my %opts);

# option '-q' ==> perform quick comparison (eq/not eq) between file contents

# determine the shell quote $q ==> (") on Windows, (') everywhere else...
my $q = $^O eq 'MSWin32' ? q{"} : q{'};

my $cnst_workdir  = 'Work';
my $cnst_cmddir   = 'Cmd';
my $cnst_paramxml = 'vc_parameter.xml';
my $cnst_xmllist  = 'B_Flist.xml';
my $cnst_clist    = 'D_Coutlist.dat';
my $cnst_VcParam  = File::Spec->catfile(($ENV{'VCTOOLDIR'} || File::Spec->rel2abs(dirname($0))), $cnst_paramxml);
my $cnst_workabs  = File::Spec->catfile(File::Spec->rel2abs('.'), $cnst_workdir);
my $cnst_worklc   = lc $cnst_workabs;

my $magic_file = File::Spec->catfile($cnst_cmddir, 'r_apply.pl');
unless (-f $magic_file) {
    die "Error-0010: Can't find '$magic_file' - Program stopped";
}

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
        if ($rdr->rx == 1) { $DiffProgram = $rdr->rvalue->[0]; }
    }
}

unless (defined $VcArchDir) {
    die "Error-0040: Can't find '/vc/archive/\@path' in '$cnst_VcParam')";
}

unless (defined $DiffProgram) {
    $DiffProgram = get_difftool() or die "Error-0050: Can't get difftool from File::Vctools";
}

my $pth_clist = File::Spec->rel2abs(File::Spec->catfile($VcArchDir, $cnst_clist));
my $difftool  = ($DiffProgram =~ m{\.pl \z}xmsi ? $q.$^X.$q.' ' : '').$q.$DiffProgram.$q;

# ****************************
# * reading 'D_Coutlist.dat' *
# ****************************

my $coutlist = {};

if (-f $pth_clist) {
    $coutlist = retrieve($pth_clist);
    unless (defined $coutlist) {
        die "Error-0060: retrieve('$pth_clist') returned undef";
    }
}

# *************************************************
# * check that each $dirlist exists in $archlist. *
# *************************************************

my %archlist = map  { lc $coutlist->{$_}{$cnst_worklc}{id} => [$coutlist->{$_}{$cnst_worklc}, $_] }
               grep { exists $coutlist->{$_}{$cnst_worklc}; }
               keys %$coutlist;

my %dirlist  = -e $cnst_workdir ? map { lc $_ => 1 } read_dir $cnst_workdir : ();

delete $dirlist{lc $cnst_xmllist}; # don't look at the xml checkout list

# use Data::Dumper; print Dumper { coutlist => $coutlist, archlist => \%archlist, dirlist => \%dirlist };

for (keys %dirlist) {
    unless (exists $archlist{$_}) {
        die "Error-0070: Found directory file '$_' which does not exist in archive";
    }
}

for (sort keys %archlist) {
    my $file_arch = File::Spec->catfile($VcArchDir, $archlist{$_}[0]{arch});
    unless (-f $file_arch) {
        die "Error-0080: Archive file '$file_arch' does not exist";
    }
}

# *********************
# * Chdir into 'Work' *
# *********************

unless (-e $cnst_workdir) {
    mkdir $cnst_workdir or die "Error-0090: Can't mkdir '$cnst_workdir' because $!";
}

chdir $cnst_workdir or die "Error-0100: Can't chdir '$cnst_workdir' because $!";

# ***************************
# * Loop over all %archlist *
# ***************************

my $chg_max = keys %archlist;

my $chg_ct;
for (sort keys %archlist) {
    $chg_ct++;

    my $p_orig  = $archlist{$_}[0]{orig};
    my $p_id    = $archlist{$_}[0]{id};
    my $p_stamp = $archlist{$_}[0]{stamp};
    my $p_path  = $archlist{$_}[0]{path};
    my $p_arch  = $archlist{$_}[0]{arch};
    my $p_key   = $archlist{$_}[1];

    my $file_arch = File::Spec->catfile($VcArchDir, $p_arch);

    my $ln_ins = 0;
    my $ln_del = 0;

    my $ln_comp;

    if (-f $p_id) {
        if (-f $p_orig) {
            $ln_comp = 2;

            if ($opts{q}) {
                my $content_orig = read_file($p_orig);
                my $content_id   = read_file($p_id);
                $ln_ins = $content_orig eq $content_id ? 0 : -1;
                $ln_del = $ln_ins;
            }
            else {
                my @dlines = qx{$difftool $q$p_orig$q $q$p_id$q};

                $ln_ins = () = grep { m{\A >}xms } @dlines;
                $ln_del = () = grep { m{\A <}xms } @dlines;
            }
        }
        else {
            $ln_comp = 1;
        }
    }
    else {
        if (-f $p_orig and -f $file_arch) {
            $ln_comp = 3;

            if ($opts{q}) {
                my $content_orig = read_file($p_orig);
                my $content_arch = read_file($file_arch);
                $ln_ins = $content_orig eq $content_arch ? 0 : -1;
                $ln_del = $ln_ins;
            }
            else {
                my @dlines = qx{$difftool $q$p_orig$q $q$file_arch$q};

                $ln_ins = () = grep { m{\A >}xms } @dlines;
                $ln_del = () = grep { m{\A <}xms } @dlines;
            }
        }
        else {
            $ln_comp = 4;
        }
    }

    my $action;

    if ($ln_comp == 3 or $ln_comp == 4) {
        if ($ln_comp == 3 and $ln_ins == 0 and $ln_del == 0) {
            $action = '=>> no action <<= ';
        }
        else {
            if ($ln_comp == 3) {
                if ($ln_ins < 0 or $ln_del < 0) {
                    $action = '===== Update ====>';
                }
                else {
                    $action = sprintf '==I=%04d/D=%04d==>', $ln_ins, $ln_del;
                }
            }
            else {
                $action = sprintf '==== Restore ====>', $ln_ins, $ln_del;
            }
            if (-e $p_orig) {
                unlink $p_orig or die "Error-0110: Can't unlink '$p_orig' because $!";
            }
            copy $file_arch, $p_orig or die "Error-0120: Can't copy('$file_arch', '$p_orig') because $!";
        }

        delete $coutlist->{$p_key}{$cnst_worklc};
        store $coutlist, $pth_clist or die "Error-0130: Can't store into '$pth_clist'";
    }
    elsif ($ln_comp == 1) {
        $action = '----------------->';
        if (-e $p_orig) {
            unlink $p_orig or die "Error-0140: Can't unlink '$p_orig' because $!";
        }
        copy $p_id, $p_orig or die "Error-0150: Can't copy('$p_id', '$p_orig') because $!";
    }
    elsif ($ln_comp == 2) {
        if ($ln_ins == 0 and $ln_del == 0) {
            $action = ' ' x 18;
        }
        else {
            if ($ln_ins < 0 or $ln_del < 0) {
                $action = '===== Update ====>';
            }
            else {
                $action = sprintf '--I=%04d/D=%04d-->', $ln_ins, $ln_del;
            }
            if (-e $p_orig) {
                unlink $p_orig or die "Error-0160: Can't unlink '$p_orig' because $!";
            }
            copy $p_id, $p_orig or die "Error-0170: Can't copy('$p_id', '$p_orig') because $!";
        }
    }
    else {
       $action = '?? Invalid ??';
    }
    printf "Apply [%3d/%3d] %-30s %-3s %-18s %-3s %-18s %-3s%s\n",
      $chg_ct,
      $chg_max,
      $p_id,
      '',
      '',
      'WRK',
      $action,
      'ORG',
      ($ln_comp == 3 || $ln_comp == 4 ? ' (** Backout **)' : ''),
      ;
}
