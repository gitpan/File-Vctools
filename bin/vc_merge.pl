use strict;
use warnings;
use 5.010;

# **************************************************************************
# * This is the program "vc_merge.pl", which is part of the larger package
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

use Getopt::Long;
use File::Slurp;
use Algorithm::Diff;

my $p_input  = '';
my $p_diff   = '';
my $p_output = '';
my $p_linewd = 110;

GetOptions('input=s' => \$p_input, 'diff=s' => \$p_diff, 'output=s' => \$p_output, 'linewd=s' => \$p_linewd);

$p_linewd =~ s{\D}''xmsg;

# determine the shell quote $q ==> (") on Windows, (') everywhere else...
my $q = $^O eq 'MSWin32' ? q{"} : q{'};

say '*******************************';
say '** Merging diffs into a file **';
say '*******************************';
say '';

# début modif Klaus Eichner, 2010-02-19:
my $s_input  = $p_input;  $s_input  =~ s/\A\Q$ENV{USERPROFILE}/~/xms if defined $ENV{USERPROFILE};
my $s_diff   = $p_diff;   $s_diff   =~ s/\A\Q$ENV{USERPROFILE}/~/xms if defined $ENV{USERPROFILE};
my $s_output = $p_output; $s_output =~ s/\A\Q$ENV{USERPROFILE}/~/xms if defined $ENV{USERPROFILE};
# fin   modif Klaus Eichner, 2010-02-19:

say "input file  = '$s_input'";
say "diff        = '$s_diff'";

if ($p_output eq '') {
    say "linewd      = $p_linewd";
}
else {
    say "output file = '$s_output'";
}
say '';

my @diff;
my $before = '';
my $after  = '';
my $hunk   = '';

my $lineno = 0;

open my $ifh, '<', $p_diff or die "Error-0010: Can't open < '$p_diff' because $!";

while (1) {
    my $_ = <$ifh>;

    if (not defined($_) or m{\A \@}xms) {
        push @diff, [$hunk, $before, $after] unless $hunk eq '';
        $before = '';
        $after  = '';
    }

    last unless defined $_;

    $lineno++;
    chomp;

    if (m{\A \@}xms) {
        $hunk = $_;
        next;
    }

    next if $hunk eq '' and (m{\A --- \s}xms or m{\A \+\+\+ \s}xms);

    my ($code, $line) = m{\A (.) (.*) \z}xms ? ($1, $2) : ('', '');

    unless ($code ~~ [' ', '+', '-']) {
        die "Error-0020: in line number $lineno, expected [' ', '+', '-'], but found '$code', line is '$_'";
    }

    if ($code eq ' ' or $code eq '-') { $before .= $line."\n"; }
    if ($code eq ' ' or $code eq '+') { $after  .= $line."\n"; }
}

close $ifh;

say "There are ", scalar(@diff), " hunks:";

if ($p_output ne '') {
    my $i;
    for (@diff) { $i++;
        my ($min_at, $min_len, $plus_at, $plus_len) = 
          $_->[0] =~ m{\A \@\@ \s* - (\d+),(\d+) \s* \+ (\d+),(\d+) \s* \@\@ \z}xms
          or die "Error-0030: Can't decompose header '$_->[0]'";

        my $descr = $_->[1];

        $descr =~ s{\s+}' 'xmsg;
        $descr =~ s{\A \s}''xms;
        $descr =~ s{\s \z}''xms;

        if (length($descr) > 50) {
            $descr = substr($descr, 0, 25).'...'.substr($descr, -22);
        }

        printf "%3d. \@\@ -%05d,%05d +%05d,%05d \@\@ --> %s\n", $i, $min_at, $min_len, $plus_at, $plus_len, $descr;
    }

    say '';

    my $data = read_file($p_input);

    $i = 0;
    for (@diff) { $i++;
        my $count = $data =~ s{\Q$_->[1]}"$_->[2]"xmsg || 0;

        unless ($count == 1) {
            die "Error-0040: Conflict in hunk $i ($_->[0]): $count matches";
        }
    }

    write_file($p_output, $data);

    say "Output successfully written to '$p_output'";
    say '';
}
else {
    my @lines_red = read_file($p_input);

    my $hkcount;
    for (@diff) { $hkcount++;
        my ($min_at, $min_len, $plus_at, $plus_len) = 
          $_->[0] =~ m{\A \@\@ \s* - (\d+),(\d+) \s* \+ (\d+),(\d+) \s* \@\@ \z}xms
          or die "Error-0050: Can't decompose header '$_->[0]'";

        say '';
        say '=' x 40;
        printf "==> %3d. \@\@ -%05d,%05d +%05d,%05d \@\@\n", $hkcount, $min_at, $min_len, $plus_at, $plus_len;
        say '=' x 40;

        my @lines_blue = split m{\n}xms, $_->[1];

        for my $i_blue (0..$#lines_blue) {
            my $i_red = $i_blue + $min_at - 1;

            
            my $text_red  = $lines_red[$i_red]   // ''; chomp $text_red; # get rid of trailing newlines
            my $text_blue = $lines_blue[$i_blue] // '';                  # newlines already got rid of

            my @chars_red  = split m{}xms, $text_red;
            my @chars_blue = split m{}xms, $text_blue;

            # Here we run the actual diff, character-by-character, of one single line...
            my @chg = Algorithm::Diff::sdiff(\@chars_red, \@chars_blue);
            push @chg, ['*', '', ''];

            my $prev_action = '';

            my $container_red  = '';
            my $container_blue = '';

            my @cont;
            for my $c (@chg) {
                my $cur_action = $c->[0];

                if ($cur_action eq '*'
                or ($cur_action eq 'u' and $prev_action ne 'u')
                or ($cur_action ne 'u' and $prev_action eq 'u')) {
                    if ($container_red ne '' or $container_blue ne '') {
                        push @cont, [$container_red, $container_blue];
                    }
                    $container_red  = '';
                    $container_blue = '';
                }
                last if $cur_action eq '*';

                $container_red  .= $c->[1];
                $container_blue .= $c->[2];

                $prev_action = $cur_action;
            }

            my $disp_red   = '';
            my $disp_white = '';
            my $disp_blue  = '';

            for my $ct (@cont) {
                for ($ct->[0], $ct->[1]) {
                    s{([[:cntrl:]~`])}{sprintf('~[%d]',ord($1))}xmsge;
                    s{[ ]}'`'xmsg;
                }

                my $maxsize = length($ct->[0]) > length($ct->[1]) ? length($ct->[0]) : length($ct->[1]);

                $disp_red   .= sprintf "%-${maxsize}s", $ct->[0];
                $disp_blue  .= sprintf "%-${maxsize}s", $ct->[1];
                $disp_white .= ($ct->[0] eq $ct->[1] ? ' ' : '*') x $maxsize;
            }

            my $offset = 0;
            while ($offset < length($disp_white)) {
                my $fragment_red   = substr($disp_red,   $offset, $p_linewd);
                my $fragment_white = substr($disp_white, $offset, $p_linewd);
                my $fragment_blue  = substr($disp_blue,  $offset, $p_linewd);

                my $marker_red   = '';
                my $marker_white = '';
                my $marker_blue  = '';

                if ($offset == 0) {
                    $marker_red   = sprintf 's%5d =>', $i_red  + 1;
                    $marker_blue  = sprintf 'd%5d =>', $i_blue + 1;
                    $marker_white = $disp_white =~ m{\S}xms ? '****** =>' : '-   -- =>';
                }

                say '';
                printf "   %-9s %s\n", $marker_red,   $fragment_red;
                printf "   %-9s %s\n", $marker_white, $fragment_white;
                printf "   %-9s %s\n", $marker_blue,  $fragment_blue;

                $offset += $p_linewd;
            }
        }
    }

    say '';
}
