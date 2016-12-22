# NAME

Orange4 - Randomtest of C compilers

# About "Orange4"

Orange4 is a system to test validity of C compilers by randomly
generated programs. It currently aims at testing optimization
regarding arithmetic expressions and loop optimizations. It is based
on equivalent transformations on C programs and can generate wide
class of C test.

Orange4 has been developed by the following persons at the compiler
team of Ishiura Laboratory, School of science and Technology, Kwansei
Gakuin University <ishiura-compiler@ml.kwansei.ac.jp>

# AUTHOR

Ishiura Lab. <ishiura-compiler@ml.kwansei.ac.jp>

Mr. Kazuhiro Nakamura  
Mr. Daisuke Fujiwara  
Mr. Shogo Takakura  
Mr. Mitsuyoshi Iwatsuji  

# INSTALLATION

Please try the following command sequence.

    $ perl Build.PL
    $ ./Build
    $ ./Build test
    $ ./Build install

    * Internet connection is required.
    * If error occurs during installation, please remove Orange4 and re-download.
    * If copy error occurs during installation, please retry.

# CONFIGURATION FILES OF Orange4

To use Orange4, users need to specify settings in the three
configuration files. In the case of the “i386\_Cygwin” target.
For example, the configuration files are:

    * i386-cygwin-gcc.cnf (general settings or setting??)
    * i386-cygwin-gcc-compiler.cnf (compilation settings)
    * i386-cygwin-gcc-executor.cnf (execution settings)
    ターゲットディレクトリを作成し, そのなかに三つのコンフィグファイルをいれるようにする
    -cではそのターゲットディレクトリをしていする

We are sorry but the detailed manuals for composing the configuration
files are under construction. Please copy & edit the above files.
For most of the compilers and execution environments with standard
I/O support, you just need to edit several lines.
コンフィグのサンプルの場所を書いておく

# SYNOPSIS

An "orange4" command repeats the process of generating a test program
and compile & executes it.  The number of tests or time for testing
should be specified.

```
    $ orange4 [-c config directory] [options]

    * OPTION

-c <DIR>|--config=<DIR> : Config Directory. (must)
                          Default: <CURRENT DIR>
-n <Integer>               : Number of tesing.
                                 Default: 1
     -s <Integer>|--seed=<Integer>               : Seed number of Starting
                                 Default: 0
     -t <Integer>               : Time (hour) of testing.
                                 Cannot specify -t and -n option simultaneously.
     -h                        : Help
```

If an error is detected, Error File Set is saved to the following
directories.

    Directory      : ./LOG/<START_TIME>/

    Error File Set : Report File (*.log),
                     Config File (*.cnf),
                     Seed information File  (*.pl),
                     Detected error C source File (*.c)

# Orange4's Minimizer
Orange4 can reduce programs that detected errors by Orange4's minimizer.
Orange4で見つかるエラーの原因となるのは, 約一つの式である.
その式を明らかにするために, プログラムの中でエラーと無関係の場所を減らします.


よう修正

# SYNOPSIS OF Orange4's MINIMIZER

"File" is a seed information file saved by Orange4.  If "Directory" is
specified, add the Files in the directory and processed.

最小化には, plと実行時のコンフィグファイルが必要

    $ orange4-minimizer <FILE|DIR>
    
エラーファイル単体を指定する際のことも書く (plファイルを指定すると, ディレクトリ内のコンフィグをよんでくれる)

# Minimized Program

最小化されたプログラムはここに生成される
命名規則も記述 (seed_<オプション>_mini.c)


# LICENSE

Copyright (C) Ishiura Lab.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
