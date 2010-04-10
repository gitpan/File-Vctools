use strict;
use warnings;
use 5.010;

use Test::More tests => 178;

use File::Vctools qw(get_mpath get_difftool);
use Cwd;
use File::Spec;
use File::Basename;
use File::Slurp;
use File::Temp qw(tempdir);

my ($cwd, $q, $mpath, $difftool, $tempdir, $name_out, $name_err);

preparations();

# perform a basic diff (without any options)
# ******************************************

{
    my ($stdout, $stderr, $rc) = my_system($^X, $difftool,
      File::Spec->catdir($tempdir, 'Misc_01', 'World80a.txt'),
      File::Spec->catdir($tempdir, 'Misc_01', 'World80b.txt'),
    );

    my $difflist = qr{
      < \s+ an \s+ enigmatical \s+ personage, \s+ about \s+ whom \s+ little \s+ was \s+
      --- \s+
      > \s+ an \s+ enigmatical \s+ personage, \s+ about \s+ whom \s+ little \s+ was \s+
    }xms;

    is($rc, 256,             'diff-World80-simple: rc is 256');
    like($stdout, $difflist, 'diff-World80-simple: stdout shows the diff');
    is($stderr, '',          'diff-World80-simple: stderr is empty');
}

# perform a unified diff (without option '-u')
# ********************************************

{
    my ($stdout, $stderr, $rc) = my_system($^X, $difftool, '-u',
      File::Spec->catdir($tempdir, 'Misc_01', 'World80a.txt'),
      File::Spec->catdir($tempdir, 'Misc_01', 'World80b.txt'),
    );

    my $difflist = qr{
        he \s+ seemed \s+ always \s+ to \s+ avoid \s+ attracting \s+ attention; \s+
       -an \s+ enigmatical \s+ personage, \s+ about \s+ whom \s+ little \s+ was \s+ 
      \+an \s+ enigmatical \s+ personage, \s+ about \s+ whom \s+ little \s+ was \s+ 
        known, \s+ except \s+ that \s+ he \s+ was \s+ a \s+ polished \s+ man \s+ of \s+ the \s+
    }xms;

    is($rc, 256,             'diff-World80-unified: rc is 256');
    like($stdout, $difflist, 'diff-World80-unified: stdout shows the diff');
    is($stderr, '',          'diff-World80-unified: stderr is empty');
}

# initialising Prj_01:
# ********************

#~ Item [dir]  ==> Work                      : *** Write ***
#~ Item [dir]  ==> Data                      : *** Write ***
#~ Item [dir]  ==> Cmd                       : *** Write ***
#~ Item [xml]  ==> B_Flist.xml               : *** Write ***
#~ Item [txt]  ==> a_Prj_01.txt              : *** Write ***
#~ Item [pl]   ==> r_apply.pl                : *** Write ***
#~ Item [pl]   ==> r_checkout.pl             : *** Write ***
#~ Item [pl]   ==> r_list_det.pl             : *** Write ***
#~ Item [pl]   ==> r_list_file.pl            : *** Write ***
#~ Item [pl]   ==> r_list_proj.pl            : *** Write ***
#~ Item [pl]   ==> r_renew.pl                : *** Write ***
#~ Item [pl]   ==> r_reset.pl                : *** Write ***
#~ Item [pl]   ==> r_statdiff.pl             : *** Write ***
#~ Item [pl]   ==> r_status.pl               : *** Write ***

{
    my $dir = File::Spec->catdir($tempdir, 'Prj_01');
    chdir $dir or die "Error-0010: Can't chdir '$dir' because $!";

    my ($stdout, $stderr, $rc) = my_system($^X, File::Spec->catdir($mpath, 'vc_init.pl'));

    is($rc, 0,                                          'init-prj01: rc is zero');
    is($stderr, '',                                     'init-prj01: stderr is empty');

    like($stdout, qr{==> \s a_Prj_01\.txt   \s}xms,     'init-prj01: stdout contains "a_Prj_01.txt"');
    like($stdout, qr{==> \s r_apply\.pl     \s}xms,     'init-prj01: stdout contains "r_apply.pl"');
    like($stdout, qr{==> \s r_checkout\.pl  \s}xms,     'init-prj01: stdout contains "r_checkout.pl"');
    like($stdout, qr{==> \s r_list_det\.pl  \s}xms,     'init-prj01: stdout contains "r_list_det.pl"');
    like($stdout, qr{==> \s r_list_file\.pl \s}xms,     'init-prj01: stdout contains "r_list_file.pl"');
    like($stdout, qr{==> \s r_list_proj\.pl \s}xms,     'init-prj01: stdout contains "r_list_proj.pl"');
    like($stdout, qr{==> \s r_renew\.pl     \s}xms,     'init-prj01: stdout contains "r_renew.pl"');
    like($stdout, qr{==> \s r_reset\.pl     \s}xms,     'init-prj01: stdout contains "r_reset.pl"');
    like($stdout, qr{==> \s r_statdiff\.pl  \s}xms,     'init-prj01: stdout contains "r_statdiff.pl"');
    like($stdout, qr{==> \s r_status\.pl    \s}xms,     'init-prj01: stdout contains "r_status.pl"');

    ok(-f File::Spec->catfile('Cmd', 'a_Prj_01.txt'),   'init-prj01: file "a_Prj_01.txt"   actually exists');
    ok(-f File::Spec->catfile('Cmd', 'r_apply.pl'),     'init-prj01: file "r_apply.pl"     actually exists');
    ok(-f File::Spec->catfile('Cmd', 'r_checkout.pl'),  'init-prj01: file "r_checkout.pl"  actually exists');
    ok(-f File::Spec->catfile('Cmd', 'r_list_det.pl'),  'init-prj01: file "r_list_det.pl"  actually exists');
    ok(-f File::Spec->catfile('Cmd', 'r_list_file.pl'), 'init-prj01: file "r_list_file.pl" actually exists');
    ok(-f File::Spec->catfile('Cmd', 'r_list_proj.pl'), 'init-prj01: file "r_list_proj.pl" actually exists');
    ok(-f File::Spec->catfile('Cmd', 'r_renew.pl'),     'init-prj01: file "r_renew.pl"     actually exists');
    ok(-f File::Spec->catfile('Cmd', 'r_reset.pl'),     'init-prj01: file "r_reset.pl"     actually exists');
    ok(-f File::Spec->catfile('Cmd', 'r_statdiff.pl'),  'init-prj01: file "r_statdiff.pl"  actually exists');
    ok(-f File::Spec->catfile('Cmd', 'r_status.pl'),    'init-prj01: file "r_status.pl"    actually exists');
}

# initialising Prj_02:
# ********************

