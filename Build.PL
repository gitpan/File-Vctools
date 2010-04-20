use strict;
use warnings;
use 5.010;

use Module::Build;

unless ($^O eq 'MSWin32' or $^O eq 'linux') {
    die "Error-0010: File::Vctools can only run on \$^O = 'MSWin32' or 'linux', but found \$^O = '$^O'";
}

Module::Build->new(
  module_name   => 'File::Vctools',
  license       => 'perl',
  requires      => { 
                     'XML::Reader'     => 0.32,
                     'Algorithm::Diff' => 1.19_02,
                     'File::Slurp'     => 9999.12,
                   },
  dist_abstract => 'Compare different versions of text files and identify changes',
)->create_build_script;
