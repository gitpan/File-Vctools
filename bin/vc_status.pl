use strict;
use warnings;
use 5.010;

# **************************************************************************
# * This is the program "vc_status.pl", which is part of the larger package
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
use XML::Reader;
use Storable qw(retrieve);
use File::Slurp;

use Getopt::Std;
getopts('aenou', \my %opts);

# option '-e' ==> extended output 
# option '-n' ==> no headers
# option '-u' ==> use unified diff -u
# option '-a' ==> show diff between archive and work
# option '-o' ==> show diff between work and original

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

say '*******************';
say '** Status Report **';
say '*******************';
say '';

{
    my $p_show = File::Spec->rel2abs('.');

    # début modif Klaus Eichner, 2010-02-19:
    $p_show =~ s/\A\Q$ENV{USERPROFILE}/~/xms if defined $ENV{USERPROFILE};
    # fin   modif Klaus Eichner, 2010-02-19:

    say "Project: $p_show";
    say '';
}

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
    unless (-e $file_arch) {
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

    my $p_arch  = File::Spec->catfile($VcArchDir, $archlist{$_}[0]{arch});
    my $p_orig  = $archlist{$_}[0]{orig};
    my $p_work  = $archlist{$_}[0]{id};
    my $p_stamp = $archlist{$_}[0]{stamp};
    my $p_path  = $archlist{$_}[0]{path};
    my $p_key   = $archlist{$_}[1];

    my $ex_arch = -e $p_arch ? 1 : 0;
    my $ex_work = -e $p_work ? 1 : 0;
    my $ex_orig = -e $p_orig ? 1 : 0;

    my $gen_name = (File::Spec->splitdir($p_orig))[-1];

    # **********************************************
    # * 'caw' ==> compare 'archive' against 'work' *
    # **********************************************

    my $caw_ins = 0;
    my $caw_del = 0;
    my @caw_lines;

    if ($ex_arch and $ex_work) {
        if ($opts{u}) {
            @caw_lines = qx{$difftool -u $q$p_arch$q $q$p_work$q};

            if (@caw_lines >= 2) {
                my $minus = shift(@caw_lines) || '';
                my $plus  = shift(@caw_lines) || '';

                $minus =~ m{\A --- \s}xms    or die "Error-0110: Expected --- at the beginning of line, but found '$minus'";
                $plus  =~ m{\A \+\+\+ \s}xms or die "Error-0120: Expected +++ at the beginning of line, but found '$plus'";

                unshift @caw_lines,
                    "[-] ARC/$gen_name\n",
                    "[+] WRK/$gen_name\n";
            }

            $caw_ins = () = grep { m{\A \+}xms } @caw_lines;
            $caw_del = () = grep { m{\A \-}xms } @caw_lines;
        }
        else {
            @caw_lines = qx{$difftool $q$p_arch$q $q$p_work$q};
            $caw_ins = () = grep { m{\A >}xms } @caw_lines;
            $caw_del = () = grep { m{\A <}xms } @caw_lines;
        }
    }

    # ***********************************************
    # * 'cow' ==> compare 'original' against 'work' *
    # ***********************************************

    my $cow_ins = 0;
    my $cow_del = 0;
    my @cow_lines;

    if ($ex_orig and $ex_work) {
        if ($opts{u}) {
            @cow_lines = qx{$difftool -u $q$p_orig$q $q$p_work$q};

            if (@cow_lines >= 2) {
                my $minus = shift(@cow_lines) || '';
                my $plus  = shift(@cow_lines) || '';

                $minus =~ m{\A --- \s}xms    or die "Error-0130: Expected --- at the beginning of line, but found '$minus'";
                $plus  =~ m{\A \+\+\+ \s}xms or die "Error-0140: Expected +++ at the beginning of line, but found '$plus'";

                unshift @cow_lines,
                    "[-] ORG/$gen_name\n",
                    "[+] WRK/$gen_name\n";
            }

            $cow_ins = () = grep { m{\A \+}xms } @cow_lines;
            $cow_del = () = grep { m{\A \-}xms } @cow_lines;
        }
        else {
            @cow_lines = qx{$difftool $q$p_orig$q $q$p_work$q};
            $cow_ins = () = grep { m{\A >}xms } @cow_lines;
            $cow_del = () = grep { m{\A <}xms } @cow_lines;
        }
    }

    # **************************************************
    # * 'cao' ==> compare 'archive' against 'original' *
    # **************************************************

    my $cao_ins = 0;
    my $cao_del = 0;
    my @cao_lines;

    if ($ex_arch and $ex_orig and !$ex_work) {
        if ($opts{u}) {
            @cao_lines = qx{$difftool -u $q$p_arch$q $q$p_orig$q};

            if (@cao_lines >= 2) {
                my $minus = shift(@cao_lines) || '';
                my $plus  = shift(@cao_lines) || '';

                $minus =~ m{\A --- \s}xms    or die "Error-0150: Expected --- at the beginning of line, but found '$minus'";
                $plus  =~ m{\A \+\+\+ \s}xms or die "Error-0160: Expected +++ at the beginning of line, but found '$plus'";

                unshift @cao_lines,
                    "[-] ARC/$gen_name\n",
                    "[+] ORG/$gen_name\n";
            }

            $cao_ins = () = grep { m{\A \+}xms } @cao_lines;
            $cao_del = () = grep { m{\A \-}xms } @cao_lines;
        }
        else {
            @cao_lines = qx{$difftool $q$p_arch$q $q$p_orig$q};
            $cao_ins = () = grep { m{\A >}xms } @cao_lines;
            $cao_del = () = grep { m{\A <}xms } @cao_lines;
        }
    }

    # ********************
    # * calculate action *
    # ********************

    my $rec1_action = '';
    my $rec2_action = '';

    if ($ex_work) {
        if ($ex_arch) {
            if ($caw_ins == 0 and $caw_del == 0) {
                $rec1_action = '----------------->';
            }
            else {
                $rec1_action = sprintf '--I=%04d/D=%04d-->', $caw_ins, $caw_del;
            }
        }
        if ($ex_orig) {
            if ($cow_ins == 0 and $cow_del == 0) {
                $rec2_action = '----------------->';
            }
            else {
                $rec2_action = sprintf '--I=%04d/D=%04d-->', $cow_ins, $cow_del;
            }
        }
    }
    else {
        if ($ex_arch and $ex_orig) {
            if ($cao_ins == 0 and $cao_del == 0) {
                $rec1_action = '----------------->';
            }
            else {
                $rec1_action = sprintf '--I=%04d/D=%04d-->', $cao_ins, $cao_del;
            }
        }
    }

    # ********************
    # * show result line *
    # ********************

    unless ($opts{n}) {
    
        if ($opts{e}) {
            say '=' x 95;
        }
        printf "[%3d/%3d] %-30s %-3s %-18s %-3s %-18s %-3s\n",
          $chg_ct,
          $chg_max,
          $p_work,
          ($ex_arch ? 'ARC': ''),
          $rec1_action,
          ($ex_work ? 'WRK': ''),
          $rec2_action,
          ($ex_orig ? 'ORG': ''),
        ;
        if ($opts{e}) {
            say '=' x 95;
        }
    }

    if ($opts{e}) {
        my $abs_work = File::Spec->rel2abs($p_work);

        showfile('ARC', $p_arch);
        showfile('WRK', $abs_work);
        showfile('ORG', $p_orig);
        say '';
    }

    if ($opts{a}) {
        if ($ex_work) {
            showdiff(\@caw_lines, 'ARC->WRK');
        }
        else {
            showdiff(\@cao_lines, 'ARC->ORG');
        }
    }
    if ($opts{o}) {
        showdiff(\@cow_lines, 'WRK->ORG');
    }

}

sub showdiff {
    my ($lines, $prf) = @_;

    for (@$lines) {
        my $prefix = $opts{e} ? $prf.': ' : '';
        print $prefix, $_;
    }

    if (@$lines) {
        say '';
    }
}

sub showfile {
    my ($prf, $fname) = @_;

    my $stamp = '';
    if (-e $fname) {
        my ($sec, $min, $hour, $day, $mon, $year) = localtime((stat $fname)[9]);
        $stamp = sprintf '%02d/%02d/%04d %02d:%02d:%02d',
          $day, $mon + 1, $year + 1900, $hour, $min, $sec;
    }

    # début modif Klaus Eichner, 2010-02-19:
    my $showname = $fname;
    $showname =~ s/\A\Q$ENV{USERPROFILE}/~/xms if defined $ENV{USERPROFILE};
    # fin   modif Klaus Eichner, 2010-02-19:

    printf "%-3s: %-19s %s\n", $prf, $stamp, $showname;
}
