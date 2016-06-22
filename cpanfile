requires 'perl', '5.008001';
requires 'Carp';
requires 'Encode';
requires 'List::MoreUtils';
requires 'Math::BigFloat';
requires 'Math::BigInt::FastCalc', '== 0.30';
requires 'Math::BigInt::GMP', '== 1.40';
requires 'Math::BigInt::Pari', '== 1.18';
requires 'Math::BigInt', '== 1.9997';
requires 'Time::HiRes';
requires 'Term::UI';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

on 'configure' => sub {
  requires 'Module::Install';
  requires 'Module::Install::CPANfile';
};