{
    my $dir = File::Spec->catdir($tempdir, 'Prj_02');
    chdir $dir or die "Error-0020: Can't chdir '$dir' because $!";

    my ($stdout, $stderr, $rc) = my_system($^X, File::Spec->catdir($mpath, 'vc_init.pl'));

    is($rc, 0,                                          'init-prj02: rc is zero');
    is($stderr, '',                                     'init-prj02: stderr is empty');

    like($stdout, qr{==> \s a_Prj_02\.txt   \s}xms,     'init-prj02: stdout contains "a_Prj_02.txt"');
    like($stdout, qr{==> \s r_apply\.pl     \s}xms,     'init-prj02: stdout contains "r_apply.pl"');
    like($stdout, qr{==> \s r_checkout\.pl  \s}xms,     'init-prj02: stdout contains "r_checkout.pl"');
    like($stdout, qr{==> \s r_list_det\.pl  \s}xms,     'init-prj02: stdout contains "r_list_det.pl"');
    like($stdout, qr{==> \s r_list_file\.pl \s}xms,     'init-prj02: stdout contains "r_list_file.pl"');
    like($stdout, qr{==> \s r_list_proj\.pl \s}xms,     'init-prj02: stdout contains "r_list_proj.pl"');
    like($stdout, qr{==> \s r_renew\.pl     \s}xms,     'init-prj02: stdout contains "r_renew.pl"');
    like($stdout, qr{==> \s r_reset\.pl     \s}xms,     'init-prj02: stdout contains "r_reset.pl"');
    like($stdout, qr{==> \s r_statdiff\.pl  \s}xms,     'init-prj02: stdout contains "r_statdiff.pl"');
    like($stdout, qr{==> \s r_status\.pl    \s}xms,     'init-prj02: stdout contains "r_status.pl"');

    ok(-f File::Spec->catfile('Cmd', 'a_Prj_02.txt'),   'init-prj02: file "a_Prj_02.txt"   actually exists');
    ok(-f File::Spec->catfile('Cmd', 'r_apply.pl'),     'init-prj02: file "r_apply.pl"     actually exists');
    ok(-f File::Spec->catfile('Cmd', 'r_checkout.pl'),  'init-prj02: file "r_checkout.pl"  actually exists');
    ok(-f File::Spec->catfile('Cmd', 'r_list_det.pl'),  'init-prj02: file "r_list_det.pl"  actually exists');
    ok(-f File::Spec->catfile('Cmd', 'r_list_file.pl'), 'init-prj02: file "r_list_file.pl" actually exists');
    ok(-f File::Spec->catfile('Cmd', 'r_list_proj.pl'), 'init-prj02: file "r_list_proj.pl" actually exists');
    ok(-f File::Spec->catfile('Cmd', 'r_renew.pl'),     'init-prj02: file "r_renew.pl"     actually exists');
    ok(-f File::Spec->catfile('Cmd', 'r_reset.pl'),     'init-prj02: file "r_reset.pl"     actually exists');
    ok(-f File::Spec->catfile('Cmd', 'r_statdiff.pl'),  'init-prj02: file "r_statdiff.pl"  actually exists');
    ok(-f File::Spec->catfile('Cmd', 'r_status.pl'),    'init-prj02: file "r_status.pl"    actually exists');
}

# successfully checking out 2 files in Prj_01 (plus 1 checkout of a non-existent file):
# *************************************************************************************

{
    my $dir = File::Spec->catdir($tempdir, 'Prj_01');
    chdir $dir or die "Error-0030: Can't chdir '$dir' because $!";
}

{
    my ($stdout, $stderr, $rc) = my_system($^X,
      File::Spec->catdir($mpath, 'vc_checkout.pl'),
      File::Spec->catdir($tempdir, 'Data_01', 'test-003.txt'),
    );

    ok(-e File::Spec->catdir('Work', 'F_test-003_Z001.txt'),                                                     'co-prj01-test-003: checked-out file does actually exist under Work/');
    like($stdout, qr{^ Ckout \s \[ \s+ 1/ \s+ 1\] \s \*\* \s \S+ \s \*\* \s F_test-003_Z \d{3} \.txt \s}xms,     'co-prj01-test-003: stdout contains checkout message');
    is($rc, 0,                                                                                                   'co-prj01-test-003: rc is zero');
    is($stderr, '',                                                                                              'co-prj01-test-003: stderr is empty');
}

{
    my ($stdout, $stderr, $rc) = my_system($^X,
      File::Spec->catdir($mpath, 'vc_checkout.pl'),
      File::Spec->catdir($tempdir, 'Data_02', 'example-004.txt'),
    );

    ok(-e File::Spec->catdir('Work', 'F_example-004_Z001.txt'),                                                  'co-prj01-exmp-004: checked-out file does actually exist under Work/');
    like($stdout, qr{^ Ckout \s \[ \s+ 1/ \s+ 1\] \s \*\* \s \S+ \s \*\* \s F_example-004_Z \d{3} \.txt \s}xms,  'co-prj01-exmp-004: stdout contains checkout message');
    is($rc, 0,                                                                                                   'co-prj01-exmp-004: rc is zero');
    is($stderr, '',                                                                                              'co-prj01-exmp-004: stderr is empty');
}

{
    my ($stdout, $stderr, $rc) = my_system($^X,
      File::Spec->catdir($mpath, 'vc_checkout.pl'),
      File::Spec->catdir($tempdir, 'Data_99', 'nfound-999.txt'),
    );

    like($stdout, qr{^ Ckout \s \[ \s+ 1/ \s+ 1\] \s -- \s+ \*\* \s not \s found \s \*\*}xms,                    'co-prj01-nfnd-999: stdout contains not-found message');
    is($rc, 0,                                                                                                   'co-prj01-nfnd-999: rc is zero');
    is($stderr, '',                                                                                              'co-prj01-nfnd-999: stderr is empty');
}

# modifying the 2 files in Prj_01:
# ********************************

{
    my $filename = File::Spec->catdir('Work', 'F_test-003_Z001.txt');

    my $content = read_file($filename, err_mode => 'quiet') // '?';

    my $nbl_bef = () = $content =~ m{(\n)}xmsg;

    my $chg01 = $content =~ s{Line \s >>test<< \s ctr=0005\n Line \s >>test<< \s ctr=0006\n}''xms; # Delete two subsequent lines
    my $chg02 = $content =~ s{(Line \s >>test<< \s ctr=0012\n)}"${1}insert monday\n"xms;           # insert a line
    my $chg03 = $content =~ s{(Line \s >>) test (<< \s ctr=0017\n)}"${1}mod tuesday${2}"xms;       # modify a line
    my $chg04 = $content =~ s{(Line \s >>) test (<< \s ctr=0019\n)}"${1}mod friday${2}"xms;        # modify another line

    my $nbl_aft = () = $content =~ m{(\n)}xmsg;

    my $write_ok = write_file($filename, {err_mode => 'quiet'}, \$content);

    is($nbl_bef, 35, 'upd-prj01-test-003: no of lines before update');

    is($chg01, 1,    'upd-prj01-test-003: two subsequent lines deleted');
    is($chg02, 1,    'upd-prj01-test-003: one line inserted');
    is($chg03, 1,    'upd-prj01-test-003: one line modified');
    is($chg04, 1,    'upd-prj01-test-003: another line modified');

    is($nbl_aft,  34,'upd-prj01-test-003: no of lines after update');

    ok($write_ok,    'upd-prj01-test-003: file successfully written back');
}

{
    my $filename = File::Spec->catdir('Work', 'F_example-004_Z001.txt');

    my $content = read_file($filename, err_mode => 'quiet') // '?';

    my $nbl_bef = () = $content =~ m{(\n)}xmsg;

    my $chg01 = $content =~ s{Line \s >>example<< \s ctr=0005\n Line \s >>example<< \s ctr=0006\n}''xms; # Delete two subsequent lines
    my $chg02 = $content =~ s{(Line \s >>example<< \s ctr=0012\n)}"${1}insert wednesday\n"xms;           # insert a line
    my $chg03 = $content =~ s{(Line \s >>) example (<< \s ctr=0017\n)}"${1}mod thursday${2}"xms;         # modify a line

    my $nbl_aft = () = $content =~ m{(\n)}xmsg;

    my $write_ok = write_file($filename, {err_mode => 'quiet'}, \$content);

    is($nbl_bef, 35, 'upd-prj01-exmp-004: no of lines before update');

    is($chg01, 1,    'upd-prj01-exmp-004: two subsequent lines deleted');
    is($chg02, 1,    'upd-prj01-exmp-004: one line inserted');
    is($chg03, 1,    'upd-prj01-exmp-004: one line modified');

    is($nbl_aft,  34,'upd-prj01-exmp-004: no of lines after update');

    ok($write_ok,    'upd-prj01-exmp-004: file successfully written back');
}

