package File::Vctools;

use strict;
use warnings;
use 5.010;

use File::Spec;

require Exporter;

our @ISA         = qw(Exporter);
our %EXPORT_TAGS = ( all => [ qw(get_difftool get_mpath) ] );
our @EXPORT_OK   = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT      = qw();
our $VERSION     = '0.06';

# =============================================================================================
# This module is basically empty, its main purpose in life is to assemble all the different
# Vctool programs ('vc_status.pl', 'vc_checkout.pl', 'vc_apply.pl', etc...) all together
# in a nice CPAN-enabled package.
#
# But in addition to assembling the different Vctool programs, this file also...
#   - holds the actual version number of File::Vctools (our $VERSION)
#   - sets the minimum perl version to 5.10
#   - contains the POD documentation (in English) -- although there also exist documentations
#     in French (see 'Vctools_fr.pod') and in German (see 'Vctools_de.pod')
#   - exports two utility functions: 'get_difftool()' and 'get_mpath()'
# =============================================================================================

# probe 'diffnew.pl' in @INC and store the resulting full-path name in $difftool

my $difftool;

for (@INC) {
    my @dirs = File::Spec->splitdir($_);
    my $probetool = File::Spec->catdir(@dirs, 'Algorithm', 'diffnew.pl');

    if (-f $probetool) {
        $difftool = $probetool;
        last;
    }
}

# probe 'vc_status.pl' in @INC and store the directory in $mpath

my $mpath;

