# NAME

Orange4 - Randomtest of C compilers

# About "Orange4"

Orange4 is yet another random test system for C compilers. Although it is newer than Orange3, it is not necessarily an upgrade of Orange3. Orange4 employs a new algorithm for random program generation based on equivalence program transformation which is very different from that of Orange3. It allows program generation of wider C syntax, but there are cases where Orange3 does better jobs.

# AUTHORS
Orange4 has been developed by the following persons at the compiler
team of Ishiura Laboratory, School of science and Technology, Kwansei Gakuin University

Mr. Kazuhiro Nakamura  
Mr. Daisuke Fujiwara  
Mr. Shogo Takakura  
Mr. Mitsuyoshi Iwatsuji  

Ishiura Lab. <ishiura-compiler@ml.kwansei.ac.jp>

# DEPENDENCY
    * cpanm
    * GMP

# INSTALLATION

Please try the following command sequence.

    $ cpanm https://github.com/ishiura-compiler/Orange4/archive/v0.1.tar.gz

    * Internet connection is required.
    * If error occurs during installation, please remove Orange4 and re-download.
    * If copy error occurs during installation, please retry.

# CONFIGURATION FILES OF Orange4

To use Orange4, users need to specify settings in the three
configuration files.  In the case of the “i386\_Cygwin” target.
for example, the configuration files are:

    * i386-cygwin-gcc.cnf (general settings)
    * i386-cygwin-gcc-compiler.cnf (compilation settings)
    * i386-cygwin-gcc-executor.cnf (execution settings)

We are sorry but the detailed manuals for composing the configuration
files are under construction.  Please copy & edit the above files.
For most of the compilers and execution environments with standard
I/O support, you just need to edit several lines.

# SYNOPSIS

An "Orange4" command repeats the process of generating a test program
and compile & executes it.  The number of tests or time for testing
should be specified.

    $ orange4 [-c config file] [options]

    * OPTION

     -c <FILE>|--config=<FILE> : Config File. (must)
                                 Default: <root>/.orangerc.cnf
     -n <Integer>               : Number of tesing.
                                 Default: 1
     -s <Integer>               : Seed number of Starting
                                 Default: 0
     -t <Integer>               : Time (hour) of testing.
                                 Cannot specify -t and -n option simultaneously.
     -h                        : Help

If an error is detected, Error File Set is saved to the following
directories.

    Directory      : ./LOG/<START_TIME>/

    Error File Set : Report File (*.log),
                     Config File (*.cnf),
                     Seed information File  (*.pl),
                     Detected error C source File (*.c)

# MINIMIZATION OF ERROR FILE

Orange4 can reduce programs that detected errors by Orange4's minimizer.

# SYNOPSIS OF Orange4's MINIMIZER

"File" is a seed information file saved by Orange4.  If "Directory" is
specified, add the Files in the directory and processed.

    $ orange4-minimizer <File|Directory>

# LICENSE

Copyright (C) Ishiura Lab.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
