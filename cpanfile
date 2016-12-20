requires 'perl', '5.008001';
requires 'Encode';
requires 'Math::BigFloat';
requires 'Math::BigInt::FastCalc', '== 0.30';
requires 'Math::BigInt::GMP', '== 1.40';
requires 'Math::Prime::Util';
requires 'Math::BigInt', '== 1.9997';
requires 'Time::HiRes';
requires 'Term::UI';
requires 'Carp';
requires 'File::Spec';
requires 'File::Term';
requires 'File::Copy';
requires 'File::Path';
requires 'File::Basename';
requires 'Getopt::Long';
requires 'POSIX';
requires 'Data::Dumper';
requires 'List::Util';
requires 'constant';
requires 'parent'

on 'test' => sub {
    requires 'Test::More', '0.98';
};

on 'configure' => sub {
  requires 'Module::Install';
  requires 'Module::Install::CPANfile';
};