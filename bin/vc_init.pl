use strict;
use warnings;
use 5.010;

# **************************************************************************
# * This is the program "vc_init.pl", which is part of the larger package
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

use File::Vctools qw(get_mpath);
use File::Slurp;
use File::Spec;

my $cwd = File::Spec->rel2abs('.');

# determine the shell quote $q ==> (") on Windows, (') everywhere else...
my $q = $^O eq 'MSWin32' ? q{"} : q{'};

# determine the directory separator $d ==> (\) on Windows, (/) everywhere else...
my $d = $^O eq 'MSWin32' ? q{\\\\} : q{/};

# provide an example file path (for Windows or other OS)
my $exdir = $^O eq 'MSWin32' ? "C:\\dir_a\\dir_b\\data.txt" : "/dir_a/dir_b/data.txt";

my $perl = $^X;         $perl =~ s{\\}'\\\\'xmsg;
my $sbin = get_mpath(); $sbin =~ s{\\}'\\\\'xmsg;

my $cnst_workdir  = 'Work';
my $cnst_datadir  = 'Data';
my $cnst_cmddir   = 'Cmd';
my $cnst_xmllist  = 'B_Flist.xml';

say '****************************';
say '**  Initialising Project  **';
say '****************************';
say '';

my $show_dir = $cwd;
$show_dir =~ s/\A\Q$ENV{USERPROFILE}/~/xms if defined $ENV{USERPROFILE};

my @z_ele = File::Spec->splitdir($show_dir);

my $z_project = pop @z_ele;
my $z_path    = File::Spec->catdir(@z_ele);

printf "Project %-15s ==> %s\n", $z_project, $z_path;
say '';

my @files = grep {$_ ne $cnst_workdir
             and  $_ ne $cnst_datadir
             and  $_ ne $cnst_cmddir} read_dir '.';

if (@files) {
    local $" = "', '";
    die "Error-0010: Can't initialise Project because directory '$cwd' is not empty: ('@files')";
}

putdir($cnst_workdir);
putdir($cnst_datadir);
putdir($cnst_cmddir);

printf "Item [xml]  ==> %-25s : ", $cnst_xmllist;

my $xmlflist = File::Spec->catfile($cnst_workdir, $cnst_xmllist);
if (-f $xmlflist) {
    say '--- already exists';
}
else {
    say '*** Write ***';

    my $content =
      qq{<?xml version="1.0" encoding="iso-8859-1"?>\n}.
      qq{<checkout>\n}.
      qq{  <!--\n}.
      qq{  <file name="$exdir" />\n}.
      qq{  -->\n}.
      qq{</checkout>\n};

    write_file $xmlflist, $content;
}

my $p_name = 'a_'.(File::Spec->splitdir($cwd))[-1].'.txt';

printf "Item [txt]  ==> %-25s : *** Write ***\n", $p_name;

my $p_file = File::Spec->catfile($cnst_cmddir, $p_name);

write_file $p_file, "Project directory is: $cwd\n";

putinplace('Apply changes', 'P', 'r_apply.pl',     "go('vc_apply', '-q');\n");
putinplace('',              '',  'r_checkout.pl',  "go('vc_checkout');\n");
putinplace('',              '',  'r_list_det.pl',  "go('vc_list', '-c', '-d');\n");
putinplace('',              '',  'r_list_file.pl', "go('vc_list', '-c', '-n');\n");
putinplace('',              '',  'r_list_proj.pl', "go('vc_list', '-c');\n");
putinplace('Renew project', 'P', 'r_renew.pl',     "go('vc_reset');\n".
                                                   "go('vc_checkout', '-z');\n".
                                                   "go('vc_list', '-n', '-z', '-c');\n".
                                                   "go('vc_checkout', '-z');\n".
                                                   "go('vc_apply', '-q');\n");
putinplace('Reset',         '',  'r_reset.pl',     "go('vc_reset');\n");
putinplace('',              '',  'r_statchar.pl',  "go('vc_status', '-a', '-o', '-e', '-c');\n");
putinplace('',              '',  'r_statdiff.pl',  "go('vc_status', '-a', '-o', '-u', '-n');\n");
putinplace('',              '',  'r_status.pl',    "go('vc_status', '-a', '-o', '-e');\n");

say '';

sub putdir {
    my ($dir) = @_;

    printf "Item [dir]  ==> %-25s : ", $dir;
    if (-d $dir) {
        say '--- already exists';
    }
    else {
        say '*** Write ***';
        mkdir $dir or die "Error-0090: Can't mkdir '$dir' because $!";
    }
}

sub putinplace {
    my ($title, $proj, $filename, $text) = @_;

    my $prolog =
      qq!use strict;\n!.
      qq!use warnings;\n!.
      qq!use 5.010;\n!.
      qq!\n!;

    my $banner = '';
    unless ($title eq '') {
        $banner =
          qq!say '!.('*' x (length($title) + 4)).qq!';\n!.
          qq!say '* !.$title.qq! *';\n!.
          qq!say '!.('*' x (length($title) + 4)).qq!';\n!.
          qq!say '';\n!.
          qq!\n!;
    }

    my $chdir =
      qq!use File::Basename;\n!.
      qq!use File::Spec;\n!.
      qq!\n!.
      qq!my \$basedir = dirname \$0;\n!.
      qq!\n!.

      # qq!say "DEBUG-9900: 0 = '\$0', d = '\$basedir'";\n\n!.

      qq!chdir \$basedir !.qq!or die "Error-9910: Can't chdir '\$basedir' because \$\!";\n!.
      qq!chdir '..'     ! .qq!or die "Error-9920: Can't chdir '..' because \$\!";\n!.
      qq!\n!.
      qq!my \$curdir = File::Spec->rel2abs('.');\n!.
      qq!\n!;

    my $blank = '';
    unless ($title eq '') {
        $blank =
          qq!say '';\n!.
          qq!\n!;
    }

    my $showpr = '';
    if ($proj) {
        $showpr =
          qq!my \$show_dir = \$curdir;\n!.
          qq!\$show_dir =~ s/\\A\\Q\$ENV{USERPROFILE}/~/xms if defined \$ENV{USERPROFILE};\n!.
          qq!\n!.
          qq!my \@z_ele = File::Spec->splitdir(\$show_dir);\n!.
          qq!\n!.
          qq!my \$z_project = pop \@z_ele;\n!.
          qq!my \$z_path    = File::Spec->catdir(\@z_ele);\n!.
          qq!\n!.
          qq!printf "Project %-15s ==> %s\\n", \$z_project, \$z_path;\n!.
          qq!say '';\n!.
          qq!\n!;
    }

    my $epilog =
      qq!\n!.
      qq!sub go {\n!.
      qq!    my \$prog = shift;\n!.
      qq!\n!.
      qq!    my \$line =\n!.
      qq!      qq{$q$perl$q }.\n!.
      qq!      qq{$q$sbin$d}.\$prog.qq{.pl$q};\n!.
      qq!\n!.
      qq!    \$line .= qq{ $q\$_$q} for (\@_);\n!.
      qq!\n!.
      qq!    system \$line;\n!.
      qq!}\n!.
      qq!\n!;

    printf "Item [pl]   ==> %-25s : *** Write ***\n", $filename;
    write_file(File::Spec->catfile($cnst_cmddir, $filename), $prolog, $banner, $chdir, $showpr, $text, $blank, $epilog);
}
