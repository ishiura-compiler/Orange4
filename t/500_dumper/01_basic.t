use strict;
use warnings;

use Test::More;

use Math::BigInt;

use Orange4::Dumper;

subtest 'basic' => sub {
    my $dumper = Orange4::Dumper->new(
        vars  => undef,
        statements => undef,
    );
    isa_ok $dumper, 'Orange4::Dumper';
    can_ok $dumper, 'vars_and_statements';
    can_ok $dumper, 'all';
};

subtest 'dies ok' => sub {
    eval {
        Orange4::Dumper->new();
    };
    like $@, qr/^Missing mandatory parameter:/, 'none both of parameters';

    eval {
        Orange4::Dumper->new(
            vars => undef,
        );
    };
    like $@, qr/Missing mandatory parameter: statements/, 'vars only';

    eval {
        Orange4::Dumper->new(
            statements => undef,
        );
    };
    like $@, qr/Missing mandatory parameter: vars/, 'statements only';
};

subtest 'bigint' => sub {
    my $num = '1234';

    my $value = Math::BigInt->new($num);
    my $got = Orange4::Dumper::_bigint_dumper($value);
    my $expected = "'1234'";
    is $got, $expected, '+ is ok';

    my $value2 = Math::BigInt->new(-$num);
    my $got2 = Orange4::Dumper::_bigint_dumper($value2);
    my $expected2 = "'-1234'";
    is $got2, $expected2, '- is ok';
};

done_testing;
