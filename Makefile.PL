use 5.010;

use ExtUtils::MakeMaker;

unless ($^O eq 'MSWin32' or $^O eq 'linux') {
    die "Error-0010: File::Vctools can only run on \$^O = 'MSWin32' or 'linux', but found \$^O = '$^O'";
}

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'File::Vctools',
    VERSION_FROM      => 'lib/File/Vctools.pm', # finds $VERSION
    PREREQ_PM         => { 
                           'XML::Reader'     => 0.37,
                           'Algorithm::Diff' => 1.19_02,
                           'File::Slurp'     => 9999.12,
                         }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/File/Vctools.pm', # retrieve abstract from module
       AUTHOR         => 'Klaus Eichner <klaus03@gmail.com>') : ()),
);