for (@INC) {
    my @dirs = File::Spec->splitdir($_);

    if (@dirs > 1 and $dirs[-1] eq 'lib') {
        my $probe = 'vc_status.pl';
        my $path_script = File::Spec->catdir(@dirs[0..$#dirs - 1], 'script');
        my $path_bin    = File::Spec->catdir(@dirs[0..$#dirs - 1], 'bin');

        if (-f File::Spec->catdir($path_script, $probe)) {
            $mpath = $path_script;
            last;
        }

        if (-f File::Spec->catdir($path_bin,    $probe)) {
            $mpath = $path_bin;
            last;
        }
    }
}

sub get_difftool { $difftool; }
sub get_mpath    { $mpath;    }

1;

__END__

=head1 NAME

File::Vctools - Compare different versions of text files and identify changes

=head1 SYNOPSIS

File::Vctools is a collection of utility programs that help you to organise your
projects. Currently, File::Vctools only runs on Windows and on Linux, but if somebody
wants to run it on a platform other than Windows or Linux, the conversion should
be easy. If you already have converted File::Vctools to a different platform, let me
know at <klaus03@gmail.com>, I appreciate any feedback.

Here is a first program that runs the components of File::Vctools:

  use strict;
  use warnings;
  use 5.010;

  use File::Vctools qw(get_mpath get_difftool);
  use File::Spec;
  use File::Slurp;
  use File::Temp qw(tempdir);

  my $difftool = get_difftool();
  my $mpath    = get_mpath();
  my $cwd      = File::Spec->rel2abs('.'); END { chdir $cwd if defined $cwd; }
  my $tempdir  = tempdir(CLEANUP => 1);

  say "difftool is $difftool";
  say "mpath    is $mpath";
  say "cwd      is $cwd";
  say "tempdir  is $tempdir";
  say '';

  mkdir File::Spec->catdir($tempdir, 'XmlRepo');
  mkdir File::Spec->catdir($tempdir, 'test_arch');
  mkdir File::Spec->catdir($tempdir, 'Original');
  mkdir File::Spec->catdir($tempdir, 'P001');

  $ENV{VCTOOLDIR} = File::Spec->catdir($tempdir, 'XmlRepo');

  write_file(File::Spec->catdir($tempdir, 'XmlRepo', 'vc_parameter.xml'),
    qq{<?xml version="1.0" encoding="iso-8859-1"?>\n},
    qq{<vc>\n},
    qq{  <archive path="}, File::Spec->catdir($tempdir, 'test_arch'), qq{" />\n},
    qq{</vc>\n},
  );

  write_file(File::Spec->catfile($tempdir, 'Original', 'file.txt'),
    qq{Line001\n},
    qq{Line002\n},
    qq{Line003\n},
    qq{Line004\n},
  );

  chdir File::Spec->catdir($tempdir, 'P001') or die "Error-0010: chdir $!";

  system $^X, File::Spec->catfile($mpath, 'vc_init.pl');
  system $^X, File::Spec->catfile($mpath, 'vc_checkout.pl'), File::Spec->catfile($tempdir, 'Original', 'file.txt');

  write_file(File::Spec->catfile('Work', 'F_file_Z001.txt'),
    qq{Line001\n},
    qq{Line002 ***\n},
    qq{Line003\n},
    qq{Line004\n},
  );

  system $^X, File::Spec->catfile($mpath, 'vc_apply.pl');
  system $^X, File::Spec->catfile($mpath, 'vc_status.pl'), '-a', '-o';
  system $^X, File::Spec->catfile($mpath, 'vc_list.pl');
  system $^X, File::Spec->catfile($mpath, 'vc_reset.pl');

  chdir 'Data' or die "Error-0020: chdir $!";

  write_file('orig.txt',
    qq{Orig001\n},
    qq{Orig002\n},
    qq{Orig003\n},
    qq{Orig004\n},
    qq{Orig005\n},
  );

  write_file('patch.txt',
    qq{\@\@ -2,4 +2,4 \@\@\n},
    qq{ Orig002\n},
    qq{-Orig003\n},
    qq{+Orig003***\n},
    qq{ Orig004\n},
  );

  system $^X, File::Spec->catfile($mpath, 'vc_merge.pl'),
    '--input=orig.txt', '--diff=patch.txt', '--output=out.txt';

Here is the output (on a Windows system):

  # difftool is C:\Perl\lib\Algorithm\diffnew.pl
  # mpath    is C:\Perl\site\bin
  # cwd      is C:\Users\user1\Documents\Sandbox
  # tempdir  is C:\Users\user1\AppData\Local\Temp\6ALx6IvP22
  #
  # ****************************
  # **  Initialising Project  **
  # ****************************
  #
  # Project P001            ==> ~\AppData\Local\Temp\6ALx6IvP22
  #
  # Item [dir]  ==> Work                      : *** Write ***
  # Item [dir]  ==> Data                      : *** Write ***
  # Item [dir]  ==> Cmd                       : *** Write ***
  # Item [xml]  ==> B_Flist.xml               : *** Write ***
  # Item [txt]  ==> a_Project.txt             : *** Write ***
  # Item [pl]   ==> r_apply.pl                : *** Write ***
  # Item [pl]   ==> r_checkout.pl             : *** Write ***
  # Item [pl]   ==> r_list_det.pl             : *** Write ***
  # Item [pl]   ==> r_list_file.pl            : *** Write ***
  # Item [pl]   ==> r_list_proj.pl            : *** Write ***
  # Item [pl]   ==> r_renew.pl                : *** Write ***
  # Item [pl]   ==> r_reset.pl                : *** Write ***
  # Item [pl]   ==> r_statchar.pl             : *** Write ***
  # Item [pl]   ==> r_statdiff.pl             : *** Write ***
  # Item [pl]   ==> r_status.pl               : *** Write ***
  #
  # ***************************
  # ** Checking out programs **
  # ***************************
  #
  # Project P001            ==> ~\AppData\Local\Temp\6ALx6IvP22
  #
  # Ckout [  1/  1] ** Write ** F_file_Z001.txt                << ~\AppData\Local\Temp\6ALx6IvP22\Data\file.txt
  #
  # Apply [  1/  1] F_file_Z001.txt                                       WRK --I=0001/D=0001--> ORG
  # *******************
  # ** Status Report **
  # *******************
  #
  # Project P001            ==> ~\AppData\Local\Temp\6ALx6IvP22
  #
  # [  1/  1] F_file_Z001.txt                ARC --I=0001/D=0001--> WRK -----------------> ORG
  # 2c2
  # < Line002
  # ---
  # > Line002 ***
  #
  # *******************
  # ** List Projects **
  # *******************
  #
  # Reading ~\AppData\Local\Temp\6ALx6IvP22\test_arch\D_Coutlist.dat
  #
  # Project P001            ==> ~\AppData\Local\Temp\6ALx6IvP22
  #
  #    1. [CO=  1] P001            ~\AppData\Local\Temp\6ALx6IvP22\Data\file.txt
  #
  # Reset [  1/  1] rewrite ==> ~\AppData\Local\Temp\6ALx6IvP22\Data\file.txt
  # *******************************
  # ** Merging diffs into a file **
  # *******************************
  #
  # input file  = 'orig.txt'
  # diff        = 'patch.txt'
  # output file = 'out.txt'
  #
  # There are 1 hunks:
  #   1. @@ -00002,00004 +00002,00004 @@ --> Orig002 Orig003 Orig004
  #
  # Output successfully written to 'out.txt'

=head1 PREPARATION

=head2 Archive

The archive is a directory where the backups are held. This directory is initially
empty, but is populated by backups whenever a checkout is performed. The archive can
be any directory, but you need to have write access to that directory.

=head2 Diff method

As per default, a perl program ('diffnew.pl') in the Algorithm::Diff namespace is
called whenever the difference between two text files needs to be calculated. This
perl program works correctly, but is very slow.

It is better to redirect to the internal diff command, which is much faster. There
should be an internal diff command already built into Linux.

On Windows, however, there is no prebuilt internal diff command. Therefore it is
recommended practice on Windows to download and install the GNU port of diff:

=over

=item Step 1

goto http://gnuwin32.sourceforge.net/packages/diffutils.htm

=item Step 2

Download and unzip two archives: diffutils-bin.zip and diffutils-dep.zip

=item Step 3

The archive 'diffutils-bin.zip' contains 4 files (*.exe) in the bin/ subdirectory:
'cmp.exe', 'diff.exe', 'diff3.exe' and 'sdiff.exe'.

=item Step 4

The archive 'diffutils-dep.zip' contains 2 files (*.dll) in the bin/ subdirectory:
'libiconv2.dll' and 'libintl3.dll'.

=item Step 5

All 6 files (*.exe and *.dll) need to be extracted into the same directory, and that
directory should be in the path.

=back

=head2 Parameter file

After successfully installing the package File::Vctools, we need to prepare (create
from scratch) the parameter file called 'vc_parameter.xml'. This file needs to be
placed in the directory where the files 'vc_init.pl', 'vc_checkout.pl', 'vc_apply.pl',
etc... are stored (this is typically the site/bin/ directory, but can also be a
different directory if the files have been relocated).

The parameter file contains two bits of information: firstly it specifies the
archive location where the backups are stored. Secondly, it specifies (optional) a
difftool that points to a replacement for the diffnew.pl of Algorithm::Diff.

Here is a sample 'vc_parameter.xml':

  <?xml version="1.0" encoding="iso-8859-1"?>
  <vc>
    <archive  path="/home/user1/Programs/vc_archive" />
    <difftool prog="diff" />
  </vc>

Of course, we have to make sure that the directory /home/user1/Programs/vc_archive
actually exists:

  ~> cd /home/user1/Programs

  ~/Programs> mkdir vc_archive

  ~/Programs> ll

  # total 1
  # drwxr-xr-x  2 user1 user1  4096 2010-04-06 16:37 vc_archive

  ~/Programs>

=head1 COMPONENTS

There are seven main components in File::Vctools: vc_init.pl, vc_checkout.pl, vc_apply.pl,
vc_status.pl, vc_reset.pl, vc_list.pl and vc_merge.pl.

=head2 vc_init.pl

vc_init.pl is the first command to use in File::Vctools. Make sure that you have chdir'ed into
an empty directory, then issue the command 'perl .../site/bin/vc_init.pl' (use the command 'perl
-V:sitebin' to find out the exact location of the site/bin directory). vc_init.pl sets
up a subdirectory 'Work', a directory 'Data' and a directory 'Cmd' with 10 "shortcut" programs ('r_*.pl'):

  ~> cd /home/user1/Projects

  ~/Projects> mkdir NewProject

  ~/Projects> cd NewProject

  ~/Projects/NewProject> ll

  # total 0

  ~/Projects/NewProject> perl -V:sitebin

  # sitebin='/opt/perl/site/bin';

  ~/Projects/NewProject> perl /opt/perl/site/bin/vc_init.pl 

  # ****************************
  # **  Initialising Project  **
  # ****************************
  #
  # Project NewProject      ==> ~/Projects
  #
  # Item [dir]  ==> Work                      : *** Write ***
  # Item [dir]  ==> Data                      : *** Write ***
  # Item [dir]  ==> Cmd                       : *** Write ***
  # Item [xml]  ==> B_Flist.xml               : *** Write ***
  # Item [txt]  ==> a_NewProject.txt          : *** Write ***
  # Item [pl]   ==> r_apply.pl                : *** Write ***
  # Item [pl]   ==> r_checkout.pl             : *** Write ***
  # Item [pl]   ==> r_list_det.pl             : *** Write ***
  # Item [pl]   ==> r_list_file.pl            : *** Write ***
  # Item [pl]   ==> r_list_proj.pl            : *** Write ***
  # Item [pl]   ==> r_renew.pl                : *** Write ***
  # Item [pl]   ==> r_reset.pl                : *** Write ***
  # Item [pl]   ==> r_statchar.pl             : *** Write ***
  # Item [pl]   ==> r_statdiff.pl             : *** Write ***
  # Item [pl]   ==> r_status.pl               : *** Write ***

  ~/Projects/NewProject> ll

  # total 3
  # drwxr-xr-x 2 user1 user1 4096 2010-04-09 17:21 Cmd
  # drwxr-xr-x 2 user1 user1 4096 2010-04-09 17:21 Data
  # drwxr-xr-x 2 user1 user1 4096 2010-04-09 17:21 Work

  ~/Projects/NewProject> ll Cmd/

  # total 11
  # -rw-r--r-- 1 user1 user1  55 2010-04-09 17:21 a_NewProject.txt
  # -rw-r--r-- 1 user1 user1 723 2010-04-09 17:21 r_apply.pl
  # -rw-r--r-- 1 user1 user1 494 2010-04-09 17:21 r_checkout.pl
  # -rw-r--r-- 1 user1 user1 502 2010-04-09 17:21 r_list_det.pl
  # -rw-r--r-- 1 user1 user1 502 2010-04-09 17:21 r_list_file.pl
  # -rw-r--r-- 1 user1 user1 496 2010-04-09 17:21 r_list_proj.pl
  # -rw-r--r-- 1 user1 user1 797 2010-04-09 17:21 r_renew.pl
  # -rw-r--r-- 1 user1 user1 560 2010-04-09 17:21 r_reset.pl
  # -rw-r--r-- 1 user1 user1 518 2010-04-09 17:21 r_statchar.pl
  # -rw-r--r-- 1 user1 user1 516 2010-04-09 17:21 r_statdiff.pl
  # -rw-r--r-- 1 user1 user1 510 2010-04-09 17:21 r_status.pl

  ~/Projects/NewProject> ll Work/

  # total 1
  # -rw-r--r-- 1 user1 user1 120 2010-04-09 17:21 B_Flist.xml

  ~/Projects/NewProject> ll Data/

  # total 0

  ~/Projects/NewProject>

=head2 vc_checkout.pl

Suppose you have a file ~/Documents/Book/shakespeare.txt with some text in
Ascii format:

  ~/Projects/NewProject> cat ~/Documents/Book/shakespeare.txt

  # Orlando: As I remember, Adam, it was upon this fashion bequeathed me by will but poor
  # a thousand crowns, and, as thou say'st, charged my brother, on his blessing, to breed
  # me well; and there begins my sadness. My brother Jaques he keeps at school, and
  # report speaks goldenly of his profit. For my part, he keeps me rustically at home,
  # or, to speak more properly, stays me here at home unkept; for call you that keeping
  # for a gentleman of my birth that differs not from the stalling of an ox? His horses
  # are bred better; for, besides that they are fair with their feeding, they are taught
  # their manage, and to that end riders dearly hir'd; [...]
  # ==
  # William Shakespeare,
  # As you like it

You can issue the checkout command (with ~/Projects/NewProject as your current directory)
as follows:

  ~/Projects/NewProject> perl /opt/perl/site/bin/vc_checkout.pl /home/user1/Documents/Book/shakespeare.txt

  # ***************************
  # ** Checking out programs **
  # ***************************
  #
  # Project NewProject      ==> ~/Projects
  #
  # Ckout [  1/  1] ** Write ** F_shakespeare_Z001.txt         << ~/Documents/Book/shakespeare.txt

A new file ('F_shakespeare_Z001.txt') has been created in the subdirectory Work/ (don't worry about the
'B_Flist.xml' file, we will discuss this file later)

  ~/Projects/NewProject> cd Work

  ~/Projects/NewProject/Work> ll

  # total 2
  # -rw-r--r-- 1 user1 user1 120 2010-04-09 17:21 B_Flist.xml
  # -rw-r--r-- 1 user1 user1 538 2010-04-09 17:31 F_shakespeare_Z001.txt

  ~/Projects/NewProject/Work> 

=head2 vc_apply.pl

To make changes, you stay in the ~/Projects/NewProject/Work directory and you edit the
file 'F_shakespeare_Z001.txt' using your favourite ASCII editor (vi, emacs, notepad,
UltraEdit, SciTE, ...). Let's say you change the words '...me here at home...' into
'...me here in London...', then you save the file.

  ~/Projects/NewProject/Work> grep "me here" F_shakespeare_Z001.txt

  # or, to speak more properly, stays me here at home unkept; for call you that keeping

  ~/Projects/NewProject/Work> scite F_shakespeare_Z001.txt

  ~/Projects/NewProject/Work> grep "me here" F_shakespeare_Z001.txt

  # or, to speak more properly, stays me here in London unkept; for call you that keeping

You go one directory up (to be back in ~/Projects/NewProject) and you issue the apply command
as follows:

  ~/Projects/NewProject/Work> cd ..

  ~/Projects/NewProject> perl /opt/perl/site/bin/vc_apply.pl

  # Apply [  1/  1] F_shakespeare_Z001.txt                                WRK --I=0001/D=0001--> ORG

  ~/Projects/NewProject> 

To confirm that your changes ('...me here in London...') have made it correctly into the file
'shakespeare.txt', we issue the following commands:

  ~/Projects/NewProject> grep "me here" ~/Documents/Book/shakespeare.txt

  # or, to speak more properly, stays me here in London unkept; for call you that keeping

  ~/Projects/NewProject> 

=head2 vc_status.pl

To review your changes, simply call vc_status.pl with options -a -o -e:

  ~/Projects/NewProject> perl /opt/perl/site/bin/vc_status.pl -a -o -e

  # *******************
  # ** Status Report **
  # *******************
  #
  # Project NewProject     ==> ~/Projects
  #
  # ===============================================================================================
  # [  1/  1] F_shakespeare_Z001.txt         ARC --I=0001/D=0001--> WRK -----------------> ORG
  # ===============================================================================================
  # ARC: 06/04/2010 16:37:51 ~/Programs/vc_archive/F_=home=user1=Documents=Book=shakespeare.txt
  # WRK: 09/04/2010 17:35:59 ~/Projects/NewProject/Work/F_shakespeare_Z001.txt
  # ORG: 09/04/2010 17:36:06 ~/Documents/Book/shakespeare.txt
  #
  # ARC->WRK: 5c5
  # ARC->WRK: < or, to speak more properly, stays me here at home unkept; for call you that keeping
  # ARC->WRK: ---
  # ARC->WRK: > or, to speak more properly, stays me here in London unkept; for call you that keeping

  ~/Projects/NewProject>

If you prefer a different format, then you can replace the option '-e' by '-u':

  ~/Projects/NewProject> perl /opt/perl/site/bin/vc_status.pl -a -o -u

  # *******************
  # ** Status Report **
  # *******************
  #
  # Project NewProject      ==> ~/Projects
  #
  # [  1/  1] F_shakespeare_Z001.txt         ARC --I=0001/D=0001--> WRK -----------------> ORG
  # [-] ARC/shakespeare.txt
  # [+] WRK/shakespeare.txt
  # @@ -2,8 +2,8 @@
  #  a thousand crowns, and, as thou say'st, charged my brother, on his blessing, to breed
  #  me well; and there begins my sadness. My brother Jaques he keeps at school, and
  #  report speaks goldenly of his profit. For my part, he keeps me rustically at home,
  # -or, to speak more properly, stays me here at home unkept; for call you that keeping
  # +or, to speak more properly, stays me here in London unkept; for call you that keeping
  #  for a gentleman of my birth that differs not from the stalling of an ox? His horses
  #  are bred better; for, besides that they are fair with their feeding, they are taught
  #  their manage, and to that end riders dearly hir'd; [...]

  ~/Projects/NewProject>

=head2 vc_reset.pl

You can choose to back out the changes you made in the original file ~/Documents/Book/shakespeare.txt,
and, at the same time, still keep the changes in ~/Projects/NewProject/Work/F_shakespeare_Z001.txt (in
case you want to come back to those changes later). The command is as follows:

  ~/Projects/NewProject> perl /opt/perl/site/bin/vc_reset.pl

  # Reset [  1/  1] rewrite ==> ~/Documents/Book/shakespeare.txt

  ~/Projects/NewProject>

To confirm that your changes ('...me here in London...') have been taken out of 'shakespeare.txt' -- that
file should now have the original '...me here at home...' -- we issue the following command:

  ~/Projects/NewProject> grep "bright" /home/user1/Documents/Book/shakespeare.txt

  # or, to speak more properly, stays me here at home unkept; for call you that keeping

  ~/Projects/NewProject>

Should you wish to re-activate the changes, a simple 'perl /opt/perl/site/bin/vc_apply.pl' does the trick.

=head2 vc_list.pl

Now it is time to leave the Project directory and chdir into the home directory:

  ~/Projects/NewProject> cd ~

  ~>

If we want to get an overview of all archived files, we simply issue the vc_list command:

  ~> perl /opt/perl/site/bin/vc_list.pl

  # *******************
  # ** List Projects **
  # *******************
  #
  # Reading ~/Programs/vc_archive/D_Coutlist.dat
  #
  # Project * Reset *
  #
  #    1. [CO=  1]                 ~/Documents/Book/shakespeare.txt

  ~>

To get the details of which projects the files actually belong to, we add the option '-d':

  ~> perl /opt/perl/site/bin/vc_list.pl -d

  # ******************
  # ** List Details **
  # ******************
  #
  # Reading ~/Programs/vc_archive/D_Coutlist.dat
  #
  # Project * Reset *
  #
  #    1. [CO=  1]                 ~/Documents/Book/shakespeare.txt
  #     +  NewProject      ----> F_shakespeare_Z001.txt         09-Apr-2010 17:31:30 ~/Projects

  ~>

The '+' character (in front of the 'NewProject') indicates that the file has been modified, but not
yet applied to ~/Documents/Book/shakespeare.txt (that's because we have previously run vc_reset.pl)

Let's apply the changes in NewProjects:

  ~> cd ~/Projects/NewProject
  
  ~/Projects/NewProject> perl /opt/perl/site/bin/vc_apply.pl

  # Apply [  1/  1] F_shakespeare_Z001.txt                                WRK --I=0001/D=0001--> ORG

  ~/Projects/NewProject> cd ~

  ~>

If we now run again the same 'vc_list.pl -d', the 'NewProject' is now marked with a '=>' (instead of
the old '+'):

  ~> perl /opt/perl/site/bin/vc_list.pl -d

  # ******************
  # ** List Details **
  # ******************
  #
  # Reading ~/Programs/vc_archive/D_Coutlist.dat
  #
  # Project NewProject      ==> ~/Projects
  #
  #    1. [CO=  1] NewProject      ~/Documents/Book/shakespeare.txt
  #     => NewProject      ----> F_shakespeare_Z001.txt         09-Apr-2010 17:31:30 ~/Projects

  ~>

=head2 vc_merge.pl

The program vc_merge.pl allows you to take a patch-file from an unrelated project and apply it
to your project. Let's say somebody else had worked independently and in secret on the same
file ('shakespeare.txt'), but on a different project, and this person is sending you now his
patch file (that should be a 'unified' patch file, created by 'diff -u') with the changes he
has made and he asks you to incorporate (merge) his changes with your changes into the same
file. Here is how it works:

This is the 'unified' patch, sent to you by somebody else. The change is in fact the
modification of the words '...part, he keeps...' into '...part, he holds...':

  ~/Projects/NewProject> cat patch.txt

  # --- a/shakespeare.txt  2010-04-06 14:25:07.000000000 +0200
  # +++ b/shakespeare.txt  2010-04-06 14:27:51.000000000 +0200
  # @@ -4,6 +4,6 @@
  #  me well; and there begins my sadness. My brother Jaques he keeps at school, and
  # -report speaks goldenly of his profit. For my part, he keeps me rustically at home,
  # +report speaks goldenly of his profit. For my part, he holds me rustically at home,
  #  or, to speak more properly, stays me here at home unkept; for call you that keeping

  ~/Projects/NewProject>

To merge his changes and your changes in the same output file, the following commands have to
be issued:

  ~/Projects/NewProject> perl /opt/perl/site/bin/vc_merge.pl
     --input=Work/F_shakespeare_Z001.txt --diff=patch.txt --output=out.txt

  # *******************************
  # ** Merging diffs into a file **
  # *******************************
  #
  # input file  = 'Work/F_shakespeare_Z001.txt'
  # diff        = 'patch.txt'
  # output file = 'out.txt'
  #
  # There are 1 hunks:
  #   1. @@ -00004,00006 +00004,00006 @@ --> me well; and there begins... call you that keeping
  # 
  # Error-0040: Conflict in hunk 1 (@@ -4,6 +4,6 @@): 0 matches at /opt/perl/site/bin/vc_merge.pl line 131.

  ~/Projects/NewProject>

We notice that there is a conflict between his changes and our changes. To resolve this conflict, we have to
investigate the details of what constitutes the conflict. If we re-run vc_merge.pl, but we replace the
'--output=out.txt' parameter by '--linewd=85', then we get a detailed report (alignment) of the merge:

  ~/Projects/NewProject> perl /opt/perl/site/bin/vc_merge.pl
     --input=Work/F_shakespeare_Z001.txt --diff=patch.txt --linewd=85

  # *******************************
  # ** Merging diffs into a file **
  # *******************************
  #
  # input file  = 'Work/F_shakespeare_Z001.txt'
  # diff        = 'patch.txt'
  # linewd      = 85
  #
  # There are 1 hunks:
  #
  # ========================================
  # ==>   1. @@ -00004,00006 +00004,00006 @@
  # ========================================
  #
  #    s    4 => report`speaks`goldenly`of ` h       i s`profit.`For`my`pa           r t,  `       he`
  #    ****** => * **** ** ****** *** * *** * ******* *  ************   * *********** * *** *******
  #    d    1 => me    `w e      l   l;`and`there`begins`            my`sadness.`My`brother`Jaques`he`
  #
  #              keeps`me`rustically`at`  home,~\
  #                    ********* *****  **  ** ******
  #              keeps`         a     t`school,`and~\
  #
  #    s    5 =>    or,`to`speak `mor e   `       prope     rl y,`stays `me`here`in`London`unke pt;`fo
  #    ****** => ***  ** *      * * ** *** *******   ******* ** * ** *** ***  ** ************  * ** **
  #    d    2 => repor  t `speaks`goldenly`of`his`profit.`For`my `p art,`   he  `            keeps `me
  #
  #              r`     call`you`that`k  eeping~\
  #              * *****    * ** **   *** *******
  #               `rusticall y  `  at`home,~\
  #
  #    s    6 => for `a `g entleman` of `m      y `birth  `t  h    at`differs` no  t `from`the`stallin
  #    ****** => *  * ** ** ***** * * ** ******* * *** *** *** ****   **** ** * *** *  * * ******   **
  #    d    3 =>  or,`to`spe     ak`more`properly,`s  tays`me`here`at`hom e  `unkept;`f or`c     all
  #
  #              g` of`  an`ox?`His`horses~\
  #              * * * ** * ************ *******
  #               `you`that`k           eeping~\

  ~/Projects/NewProject>

Unfortunately, this report doesn't help us very much. In fact, it seems that the alignment of the lines
is incorrect. If you look closely, you will notice that the "@@ -00004,00006 +00004,00006 @@" in the
patch file seems to be wrong, if it was "@@ -00003,00005 +00003,00005 @@", the report would align much
better.

So we decide to manipulate the 'patch.txt' file and replace '@@ -4,6 +4,6 @@' by '@@ -3,5 +3,5 @@', as
follows:

  ~/Projects/NewProject> scite patch.txt

  ~/Projects/NewProject> cat patch.txt
  
  # --- a/shakespeare.txt  2010-04-06 14:25:07.000000000 +0200
  # +++ b/shakespeare.txt  2010-04-06 14:27:51.000000000 +0200
  # @@ -3,5 +3,5 @@
  #  me well; and there begins my sadness. My brother Jaques he keeps at school, and
  # -report speaks goldenly of his profit. For my part, he keeps me rustically at home,
  # +report speaks goldenly of his profit. For my part, he holds me rustically at home,
  #  or, to speak more properly, stays me here at home unkept; for call you that keeping

  ~/Projects/NewProject>

Now we re-run exactly the same 'vc_merge.pl ... --linewd=85', and we get:

  ~/Projects/NewProject> perl /opt/perl/site/bin/vc_merge.pl
     --input=Work/F_shakespeare_Z001.txt --diff=patch.txt --linewd=85

  # *******************************
  # ** Merging diffs into a file **
  # *******************************
  #
  # input file  = 'Work/F_shakespeare_Z001.txt'
  # diff        = 'patch.txt'
  # linewd      = 85
  #
  # There are 1 hunks:
  #
  # ========================================
  # ==>   1. @@ -00003,00005 +00003,00005 @@
  # ========================================
  #
  #    s    3 => me`well;`and`there`begins`my`sadness.`My`brother`Jaques`he`keeps`at`school,`and~\
  #    -   -- =>
  #    d    1 => me`well;`and`there`begins`my`sadness.`My`brother`Jaques`he`keeps`at`school,`and~\
  #
  #    s    4 => report`speaks`goldenly`of`his`profit.`For`my`part,`he`keeps`me`rustically`at`home,~\
  #    -   -- =>
  #    d    2 => report`speaks`goldenly`of`his`profit.`For`my`part,`he`keeps`me`rustically`at`home,~\
  #
  #    s    5 => or,`to`speak`more`properly,`stays`me`here`in`London`unkept;`for`call`you`that`keeping~\
  #    ****** =>                                           ** * ****
  #    d    3 => or,`to`speak`more`properly,`stays`me`here`at`home  `unkept;`for`call`you`that`keeping~\

  ~/Projects/NewProject>

That's much better now, we can easily identify that indeed, there is a conflict, and the
conflict is caused by the modification of the word '...me here at home...' into '...me here in London...'.

To resolve the conflict, we decide to intervene manually in the 'patch.txt' file and change
the word '...me here at home...' into '...me here in London...'.:

  ~/Projects/NewProject> scite patch.txt

  ~/Projects/NewProject> cat patch.txt

  # --- a/shakespeare.txt  2010-04-06 14:25:07.000000000 +0200
  # +++ b/shakespeare.txt  2010-04-06 14:27:51.000000000 +0200
  # @@ -3,5 +3,5 @@
  #  me well; and there begins my sadness. My brother Jaques he keeps at school, and
  # -report speaks goldenly of his profit. For my part, he keeps me rustically at home,
  # +report speaks goldenly of his profit. For my part, he holds me rustically at home,
  #  or, to speak more properly, stays me here in London unkept; for call you that keeping

  ~/Projects/NewProject>

We come back to our initial command 'vc_merge.pl ... --output=out.txt', which now succeeds:

  ~/Projects/NewProject> perl /opt/perl/site/bin/vc_merge.pl
     --input=Work/F_shakespeare_Z001.txt --diff=patch.txt --output=out.txt

  # *******************************
  # ** Merging diffs into a file **
  # *******************************
  #
  # input file  = 'Work/F_shakespeare_Z001.txt'
  # diff        = 'patch.txt'
  # output file = 'out.txt'
  #
  # There are 1 hunks:
  #   1. @@ -00003,00005 +00003,00005 @@ --> me well; and there begins... call you that keeping
  #
  # Output successfully written to 'out.txt'

  ~/Projects/NewProject>

We confirm that both changes (first change was '...he keeps me...' into '...he holds me...',
second change was '...me here at home...' into '...me here in London...') are in the
file 'out.txt':

  ~/Projects/NewProject> cat out.txt
  
  # Orlando: As I remember, Adam, it was upon this fashion bequeathed me by will but poor
  # a thousand crowns, and, as thou say'st, charged my brother, on his blessing, to breed
  # me well; and there begins my sadness. My brother Jaques he keeps at school, and
  # report speaks goldenly of his profit. For my part, he holds me rustically at home,
  # or, to speak more properly, stays me here in London unkept; for call you that keeping
  # for a gentleman of my birth that differs not from the stalling of an ox? His horses
  # are bred better; for, besides that they are fair with their feeding, they are taught
  # their manage, and to that end riders dearly hir'd; [...]
  # ==
  # William Shakespeare,
  # As you like it

  ~/Projects/NewProject>

=head1 SHORTCUTS

When you run 'vc_init.pl', the following 10 "shortcut" programs are automatically created in
directory 'Cmd': r_apply.pl, r_checkout.pl, r_list_det.pl, r_list_file.pl, r_list_proj.pl,
r_renew.pl, r_reset.pl, r_statchar.pl, r_statdiff.pl and r_status.pl.

But before we go into the details of how the shortcuts actually work, let's first create
some more projects to make things more interesting. First we make sure that we have more
than one book in ~/Documents/Book/

  ~/Projects/NewProject> cd ~

  ~> ll ~/Documents/Book/

  # total 3
  # -rw-r--r-- 1 user1 user1 559 2010-04-10 13:18 jules_verne.txt
  # -rw-r--r-- 1 user1 user1 650 2010-04-10 13:24 lewis_carroll.txt
  # -rw-r--r-- 1 user1 user1 538 2010-04-06 16:37 shakespeare.txt

  ~> cat ~/Documents/Book/jules_verne.txt

  # Mr. Phileas Fogg lived, in 1872, at No. 7, Saville Row, Burlington Gardens,
  # the house in which Sheridan died in 1814. He was one of the most noticeable
  # members of the Reform Club, though he seemed always to avoid attracting
  # attention; an enigmatical personage, about whom little was known, except that
  # he was a polished man of the world. People said that he resembled Byron--at
  # least that his head was Byronic; but he was a bearded, tranquil Byron, who
  # might live on a thousand years without growing old. [...]
  # ==
  # Jules Verne,
  # Around the World in Eighty Days

  ~> cat ~/Documents/Book/lewis_carroll.txt

  # Alice was beginning to get very tired of sitting by her sister on the bank, and
  # of having nothing to do: once or twice she had peeped into the book her sister
  # was reading, but it had no pictures or conversations in it, 'and what is the use
  # of a book,' thought Alice 'without pictures or conversation?'
  # So she was considering in her own mind (as well as she could, for the hot day made
  # her feel very sleepy and stupid), whether the pleasure of making a daisy-chain
  # would be worth the trouble of getting up and picking the daisies, when suddenly
  # a White Rabbit with pink eyes ran close by her. [...]
  # ==
  # Lewis Carroll,
  # Alice's Adventures in Wonderland

  ~>

In addition to the existing project 'NewProject', we also want a second project, called
'OtherProject'. So we create a new subdirectory...

  ~> mkdir ~/Projects/OtherProject

  ~> ll ~/Projects

  # total 2
  # drwxr-xr-x 2 user1 user1 4096 2010-04-10 13:51 NewProject
  # drwxr-xr-x 2 user1 user1 4096 2010-04-10 13:50 OtherProject

  ~>

...then we change into that new directory, we run vc_init.pl and we change back into the
home directory:

  ~> cd ~/Projects/OtherProject

  ~/Projects/OtherProject> perl /opt/perl/site/bin/vc_init.pl

  # ****************************
  # **  Initialising Project  **
  # ****************************
  #
  # Project OtherProject    ==> ~/Projects
  #
  # Item [dir]  ==> Work                      : *** Write ***
  # Item [dir]  ==> Data                      : *** Write ***
  # Item [dir]  ==> Cmd                       : *** Write ***
  # Item [xml]  ==> B_Flist.xml               : *** Write ***
  # Item [txt]  ==> a_OtherProject.txt        : *** Write ***
  # Item [pl]   ==> r_apply.pl                : *** Write ***
  # Item [pl]   ==> r_checkout.pl             : *** Write ***
  # Item [pl]   ==> r_list_det.pl             : *** Write ***
  # Item [pl]   ==> r_list_file.pl            : *** Write ***
  # Item [pl]   ==> r_list_proj.pl            : *** Write ***
  # Item [pl]   ==> r_renew.pl                : *** Write ***
  # Item [pl]   ==> r_reset.pl                : *** Write ***
  # Item [pl]   ==> r_statchar.pl             : *** Write ***
  # Item [pl]   ==> r_statdiff.pl             : *** Write ***
  # Item [pl]   ==> r_status.pl               : *** Write ***

  ~/Projects/OtherProject> cd ~

  ~>

=head2 r_checkout.pl

The first shortcut we use is 'r_checkout.pl'. This shortcut defines what files are
included in the project. To do that, the XML file ('Work/B_Flist.xml') has to be manually
updated in each project with the full path of all files. In our case, we need to manually
update two XML files: '~/Projects/NewProject/Work/B_Flist.xml' and
'~/Projects/OtherProject/Work/B_Flist.xml'.

This is how we update the XML file in project 'NewProject' (we want to have the file
'shakespeare.txt', as well as a new second file, 'jules_verne.txt'):

  ~> cat ~/Projects/NewProject/Work/B_Flist.xml

  # <?xml version="1.0" encoding="iso-8859-1"?>
  # <checkout>
  #   <!--
  #   <file name="/dir_a/dir_b/data.txt" />
  #   -->
  # </checkout>

  ~> scite ~/Projects/NewProject/Work/B_Flist.xml

  ~> cat ~/Projects/NewProject/Work/B_Flist.xml

  # <?xml version="1.0" encoding="iso-8859-1"?>
  # <checkout>
  #   <file name="/home/user1/Documents/Book/shakespeare.txt" />
  #   <file name="/home/user1/Documents/Book/jules_verne.txt" />
  # </checkout>

  ~>

This is how we update the XML file in project 'OtherProject' (we want to have the same
file 'shakespeare.txt', as well as another file, 'lewis_carroll.txt'):

  ~> cat ~/Projects/OtherProject/Work/B_Flist.xml

  # <?xml version="1.0" encoding="iso-8859-1"?>
  # <checkout>
  #   <!--
  #   <file name="/dir_a/dir_b/data.txt" />
  #   -->
  # </checkout>

  ~> scite ~/Projects/OtherProject/Work/B_Flist.xml

  ~> cat ~/Projects/OtherProject/Work/B_Flist.xml

  # <?xml version="1.0" encoding="iso-8859-1"?>
  # <checkout>
  #   <file name="/home/user1/Documents/Book/shakespeare.txt" />
  #   <file name="/home/user1/Documents/Book/lewis_carroll.txt" />
  # </checkout>

  ~>

Now we can run 'r_checkout.pl' twice, once for ~/Projects/NewProject, then for
~/Projects/OtherProject. (...and there is no need to change directory, we stay in our
home directory):

  ~> perl Projects/NewProject/Cmd/r_checkout.pl

  # ***************************
  # ** Checking out programs **
  # ***************************
  #
  # Project NewProject      ==> ~/Projects
  #
  # Ckout [  1/  2]             F_shakespeare_Z001.txt         -- ~/Documents/Book/shakespeare.txt
  # Ckout [  2/  2] ** Write ** F_jules_verne_Z001.txt         << ~/Documents/Book/jules_verne.txt

  ~> perl Projects/OtherProject/Cmd/r_checkout.pl

  # ***************************
  # ** Checking out programs **
  # ***************************
  #
  # Project OtherProject    ==> ~/Projects
  #
  # Ckout [  1/  2] ** Write ** F_shakespeare_Z001.txt         << ~/Documents/Book/shakespeare.txt
  # Ckout [  2/  2] ** Write ** F_lewis_carroll_Z001.txt       << ~/Documents/Book/lewis_carroll.txt

  ~>

Please note that the checkout of 'NewProject' did not write 'F_shakespeare_Z001.txt'.
That's completely normal, because we already had checked out 'shakespeare.txt' to
'NewProject' previously (with modification of the word 'sapphires' into 'diamonds'). It
is also important to notice that the checkout of 'shakespeare.txt' for project 'OtherProject'
does not contain that modification.

=head2 r_apply.pl

To make changes in '~/Documents/Book/' (files 'shakespeare.txt', 'jules_verne.txt'
and 'lewis_carroll.txt'), we can't (or rather: we shouldn't) update the files in '~/Documents/Book/' directly,
instead we update the project files in '~/Projects/NewProject/Work' and in '~/Projects/OtherProject/Work'.
We then will use 'r_apply.pl' to transfer the updated file into '~/Documents/Book/'.

In 'F_shakespeare_Z001.txt' ('OtherProject'), we change '...me here at home...' into
'...me here in Cardiff...':

  ~> grep "me here" Projects/OtherProject/Work/F_shakespeare_Z001.txt

  # or, to speak more properly, stays me here at home unkept; for call you that keeping

  ~> scite Projects/OtherProject/Work/F_shakespeare_Z001.txt

  ~> grep "me here" Projects/OtherProject/Work/F_shakespeare_Z001.txt

  # or, to speak more properly, stays me here in Cardiff unkept; for call you that keeping

  ~> 

In 'F_lewis_carroll_Z001.txt' ('OtherProject'), we change '...picking the daisies...' into
'...picking the flowers...':

  ~> grep "picking" Projects/OtherProject/Work/F_lewis_carroll_Z001.txt

  # would be worth the trouble of getting up and picking the daisies, when suddenly

  ~> scite Projects/OtherProject/Work/F_lewis_carroll_Z001.txt

  ~> grep "picking" Projects/OtherProject/Work/F_lewis_carroll_Z001.txt

  # would be worth the trouble of getting up and picking the flowers, when suddenly

  ~> 

In 'F_jules_verne_Z001.txt' ('NewProject'), we change '...People said...' into
'...People thought...':

  ~> grep "People" Projects/NewProject/Work/F_jules_verne_Z001.txt

  # he was a polished man of the world. People said that he resembled Byron--at

  ~> scite Projects/NewProject/Work/F_jules_verne_Z001.txt

  ~> grep "People" Projects/NewProject/Work/F_jules_verne_Z001.txt

  # he was a polished man of the world. People thought that he resembled Byron--at

  ~>

To apply the changes (that is to update the original files in ~/Documents/Book/), we run
'r_apply.pl' twice, once for each project 'NewProject' and 'OtherProject' (...again, there
is no need to change directory, we stay in our home directory):

  ~> perl Projects/NewProject/Cmd/r_apply.pl

  # *****************
  # * Apply changes *
  # *****************
  #
  # Project NewProject      ==> ~/Projects
  #
  # Apply [  1/  2] F_jules_verne_Z001.txt                                WRK ===== Update ====> ORG
  # Apply [  2/  2] F_shakespeare_Z001.txt                                WRK ===== Update ====> ORG

However, we can't just apply the second project (if we attempt, we will get an error):

  ~> perl Projects/OtherProject/Cmd/r_apply.pl

  # *****************
  # * Apply changes *
  # *****************
  #
  # Project NewProject      ==> ~/Projects
  #
  # Error-0064: Current project is '/home/user1/Projects/OtherProject', but another
  # project '/home/user1/Projects/NewProject' is already active at
  # /perl/site/bin/vc_apply.pl line 118.

We need to reset first:

  ~> perl Projects/OtherProject/Cmd/r_reset.pl

  # *********
  # * Reset *
  # *********
  #
  # Reset [  1/  3] rewrite ==> ~/Documents/Book/jules_verne.txt
  # Reset [  2/  3] rewrite ==> ~/Documents/Book/lewis_carroll.txt
  # Reset [  3/  3] rewrite ==> ~/Documents/Book/shakespeare.txt

Now we can successfully apply the second project ('OtherProject'):

  ~> perl Projects/OtherProject/Cmd/r_apply.pl

  # *****************
  # * Apply changes *
  # *****************
  #
  # Project OtherProject    ==> ~/Projects
  #
  # Apply [  1/  2] F_lewis_carroll_Z001.txt                              WRK ===== Update ====> ORG
  # Apply [  2/  2] F_shakespeare_Z001.txt                                WRK ===== Update ====> ORG

  ~>

=head2 r_status.pl

Let's say we want to find out what changes have been made for one given project. For that
task we use 'r_status.pl'.

Here is the status for 'OtherProject':

  ~> perl Projects/OtherProject/Cmd/r_status.pl

  # *******************
  # ** Status Report **
  # *******************
  #
  # Project OtherProject    ==> ~/Projects
  #
  # ===============================================================================================
  # [  1/  2] F_lewis_carroll_Z001.txt       ARC --I=0001/D=0001--> WRK -----------------> ORG
  # ===============================================================================================
  # ARC: 10/04/2010 14:45:46 ~/Programs/vc_archive/F_=home=klaus=Documents=Book=lewis_carroll.txt
  # WRK: 10/04/2010 15:33:57 ~/Projects/OtherProject/Work/F_lewis_carroll_Z001.txt
  # ORG: 10/04/2010 15:42:49 ~/Documents/Book/lewis_carroll.txt
  #
  # ARC->WRK: 7c7
  # ARC->WRK: < would be worth the trouble of getting up and picking the daisies, when suddenly
  # ARC->WRK: ---
  # ARC->WRK: > would be worth the trouble of getting up and picking the flowers, when suddenly
  #
  # ===============================================================================================
  # [  2/  2] F_shakespeare_Z001.txt         ARC --I=0001/D=0001--> WRK -----------------> ORG
  # ===============================================================================================
  # ARC: 10/04/2010 14:43:24 ~/Programs/vc_archive/F_=home=klaus=Documents=Book=shakespeare.txt
  # WRK: 10/04/2010 15:28:21 ~/Projects/OtherProject/Work/F_shakespeare_Z001.txt
  # ORG: 10/04/2010 15:48:31 ~/Documents/Book/shakespeare.txt
  #
  # ARC->WRK: 5c5
  # ARC->WRK: < or, to speak more properly, stays me here at home unkept; for call you that keeping
  # ARC->WRK: ---
  # ARC->WRK: > or, to speak more properly, stays me here in Cardiff unkept; for call you that keeping

=head2 r_statchar.pl

The command 'r_statchar.pl' provides the changes in a character-by-character alignment:

  ~> perl Projects/OtherProject/Cmd/r_statchar.pl

  # *******************
  # ** Status Report **
  # *******************
  #
  # Project OtherProject    ==> ~/Projects
  #
  # ===============================================================================================
  # [  1/  2] F_lewis_carroll_Z001.txt       ARC --I=0001/D=0001--> WRK -----------------> ORG
  # ===============================================================================================
  # ARC: 10/04/2010 14:45:46 ~/Programs/vc_archive/F_=home=klaus=Documents=Book=lewis_carroll.txt
  # WRK: 10/04/2010 15:33:57 ~/Projects/OtherProject/Work/F_lewis_carroll_Z001.txt
  # ORG: 10/04/2010 15:42:49 ~/Documents/Book/lewis_carroll.txt
  #
  # ARC->WRK: 7c7
  # ARC->WRK: --------------------------------------------------------------------------------------------
  # ARC->WRK: < would`be`worth`the`trouble`of`getting`up`and`picking`the`daisie s,`when`suddenly~\
  # ARC->WRK: *                                                          ***** *                  
  # ARC->WRK: > would`be`worth`the`trouble`of`getting`up`and`picking`the`flow ers,`when`suddenly~\
  # ARC->WRK: --------------------------------------------------------------------------------------------
  #
  # ===============================================================================================
  # [  2/  2] F_shakespeare_Z001.txt         ARC --I=0001/D=0001--> WRK -----------------> ORG
  # ===============================================================================================
  # ARC: 10/04/2010 14:43:24 ~/Programs/vc_archive/F_=home=klaus=Documents=Book=shakespeare.txt
  # WRK: 10/04/2010 15:28:21 ~/Projects/OtherProject/Work/F_shakespeare_Z001.txt
  # ORG: 10/04/2010 15:48:31 ~/Documents/Book/shakespeare.txt
  #
  # ARC->WRK: 5c5
  # ARC->WRK: --------------------------------------------------------------------------------------------
  # ARC->WRK: < or,`to`speak`more`properly,`stays`me`here`    at`home`unkept;`for`call`you`that`keeping~\
  # ARC->WRK: *                                           **** ******                                    
  # ARC->WRK: > or,`to`speak`more`properly,`stays`me`here`in`Cardiff `unkept;`for`call`you`that`keeping~\
  # ARC->WRK: --------------------------------------------------------------------------------------------

=head2 r_statdiff.pl

The command 'r_statdiff.pl' provides the same information in yet another format:

  ~> perl Projects/OtherProject/Cmd/r_statdiff.pl

  # *******************
  # ** Status Report **
  # *******************
  #
  # Project OtherProject   ==> ~/Projects
  #
  # [-] ARC/lewis_carroll.txt
  # [+] WRK/lewis_carroll.txt
  # @@ -5,10 +5,10 @@
  #  So she was considering in her own mind (as well as she could, for the hot day made
  #  her feel very sleepy and stupid), whether the pleasure of making a daisy-chain
  # -would be worth the trouble of getting up and picking the daisies, when suddenly
  # +would be worth the trouble of getting up and picking the flowers, when suddenly
  #  a White Rabbit with pink eyes ran close by her. [...]
  #  ==
  #  Lewis Carroll,
  #
  # [-] ARC/shakespeare.txt
  # [+] WRK/shakespeare.txt
  # @@ -2,8 +2,8 @@
  #  a thousand crowns, and, as thou say'st, charged my brother, on his blessing, to breed
  #  me well; and there begins my sadness. My brother Jaques he keeps at school, and
  #  report speaks goldenly of his profit. For my part, he keeps me rustically at home,
  # -or, to speak more properly, stays me here at home unkept; for call you that keeping
  # +or, to speak more properly, stays me here in Cardiff unkept; for call you that keeping
  #  for a gentleman of my birth that differs not from the stalling of an ox? His horses
  #  are bred better; for, besides that they are fair with their feeding, they are taught
  #  their manage, and to that end riders dearly hir'd; [...]

  ~>

=head2 r_list_proj.pl

To get an overview of all projects, we use the 'r_list_proj.pl' command (the actual project
name does not matter, but all 'r_list_proj.pl' programs are stored under a project directory,
therefore we have to pick one -- We choose 'OtherProject'):

   ~> perl Projects/OtherProject/Cmd/r_list_proj.pl

  # *****************************
  # ** List Projects (Cleanup) **
  # *****************************
  #
  # Reading ~/Programs/vc_archive/D_Coutlist.dat
  #
  # Project OtherProject    ==> ~/Projects
  #
  #    1. [CO=  1]                 ~/Documents/Book/jules_verne.txt
  #    2. [CO=  1] OtherProject    ~/Documents/Book/lewis_carroll.txt
  #    3. [CO=  2] OtherProject    ~/Documents/Book/shakespeare.txt

  ~>

=head2 r_list_file.pl

To get information about all files in the project, we run the 'r_list_file.pl' command:

  ~> perl Projects/OtherProject/Cmd/r_list_file.pl

  # **************************
  # ** List Files (Cleanup) **
  # **************************
  #
  # Reading ~/Programs/vc_archive/D_Coutlist.dat
  #
  # Project OtherProject    ==> ~/Projects
  #
  # List  [  1/  4] F_jules_verne_Z001.txt         => NewProject                ~/Projects
  # List  [  2/  4] F_lewis_carroll_Z001.txt       => OtherProject              ~/Projects
  # List  [  3/  4] F_shakespeare_Z001.txt         +  NewProject                ~/Projects
  # List  [  4/  4] F_shakespeare_Z001.txt         => OtherProject              ~/Projects

  ~>

The '=>' indicates that the file has been applied for the given project, a '+' indicates that
changes have been made in the project file, but they have not been applied (as it is the case
for 'shakespeare.txt' in project 'NewProject')

=head2 r_list_det.pl

The same information, but in a different format can be displayed with the 'r_list_det.pl' command:

  ~> perl Projects/OtherProject/Cmd/r_list_det.pl

  # ****************************
  # ** List Details (Cleanup) **
  # ****************************
  #
  # Reading ~/Programs/vc_archive/D_Coutlist.dat
  #
  # Project OtherProject    ==> ~/Projects
  #
  #    1. [CO=  1] NewProject      ~/Documents/Book/jules_verne.txt
  #     => NewProject      ----> F_jules_verne_Z001.txt         10-Apr-2010 14:43:24 ~/Projects
  #
  #    2. [CO=  1] OtherProject    ~/Documents/Book/lewis_carroll.txt
  #     => OtherProject    ----> F_lewis_carroll_Z001.txt       10-Apr-2010 14:45:46 ~/Projects
  #
  #    3. [CO=  2] OtherProject    ~/Documents/Book/shakespeare.txt
  #     +  NewProject      ----> F_shakespeare_Z001.txt         10-Apr-2010 14:43:24 ~/Projects
  #     => OtherProject    ----> F_shakespeare_Z001.txt         10-Apr-2010 14:45:46 ~/Projects

  ~>

=head2 r_reset.pl

In order to reset all apply-commands, the 'r_reset.pl' command can be used:

  ~> perl Projects/OtherProject/Cmd/r_reset.pl

  # *********
  # * Reset *
  # *********
  #
  # Reset [  1/  3] rewrite ==> ~/Documents/Book/jules_verne.txt
  # Reset [  2/  3] rewrite ==> ~/Documents/Book/lewis_carroll.txt
  # Reset [  3/  3] rewrite ==> ~/Documents/Book/shakespeare.txt

  ~>

If we re-run the 'r_list_det.pl' command, we will see that the '=>' indicators have changed into '+':

  ~> perl Projects/OtherProject/Cmd/r_list_det.pl

  # ****************************
  # ** List Details (Cleanup) **
  # ****************************
  #
  # Reading ~/Programs/vc_archive/D_Coutlist.dat
  #
  # Project * Reset *
  #
  #    1. [CO=  1]                 ~/Documents/Book/jules_verne.txt
  #     +  NewProject      ----> F_jules_verne_Z001.txt         10-Apr-2010 14:43:24 ~/Projects
  #
  #    2. [CO=  1]                 ~/Documents/Book/lewis_carroll.txt
  #     +  OtherProject    ----> F_lewis_carroll_Z001.txt       10-Apr-2010 14:45:46 ~/Projects
  #
  #    3. [CO=  2]                 ~/Documents/Book/shakespeare.txt
  #     +  NewProject      ----> F_shakespeare_Z001.txt         10-Apr-2010 14:43:24 ~/Projects
  #     +  OtherProject    ----> F_shakespeare_Z001.txt         10-Apr-2010 14:45:46 ~/Projects

  ~>

=head2 r_renew.pl

Finally we want to switch easily back and forth between different projects. To achieve this, the
'r_renew.pl' command can be used. If you run 'r_renew.pl' in a given project, it first
resets all apply commands and then it applies the changes for the given project. In fact, 'r_renew.pl'
performs the following commands: 'vc_reset.pl', 'vc_list.pl', 'vc_checkout.pl' and 'vc_apply.pl'.

  ~> perl Projects/OtherProject/Cmd/r_renew.pl

  # *****************
  # * Renew project *
  # *****************
  #
  # Project OtherProject    ==> ~/Projects
  #
  # Reset [  1/  3]         ==> ~/Documents/Book/jules_verne.txt
  # Reset [  2/  3]         ==> ~/Documents/Book/lewis_carroll.txt
  # Reset [  3/  3]         ==> ~/Documents/Book/shakespeare.txt
  # List  [  1/  4] F_jules_verne_Z001.txt         +  NewProject                ~/Projects
  # List  [  2/  4] F_lewis_carroll_Z001.txt       +  OtherProject              ~/Projects
  # List  [  3/  4] F_shakespeare_Z001.txt         +  NewProject                ~/Projects
  # List  [  4/  4] F_shakespeare_Z001.txt         +  OtherProject              ~/Projects
  # Ckout [  1/  2]             F_shakespeare_Z001.txt         -- ~/Documents/Book/shakespeare.txt
  # Ckout [  2/  2]             F_lewis_carroll_Z001.txt       -- ~/Documents/Book/lewis_carroll.txt
  # Apply [  1/  2] F_lewis_carroll_Z001.txt                              WRK ===== Update ====> ORG
  # Apply [  2/  2] F_shakespeare_Z001.txt                                WRK ===== Update ====> ORG

  ~>

=head1 AUTHOR

Klaus Eichner, <klaus03@gmail.com>, March 2010

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Klaus Eichner

All rights reserved. This program is free software; you can redistribute
it and/or modify it under the terms of the artistic license,
see http://www.opensource.org/licenses/artistic-license-1.0.php

=cut