# applying changes in the 2 files of Prj_01:
# ******************************************

{
    my $fn_test = File::Spec->catdir($tempdir, 'Data_01', 'test-003.txt');
    my $fn_exmp = File::Spec->catdir($tempdir, 'Data_02', 'example-004.txt');

    my $nbl_test_bef = do{ my $content = read_file($fn_test, err_mode => 'quiet') // '?'; my $nb = () = $content =~ m{(\n)}xmsg; $nb; };
    my $nbl_exmp_bef = do{ my $content = read_file($fn_exmp, err_mode => 'quiet') // '?'; my $nb = () = $content =~ m{(\n)}xmsg; $nb; };

    my ($stdout, $stderr, $rc) = my_system($^X,
      File::Spec->catdir($mpath, 'vc_apply.pl'),
    );

    my $nbl_test_aft = do{ my $content = read_file($fn_test, err_mode => 'quiet') // '?'; my $nb = () = $content =~ m{(\n)}xmsg; $nb; };
    my $nbl_exmp_aft = do{ my $content = read_file($fn_exmp, err_mode => 'quiet') // '?'; my $nb = () = $content =~ m{(\n)}xmsg; $nb; };

    my $act_test = $stdout =~ m{F_test-003_Z001\.txt    \s+ (\w+ \s+ --I=\d+/D=\d+--> \s+ \w+)}xms ? $1 : '?';
    my $act_exmp = $stdout =~ m{F_example-004_Z001\.txt \s+ (\w+ \s+ --I=\d+/D=\d+--> \s+ \w+)}xms ? $1 : '?';

    is($act_test, 'WRK --I=0003/D=0004--> ORG', 'co-prj01-apply: message >>test<<');
    is($act_exmp, 'WRK --I=0002/D=0003--> ORG', 'co-prj01-apply: message >>exmp<<');
    is($rc, 0,                                  'co-prj01-apply: rc is zero');
    is($stderr, '',                             'co-prj01-apply: check STDERR');
    is($nbl_test_bef, 35,                       'co-prj01-apply: nb lines >>test<< before');
    is($nbl_exmp_bef, 35,                       'co-prj01-apply: nb lines >>exmp<< before');
    is($nbl_test_aft, 34,                       'co-prj01-apply: nb lines >>test<< after');
    is($nbl_exmp_aft, 34,                       'co-prj01-apply: nb lines >>exmp<< after');
}

# successfully checking out 2 files in Prj_02 (plus 1 checkout of a non-existent file):
# *************************************************************************************

{
    my $dir = File::Spec->catdir($tempdir, 'Prj_02');
    chdir $dir or die "Error-0040: Can't chdir '$dir' because $!";
}

{
    my ($stdout, $stderr, $rc) = my_system($^X,
      File::Spec->catdir($mpath, 'vc_checkout.pl'),
      File::Spec->catdir($tempdir, 'Data_01', 'test-003.txt'),
    );

    ok(-e File::Spec->catdir('Work', 'F_test-003_Z001.txt'),                                                    'co-prj02-test-003: checked-out file does actually exist under Work/');
    like($stdout, qr{^ Ckout \s \[ \s+ 1/ \s+ 1\] \s \*\* \s \S+ \s \*\* \s F_test-003_Z \d{3} \.txt \s}xms,    'co-prj02-test-003: stdout contains checkout message');
    is($rc, 0,                                                                                                  'co-prj02-test-003: rc is zero');
    is($stderr, '',                                                                                             'co-prj02-test-003: stderr is empty');
}

{
    my ($stdout, $stderr, $rc) = my_system($^X,
      File::Spec->catdir($mpath, 'vc_checkout.pl'),
      File::Spec->catdir($tempdir, 'Data_02', 'example-005.txt'),
    );

    ok(-e File::Spec->catdir('Work', 'F_example-005_Z001.txt'),                                                 'co-prj02-exmp-005: checked-out file does actually exist under Work/');
    like($stdout, qr{^ Ckout \s \[ \s+ 1/ \s+ 1\] \s \*\* \s \S+ \s \*\* \s F_example-005_Z \d{3} \.txt \s}xms, 'co-prj02-exmp-005: stdout contains checkout message');
    is($rc, 0,                                                                                                  'co-prj02-exmp-005: rc is zero');
    is($stderr, '',                                                                                             'co-prj02-exmp-005: stderr is empty');
}

{
    my ($stdout, $stderr, $rc) = my_system($^X,
      File::Spec->catdir($mpath, 'vc_checkout.pl'),
      File::Spec->catdir($tempdir, 'Data_88', 'nfound-888.txt'),
    );

    like($stdout, qr{^ Ckout \s \[ \s+ 1/ \s+ 1\] \s -- \s+ \*\* \s not \s found \s \*\*}xms,                   'co-prj02-nfnd-888: stdout contains not-found message');
    is($rc, 0,                                                                                                  'co-prj02-nfnd-888: rc is zero');
    is($stderr, '',                                                                                             'co-prj02-nfnd-888: stderr is empty');
}

# modifying the 2 files in Prj_02:
# ********************************

{
    my $filename = File::Spec->catdir('Work', 'F_test-003_Z001.txt');

    my $content = read_file($filename, err_mode => 'quiet') // '?';

    my $nbl_bef = () = $content =~ m{(\n)}xmsg;

    my $chg01 = $content =~ s{Line \s >>test<< \s ctr=0013\n Line \s >>test<< \s ctr=0014\n}''xms; # Delete two subsequent lines
    my $chg02 = $content =~ s{(Line \s >>test<< \s ctr=0003\n)}"${1}jan\nfeb\nmar\napr\n"xms;      # insert 4 lines
    my $chg03 = $content =~ s{(Line \s >>) test (<< \s ctr=0007\n)}"${1}mod may${2}"xms;           # modify a line
    my $chg04 = $content =~ s{(Line \s >>) test (<< \s ctr=0009\n)}"${1}mod jun${2}"xms;           # modify another line

    my $nbl_aft = () = $content =~ m{(\n)}xmsg;

    my $write_ok = write_file($filename, {err_mode => 'quiet'}, \$content);

    is($nbl_bef, 35, 'upd-prj02-test-003: no of lines before update');

    is($chg01, 1,    'upd-prj02-test-003: two subsequent lines deleted');
    is($chg02, 1,    'upd-prj02-test-003: four lines inserted');
    is($chg03, 1,    'upd-prj02-test-003: one line modified');
    is($chg04, 1,    'upd-prj02-test-003: another line modified');

    is($nbl_aft,  37,'upd-prj02-test-003: no of lines after update');

    ok($write_ok,    'upd-prj02-test-003: file successfully written back');
}

{
    my $filename = File::Spec->catdir('Work', 'F_example-005_Z001.txt');

    my $content = read_file($filename, err_mode => 'quiet') // '?';

    my $nbl_bef = () = $content =~ m{(\n)}xmsg;

    my $chg01 = $content =~ s{Line \s >>example<< \s ctr=0010\n Line \s >>example<< \s ctr=0011\n}''xms; # Delete two subsequent lines
    my $chg02 = $content =~ s{(Line \s >>example<< \s ctr=0004\n)}"${1}jul\naug\nsep\noct\nnov\n"xms;    # insert 5 lines
    my $chg03 = $content =~ s{(Line \s >>) example (<< \s ctr=0008\n)}"${1}mod dec${2}"xms;              # modify a line

    my $nbl_aft = () = $content =~ m{(\n)}xmsg;

    my $write_ok = write_file($filename, {err_mode => 'quiet'}, \$content);

    is($nbl_bef, 35, 'upd-prj02-exmp-005: no of lines before update');

    is($chg01, 1,    'upd-prj02-exmp-005: two subsequent lines deleted');
    is($chg02, 1,    'upd-prj02-exmp-005: five lines inserted');
    is($chg03, 1,    'upd-prj02-exmp-005: one line modified');

    is($nbl_aft,  38,'upd-prj02-exmp-005: no of lines after update');

    ok($write_ok,    'upd-prj02-exmp-005: file successfully written back');
}

# applying changes in the 2 files of Prj_02:
# ******************************************

{
    my $fn_test = File::Spec->catdir($tempdir, 'Data_01', 'test-003.txt');
    my $fn_exmp = File::Spec->catdir($tempdir, 'Data_02', 'example-005.txt');

    my $nbl_test_bef = do{ my $content = read_file($fn_test, err_mode => 'quiet') // '?'; my $nb = () = $content =~ m{(\n)}xmsg; $nb; };
    my $nbl_exmp_bef = do{ my $content = read_file($fn_exmp, err_mode => 'quiet') // '?'; my $nb = () = $content =~ m{(\n)}xmsg; $nb; };

    my ($stdout, $stderr, $rc) = my_system($^X,
      File::Spec->catdir($mpath, 'vc_apply.pl'),
    );

    my $nbl_test_aft = do{ my $content = read_file($fn_test, err_mode => 'quiet') // '?'; my $nb = () = $content =~ m{(\n)}xmsg; $nb; };
    my $nbl_exmp_aft = do{ my $content = read_file($fn_exmp, err_mode => 'quiet') // '?'; my $nb = () = $content =~ m{(\n)}xmsg; $nb; };

    my $act_test = $stdout =~ m{F_test-003_Z001\.txt    \s+ (\w+ \s+ --I=\d+/D=\d+--> \s+ \w+)}xms ? $1 : '?';
    my $act_exmp = $stdout =~ m{F_example-005_Z001\.txt \s+ (\w+ \s+ --I=\d+/D=\d+--> \s+ \w+)}xms ? $1 : '?';

    is($act_test, 'WRK --I=0010/D=0007--> ORG', 'co-prj02-apply: message >>test<<');
    is($act_exmp, 'WRK --I=0006/D=0003--> ORG', 'co-prj02-apply: message >>exmp<<');
    is($rc, 0,                                  'co-prj02-apply: rc is zero');
    is($stderr, '',                             'co-prj02-apply: check STDERR');
    is($nbl_test_bef, 34,                       'co-prj02-apply: nb lines >>test<< before');
    is($nbl_exmp_bef, 35,                       'co-prj02-apply: nb lines >>exmp<< before');
    is($nbl_test_aft, 37,                       'co-prj02-apply: nb lines >>test<< after');
    is($nbl_exmp_aft, 38,                       'co-prj02-apply: nb lines >>exmp<< after');
}

# Checking no changes:
# ********************

{
    my_system($^X, File::Spec->catdir($mpath, 'vc_reset.pl'));

    my $fn_tst3 = File::Spec->catdir($tempdir, 'Data_01', 'test-003.txt');
    my $fn_exp4 = File::Spec->catdir($tempdir, 'Data_02', 'example-004.txt');
    my $fn_exp5 = File::Spec->catdir($tempdir, 'Data_02', 'example-005.txt');

    my $nbl_tst3 = do{ my $content = read_file($fn_tst3, err_mode => 'quiet') // '?'; my $nb = () = $content =~ m{(\n)}xmsg; $nb; };
    my $nbl_exp4 = do{ my $content = read_file($fn_exp4, err_mode => 'quiet') // '?'; my $nb = () = $content =~ m{(\n)}xmsg; $nb; };
    my $nbl_exp5 = do{ my $content = read_file($fn_exp5, err_mode => 'quiet') // '?'; my $nb = () = $content =~ m{(\n)}xmsg; $nb; };

    is($nbl_tst3, 35, 'reset: nb lines >>test-003<<');
    is($nbl_exp4, 35, 'reset: nb lines >>example-004<<');
    is($nbl_exp5, 35, 'reset: nb lines >>example-005<<');
}

# Checking changes in Prj_01:
# ***************************

{
    do{ my $dir = File::Spec->catdir($tempdir, 'Prj_01'); chdir $dir or die "Error-0050: Can't chdir '$dir' because $!"; };
    my_system($^X, File::Spec->catdir($mpath, 'vc_reset.pl'));
    my_system($^X, File::Spec->catdir($mpath, 'vc_apply.pl'));

    my $filename = File::Spec->catdir('Work', 'F_test-003_Z001.txt');
    my $content = read_file($filename, err_mode => 'quiet') // '?';
    my $chg = $content =~ s{(Line \s >>) test (<< \s ctr=0020\n)}"${1}mod zzz${2}"xms; # modify a line
    my $write_ok = write_file($filename, {err_mode => 'quiet'}, \$content);

    my $fn_tst3 = File::Spec->catdir($tempdir, 'Data_01', 'test-003.txt');
    my $fn_exp4 = File::Spec->catdir($tempdir, 'Data_02', 'example-004.txt');
    my $fn_exp5 = File::Spec->catdir($tempdir, 'Data_02', 'example-005.txt');

    my $nbl_tst3 = do{ my $content = read_file($fn_tst3, err_mode => 'quiet') // '?'; my $nb = () = $content =~ m{(\n)}xmsg; $nb; };
    my $nbl_exp4 = do{ my $content = read_file($fn_exp4, err_mode => 'quiet') // '?'; my $nb = () = $content =~ m{(\n)}xmsg; $nb; };
    my $nbl_exp5 = do{ my $content = read_file($fn_exp5, err_mode => 'quiet') // '?'; my $nb = () = $content =~ m{(\n)}xmsg; $nb; };

    is($nbl_tst3, 34, 'apply-prj1: nb lines >>test-003<<');
    is($nbl_exp4, 34, 'apply-prj1: nb lines >>example-004<<');
    is($nbl_exp5, 35, 'apply-prj1: nb lines >>example-005<<');
    is($chg, 1,       'apply-prj1: modification after apply - one line has been modified');
    ok($write_ok,     'apply-prj1: modification after apply - file successfully written back');
}

{
    my ($stdout, $stderr, $rc) = my_system($^X, File::Spec->catdir($mpath, 'vc_status.pl'), '-a', '-o', '-e');

    my $hunk01 = qr{
      ARC->WRK: \s+ 5,6d4 \s+
      ARC->WRK: \s+ < \s+ Line \s+ >>example<< \s+ ctr=0005 \s+
      ARC->WRK: \s+ < \s+ Line \s+ >>example<< \s+ ctr=0006 \s+
    }xms;

    my $hunk02 = qr{
      ARC->WRK: \s+ 12a11 \s+
      ARC->WRK: \s+ > \s+ insert \s+ wednesday \s+
    }xms;

    my $hunk03 = qr{
      ARC->WRK: \s+ 17c16 \s+
      ARC->WRK: \s+ < \s+ Line \s+ >>example<< \s+ ctr=0017 \s+
      ARC->WRK: \s+ --- \s+
      ARC->WRK: \s+ > \s+ Line \s+ >>mod \s+ thursday<< \s+ ctr=0017 \s+
    }xms;

    my $hunk04 = qr{
      ARC->WRK: \s+ 5,6d4 \s+
      ARC->WRK: \s+ < \s+ Line \s+ >>test<< \s+ ctr=0005 \s+
      ARC->WRK: \s+ < \s+ Line \s+ >>test<< \s+ ctr=0006 \s+
    }xms;

    my $hunk05 = qr{
      ARC->WRK: \s+ 12a11 \s+
      ARC->WRK: \s+ > \s+ insert \s+ monday \s+
    }xms;

    my $hunk06 = qr{
      ARC->WRK: \s+ 17c16 \s+
      ARC->WRK: \s+ < \s+ Line \s+ >>test<<            \s+ ctr=0017 \s+
      ARC->WRK: \s+ --- \s+
      ARC->WRK: \s+ > \s+ Line \s+ >>mod \s+ tuesday<< \s+ ctr=0017 \s+
    }xms;

    my $hunk07 = qr{
      ARC->WRK: \s+ 19,20c18,19 \s+
      ARC->WRK: \s+ < \s+ Line \s+ >>test<< \s+ ctr=0019 \s+
      ARC->WRK: \s+ < \s+ Line \s+ >>test<< \s+ ctr=0020 \s+
      ARC->WRK: \s+ --- \s+
      ARC->WRK: \s+ > \s+ Line \s+ >>mod \s+ friday<< \s+ ctr=0019 \s+
      ARC->WRK: \s+ > \s+ Line \s+ >>mod \s+ zzz<<    \s+ ctr=0020 \s+
    }xms;

    my $hunk08 = qr{
      WRK->ORG: \s+ 19c19 \s+
      WRK->ORG: \s+ < \s+ Line \s+ >>test<<        \s+ ctr=0020 \s+
      WRK->ORG: \s+ --- \s+
      WRK->ORG: \s+ > \s+ Line \s+ >>mod \s+ zzz<< \s+ ctr=0020 \s+
    }xms;

    is($rc, 0,             'status-prj1: rc is zero');
    is($stderr, '',        'status-prj1: stderr is empty');
    like($stdout, $hunk01, 'status-prj1: stdout find hunk01');
    like($stdout, $hunk02, 'status-prj1: stdout find hunk02');
    like($stdout, $hunk03, 'status-prj1: stdout find hunk03');
    like($stdout, $hunk04, 'status-prj1: stdout find hunk04');
    like($stdout, $hunk05, 'status-prj1: stdout find hunk05');
    like($stdout, $hunk06, 'status-prj1: stdout find hunk06');
    like($stdout, $hunk07, 'status-prj1: stdout find hunk07');
    like($stdout, $hunk08, 'status-prj1: stdout find hunk08');
}

# Checking changes in Prj_02:
# ***************************

{
    do{ my $dir = File::Spec->catdir($tempdir, 'Prj_02'); chdir $dir or die "Error-0060: Can't chdir '$dir' because $!"; };
    my_system($^X, File::Spec->catdir($mpath, 'vc_reset.pl'));
    my_system($^X, File::Spec->catdir($mpath, 'vc_apply.pl'));

    my $filename = File::Spec->catdir('Work', 'F_test-003_Z001.txt');
    my $content = read_file($filename, err_mode => 'quiet') // '?';
    my $chg = $content =~ s{(Line \s >>) test (<< \s ctr=0022\n)}"${1}mod\nyyy${2}"xms; # modify a line
    my $write_ok = write_file($filename, {err_mode => 'quiet'}, \$content);

    my $fn_tst3 = File::Spec->catdir($tempdir, 'Data_01', 'test-003.txt');
    my $fn_exp4 = File::Spec->catdir($tempdir, 'Data_02', 'example-004.txt');
    my $fn_exp5 = File::Spec->catdir($tempdir, 'Data_02', 'example-005.txt');

    my $nbl_tst3 = do{ my $content = read_file($fn_tst3, err_mode => 'quiet') // '?'; my $nb = () = $content =~ m{(\n)}xmsg; $nb; };
    my $nbl_exp4 = do{ my $content = read_file($fn_exp4, err_mode => 'quiet') // '?'; my $nb = () = $content =~ m{(\n)}xmsg; $nb; };
    my $nbl_exp5 = do{ my $content = read_file($fn_exp5, err_mode => 'quiet') // '?'; my $nb = () = $content =~ m{(\n)}xmsg; $nb; };

    is($nbl_tst3, 37, 'apply-prj2: nb lines >>test-003<<');
    is($nbl_exp4, 35, 'apply-prj2: nb lines >>example-004<<');
    is($nbl_exp5, 38, 'apply-prj2: nb lines >>example-005<<');
    is($chg, 1,       'apply-prj2: modification after apply - one line has been modified');
    ok($write_ok,     'apply-prj2: modification after apply - file successfully written back');
}

{
    my ($stdout, $stderr, $rc) = my_system($^X, File::Spec->catdir($mpath, 'vc_status.pl'), '-a', '-o', '-e');

    my $hunk01 = qr{
      ARC->WRK: \s+ 4a5,9 \s+
      ARC->WRK: \s+ > \s+ jul \s+
      ARC->WRK: \s+ > \s+ aug \s+
      ARC->WRK: \s+ > \s+ sep \s+
      ARC->WRK: \s+ > \s+ oct \s+
      ARC->WRK: \s+ > \s+ nov \s+
    }xms;

    my $hunk02 = qr{
      ARC->WRK: \s+ 7c11 \s+
      ARC->WRK: \s+ < \s+ Line \s+ >>test<<        \s+ ctr=0007 \s+
      ARC->WRK: \s+ --- \s+
      ARC->WRK: \s+ > \s+ Line \s+ >>mod \s+ may<< \s+ ctr=0007 \s+
    }xms;

    my $hunk03 = qr{
      ARC->WRK: \s+ 9c13 \s+
      ARC->WRK: \s+ < \s+ Line \s+ >>test<<        \s+ ctr=0009 \s+
      ARC->WRK: \s+ --- \s+
      ARC->WRK: \s+ > \s+ Line \s+ >>mod \s+ jun<< \s+ ctr=0009 \s+
    }xms;

    my $hunk04 = qr{
      ARC->WRK: \s+ 13,14d16 \s+
      ARC->WRK: \s+ < \s+ Line \s+ >>test<< \s+ ctr=0013 \s+
      ARC->WRK: \s+ < \s+ Line \s+ >>test<< \s+ ctr=0014 \s+
    }xms;

    my $hunk05 = qr{
      ARC->WRK: \s+ 22c24,25 \s+
      ARC->WRK: \s+ < \s+ Line \s+ >>test<< \s+ ctr=0022 \s+
      ARC->WRK: \s+ --- \s+
      ARC->WRK: \s+ > \s+ Line \s+ >>mod \s+
      ARC->WRK: \s+ > \s+ yyy<< \s+ ctr=0022 \s+
    }xms;

    my $hunk06 = qr{
      WRK->ORG: \s+ 24c24,25 \s+
      WRK->ORG: \s+ < \s+ Line \s+ >>test<< \s+ ctr=0022 \s+
      WRK->ORG: \s+ --- \s+
      WRK->ORG: \s+ > \s+ Line \s+ >>mod \s+
      WRK->ORG: \s+ > \s+ yyy<< \s+ ctr=0022 \s+
    }xms;

    is($rc, 0,             'status-prj2: rc is zero');
    is($stderr, '',        'status-prj2: stderr is empty');
    like($stdout, $hunk01, 'status-prj2: stdout find hunk01');
    like($stdout, $hunk02, 'status-prj2: stdout find hunk02');
    like($stdout, $hunk03, 'status-prj2: stdout find hunk03');
    like($stdout, $hunk04, 'status-prj2: stdout find hunk04');
    like($stdout, $hunk05, 'status-prj2: stdout find hunk05');
    like($stdout, $hunk06, 'status-prj2: stdout find hunk06');
}

# additional check to verify that option -u does *not* show the lines '---' and '+++'
# ...and the number of inserted/deleted lines "--I=0000/D=0000-->" is correct
# ***********************************************************************************

{
    my ($stdout, $stderr, $rc) = my_system($^X, File::Spec->catdir($mpath, 'vc_status.pl'), '-a', '-o', '-e', '-u');


    my ($f_name, $f_ins, $f_del) =
      $stdout =~ m{^ \s* \[ \s+ 1/ \s+ 2] \s+ (\S+) \s+ ARC \s+ --I= (\d+) / D= (\d+) -->}xms ? ($1, $2 + 0, $3 + 0) : ('', 0, 0);

    is($rc, 0,                            'status-prj2-u: rc is zero');
    is($stderr, '',                       'status-prj2-u: stderr is empty');
    unlike($stdout, qr{\s --- \s}xms,     'status-prj2-u: there is no ---');
    unlike($stdout, qr{\s \+\+\+ \s}xms,  'status-prj2-u: there is no +++');
    is($f_name, 'F_example-005_Z001.txt', 'status-prj2-u: name for [1/2]');
    is($f_ins, 6,                         'status-prj2-u: inserted for [1/2]');
    is($f_del, 3,                         'status-prj2-u: deleted for [1/2]');
}

# General list
# ************

{
    my ($stdout, $stderr, $rc) = my_system($^X, File::Spec->catdir($mpath, 'vc_list.pl'), '-d');

    my $line01 = qr{
      1\. [ ]+ \[CO=  [ ]+ 2\]   [ ]+ >>Dirty<<               [^\n]* \n
  [ ]+ \+ [ ]+ Prj_01 [ ]+ ----> [ ]+ F_test-003_Z001\.txt    [^\n]* \n
  [ ]+ \+ [ ]+ Prj_02 [ ]+ ----> [ ]+ F_test-003_Z001\.txt    [^\n]* \n
    }xms;

    my $line02 = qr{
      2\. [ ]+ \[CO=  [ ]+ 1\]                                [^\n]* \n
  [ ]+ \+ [ ]+ Prj_01 [ ]+ ----> [ ]+ F_example-004_Z001\.txt [^\n]* \n
    }xms;

    my $line03 = qr{
      3\. [ ]+ \[CO=  [ ]+ 1\]   [ ]+ Prj_02                  [^\n]* \n
  [ ]+ => [ ]+ Prj_02 [ ]+ ----> [ ]+ F_example-005_Z001\.txt [^\n]* \n
    }xms;

    is($rc, 0,             'list-detail: rc is zero');
    is($stderr, '',        'list-detail: stderr is empty');
    like($stdout, $line01, 'list-detail: stdout find line01');
    like($stdout, $line02, 'list-detail: stdout find line02');
    like($stdout, $line03, 'list-detail: stdout find line03');
}

# Testing vc_merge
# ****************

{
    my $inp_file = File::Spec->catdir($tempdir, 'Misc_01', 'Pips.txt');
    my $dif_file = File::Spec->catdir($tempdir, 'Misc_01', 'Patch_03.txt');

    my ($stdout, $stderr, $rc) = my_system($^X, File::Spec->catdir($mpath, 'vc_merge.pl'),
      '--input='  . $inp_file,
      '--diff='   . $dif_file,
    );

    my $verif01 = qr{There \s+ are \s+ 2 \s+ hunks}xms;

    my $verif02 = qr{
      s \s+  3 \s+ => \s+ the`years`’82`and`’90,`I`am`faced`by \s+
      - \s+ -- \s+ => \s+
      d \s+  2 \s+ => \s+ the`years`’82`and`’90,`I`am`faced`by \s+
    }xms;

    is($rc, 0,              'vc_merge_01: rc is zero');
    like($stdout, $verif01, 'vc_merge_01: stdout verification 01');
    like($stdout, $verif02, 'vc_merge_01: stdout verification 02');
    is($stderr, '',         'vc_merge_01: stderr is empty');
}

{
    my $inp_file = File::Spec->catdir($tempdir, 'Misc_01', 'Pips.txt');
    my $dif_file = File::Spec->catdir($tempdir, 'Misc_01', 'Patch_03a.txt');

    my ($stdout, $stderr, $rc) = my_system($^X, File::Spec->catdir($mpath, 'vc_merge.pl'),
      '--input='  . $inp_file,
      '--diff='   . $dif_file,
    );

    my $verif01 = qr{There \s+ are \s+ 2 \s+ hunks}xms;

    is($rc, 0,              'vc_merge_02: rc is zero');
    like($stdout, $verif01, 'vc_merge_02: stdout verification 01');
    is($stderr, '',         'vc_merge_02: stderr is empty');
}

{
    my $inp_file = File::Spec->catdir($tempdir, 'Misc_01', 'Pips.txt');
    my $dif_file = File::Spec->catdir($tempdir, 'Misc_01', 'Patch_04.txt');

    my ($stdout, $stderr, $rc) = my_system($^X, File::Spec->catdir($mpath, 'vc_merge.pl'),
      '--input='  . $inp_file,
      '--diff='   . $dif_file,
    );

    my $verif01 = qr{
      s \s+ 8 \s+ => \s+ gained`publicity` \s+   through` \s+  the` \s+ papers,` \s+  and \s+
          \*+ \s+ => \s+ \*+ \s+ \*+ \s+ \*+ \s+ \*+ \s+
      d \s+ 7 \s+ => \s+ gained`publicity~\[126\]through~\[96\]the~\[9\]papers,~\[23\]and \s+
    }xms;

    is($rc, 0,              'vc_merge_03: rc is zero');
    like($stdout, $verif01, 'vc_merge_03: stdout verification 01');
    is($stderr, '',         'vc_merge_03: stderr is empty');
}

{
    my $inp_file = File::Spec->catdir($tempdir, 'Misc_01', 'Pips.txt');
    my $dif_file = File::Spec->catdir($tempdir, 'Misc_01', 'Patch_04.txt');

    my ($stdout, $stderr, $rc) = my_system($^X, File::Spec->catdir($mpath, 'vc_merge.pl'),
      '--input='  . $inp_file,
      '--diff='   . $dif_file,
      '--linewd=' . '39',
    );

    my $verif01 = qr{
      s \s+  5 \s+ => \s+ interesting`features`that`it`is`no`easy    \s+
      - \s+ -- \s+ => \s+
      d \s+  4 \s+ => \s+ interesting`features`that`it`is`no`easy    \s+

      s \s+  6 \s+ => \s+ matter`to`know`which`to`choose`and`whic    \s+
      - \s+ -- \s+ => \s+
      d \s+  5 \s+ => \s+ matter`to`know`which`to`choose`and`whic    \s+

                          h \s+

                          h \s+

      s \s+ 7 \s+ => \s+ to`leave\.`Some,`however,`                  \s+
          \*+ \s+ => \s+ \*+ \s+
      d \s+ 6 \s+ => \s+ to`leave\.`Some,`however,`\.\.\.and`here`co \s+
    }xms;

    is($rc, 0,              'vc_merge_04: rc is zero');
    like($stdout, $verif01, 'vc_merge_04: stdout verification 01');
    is($stderr, '',         'vc_merge_04: stderr is empty');
}

{
    my $inp_file = File::Spec->catdir($tempdir, 'Misc_01', 'Sherlock.txt');
    my $dif_file = File::Spec->catdir($tempdir, 'Misc_01', 'Patch_01.txt');
    my $out_file = File::Spec->catdir($tempdir, 'Misc_01', 'Output_01.txt');

    my ($stdout, $stderr, $rc) = my_system($^X, File::Spec->catdir($mpath, 'vc_merge.pl'),
      '--input='  . $inp_file,
      '--diff='   . $dif_file,
      '--output=' . $out_file,
    );

    my $content = read_file($out_file, err_mode => 'quiet') // '?';

    is($rc, 0,                                              'vc_merge_05: rc is zero');
    like($stdout, qr{Output \s successfully \s written}xms, 'vc_merge_05: stdout shows success');
    is($stderr, '',                                         'vc_merge_05: stderr is empty');
    like($content, qr{behind \s ----- \s the}xms,           'vc_merge_05: modification has been made');
}

{
    my $inp_file = File::Spec->catdir($tempdir, 'Misc_01', 'Sherlock.txt');
    my $dif_file = File::Spec->catdir($tempdir, 'Misc_01', 'Patch_02.txt');
    my $out_file = File::Spec->catdir($tempdir, 'Misc_01', 'Output_02.txt');

    my ($stdout, $stderr, $rc) = my_system($^X, File::Spec->catdir($mpath, 'vc_merge.pl'),
      '--input='  . $inp_file,
      '--diff='   . $dif_file,
      '--output=' . $out_file,
    );

    my $content = read_file($out_file, err_mode => 'quiet') // '?';

    ok($rc != 0,                                      'vc_merge_06: rc is not zero');
    like($stdout, qr{There \s are \s 1 \s hunks}xms,  'vc_merge_06: stdout shows 1 hunk');
    like($stderr, qr{Conflict \s in \s hunk \s 1}xms, 'vc_merge_06: stderr shows conflict');
    is($content, '?',                                 'vc_merge_06: no output was written');
}

# ****************************
# These are the subroutines...
# ****************************

sub preparations {
    $cwd = cwd();

    # determine the shell quote $q ==> (") on Windows, (') everywhere else...
    $q = $^O eq 'MSWin32' ? q{"} : q{'};

    $mpath    = get_mpath()    or die "Error-0070: Can't find 'vc_status.pl' in \@INC = (@INC)";
    $difftool = get_difftool() or die "Error-0072: Can't find 'Algorithm/diffnew.pl' in \@INC = (@INC)";

    $tempdir = tempdir(CLEANUP => 1); END { chdir $cwd if defined $cwd; }

    my_mkdir(File::Spec->catdir($tempdir, 'StdIO'));

    $name_out = File::Spec->catdir($tempdir, 'StdIO', 'stdout.txt');
    $name_err = File::Spec->catdir($tempdir, 'StdIO', 'stderr.txt');

    my_mkdir(File::Spec->catdir($tempdir, 'XmlRepo'));
    my_mkdir(File::Spec->catdir($tempdir, 'test_arch'));

    my_crxml(File::Spec->catdir($tempdir, 'XmlRepo'), File::Spec->catdir($tempdir, 'test_arch'));

    my_mkdir(File::Spec->catdir($tempdir, 'Data_01'));
    my_mkdir(File::Spec->catdir($tempdir, 'Data_02'));

    my_crdat(File::Spec->catdir($tempdir, 'Data_01'), 'test');
    my_crdat(File::Spec->catdir($tempdir, 'Data_02'), 'example');

    my_mkdir(File::Spec->catdir($tempdir, 'Prj_01'));
    my_mkdir(File::Spec->catdir($tempdir, 'Prj_02'));

    my_mkdir(File::Spec->catdir($tempdir, 'Misc_01'));
    my_crmsc(File::Spec->catdir($tempdir, 'Misc_01'));

    $ENV{'VCTOOLDIR'} = File::Spec->catdir($tempdir, 'XmlRepo');

    # perform one acid test first (...that is, check that vc_list.pl shows archive inside '.../test_arch/...' directory):

    my ($stdout) = my_system($^X, File::Spec->catdir($mpath, 'vc_list.pl'));

    my ($archname) = $stdout =~ m{^ Reading \s ([^\n]*) \n}xms or die "Error-0080: Can't extract 'Reading...' from '$stdout'";

    my @ele = File::Spec->splitdir($archname);

    unless (@ele >= 2) {
        local $" = "', '";
        die "Error-0090: found dir = '$archname' with only ".scalar(@ele)." elements, but expected at least 2";
    }

    my $arch2 = $ele[-2];

    unless ($arch2 eq 'test_arch') {
        die "Error-0100: found arch2 = '$arch2', but expected 'test_arch'";
    }
}

sub my_mkdir {
    unless (-d $_[0]) {
        mkdir $_[0] or die "Error-0110: Can't mkdir '$_[0]' because $!";
    }
}

sub my_crdat {
    for my $fno (1..7) {
        my $filename = File::Spec->catdir($_[0], sprintf('%s-%03d.txt', $_[1], $fno));

        open my $ofh, '>', $filename or die "Error-0120: Can't open > '$filename' because $!";

        for my $dline (1..35) {
            say {$ofh} 'Line >>', $_[1], '<< ', sprintf('ctr=%04d', $dline);
        }

        close $ofh;
    }
}

sub my_crxml {
    my $filename = File::Spec->catdir($_[0], 'vc_parameter.xml');

    open my $ofh, '>', $filename or die "Error-0130: Can't open > '$filename' because $!";

    say {$ofh} '<?xml version="1.0" encoding="iso-8859-1"?>';
    say {$ofh} '<vc>';
    say {$ofh} qq{  <archive path="$_[1]" />};
    say {$ofh} '</vc>';

    close $ofh;
}

sub my_crmsc {

    write_file(File::Spec->catdir($_[0], 'Sherlock.txt'),
      qq{Mr. Sherlock Holmes, who\n},
      qq{was usually very late in the\n},
      qq{mornings, save upon those not\n},
      qq{infrequent occasions when he\n},
      qq{was up all night, was seated\n},
      qq{at the breakfast table. I stood\n},
      qq{upon the hearth-rug and picked\n},
      qq{up the stick which our visitor\n},
      qq{had left behind him the night\n},
      qq{before. It was a fine, thick\n},
      qq{piece of wood, bulbous-headed,\n},
      qq{of the sort which is known as a\n},
      qq{"Penang lawyer." Just under the\n},
      qq{head was a broad silver band nearly\n},
      qq{an inch across. "To James Mortimer,\n},
      qq{M.R.C.S., from his friends of the\n},
      qq{C.C.H.," was engraved upon it, with the\n},
      qq{date "1884." It was just such a stick\n},
      qq{as the old-fashioned family practitioner\n},
      qq{used to carry—dignified, solid, and\n},
      qq{reassuring. [...]\n},
      qq{==\n},
      qq{A. Conan Doyle\n},
      qq{THE HOUND OF THE BASKERVILLES\n},
    );

    write_file(File::Spec->catdir($_[0], 'Patch_01.txt'),
      qq{--- a/Sherlock.txt 2010-01-19 04:31:00.000000000 +0100\n},
      qq{+++ b/Sherlock.txt 2010-02-04 21:53:31.512000000 +0100\n},
      qq{@@ -4,7 +4,7 @@\n},
      qq{ upon the hearth-rug and picked\n},
      qq{ up the stick which our visitor\n},
      qq{-had left behind him the night\n},
      qq{+had left behind ----- the night\n},
      qq{ before. It was a fine, thick\n},
      qq{ piece of wood, bulbous-headed,\n},
      qq{ of the sort which is known as a\n},
    );

    write_file(File::Spec->catdir($_[0], 'Patch_02.txt'),
      qq{--- a/Sherlock.txt 2010-01-19 04:31:00.000000000 +0100\n},
      qq{+++ b/Sherlock.txt 2010-02-04 21:53:31.512000000 +0100\n},
      qq{@@ -4,7 +4,7 @@\n},
      qq{ upon the hearth-rug and picked\n},
      qq{ up the stick ******* which our visitor\n},
      qq{-had left behind him the night\n},
      qq{+had left behind ----- the night\n},
      qq{ before. It was a fine, thick\n},
      qq{ piece of wood, bulbous-headed,\n},
      qq{ of the sort which is known as a\n},
    );

    write_file(File::Spec->catdir($_[0], 'World80a.txt'),
      qq{Mr. Phileas Fogg lived, in 1872, at No. 7,\n},
      qq{Saville Row, Burlington Gardens, the house in\n},
      qq{which Sheridan died in 1814. He was one of the\n},
      qq{most noticeable members of the Reform Club, though\n},
      qq{he seemed always to avoid attracting attention;\n},
      qq{an enigmatical personage, about whom little was\n},
      qq{known, except that he was a polished man of the\n},
      qq{world. People said that he resembled Byron—at least\n},
      qq{that his head was Byronic; but he was a bearded,\n},
      qq{tranquil Byron, who might live on a thousand years\n},
      qq{without growing old. [...]\n},
      qq{==\n},
      qq{Jules Verne\n},
      qq{AROUND THE WORLD IN EIGHTY DAYS\n},
    );

    write_file(File::Spec->catdir($_[0], 'World80b.txt'),
      qq{Mr. Phileas Fogg lived, in 1872, at No. 7,\n},
      qq{Saville Row, Burlington Gardens, the house in\n},
      qq{which Sheridan died in 1814. He was one of the\n},
      qq{most noticeable members of the Reform Club, though\n},
      qq{he seemed always to avoid attracting attention;\n},
      qq{an enigmatical personage, about whom little was \n}, # <-- Notice the extra space at the end of this line (after 'was')
      qq{known, except that he was a polished man of the\n},
      qq{world. People said that he resembled Byron—at least\n},
      qq{that his head was Byronic; but he was a bearded,\n},
      qq{tranquil Byron, who might live on a thousand years\n},
      qq{without growing old. [...]\n},
      qq{==\n},
      qq{Jules Verne\n},
      qq{AROUND THE WORLD IN EIGHTY DAYS\n},
    );

    write_file(File::Spec->catdir($_[0], 'Pips.txt'),
      qq{When I glance over my notes and records\n},
      qq{of the Sherlock Holmes cases between\n},
      qq{the years ’82 and ’90, I am faced by\n},
      qq{so many which present strange and\n},
      qq{interesting features that it is no easy\n},
      qq{matter to know which to choose and which\n},
      qq{to leave. Some, however, have already\n},
      qq{gained publicity through the papers, and\n},
      qq{others have not offered a field for those\n},
      qq{peculiar qualities which my friend\n},
      qq{possessed in so high a degree, and which\n},
      qq{it is the object of these papers to\n},
      qq{illustrate. Some, too, have baffled his\n},
      qq{analytical skill, and would be, as narratives,\n},
      qq{beginnings without an ending, while others\n},
      qq{have been but partially cleared up, and have\n},
      qq{their explanations founded rather upon\n},
      qq{conjecture and surmise than on that absolute\n},
      qq{logical proof which was so dear to him. There is,\n},
      qq{however, one of these last which was so\n},
      qq{remarkable in its details and so startling\n},
      qq{in its results that I am tempted to give some\n},
      qq{account of it in spite of the fact that there\n},
      qq{are points in connection with it which\n},
      qq{never have been, and probably never will be,\n},
      qq{entirely cleared up. [...]\n},
      qq{==\n},
      qq{A. Conan Doyle\n},
      qq{THE FIVE ORANGE PIPS\n},
    );

    write_file(File::Spec->catdir($_[0], 'Patch_03.txt'),
      qq{--- Doc-0010-orig.txt 2010-04-04 18:08:36.265000000 +0200\n},
      qq{+++ Doc-0020-mod.txt  2010-04-04 18:10:02.844000000 +0200\n},
      qq{@@ -2,7 +2,7 @@\n},
      qq{ of the Sherlock Holmes cases between\n},
      qq{ the years ’82 and ’90, I am faced by\n},
      qq{ so many which present strange and\n},
      qq{-interesting features that it is no easy\n},
      qq{+interesting feature that it is no easy\n},
      qq{ matter to know which to choose and which\n},
      qq{ to leave. Some, however, have already\n},
      qq{ gained publicity through the papers, and\n},
      qq{@@ -21,8 +21,8 @@\n},
      qq{ remarkable in its details and so startling\n},
      qq{ in its results that I am tempted to give some\n},
      qq{ account of it in spite of the fact that there\n},
      qq{+a new line has been added\n},
      qq{ are points in connection with it which\n},
      qq{-never have been, and probably never will be,\n},
      qq{ entirely cleared up. [...]\n},
      qq{ ==\n},
      qq{ A. Conan Doyle\n},
    );

    write_file(File::Spec->catdir($_[0], 'Patch_03a.txt'),
      qq{--- Doc-0010-orig.txt 2010-04-04 18:08:36.265000000 +0200\n},
      qq{+++ Doc-0020-mod.txt  2010-04-04 18:10:02.844000000 +0200\n},
      qq{@@ -3,7 +2,7 @@\n}, # identical to 'Patch_03.txt', except for '@@ -2,7' now becomes ==> '@@ -3,7'
      qq{ of the Sherlock Holmes cases between\n},
      qq{ the years ’82 and ’90, I am faced by\n},
      qq{ so many which present strange and\n},
      qq{-interesting features that it is no easy\n},
      qq{+interesting feature that it is no easy\n},
      qq{ matter to know which to choose and which\n},
      qq{ to leave. Some, however, have already\n},
      qq{ gained publicity through the papers, and\n},
      qq{@@ -21,8 +21,8 @@\n},
      qq{ remarkable in its details and so startling\n},
      qq{ in its results that I am tempted to give some\n},
      qq{ account of it in spite of the fact that there\n},
      qq{+a new line has been added\n},
      qq{ are points in connection with it which\n},
      qq{-never have been, and probably never will be,\n},
      qq{ entirely cleared up. [...]\n},
      qq{ ==\n},
      qq{ A. Conan Doyle\n},
    );

    write_file(File::Spec->catdir($_[0], 'Patch_04.txt'),
      qq{--- Doc-0010-orig.txt 2010-04-04 18:08:36.265000000 +0200\n},
      qq{+++ Doc-0020-mod.txt  2010-04-04 18:10:02.844000000 +0200\n},
      qq{@@ -2,7 +2,7 @@\n},
      qq{ of the Sherlock Holmes cases between\n},
      qq{ the years ’82 ind ’90, I am faced by\n},
      qq{ so many which present strange and\n},
      qq{-interesting features that it is no easy\n},
      qq{+interesting feature that it is no easy\n},
      qq{ matter to know which to choose and which\n},
      qq{ to leave. Some, however, },
         qq{...and here comes a very long sentence that },
         qq{I have intentionally added to show how long },
         qq{lines are broken up and how special characters },
         qq{such as the tilde ('~') and the backtick('`') },
         qq{are displayed on the screen... },
         qq{have already\n},
      qq{ gained publicity~through`the\tpapers,\x{17}and\n},
      qq{@@ -21,8 +21,8 @@\n},
      qq{ remarkable in its details and so startling\n},
      qq{ in its results that i am tempted to give some\n},
      qq{ account of it in spite\t\tof the fact that there\n},
      qq{+a new line has been added\n},
      qq{ are points connection with itd which\n},
      qq{-never have been, and probably never will be,\n},
      qq{ entirely cleared up. [...] \n},
      qq{ ==\n},
      qq{ A. Conan Doyle\n},
    );
}

sub my_system {
    local $" = $q.' '.$q;
    my $exec = $q."@_".$q.' >'.$q.$name_out.$q.' 2>'.$q.$name_err.$q;

    write_file($name_out, '');
    write_file($name_err, '');

    my $text_rc = system $exec;

    my $text_out = read_file($name_out);
    my $text_err = read_file($name_err);

    unlink $name_out;
    unlink $name_err;

    # hook001 for logfile

    return ($text_out, $text_err, $text_rc);
}
