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
use Algorithm::Diff; # in case option '-c' is requested as a command-line argument

use Getopt::Std;
getopts('acenouw:', \my %opts);

# option '-e' ==> extended output 
# option '-n' ==> no headers
# option '-u' ==> use unified diff -u

# option '-c'     ==> display diff char-by-char
# option '-w:999' ==> line length for diff char-by-char

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
    my $rdr = XML::Reader->new($cnst_VcParam, {mode => 'branches'},
      {root => '/vc/archive',  branch => ['/@path']},
      {root => '/vc/difftool', branch => ['/@prog']},
    ) or die "Error-0030: Can't XML::Reader->new('$cnst_VcParam') because $!";

    while ($rdr->iterate) {
        if ($rdr->rx == 0) { ($VcArchDir)   = $rdr->value; }
        if ($rdr->rx == 1) { ($DiffProgram) = $rdr->value; }
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

# ************************************
# reading 'D_Coutlist.dat' into $pmtab
# ************************************

my $coutlist = {};

if (-f $pth_clist) {
    $coutlist = retrieve($pth_clist);
    unless (defined $coutlist) {
        die "Error-0060: retrieve('$pth_clist') returned undef";
    }
}

for (keys %$coutlist) {
    unless (m{\A D_}xms) {
        die "Error-0062: in retrieve('$pth_clist') found key = '$_', but expected /^D_/";
    }
}

unless (exists $coutlist->{D_pmtab}) {
    $coutlist->{D_pmtab} = {};
}

my $pmtab = $coutlist->{D_pmtab};

#~ use Data::Dumper; print Dumper $pmtab;

# *************************************************
# * check that each $dirlist exists in $archlist. *
# *************************************************

my %archlist = map  { lc $pmtab->{$_}{$cnst_worklc}{id} => [$pmtab->{$_}{$cnst_worklc}, $_] }
               grep { exists $pmtab->{$_}{$cnst_worklc}; }
               keys %$pmtab;

# ******************************************************************************
# ** executive decision by Klaus Eichner, 23 July 2010:
# ** We *DO NOT* warn in vc_status.pl if the file does not exist in the archive
#
# my %dirlist  = -e $cnst_workdir ? map { $_ => 1 } read_dir $cnst_workdir : ();
#
# delete $dirlist{$cnst_xmllist}; # don't look at the xml checkout list
#
# ** use Data::Dumper; print Dumper
# **   { coutlist => $pmtab, archlist => \%archlist, dirlist => \%dirlist };
#
# for (keys %dirlist) {
#     unless (exists $archlist{lc $_}) {
#         warn "Warning-04: Found file '$_' which does not exist in archive";
#     }
# }
# ******************************************************************************

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

    my $p_prefix = $opts{e} ? $prf.': ' : '';

    if ($opts{c} and !$opts{u}) {

        my $p_linewd = 110;
        if ($opts{w}) {
            $p_linewd = $opts{w};
            $p_linewd =~ s{\D}''xmsg;
            $p_linewd += 0;
        }

        my ($hk_hunk, $hk_red, $hk_blue) = ('', '', '');

        for (@$lines, '#') {
            if (m{\A \d}xms or m{\A \#}xms) {
                if ($hk_hunk) {
                    print $p_prefix, $hk_hunk;

                    my @chg;

                    my @chars_red  = split m{}xms, $hk_red;
                    my @chars_blue = split m{}xms, $hk_blue;

                    if (@chars_red == 0) {
                        @chg = map {['+', '', $_]} @chars_blue;
                    }
                    elsif (@chars_blue == 0) {
                        @chg = map {['-', $_, '']} @chars_red;
                    }
                    else {

                        my @c_red;
                        my $prv_red = '?';
                        for (@chars_red) {
                            my $cur_red = $_ eq "\n" ? 'n' : m{\w}xms ? 'w' : 's';
                            if ($cur_red ne $prv_red or $cur_red eq 'n') {
                                push @c_red, '';
                            }
                            $c_red[-1] .= $_;
                            $prv_red = $cur_red;
                        }

                        my @c_blue;
                        my $prv_blue = '?';
                        for (@chars_blue) {
                            my $cur_blue = $_ eq "\n" ? 'n' : m{\w}xms ? 'w' : 's';
                            if ($cur_blue ne $prv_blue or $cur_blue eq 'n') {
                                push @c_blue, '';
                            }
                            $c_blue[-1] .= $_;
                            $prv_blue = $cur_blue;
                        }

                        #~ use Data::Dumper;
                        #~ my $dsp_red  = Dumper(\@c_red);  $dsp_red  =~ s{\s}''xmsg; say "DEB-0010: red  => $dsp_red";
                        #~ my $dsp_blue = Dumper(\@c_blue); $dsp_blue =~ s{\s}''xmsg; say "DEB-0020: blue => $dsp_blue";

                        # Here we run the actual diff, word-by-word, of one single hunk (= possibly multiple lines)...
                        my @blocks = Algorithm::Diff::sdiff(\@c_red, \@c_blue);
                        push @blocks, ['*', '', ''];

                        my @line_red;
                        my @line_blue;

                        for my $c (@blocks) {
                            my $cur_action = $c->[0];
                            my $cur_red    = $c->[1];
                            my $cur_blue   = $c->[2];

                            if ($cur_action eq '*' or $cur_red eq "\n" or $cur_blue eq "\n") {
                                push @line_red,  "\n" if $cur_red  eq "\n";
                                push @line_blue, "\n" if $cur_blue eq "\n";

                                if (@line_red or @line_blue) {
                                    # Here we run the actual diff, character-by-character, of one single line...
                                    my @mini = Algorithm::Diff::sdiff(\@line_red, \@line_blue);
                                    push @chg, @mini;
                                }

                                @line_red  = ();
                                @line_blue = ();
                            }
                            last if $cur_action eq '*';
 
                            push @line_red,  split(m{}xms, $cur_red)  unless $cur_red  eq "\n";
                            push @line_blue, split(m{}xms, $cur_blue) unless $cur_blue eq "\n";
                        }
                    }

                    push @chg, ['*', '', ''];

                    my $prev_action = '';

                    my $container_red  = '';
                    my $container_blue = '';

                    my @cont;
                    for my $c (@chg) {
                        my $cur_action = $c->[0];
                        my $cur_red    = $c->[1];
                        my $cur_blue   = $c->[2];

                        my $cur_break  = ($cur_red eq "\n" or $cur_blue eq "\n") ? 1 : 0;

                        if ($cur_action eq '*'
                        or ($cur_action eq 'u' and $prev_action ne 'u')
                        or ($cur_action ne 'u' and $prev_action eq 'u')
                        or  $cur_break) {
                            $container_red  .= "\n" if $cur_red  eq "\n";
                            $container_blue .= "\n" if $cur_blue eq "\n";

                            if ($container_red ne '' or $container_blue ne '') {
                                push @cont, [$container_red, $container_blue];
                            }
                            if ($cur_break) {
                                push @cont, ['', ''];
                            }
                            $container_red  = '';
                            $container_blue = '';
                        }
                        last if $cur_action eq '*';

                        $container_red  .= $cur_red  unless $cur_red  eq "\n";
                        $container_blue .= $cur_blue unless $cur_blue eq "\n";

                        $prev_action = $cur_action;
                    }

                    # make sure that @cont terminates with ['', '']
                    push @cont, ['', ''];

                    #~ use Data::Dumper; say Dumper(\@cont);

                    my $disp_red   = '';
                    my $disp_white = '';
                    my $disp_blue  = '';

                    my $disp_counter = 0;

                    for my $ct (@cont) {

                        if ($ct->[0] eq '' and $ct->[1] eq '') {

                            unless ($disp_white eq '') {
                                my $offset = 0;

                                say $p_prefix, '--', '-' x $p_linewd if $disp_counter == 0;

                                $disp_counter++;

                                while ($offset < length($disp_white)) {
                                    my $fragment_red   = substr($disp_red,   $offset, $p_linewd);
                                    my $fragment_white = substr($disp_white, $offset, $p_linewd);
                                    my $fragment_blue  = substr($disp_blue,  $offset, $p_linewd);

                                    my $marker_red   = '';
                                    my $marker_white = '';
                                    my $marker_blue  = '';

                                    if ($offset == 0) {
                                        $marker_red   = '>';
                                        $marker_blue  = '<';
                                        $marker_white = $disp_white =~ m{\S}xms ? '*' : '-';
                                    }

                                    say $p_prefix unless $offset == 0;

                                    printf "%s%-1s %s\n", $p_prefix, $marker_blue,  $fragment_blue;
                                    printf "%s%-1s %s\n", $p_prefix, $marker_white, $fragment_white;
                                    printf "%s%-1s %s\n", $p_prefix, $marker_red,   $fragment_red;

                                    $offset += $p_linewd;
                                }

                                say $p_prefix, '--', '-' x $p_linewd;
                            }

                            $disp_red   = '';
                            $disp_white = '';
                            $disp_blue  = '';
                        }
                        else {
                            for ($ct->[0], $ct->[1]) {
                                s{(~)}{sprintf('~[%d]',ord($1))}xmsge;
                                s{\n}{~\\}xmsg;
                                s{([[:cntrl:]`])}{sprintf('~[%d]',ord($1))}xmsge;
                                s{[ ]}'`'xmsg;
                            }

                            my $maxsize = length($ct->[0]) > length($ct->[1]) ? length($ct->[0]) : length($ct->[1]);

                            $disp_red   .= sprintf "%-${maxsize}s", $ct->[0];
                            $disp_blue  .= sprintf "%-${maxsize}s", $ct->[1];
                            $disp_white .= ($ct->[0] eq $ct->[1] ? ' ' : '*') x $maxsize;
                        }
                    }
                    say '';
                }

                ($hk_hunk, $hk_red, $hk_blue) = ('', '', '');
            }

            if (m{\A \d}xms) {
                $hk_hunk = $_;
            }
            elsif (m{\A > [ ]? (.*) \z}xms) {
                $hk_red .= $1;
            }
            elsif (m{\A < [ ]? (.*) \z}xms) {
                $hk_blue .= $1;
            }
        }
    }
    else {
        for (@$lines) {
            print $p_prefix, $_;
        }

        if (@$lines) {
            say '';
        }
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
