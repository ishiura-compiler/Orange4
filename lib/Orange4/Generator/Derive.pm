package Orange4::Generator::Derive;

use parent 'Orange4::Generator';

use strict;
use warnings;

use Carp ();
use Math::BigInt lib => 'GMP';
use Math::BigInt;
#use Math::BigFloat;
#use Math::BigFloat lib => 'GMP';
#use Orange4::Generator::Arithmetic; # random_range
use Math::Prime::Util qw/:all/;
use List::Util;

# perl の通常の変数で扱える最大の値
use constant VAR_MAX => 1797693134862325;#9223372036854775807;

# キャッシュのサイズの最大値（bytes）
use constant CACHE_MAX => 10485760;

# キャッシュをとるオブジェクトの平均サイズ(bytes)
use constant OBJ_AVG_SIZE => 100;

# キャッシュを削除するかチェックする周期
use constant CACHE_CHECK_CYCLE => CACHE_MAX/OBJ_AVG_SIZE;

# 乗算導出用
use constant PRIME_TABLE => [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 1]; #101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211, 223, 227, 229, 233, 239, 241, 251, 257, 263, 269, 271, 277, 281, 283, 293, 307, 311, 313, 317, 331, 337, 347, 349, 353, 359, 367, 373, 379, 383, 389, 397, 401, 409, 419, 421, 431, 433, 439, 443, 449, 457, 461, 463, 467, 479, 487, 491, 499, 503, 509, 521, 523, 541, 547, 557, 563, 569, 571, 577, 587, 593, 599, 601, 607, 613, 617, 619, 631, 641, 643, 647, 653, 659, 661, 673, 677, 683, 691, 701, 709, 719, 727, 733, 739, 743, 751, 757, 761, 769, 773, 787, 797, 809, 811, 821, 823, 827, 829, 839, 853, 857, 859, 863, 877, 881, 883, 887, 907, 911, 919, 929, 937, 941, 947, 953, 967, 971, 977, 983, 991, 997, 1009, 1013, 1019, 1021, 1031, 1033, 1039, 1049, 1051, 1061, 1063, 1069, 1087, 1091, 1093, 1097, 1103, 1109, 1117, 1123, 1129, 1151, 1153, 1163, 1171, 1181, 1187, 1193, 1201, 1213, 1217, 1223, 1229, 1231, 1237, 1249, 1259, 1277, 1279, 1283, 1289, 1291, 1297, 1301, 1303, 1307, 1319, 1321, 1327, 1361, 1367, 1373, 1381, 1399, 1409, 1423, 1427, 1429, 1433, 1439, 1447, 1451, 1453, 1459, 1471, 1481, 1483, 1487, 1489, 1493, 1499, 1511, 1523, 1531, 1543, 1549, 1553, 1559, 1567, 1571, 1579, 1583, 1597, 1601, 1607, 1609, 1613, 1619, 1621, 1627, 1637, 1657, 1663, 1667, 1669, 1693, 1697, 1699, 1709, 1721, 1723, 1733, 1741, 1747, 1753, 1759, 1777, 1783, 1787, 1789, 1801, 1811, 1823, 1831, 1847, 1861, 1867, 1871, 1873, 1877, 1879, 1889, 1901, 1907, 1913, 1931, 1933, 1949, 1951, 1973, 1979, 1987, 1993, 1997, 1999, 2003, 2011, 2017, 2027, 2029, 2039, 2053, 2063, 2069, 2081, 2083, 2087, 2089, 2099, 2111, 2113, 2129, 2131, 2137, 2141, 2143, 2153, 2161, 2179, 2203, 2207, 2213, 2221, 2237, 2239, 2243, 2251, 2267, 2269, 2273, 2281, 2287, 2293, 2297, 2309, 2311, 2333, 2339, 2341, 2347, 2351, 2357, 2371, 2377, 2381, 2383, 2389, 2393, 2399, 2411, 2417, 2423, 2437, 2441, 2447, 2459, 2467, 2473, 2477, 2503, 2521, 2531, 2539, 2543, 2549, 2551, 2557, 2579, 2591, 2593, 2609, 2617, 2621, 2633, 2647, 2657, 2659, 2663, 2671, 2677, 2683, 2687, 2689, 2693, 2699, 2707, 2711, 2713, 2719, 2729, 2731, 2741, 2749, 2753, 2767, 2777, 2789, 2791, 2797, 2801, 2803, 2819, 2833, 2837, 2843, 2851, 2857, 2861, 2879, 2887, 2897, 2903, 2909, 2917, 2927, 2939, 2953, 2957, 2963, 2969, 2971, 2999, 3001, 3011, 3019, 3023, 3037, 3041, 3049, 3061, 3067, 3079, 3083, 3089, 3109, 3119, 3121, 3137, 3163, 3167, 3169, 3181, 3187, 3191, 3203, 3209, 3217, 3221, 3229, 3251, 3253, 3257, 3259, 3271, 3299, 3301, 3307, 3313, 3319, 3323, 3329, 3331, 3343, 3347, 3359, 3361, 3371, 3373, 3389, 3391, 3407, 3413, 3433, 3449, 3457, 3461, 3463, 3467, 3469, 3491, 3499, 3511, 3517, 3527, 3529, 3533, 3539, 3541, 3547, 3557, 3559, 3571, 3581, 3583, 3593, 3607, 3613, 3617, 3623, 3631, 3637, 3643, 3659, 3671, 3673, 3677, 3691, 3697, 3701, 3709, 3719, 3727, 3733, 3739, 3761, 3767, 3769, 3779, 3793, 3797, 3803, 3821, 3823, 3833, 3847, 3851, 3853, 3863, 3877, 3881, 3889, 3907, 3911, 3917, 3919, 3923, 3929, 3931, 3943, 3947, 3967, 3989, 4001, 4003, 4007, 4013, 4019, 4021, 4027, 4049, 4051, 4057, 4073, 4079, 4091, 4093, 4099, 4111, 4127, 4129, 4133, 4139, 4153, 4157, 4159, 4177, 4201, 4211, 4217, 4219, 4229, 4231, 4241, 4243, 4253, 4259, 4261, 4271, 4273, 4283, 4289, 4297, 4327, 4337, 4339, 4349, 4357, 4363, 4373, 4391, 4397, 4409, 4421, 4423, 4441, 4447, 4451, 4457, 4463, 4481, 4483, 4493, 4507, 4513, 4517, 4519, 4523, 4547, 4549, 4561, 4567, 4583, 4591, 4597, 4603, 4621, 4637, 4639, 4643, 4649, 4651, 4657, 4663, 4673, 4679, 4691, 4703, 4721, 4723, 4729, 4733, 4751, 4759, 4783, 4787, 4789, 4793, 4799, 4801, 4813, 4817, 4831, 4861, 4871, 4877, 4889, 4903, 4909, 4919, 4931, 4933, 4937, 4943, 4951, 4957, 4967, 4969, 4973, 4987, 4993, 4999, 5003, 5009, 5011, 5021, 5023, 5039, 5051, 5059, 5077, 5081, 5087, 5099, 5101, 5107, 5113, 5119, 5147, 5153, 5167, 5171, 5179, 5189, 5197, 5209, 5227, 5231, 5233, 5237, 5261, 5273, 5279, 5281, 5297, 5303, 5309, 5323, 5333, 5347, 5351, 5381, 5387, 5393, 5399, 5407, 5413, 5417, 5419, 5431, 5437, 5441, 5443, 5449, 5471, 5477, 5479, 5483, 5501, 5503, 5507, 5519, 5521, 5527, 5531, 5557, 5563, 5569, 5573, 5581, 5591, 5623, 5639, 5641, 5647, 5651, 5653, 5657, 5659, 5669, 5683, 5689, 5693, 5701, 5711, 5717, 5737, 5741, 5743, 5749, 5779, 5783, 5791, 5801, 5807, 5813, 5821, 5827, 5839, 5843, 5849, 5851, 5857, 5861, 5867, 5869, 5879, 5881, 5897, 5903, 5923, 5927, 5939, 5953, 5981, 5987, 6007, 6011, 6029, 6037, 6043, 6047, 6053, 6067, 6073, 6079, 6089, 6091, 6101, 6113, 6121, 6131, 6133, 6143, 6151, 6163, 6173, 6197, 6199, 6203, 6211, 6217, 6221, 6229, 6247, 6257, 6263, 6269, 6271, 6277, 6287, 6299, 6301, 6311, 6317, 6323, 6329, 6337, 6343, 6353, 6359, 6361, 6367, 6373, 6379, 6389, 6397, 6421, 6427, 6449, 6451, 6469, 6473, 6481, 6491, 6521, 6529, 6547, 6551, 6553, 6563, 6569, 6571, 6577, 6581, 6599, 6607, 6619, 6637, 6653, 6659, 6661, 6673, 6679, 6689, 6691, 6701, 6703, 6709, 6719, 6733, 6737, 6761, 6763, 6779, 6781, 6791, 6793, 6803, 6823, 6827, 6829, 6833, 6841, 6857, 6863, 6869, 6871, 6883, 6899, 6907, 6911, 6917, 6947, 6949, 6959, 6961, 6967, 6971, 6977, 6983, 6991, 6997, 7001, 7013, 7019, 7027, 7039, 7043, 7057, 7069, 7079, 7103, 7109, 7121, 7127, 7129, 7151, 7159, 7177, 7187, 7193, 7207, 7211, 7213, 7219, 7229, 7237, 7243, 7247, 7253, 7283, 7297, 7307, 7309, 7321, 7331, 7333, 7349, 7351, 7369, 7393, 7411, 7417, 7433, 7451, 7457, 7459, 7477, 7481, 7487, 7489, 7499, 7507, 7517, 7523, 7529, 7537, 7541, 7547, 7549, 7559, 7561, 7573, 7577, 7583, 7589, 7591, 7603, 7607, 7621, 7639, 7643, 7649, 7669, 7673, 7681, 7687, 7691, 7699, 7703, 7717, 7723, 7727, 7741, 7753, 7757, 7759, 7789, 7793, 7817, 7823, 7829, 7841, 7853, 7867, 7873, 7877, 7879, 7883, 7901, 7907, 7919, 7927, 7933, 7937, 7949, 7951, 7963, 7993, 8009, 8011, 8017, 8039, 8053, 8059, 8069, 8081, 8087, 8089, 8093, 8101, 8111, 8117, 8123, 8147, 8161, 8167, 8171, 8179, 8191, 8209, 8219, 8221, 8231, 8233, 8237, 8243, 8263, 8269, 8273, 8287, 8291, 8293, 8297, 8311, 8317, 8329, 8353, 8363, 8369, 8377, 8387, 8389, 8419, 8423, 8429, 8431, 8443, 8447, 8461, 8467, 8501, 8513, 8521, 8527, 8537, 8539, 8543, 8563, 8573, 8581, 8597, 8599, 8609, 8623, 8627, 8629, 8641, 8647, 8663, 8669, 8677, 8681, 8689, 8693, 8699, 8707, 8713, 8719, 8731, 8737, 8741, 8747, 8753, 8761, 8779, 8783, 8803, 8807, 8819, 8821, 8831, 8837, 8839, 8849, 8861, 8863, 8867, 8887, 8893, 8923, 8929, 8933, 8941, 8951, 8963, 8969, 8971, 8999, 9001, 9007, 9011, 9013, 9029, 9041, 9043, 9049, 9059, 9067, 9091, 9103, 9109, 9127, 9133, 9137, 9151, 9157, 9161, 9173, 9181, 9187, 9199, 9203, 9209, 9221, 9227, 9239, 9241, 9257, 9277, 9281, 9283, 9293, 9311, 9319, 9323, 9337, 9341, 9343, 9349, 9371, 9377, 9391, 9397, 9403, 9413, 9419, 9421, 9431, 9433, 9437, 9439, 9461, 9463, 9467, 9473, 9479, 9491, 9497, 9511, 9521, 9533, 9539, 9547, 9551, 9587, 9601, 9613, 9619, 9623, 9629, 9631, 9643, 9649, 9661, 9677, 9679, 9689, 9697, 9719, 9721, 9733, 9739, 9743, 9749, 9767, 9769, 9781, 9787, 9791, 9803, 9811, 9817, 9829, 9833, 9839, 9851, 9857, 9859, 9871, 9883, 9887, 9901, 9907, 9923, 9929, 9931, 9941, 9949, 9967, 9973, 1];

# 浮動小数点型の乱数を生成
sub generate_random_float {
    my ($self, $float_type, $zero_flg) = @_;
    my $res = '';

    if($float_type =~ m/(float|double)$/) {
        my $type = $self->{config}->get('type');

        # generate exponent
        my $e_min = $type->{$float_type}->{e_min};
        my $e_max = $type->{$float_type}->{e_max};
        my $e = int(rand($e_max - $e_min + 1)) + $e_min;

        # generate mantissa
        $res = _generate_random_binary($type->{$float_type}->{bits}-1);
        $res = bin2dec($float_type, $res);
        $res += 1;

        $res *= accurate_pow_of_two($float_type, $e);
        $res = 0 if($res == 1 && $zero_flg && int rand 2);

        $res = -$res if(int rand 2);
    }
    else {
        Carp::croak "_generate_random_float can rdeceive only float types: $float_type";
    }

    return $res;
}

# 2進数の文字列をランダムに生成
sub _generate_random_binary {
    my $bits = shift;
    my $res = '';

    for(1 .. $bits) {
        $res .= (int rand 2) ? '0' : '1';
    }

    return $res;
}

# 正確なべき乗を生成
sub accurate_pow_of_two {
    my ($type, $exp) = @_;
    my $res = 0;

    $res = _execute_with_cache("SCALAR", \&_pow, 2, $exp);
=pod
    if($exp < 0) {
        $res = Math::BigFloat->new('1');

        for(1 .. (abs $exp)) {
            $res *= 0.5;
        }
    }
    elsif($exp == 0) {
        $res = Math::BigFloat->new('1');
    }
    else {
        $res = Math::BigFloat->new('2');
        $res **= $exp;
    }
=cut
    return $res;
}

# $n の子変数ノードを @leaf_nodes に追加.
sub make_leaf_nodes_info {
    my ($self, $leaf_nodes, $n) = @_;
    my $node_info = {};
    my $expsize = $leaf_nodes->[0]->{expsize};
    my $depth = $leaf_nodes->[0]->{depth};
    my $slope_degree = 0;
    my $l_expsize_max = 0;
    my $l_expsize_min = 0;
    my $l_expsize = 0;
    my $r_expsize = 0;
    $expsize--;

    if($expsize <= 0 || $depth <= 0) {
        # 導出を終了. 変数ノードを整形
        for my $in (@{$n->{in}}) {
            # cast operation
            if($in->{ref}->{ntype} eq 'op') {
                adjust_varnode($in->{ref}->{in}->[0]->{ref});
            }
            else {
                adjust_varnode($in->{ref});
            }
        }
    }
    else {
        # 演算子数・式の深さを計算
        $depth--;
        $l_expsize_max = ($depth/6)*($depth+1)*((2*$depth)+1)+1;
        $l_expsize_min = $expsize - $l_expsize_max;
        $l_expsize_min = 0 if($l_expsize_min < 0);
        $l_expsize = int(($l_expsize_max - $l_expsize_min+1) * rand() + $l_expsize_min);

        if($l_expsize > $expsize) {
            $slope_degree = int(rand 5) * 25;
            $l_expsize =int($expsize * ($slope_degree/100));
        }
        else {
            ;
        }

        $r_expsize = $expsize - $l_expsize;

        # 導出に使用する変数ノードをリストに追加
        for my $i (0 .. $#{$n->{in}}) {
            $node_info = {
                # キャスト演算子が挿入されている場合を考慮
                ref => ( $n->{in}->[$i]->{ref}->{ntype} eq 'op' ?
                         $n->{in}->[$i]->{ref}->{in}->[0]->{ref} :
                         $n->{in}->[$i]->{ref} ),
                         expsize => ( $i==0? $l_expsize : $r_expsize ),
                         depth => $depth,
            };
            push @$leaf_nodes, $node_info;
        }
    }
}

# リーフ(変数)ノードの整形
sub adjust_varnode {
    my $vn = shift;

    $vn->{out}->{type} = $vn->{var}->{type};
    $vn->{out}->{val}  = $vn->{var}->{val};
    $vn->{var}->{used} = 1;
    delete $vn->{nxt_op};
}

# 導出で作られた opノードを返す.
# 受け取った変数ノードの値を解とする式を生成.
sub derive_expression {
    my ($self, $n, $vars_sorted_by_value) = @_;

    # 導出に使う演算子ノードに変換. in を作成
    $n = $self->varnode2opnode($n, $vars_sorted_by_value);

    # オペランドを結合
    $self->set_operand($n);

    return $n;
}

# 導出に用いる変数を演算子ノードに変換
sub varnode2opnode {
    my ($self, $n, $vars_sorted_by_value) = @_;
    my $orig_type = $n->{var}->{type};
    my $orig_val  = $n->{var}->{val};

    # 導出した算術式が返す型を決定(キャストを挿入)
    $n = $self->define_derivation_var_type($n);

    # 演算子ノードの情報(ntype, otype, $n->{out}) をセット
    # $n->{var} を削除
    set_opnode_info($n, $n->{nxt_op});

    print "$orig_val, [$n->{otype}, ($orig_type)$n->{out}->{type}] = "
        if($self->{config}->get('debug_mode'));

    # $n->{in} の val, type, print_value をセット. (type は導出元と同じ)
    $self->set_opnodein($n, $vars_sorted_by_value);

    print "$n->{in}->[0]->{val} $n->{otype} $n->{in}->[1]->{val};\n"
        if($self->{config}->get('debug_mode'));
    print "$n->{in}->[0]->{nxt_op} :: $n->{in}->[1]->{nxt_op};\n"
        if($self->{config}->get('debug_mode'));

    return $n;
}

# for cast float value with integer type
sub round_val {
    my $val = shift;

    $val = $val->copy();

    if($val < 0) {
        $val->bceil();
    }
    else {
        $val->bfloor();
    }

    return $val;
}

# 1つ目の演算子の予約. 型は次の展開でキャスト
sub select_opcode_with_range {
    my ($self, $orig_type, $rand_min, $rand_max) = @_;
    my @oplist = qw(+ + - -  * * * * / / / /);
    my $max_type = $self->get_max_inttype('unsigned');
    $max_type = $self->get_max_inttype('signed') if($rand_max < 0 || $rand_min < 0 && int rand 2);
    my ($max_type_min, $max_type_max) = $self->get_type_min_max($max_type); # for bit op
    my ($orig_type_min, $orig_type_max) = $self->get_type_min_max($orig_type); # for mod op
    my $min_mid = $orig_type_min / 2 + 1;
    my $max_mid = int($orig_type_max / 2);

    push(@oplist, qw(< <= == != >= > && ||))
        if(($rand_min <= 0 && 0 <= $rand_max) ||
           ($rand_min <= 1 && 1 <= $rand_max));

    # rand_min などに含まれていれば
    push @oplist, qw(% % % % %)
        if($orig_type =~ m/signed/ &&
           (($rand_min < 0 && $min_mid <= $rand_min) ||
            (0 <= $rand_max && $rand_max <= $max_mid)));

    # 浮動小数点数型の場合, 整数を含むかどうかチェック
    my $rand_min_int = 0;
    my $rand_max_int = 0;
    if($orig_type =~ m/(float|double)$/) {
        my $rand_min_int = $rand_min->copy()->bceil();
        $rand_min_int = 0 if($rand_min_int < 0);
        my $rand_max_int = $rand_max->copy()->bfloor();
    }
    else {
        ;
    }

    push(@oplist, qw(<< << << << << >> >> >> >> >> & & & & & | | | | | ^ ^ ^ ^ ^))
        if(0 <= $rand_max && 0 <= $rand_max_int - $rand_min_int &&
           ($rand_min_int <= $max_type_min && $max_type_max <= $rand_max_int));

    return $oplist[rand @oplist];
}

# 2つ目の演算子を選択. 型は次の展開でキャスト
sub select_opcode_with_value {
    my ($self, $val) = @_;
    my $type = $self->{config}->get('type');
    my $max_type = $self->get_max_inttype('unsigned'); # for mod op
    $max_type = $self->get_max_inttype('signed') if($val < 0);
    my $min = $type->{$max_type}->{min};
    my $max = $type->{$max_type}->{max};
    
    # config の演算子リストを使用していない
    my @oplist = qw(+ + - - * * * * / / / /);

    # 浮動小数点数の場合, 整数型で表現できるかどうかチェック
    if(can_express_integer($val)) {
        push @oplist, qw(% % %)
            if((0 <= $val && $val*2+1 <= $max) || ($val < 0 && $min <= $val*2-1));

        push(@oplist, qw(<< << << >> >> >> & & & | | | ^ ^ ^))
            if(0 <= $val && ($min <= $val && $val <= $max));
    }
    else {
        ;
    }

    push(@oplist, qw(< <= == != >= > && ||))
        if($val == 0 || $val == 1);

    return $oplist [rand @oplist];
}

# 導出する変数の型を決定
sub define_derivation_var_type {
    my ($self, $n) = @_;
    my $op = $n->{nxt_op};
    my $orig_type = $n->{var}->{type};
    my $orig_val  = $n->{var}->{val};
    #my $max_type = $self->{config}->get('types')->[-1];
    my $max_type = $self->get_max_inttype('unsigned');
    # -1 ... config typeリストの最後尾
    $max_type = $self->{config}->get('types')->[-1]
        if($orig_type =~ m/(float|double)$/ && $op =~ m/^(\+|-|\*|\/)$/);

    my $new_var_type = '';
    my $val = $orig_val;
    $val = ($val < 0) ? $val * 2 - 1 : $val * 2 + 1 if($op eq '%');

    # 展開に使用する演算子に合った型を選択
    if($op =~ m/^(<|<=|==|!=|>=|>|&&|\|\|)$/) {
        $new_var_type = 'signed int';
    }
    else {
        $new_var_type = $self->select_type($op, $max_type, $val, 1);
    }

    # 必要であればキャストを挿入
    # defined $n->{casted} && $n->{casted} == 1 ) { ; }
    if($new_var_type eq $orig_type) {
        ;
    }
    else {
        $n = insert_cast4derive($n, $new_var_type, $orig_type);
        $n->{var}->{val} = _to_big_num($new_var_type, $orig_val);
    }

    return $n;
}

# 変数ノードをキャスト演算子に書き換え, 下に変数ノードをつける.
sub insert_cast4derive {
    my ($parent_node, $child_node_type, $cast_type) = @_;
    my $cast_op = "($cast_type)";

    # 子ノードは親ノードの型違いのコピー
    my $child_node = { ntype => 'var' };
    %{$child_node->{var}} = %{$parent_node->{var}};
    $child_node->{var}->{type} = $child_node_type;
    $child_node->{out}->{type} = $child_node_type
        if(defined $child_node->{out});
    $child_node->{out}->{val}  = $child_node->{var}->{val}
        if(defined $child_node->{out});
    $child_node->{nxt_op} = $parent_node->{nxt_op};

    $child_node->{var}->{val} = _to_big_num(
        $child_node_type, $child_node->{var}->{val}
        );

    # キャスト演算子ノードに書き換え
    set_opnode_info($parent_node, $cast_op);
    $parent_node->{in}->[0]->{type} = $child_node_type;
    $parent_node->{in}->[0]->{val}  = $child_node->{var}->{val};
    $parent_node->{in}->[0]->{ref}  = $child_node;
    $parent_node->{in}->[0]->{print_value} = 0
        unless(defined $parent_node->{in}->[0]->{print_value});
    $parent_node = round_val($parent_node->{out}->{val})
        if($cast_type =~ m/signed/ && $child_node_type =~ m/(float|double)$/);

    delete $parent_node->{in}->[1]
        if(defined $parent_node->{in}->[1]);
    delete $parent_node->{nxt_op}
        if(defined $parent_node->{nxt_op});

    return $child_node;
}

# 変数ノードの情報をを演算子ノード用に書き換える
sub set_opnode_info {
    my ($n, $opcode) = @_;

    $n->{ntype} = 'op';
    $n->{otype} = $opcode;
    $n->{out}->{type} = $n->{var}->{type};
    $n->{out}->{val}  = $n->{var}->{val};
#    $n->{out}->{val} = int($n->{out}->{val})
#        unless($n->{out}->{type} =~ /(float|double)$/);

    delete $n->{ival};
    delete $n->{var};
    delete $n->{nxt_op};
}

# 変数を再利用するかどうか決定
sub decide_multi_ref_var {
    my ($n, $rand_info, $vars_sorted_by_value, $nxt_op) = @_;
    
#########################  変数を再利用する確率  ###############################

    my $prob = 0; # 変数を再利用する確率
    
################################################################################

    my $var_ref = undef;

    if($rand_info->{type} =~ m/(float|double)$/ && !defined $rand_info->{val}){
        ; # 浮動小数点の場合, 再利用されるケースはほとんどない
          # (値が全く同じなら再利用)
    }
    else {
        if(rand() <= $prob) {
        	############# 変数の再利用の順位 #############
        	# 1. t変数
        	# 2. x変数
        	# 3. 新規x変数
        	##############################################
            $var_ref = select_multi_ref_var(
                $n->{otype}, $rand_info, $vars_sorted_by_value->{t}, $nxt_op
                );
            unless(defined $var_ref) {
                $var_ref = select_multi_ref_var(
                    $n->{otype}, $rand_info, $vars_sorted_by_value->{x}, $nxt_op
                    );
            }
        }
        else {
            ;
        }
    }

    return $var_ref;
}

# 再利用する変数をランダムで選択
sub select_multi_ref_var {
    my ($op, $rand_info, $vars_sorted_by_value, $nxt_op) = @_;
    my $rand_min = $rand_info->{rand_min};
    my $rand_max = $rand_info->{rand_max};
    my @can_use_types = ();
    my $idx = -1;

    # var_sorted_by_value 内の使用する変数ノードの index を取得
    # 値が指定されている場合. 整数のみ
    if(defined $rand_info->{val}) {
        # rand_info->{val} に一致する値の index を取得
        $idx = bin_search($rand_info->{val}, $vars_sorted_by_value, 0);
    }
    # 乱数の範囲が指定されている場合
    elsif(defined $rand_min && defined $rand_max) {
        # rand_min, rand_max の値を持つ index
        my $min_idx = 0;
        my $max_idx = 0;

        $min_idx = bin_search($rand_min, $vars_sorted_by_value, 1);

        while($min_idx <= $#$vars_sorted_by_value &&
              $vars_sorted_by_value->[$min_idx]->{val} < $rand_min) {
            $min_idx++;
        }

        if($#$vars_sorted_by_value < $min_idx) {
            # 変数の再利用が不可能
            $idx = -1;
        }
        else {
            $min_idx = 0 if($min_idx < 0);
            $max_idx = bin_search($rand_max, $vars_sorted_by_value, 1);
            $max_idx = $#$vars_sorted_by_value if($#$vars_sorted_by_value < $max_idx);

            # 予約した演算子が整数だけしか使えない場合, 浮動小数点の変数は使わない
            if(defined $nxt_op && $nxt_op !~ m/^(\+|-|\*|\/)$/) {
#                || $op !~ m/^(\+|-|\*|\/)$/) {
                for my $i ($min_idx .. $max_idx) {
                    if(can_express_integer($vars_sorted_by_value->[$i]->{val})) {
                        $idx = $i;
                        last;
                    }
                    else {
                        ;
                    }
                }
            }
            else {
                $idx = int(rand($max_idx - $min_idx + 1)) + $min_idx;
            }

            $idx = -1 if($#$vars_sorted_by_value < $idx || $idx < 0 ||
                         $vars_sorted_by_value->[$idx]->{val} < $rand_min ||
                         $rand_max < $vars_sorted_by_value->[$idx]->{val});
        }
    }
    else {
        Carp::croak "Invalid rand_info: $rand_info->{rand_min}, $rand_info->{rand_max}";
    }

    # もし rand_info に一致する変数がない場合, 変数の再利用はしない
    if($idx == -1 || $#$vars_sorted_by_value < $idx ||
       ($op =~ m/^(%|<<|>>|&|\||\^)$/ && $vars_sorted_by_value->[$idx]->{type} =~ m/(float|double)$/)) {
        return;
    }
    else {
#        print "\@reuse@, $vars_sorted_by_value->[$idx]->{val}\n";
        return $vars_sorted_by_value->[$idx];
    }
}

# 演算子ごとに opnode の in の型と値を生成.
sub make_opnodein {
    my ($self, $n, $vars_sorted_by_value) = @_;
    my $op = $n->{otype};
    my $orig_type = $n->{out}->{type};

    # 各演算子に沿い導出
    if($op eq '+') {
        $self->derive_with_add($n, $vars_sorted_by_value);
    }
    elsif($op eq '-') {
        $self->derive_with_sub($n, $vars_sorted_by_value);
    }
    elsif($op eq '*') {
        $self->derive_with_mul($n, $vars_sorted_by_value);
    }
    elsif($op eq '/') {
        $self->derive_with_div($n, $n->{out}->{val}, $vars_sorted_by_value);
    }
    elsif($op eq '%') {
        $self->derive_with_mod($n, $vars_sorted_by_value);
    }
    elsif($op =~ m/^(<<|>>)$/) {
        $self->derive_with_shift($n, $vars_sorted_by_value);
    }
    elsif($op =~ m/^(<|<=|==|!=|>=|>)$/) {
        $self->derive_with_relation($n, $vars_sorted_by_value);
    }
    elsif($op =~ m/^(&&|\|\|)$/) {
        $self->derive_with_logical($n, $vars_sorted_by_value);
    }
    elsif($op =~ m/^(&|\||\^)$/) {
        $self->derive_with_bit($n, $vars_sorted_by_value);
    }
    else {
        Carp::croak "Invalid opcode: $op";
    }

    # 2つ目の演算子を予約
    my $in0 = $n->{in}->[0];
    my $in1 = $n->{in}->[1];
    if(defined $in0->{nxt_op}) {
        $in1->{nxt_op} = $self->select_opcode_with_value($in1->{val});
    }
    else {
        $in0->{nxt_op} = $self->select_opcode_with_value($in0->{val});
    }
}

# 演算子ノードの in0 と in1 を入れ替え()
sub swap_opnodein {
    my $n = shift;
    my %swap_tmp = %{$n->{in}->[0]};

    %{$n->{in}->[0]} = %{$n->{in}->[1]};
    %{$n->{in}->[1]} = %swap_tmp;
}

###################### 値の決め方(右の子から) ######################
# 1. 子の値を決めるための乱数の幅(rand_min, rand_max)を決定
# 2. 乱数の幅を考慮した子の演算子を予約
# 3. 予約された演算子から, 乱数の幅を再決定
# 4. 乱数の幅を考慮した変数を決定(再利用 OR 新規)
# 5. 値が決定される
####################################################################

# +演算子で算術式を導出する
sub derive_with_add {
    my ($self, $n, $vars_sorted_by_value) = @_;
    my $orig_val = $n->{out}->{val};
    my $orig_type = $n->{out}->{type};

    # 生成する乱数の最大・最小値を求める.
    my ($min, $max) = $self->get_type_min_max($orig_type);
    my $rand_min = $orig_val - $max;
    my $rand_max = $orig_val - $min;
    $rand_min = $min if($rand_min < $min);
    $rand_max = $max if($max < $rand_max);

    my $in0 = $n->{in}->[0];
    my $in1 = $n->{in}->[1];
    my $rand_info = {};
    # 1つ目の演算子の予約
    $in1->{nxt_op} = $self->select_opcode_with_range($orig_type, $rand_min, $rand_max);

    # in[1] の乱数の範囲(値)を, 予約した演算子に合わせて修正
    $rand_info = $self->make_rand_info($n, $rand_min, $rand_max, $in1->{nxt_op});

    # in[1]変数を再利用するかどうか決定
    $in1->{multi_ref_var} = decide_multi_ref_var(
        $n, $rand_info, $vars_sorted_by_value, $in1->{nxt_op}
        );

    # in[1] の値を生成
    $in1->{val} = $self->get_random_value(
        $n, $rand_info, $in1->{multi_ref_var}, \$in1->{nxt_op}
        );

    # in[0] の値決定, 変数を再利用するかどうか決定 ($in0, $in1 の val は == $orig_val)
    #$in0->{val} = $orig_val->copy()->bsub($in1->{val});
    $in0->{val} = -$in1->{val} + $orig_val;

    $rand_info = $self->make_rand_info($n, $in0->{val}, $in0->{val});
    $in0->{multi_ref_var} = decide_multi_ref_var(
        $n, $rand_info, $vars_sorted_by_value
        );
}

# -演算子で算術式を導出する
sub derive_with_sub {
    my ($self, $n, $vars_sorted_by_value) = @_;
    my $orig_val = $n->{out}->{val};
    my $orig_type = $n->{out}->{type};
    my ($min, $max) = $self->get_type_min_max($orig_type);

    my $rand_min = $min -$orig_val;
    my $rand_max = $max - $orig_val;
    $rand_min = $min if($rand_min < $min);
    $rand_max = $max if($max < $rand_max);

    my $in0 = $n->{in}->[0];
    my $in1 = $n->{in}->[1];
    my $rand_info = {};
    $in1->{nxt_op} = $self->select_opcode_with_range($orig_type, $rand_min, $rand_max);

    $rand_info = $self->make_rand_info($n, $rand_min, $rand_max, $in1->{nxt_op});
    $in1->{multi_ref_var} = decide_multi_ref_var(
        $n, $rand_info, $vars_sorted_by_value, $in1->{nxt_op}
        );
    $in1->{val} = $self->get_random_value(
        $n, $rand_info, $in1->{multi_ref_var}, \$in1->{nxt_op}
        );

    #$in0->{val} = $orig_val->copy()->badd($in1->{val});
    $in0->{val} = $in1->{val} + $orig_val;

    $rand_info = $self->make_rand_info($n, $in0->{val}, $in0->{val});
    $in0->{multi_ref_var} = decide_multi_ref_var(
        $n, $rand_info, $vars_sorted_by_value
        );
}

# (*)演算子で算術式を展開.
# 10000 以下の素数のテーブルで素因数分解
sub derive_with_mul {
    my ($self, $n, $vars_sorted_by_value) = @_;
    my $orig_val = $n->{out}->{val};
    my $orig_type = $n->{out}->{type};
    my ($min, $max) = $self->get_type_min_max($orig_type);

    my $in0 = $n->{in}->[0];
    my $in1 = $n->{in}->[1];
    my $rand_info = {};

    if($orig_val == 0) {
        # 左オペランドは乱数, 右オペランドは 0. 後でランダムに in を入れ替え
        $in1->{nxt_op} = $self->select_opcode_with_range($orig_type, $min, $max);

        $rand_info = $self->make_rand_info($n, $min, $max, $in1->{nxt_op});
        $in1->{multi_ref_var} = decide_multi_ref_var(
            $n, $rand_info, $vars_sorted_by_value, $in1->{nxt_op}
            );
        $in1->{val} = $self->get_random_value(
            $n, $rand_info, $in1->{multi_ref_var}, \$in1->{nxt_op}
            );

        # $orig_val == 0 のとき $in0->{val} = 0, ==1 のとき 1 に
        $in0->{val} = _to_big_num($orig_type, 0);

        $rand_info = $self->make_rand_info($n, $in0->{val}, $in0->{val});
        $in0->{multi_ref_var} = decide_multi_ref_var(
            $n, $rand_info, $vars_sorted_by_value
            );
    }
    elsif($orig_val == 1) {
        # 両オペランドとも, 値は 1
        $in1->{val} = _to_big_num($orig_type, 1);
        $in0->{val} = $in1->{val};

        $in1->{nxt_op} = $self->select_opcode_with_range(
            $orig_type, $in1->{val}, $in1->{val}
        );

        $rand_info = $self->make_rand_info(
            $n, $in1->{val}, $in1->{val}, $in1->{nxt_op}
        );
        $in1->{multi_ref_var} = decide_multi_ref_var(
            $n, $rand_info, $vars_sorted_by_value, $in1->{nxt_op}
            );
        $in0->{multi_ref_var} = decide_multi_ref_var(
            $n, $rand_info, $vars_sorted_by_value
            );
    }
    else {
        # 導出元の変数の値の絶対値で演算子を選ぶ
        my $rand_min = _to_big_num($orig_type, 1);
        $in1->{nxt_op} = $self->select_opcode_with_range(
            $orig_type, $rand_min, (abs $orig_val)
            );

        my $can_express_integer = can_express_integer($orig_val);
        if(($in1->{nxt_op} =~ m/^(<|<=|==|!=|>=|>|&&|\|\|)$/) ||
           ($in1->{nxt_op} =~ m/^(%|<<|>>|&|\||\^)$/ && $can_express_integer == 0)) {
            $in1->{val} = _to_big_num($orig_type, 1);

            $rand_info = $self->make_rand_info($n, $in1->{val}, $in1->{val});
            $in1->{multi_ref_var} = decide_multi_ref_var(
                $n, $rand_info, $vars_sorted_by_value, $in1->{nxt_op}
                );
            $in0->{val} = $orig_val;

            $rand_info = $self->make_rand_info($n, $in0->{val}, $in0->{val});
            $in0->{multi_ref_var} = decide_multi_ref_var(
                $n, $rand_info, $vars_sorted_by_value
                );
        }
        else {
            $in0->{val} = _to_big_num($orig_type, 1);
            $in1->{val} = _to_big_num($orig_type, 1);

            # 整数で表現できるかどうか確認
            #my $can_express_integer = 1;
            #$can_express_integer = can_express_integer($orig_val)
            #    if($orig_type =~ m/(float|double)$/);

            my $prime_decomp_val = abs $orig_val;
#            if($can_express_integer) {
            if($orig_type !~ m/(float|double)$/) {
                ;
            }
            else {
                my $max = _max($self->{config}->get('type')->{$orig_type}->{e_max}, abs $self->{config}->get('type')->{$orig_type}->{e_min});
                my $orig_val_e = _execute_with_cache("SCALAR", \&get_exponent_of_two, abs $orig_val, $max);
                my $type = $self->{config}->get('type');
                my $type_m_bits = $type->{$orig_type}->{bits} - 1;

                if($in1->{nxt_op} =~ m/^(&|\||\^)$/ && $orig_val_e < $type_m_bits) {
                    $in0->{val} = $orig_val;
                    $prime_decomp_val = 1;
                }
                else {
                    # set exponent
                    $orig_val_e -= $type_m_bits;
                    my $in1_exp = int($orig_val_e / 2);
                    $in1_exp = 0
                        if($in1->{nxt_op} !~ m/^(\+|-|\*|\/)$/);
                    my $in0_exp = $orig_val_e - $in1_exp;
                    $in1->{val} = accurate_pow_of_two($orig_type, $in1_exp);
                    $in0->{val} = accurate_pow_of_two($orig_type, $in0_exp);

                    my $orig_val_m = _execute_with_cache("SCALAR", \&get_mantissa_of_two, (abs $orig_val), $orig_val_e);

                    $prime_decomp_val = $orig_val_m;#Math::BigInt->new("$orig_val_m");
                }
            }

            # 素因数分解
            my @primes = ();
            if($prime_decomp_val == 0) {
                push @primes, 1;
            }
            else {
                prime_decomp($prime_decomp_val, \@primes);
            }

            # 素因数のリストを 2分割して, in_val を決定.
            @primes = List::Util::shuffle @primes;
            my $sep = 0;
            if($in1->{nxt_op} eq '%') {
                $sep = $#primes / 2;

                for my $i (0 .. $#primes) {
                    $in0->{val} *= $primes[$i] if($sep < $i);
                    $in1->{val} *= $primes[$i] if($i <= $sep);
                }
            }
            else {
                $sep = int(rand @primes);

                for my $i (0 .. $#primes) {
                    $in0->{val} *= $primes[$i] if($i <= $sep);
                    $in1->{val} *= $primes[$i] if($sep < $i);
                }
            }

            if($orig_val < 0) {
                if($in1->{nxt_op} =~ m/^(<<|>>|&|\||\^)$/) {
                    $in0->{val} = -$in0->{val};
                }
                else {
                    if($in0->{val} == (abs $min)) {
                        $in0->{val} = -$in0->{val};
                    }
                    else {
                        if(int rand 2) {
                            $in0->{val} = -$in0->{val};
                        }
                        else {
                            $in1->{val} = -$in1->{val};
                        }
                    }
                }
            }
        }

        $rand_info = $self->make_rand_info($n, $in1->{val}, $in1->{val});

        $in1->{multi_ref_var} = decide_multi_ref_var(
            $n, $rand_info, $vars_sorted_by_value, $in1->{nxt_op}
            );

        $rand_info = $self->make_rand_info($n, $in0->{val}, $in0->{val});
        $in0->{multi_ref_var} = decide_multi_ref_var(
            $n, $rand_info, $vars_sorted_by_value
            );
    }

}

# 10,000 以下の素数を用いて, 素因数分解を行う.
# → 1.perl のライブラリで素因数分解できる数であれば素因数分解し, 2.できなければ 100 以下の素数を用いて素因数分解を行い、さらに1.を試す
sub prime_decomp {
    my ($val, $primes) = @_;

    if(!can_express_integer($val)) {
        Carp::croak "prime_decomp can receive only a integer: $val";
    }
    else {
        ;
    }

    # factor で素因数分解できそうならする
    if ($val < VAR_MAX) {
        @$primes = factor($val);
        return;
    }

    do {
        if($val == 1) {
            push @$primes, 1;
        }
        else {
            for my $pn (@{PRIME_TABLE()}) {
                if($val % $pn == 0) {
                    $val /= $pn;
                    push @$primes, $pn;
                    last;
                }
                else {
                    ;
                }
            }
        }
    } while($primes->[-1] != 1);

    # 1以外の数で割り切れなかった場合は, その数を追加
    if($val != 1) {
        # factor で素因数分解できそうならする
        if ($val < VAR_MAX) {
            my @factors = factor($val);
            push @$primes, @factors;
        }
        else {
            push @$primes, $val;
        }
    }
    else {
        ;
    }
}

# (/) 演算子で算術式を展開.
sub derive_with_div {
    my ($self, $n, $orig_val, $vars_sorted_by_value) = @_;
    my $orig_type = $n->{out}->{type};
    my ($min, $max) = $self->get_type_min_max($orig_type);

    my $rand_min = 0;
    my $rand_max = 0;
    if($orig_val < 0) {
        $rand_min = ($max / $orig_val)->bceil();
        $rand_max = ($min / $orig_val)->bfloor();
    }
    elsif($orig_val == 0) {
        $rand_min = $min;
        $rand_max = $max;
    }
    elsif(0 < $orig_val) {
        $rand_min = ($min / $orig_val)->bceil();
        $rand_max = ($max / $orig_val)->bfloor();
    }
    else {
        Carp::croak "Invalid value: $orig_val";
    }

    $rand_min = $min if($rand_min < $min);
    $rand_max = $max if($max < $rand_max);

    # $rand_min ~ $rand_max の範囲に 0 を含まないようにする
    if($rand_min < 0 && 0 < $rand_max) {
        if(int rand 2) {
            $rand_min = _to_big_num($orig_type, 1);  # 1 ~ $rand_max
        }
        else {
            $rand_max = _to_big_num($orig_type, -1); # $rand_min ~ -1
        }
    }
    elsif($rand_min <  0 && $rand_max == 0) {
        $rand_max = _to_big_num($orig_type, -1);
    }
    elsif($rand_min == 0 &&  0 < $rand_max) {
        $rand_min = _to_big_num($orig_type, 1);
    }
    elsif($rand_min == 0 && $rand_max == 0) {
        $rand_min = _to_big_num($orig_type, 1);
        $rand_max = _to_big_num($orig_type, 1);
    }
    else {
        ;
    }

    my $in0 = $n->{in}->[0];
    my $in1 = $n->{in}->[1];
    my $rand_info = {};

    $in1->{nxt_op} = $self->select_opcode_with_range($orig_type, $rand_min, $rand_max);
    $rand_info = $self->make_rand_info($n, $rand_min, $rand_max, $in1->{nxt_op});

    $in1->{multi_ref_var} = decide_multi_ref_var(
        $n, $rand_info, $vars_sorted_by_value, $in1->{nxt_op}
        );
    $in1->{val} = $self->get_random_value(
        $n, $rand_info, $in1->{multi_ref_var}, \$in1->{nxt_op}
        );

    if($orig_val == 0) {
        $in0->{val} = Math::BigInt->new(0);
    }
    else {
        $in0->{val} = $in1->{val} * $orig_val;
    }

    $rand_info = $self->make_rand_info($n, $in0->{val}, $in0->{val});
    $in0->{multi_ref_var} = decide_multi_ref_var(
        $n, $rand_info, $vars_sorted_by_value
        );
}

# %演算子で算術式を展開
sub derive_with_mod {
    my ($self, $n, $vars_sorted_by_value) = @_;
    my $orig_val = $n->{out}->{val};
    my $orig_type = $n->{out}->{type};
    my ($min, $max) = $self->get_type_min_max($orig_type);

    my $rand_min = 0;
    my $rand_max = 0;

    if($orig_val == 0) {
        my $rand_val = new_random_range($min, $max);
        $self->derive_with_div($n, $rand_val, $vars_sorted_by_value);
    }
    else {
        if($orig_val < 0) {
            $rand_min = $min - $orig_val;
            $rand_max = $orig_val - 1;
            #$rand_max = $max if( $rand_max < $max );
        }
        elsif(0 < $orig_val) {
            $rand_min = $orig_val + 1;
            # $rand_min = $max if( $max < $rand_min );
            $rand_max = $max - $orig_val;
        }
        else {
            Carp::croak "Invalid value: $orig_val";
        }

        my $in0 = $n->{in}->[0];
        my $in1 = $n->{in}->[1];
        my $rand_info = {};
        $in1->{nxt_op} = $self->select_opcode_with_range(
            $orig_type, $rand_min, $rand_max
            );

        $rand_info = $self->make_rand_info(
            $n, $rand_min, $rand_max, $in1->{nxt_op}
            );
        $in1->{multi_ref_var} = decide_multi_ref_var(
            $n, $rand_info, $vars_sorted_by_value, $in1->{nxt_op}
            );

        $in1->{val} = $self->get_random_value(
            $n, $rand_info, $in1->{multi_ref_var}, \$in1->{nxt_op}
            );

        # ex)10 = 21 % 11 -> 10 = 31 % 11 などに
        my $in0_rand = ($orig_val < 0) ? $rand_min : $rand_max;
        $in0_rand = int($in0_rand / $in1->{val});
        $in0->{val} = $orig_val + $in1->{val} * (int(rand $in0_rand) + 1);

        $rand_info = $self->make_rand_info($n, $in0->{val}, $in0->{val});
        $in0->{multi_ref_var} = decide_multi_ref_var(
            $n, $rand_info, $vars_sorted_by_value
            );
    }
}

# (<<|>>) 演算子で算術式を展開.
# 2の補数表現のみ対応.
sub derive_with_shift {
    my ($self, $n, $vars_sorted_by_value) = @_;
    my $op = $n->{otype};
    my $orig_val = $n->{out}->{val};
    my $orig_type = $n->{out}->{type};
    my ($min, $max) = $self->get_type_min_max($orig_type);
    my $type = $self->{config}->get('type');
    my $max_bits = $type->{$orig_type}->{bits}-1;

    my $rand_min = 0;
    my $rand_max = 0;

    # rand_max を求める
    my $sft_tmp = Math::BigInt->new(2);
    if($op eq '<<') {
        while($rand_max < $max_bits && $orig_val % $sft_tmp == 0) {
            $rand_max++;
            $sft_tmp <<= 1;
        }
    }
    elsif($op eq '>>') {
        $sft_tmp = $orig_val << 1;
        while($rand_max < $max_bits && $sft_tmp <= $max) {
            $rand_max++;
            $sft_tmp <<= 1;
        }
    }
    else {
        Carp::croak "Invalid opcode: $op";
    }

    $rand_min = _to_big_num($orig_type, $rand_min);
    $rand_max = _to_big_num($orig_type, $rand_max);

    my $in0 = $n->{in}->[0];
    my $in1 = $n->{in}->[1];
    my $rand_info = {};
    $in1->{nxt_op} = $self->select_opcode_with_range($orig_type, $rand_min, $rand_max);

    $rand_info = $self->make_rand_info($n, $rand_min, $rand_max, $in1->{nxt_op});
    $in1->{multi_ref_var} = decide_multi_ref_var(
        $n, $rand_info, $vars_sorted_by_value, $in1->{nxt_op}
        );
    $in1->{val} = $self->get_random_value(
        $n, $rand_info, $in1->{multi_ref_var}, \$in1->{nxt_op}
        );

    $sft_tmp = _to_big_num($orig_type, 1);
    $sft_tmp <<= $in1->{val};

    if($in1->{val} == 0) {
        $in0->{val} = $orig_val;
    }
    else {
        # 最大値を利用
        $in0->{val} = ($op eq '<<')?
            $orig_val / $sft_tmp :
            $orig_val * $sft_tmp;
    }

    $rand_info = $self->make_rand_info($n, $in0->{val}, $in0->{val});
    $in0->{multi_ref_var} = decide_multi_ref_var(
        $n, $rand_info, $vars_sorted_by_value
        );
}

# 関係演算子. $orig_val == 1 の場合の値を生成
sub derive_with_relation {
    my ($self, $n, $vars_sorted_by_value) = @_;
    my $op = $n->{otype};
    my $orig_val = $n->{out}->{val};
    my $max_type = $self->get_max_inttype('unsigned');
#    my $max_type = $self->{config}->get('types')->[-1];
#    $max_type = $self->select_type($op, $max_type, $val, 0);
    my ($min, $max) = $self->get_type_min_max($max_type);
    my $type = $self->{config}->get('type');

    # 以下, 演算結果が 1 として in の値を生成
    # orig_val == 0 の場合は, 演算子を反転して値を求める
    if($orig_val == 0) {
        $op = reverse_relation_op($op);
    }
    else {
        ;
    }

    my $in0 = $n->{in}->[0];
    my $in1 = $n->{in}->[1];
    my $rand_info = {};

    if($op =~ m/^(<|<=|>=|>)$/) {
        # 左を予約
        $in0->{nxt_op} = $self->select_opcode_with_range($max_type, $min, $max);

        if($op eq '<') {
            $rand_info = $self->make_rand_info($n, $min, $max-1, $in0->{nxt_op});
            $in0->{multi_ref_var} = decide_multi_ref_var(
                $n, $rand_info, $vars_sorted_by_value, $in0->{nxt_op}
                );

            $in0->{val} = $self->get_random_value(
                $n, $rand_info, $in0->{multi_ref_var}, \$in0->{nxt_op}
                );
            $rand_info = $self->make_rand_info($n, $in0->{val}+1, $max);
        }
        elsif($op eq '<=') {
            $rand_info = $self->make_rand_info($n, $min, $max, $in0->{nxt_op});
            $in0->{multi_ref_var} = decide_multi_ref_var(
                $n, $rand_info, $vars_sorted_by_value, $in0->{nxt_op}
                );
            $in0->{val} = $self->get_random_value(
                $n, $rand_info, $in0->{multi_ref_var}, \$in0->{nxt_op}
                );
            $rand_info = $self->make_rand_info($n, $in0->{val}, $max);
        }
        elsif($op eq '>=') {
            $rand_info = $self->make_rand_info($n, $min, $max, $in0->{nxt_op});
            $in0->{multi_ref_var} = decide_multi_ref_var(
                $n, $rand_info, $vars_sorted_by_value, $in0->{nxt_op}
                );
            $in0->{val} = $self->get_random_value
                ($n, $rand_info, $in0->{multi_ref_var}, \$in0->{nxt_op}
                );

            $rand_info = $self->make_rand_info($n, $min, $in0->{val});
        }
        elsif($op eq '>') {
            $rand_info = $self->make_rand_info($n, $min+1, $max, $in0->{nxt_op});
            $in0->{multi_ref_var} = decide_multi_ref_var(
                $n, $rand_info, $vars_sorted_by_value, $in0->{nxt_op}
                );
            $in0->{val} = $self->get_random_value(
                $n, $rand_info, $in0->{multi_ref_var}, \$in0->{nxt_op}
                );
            $rand_info = $self->make_rand_info($n, $min, $in0->{val}-1);
        }
        else {
            Carp::croak "Invalid opcode: $op";
        }

        $in1->{multi_ref_var} = decide_multi_ref_var(
            $n, $rand_info, $vars_sorted_by_value
            );
        $in1->{val} = $self->get_random_value($n, $rand_info, $in1->{multi_ref_var});
=comment
        my $swap_tmp = 0;
        if(($op =~ m/^(<|<=)$/ && $in0->{val} > $in1->{val}) ||
            ($op =~ m/^(>|>=)$/ && $in1->{val} > $in0->{val})) {
            $swap_tmp = $in0->{val};
            $in0->{val} = $in1->{val};
            $in1->{val} = $swap_tmp;
        }
        else {
            ;
        }
=cut
    }
    elsif($op =~ m/^(==|!=)$/) {
        # 右を予約
        $in1->{nxt_op} = $self->select_opcode_with_range($max_type, $min, $max);
        if($op eq '==') {
            $rand_info = $self->make_rand_info($n, $min, $max, $in1->{nxt_op});
            $in1->{multi_ref_var} = decide_multi_ref_var(
                $n, $rand_info, $vars_sorted_by_value, $in1->{nxt_op}
                );
            $in1->{val} = $self->get_random_value(
                $n, $rand_info, $in1->{multi_ref_var}, \$in1->{nxt_op}
                );
            $rand_info = $self->make_rand_info($n, $in1->{val}, $in1->{val});
        }
        elsif($op eq '!=') {
            $rand_info = $self->make_rand_info($n, $min, $max, $in1->{nxt_op});
            $in1->{multi_ref_var} = decide_multi_ref_var(
                $n, $rand_info, $vars_sorted_by_value, $in1->{nxt_op}
                );
            $in1->{val} = $self->get_random_value(
                $n, $rand_info, $in1->{multi_ref_var}, \$in1->{nxt_op}
                );

            if($in1->{val} == $min) {
                $rand_info = $self->make_rand_info($n, $in1->{val}+1, $max);
            }
            elsif($in1->{val} == $max) {
                $rand_info = $self->make_rand_info($n, $min, $in1->{val}-1);
            }
            else {
                $rand_info = ( int rand 2 ?
                               $self->make_rand_info($n, $in1->{val}+1, $max) :
                               $self->make_rand_info($n, $min, $in1->{val}-1) );
            }
        }
        else {
            Carp::croak "Invalid opcode: $op";
        }

        $in0->{multi_ref_var} = decide_multi_ref_var(
            $n, $rand_info, $vars_sorted_by_value
            );
        $in0->{val} = $self->get_random_value($n, $rand_info, $in0->{multi_ref_var});
    }
    else {
        Carp::croak("Invalid opcode: $op");
    }
}

# 関係演算子を反転
sub reverse_relation_op {
    my $op = shift;

    if( $op eq '<' )     { $op = '>='; }
    elsif( $op eq '<=' ) { $op =  '>'; }
    elsif( $op eq '==' ) { $op = '!='; }
    elsif( $op eq '!=' ) { $op = '=='; }
    elsif( $op eq '>=' ) { $op =  '<'; }
    elsif( $op eq  '>' ) { $op = '<='; }
    else { Carp::croak "Invalid opcode: $op"; }

    return $op;
}

# 論理演算子による導出
sub derive_with_logical {
    my ($self, $n, $vars_sorted_by_value) = @_;
    my $op = $n->{otype};
    my $orig_val = $n->{out}->{val};
    my $max_type = $self->get_max_inttype('unsigned'); # temp
    #my $max_type = $self->{config}->get('types')->[-1];
    my ($min, $max) = $self->get_type_min_max($max_type);

    my $in0 = $n->{in}->[0];
    my $in1 = $n->{in}->[1];
    my $rand_info = {};
    my $rand_min = $min;
    my $rand_max = $max;

    if($op eq '&&') {
        $in1->{nxt_op} = $self->select_opcode_with_range($max_type, $min, $max);

        if($orig_val == 0) {
            $rand_info = $self->make_rand_info($n, $min, $max, $in1->{nxt_op});
            $in1->{multi_ref_var} = decide_multi_ref_var(
                $n, $rand_info, $vars_sorted_by_value, $in1->{nxt_op}
                );

            $in1->{val} = $self->get_random_value(
                $n, $rand_info, $in1->{multi_ref_var}, \$in1->{nxt_op}
                );

            if($in1->{val} == 0) {
                $rand_info = $self->make_rand_info($n, $min, $max);
            }
            else {
                $rand_info = $self->make_rand_info($n, 0, 0);
            }

            $in0->{multi_ref_var} = decide_multi_ref_var(
                $n, $rand_info, $vars_sorted_by_value);

            $in0->{val} = $self->get_random_value(
                $n, $rand_info, $in0->{multi_ref_var});
        }
        elsif($orig_val == 1) {
            if($min < 0) {
                if(int rand 2) {
                    $rand_min = 1;
                }
                else {
                    $rand_max = -1;
                }
            }
            elsif($min == 0) {
                $rand_min = 1;
            }
            else {
                ;
            }
            $rand_info = $self->make_rand_info(
                $n, $rand_min, $rand_max, $in1->{nxt_op}
                );
            $in1->{multi_ref_var} = decide_multi_ref_var(
                $n, $rand_info, $vars_sorted_by_value, $in1->{nxt_op}
                );
            $in1->{val} = $self->get_random_value(
                $n, $rand_info, $in1->{multi_ref_var}, \$in1->{nxt_op}
                );

            if($min < 0) {
                if(int rand 2) {
                    $rand_min = 1;
                }
                else {
                    $rand_max = -1;
                }
            }
            else {
                ;
            }
            $rand_info = $self->make_rand_info($n, $rand_min, $rand_max);
            $rand_info->{rand_min} = _to_big_num($max_type, 1)
                if($rand_info->{rand_min} == 0);

            $in0->{multi_ref_var} = decide_multi_ref_var(
                $n, $rand_info, $vars_sorted_by_value
                );
            $in0->{val} = $self->get_random_value(
                $n, $rand_info, $in0->{multi_ref_var}
                );
        }
        else {
            Carp::croak "derive_with_logical can receive only 0 or 1: $orig_val";
        }
    }
    elsif($op eq '||') {
        if($orig_val == 0) {
            $in1->{nxt_op} = $self->select_opcode_with_value($orig_val);
            $rand_info = $self->make_rand_info($n, $orig_val, $orig_val);
            $in1->{multi_ref_var} = decide_multi_ref_var(
                $n, $rand_info, $vars_sorted_by_value, $in1->{nxt_op}
                );
            $in1->{val} = _to_big_num($max_type, 0);

            $rand_info = $self->make_rand_info($n, 0, 0);
        }
        elsif($orig_val == 1) {
            $in1->{nxt_op} = $self->select_opcode_with_range($max_type, $min, $max);
            $rand_info = $self->make_rand_info($n, $min, $max, $in1->{nxt_op});
            $in1->{multi_ref_var} = decide_multi_ref_var(
                $n, $rand_info, $vars_sorted_by_value, $in1->{nxt_op}
                );
            $in1->{val} = $self->get_random_value(
                $n, $rand_info, $in1->{multi_ref_var}, \$in1->{nxt_op}
                );

            if($in1->{val} == 0) {
                if($min < 0) {
                    if(int rand 2) {
                        $rand_min = 1;
                    }
                    else {
                        $rand_max = -1;
                    }
                }
                elsif($min == 0) {
                    $rand_min = 1;
                }
                else {
                    ;
                }
            }
            else {
                ;
            }
            $rand_min = _to_big_num($max_type, $rand_min);
            $rand_max = _to_big_num($max_type, $rand_max);
            $rand_info = $self->make_rand_info($n, $rand_min, $rand_max);

        }
        else {
            Carp::croak "derive_with_logical can receive only 0 or 1: $orig_val";
        }

        $in0->{multi_ref_var} = decide_multi_ref_var(
            $n, $rand_info, $vars_sorted_by_value
            );
        $in0->{val} = $self->get_random_value($n, $rand_info, $in0->{multi_ref_var});
    }
    else {
        Carp::croak "Invalid opcode: $op";
    }
}

# ビット演算子を用いて導出 (and, or, xor)
sub derive_with_bit {
    my ($self, $n, $vars_sorted_by_value) = @_;
    my $op = $n->{otype};
    my $orig_type = $n->{out}->{type};
    my $orig_val  = $n->{out}->{val};

    my $in0 = $n->{in}->[0];
    my $in1 = $n->{in}->[1];
    my $rand_info = {};

    # $orig_val を 2進数(String)に変換
    ($in0->{val}, undef) = $self->dec2bin($orig_type, $orig_val);
    $in1->{val} = $in0->{val};

    my $rand = int rand 3;
    my $bit = '';
    for my $i (0 .. ((length $in0->{val})-1)) {
        $bit = substr($in0->{val}, $i, 1);

        if($op eq '&') {
            if($bit eq '0') {

                if($rand == 0)    { substr($in0->{val}, $i, 1, '1'); }
                elsif($rand == 1) { substr($in1->{val}, $i, 1, '1'); }
                else {
                    ;
                }

            }
            else {
                ;
            }
        }
        elsif($op eq '|') {
            if($bit eq '0') { ; }
            else {

                if( $rand == 0 )    { substr($in0->{val}, $i, 1, '0'); }
                elsif( $rand == 1 ) { substr($in1->{val}, $i, 1, '0'); }
                else {
                    ;
                }

            }
        }
        elsif($op eq '^') {
            if($bit eq '0') {

                if(int rand 2) {
                    substr($in0->{val}, $i, 1, '1');
                    substr($in1->{val}, $i, 1, '1');
                }
                else {
                    ;
                }

            }
            else {

                if( int rand 2 ) {
                    substr($in0->{val}, $i, 1, '0');
                }
                else {
                    substr($in1->{val}, $i, 1, '0');
                }

            }
        }
        else {
            Carp::croak "Invalid opcode: $op";
        }
    }

    # 2進数(string) を 10進数(BigInt, BigFloat) に変換
    $in0->{val} = bin2dec($orig_type, $in0->{val});
    $in1->{val} = bin2dec($orig_type, $in1->{val});

    $in0->{nxt_op} = $self->select_opcode_with_value($in0->{val});
    $rand_info = $self->make_rand_info($n, $in0->{val}, $in0->{val});
    $in0->{multi_ref_var} = decide_multi_ref_var(
        $n, $rand_info, $vars_sorted_by_value, $in0->{nxt_op}
        );
    $rand_info = $self->make_rand_info($n, $in1->{val}, $in1->{val});
    $in1->{multi_ref_var} = decide_multi_ref_var(
        $n, $rand_info, $vars_sorted_by_value
        );
}

# 10進数 -> 2進数(String)
sub dec2bin {
    my ($self, $res_type, $val) = @_;
    my $res = '';
    my $b = 0;
    my $type = $self->{config}->get('type');
    my $bits = $type->{$res_type}->{bits};
    # 引数の型で表現できるかどうかのため.
    my $can_express_bits = 0;

    # 生成するビット数
    if($res_type =~ m/^signed/) {
        $bits /= 2;
    }
    elsif($res_type =~ m/(float|double)$/) {
        $bits -= 1;
    }
    else {
        ;
    }

    # 引数は正の値のみ, 2進数に変換
    if($val < 0) {
        Carp::croak "dec2bin can receive only a positive num: $val";
    }
    elsif($val == 0) {
        $res = generate_string($bits, '0');
    }
    else {
        $val = _to_big_num($res_type, $val)
            unless((ref $val) =~ m/^Math::Big/);

        if($res_type =~ m/(float|double)$/) {
           if (1 <= $val) {
                $res = generate_string($bits, "1");
                $can_express_bits = $bits;
            }
            else {
                my $num = Math::BigInt->new(0);
                my $n = _execute_with_cache("SCALAR", \&_pow, 2, $bits);
                $num = int($n*$val);
                $res = $num->as_bin();
                $res = substr($res, 2, ((length $res)-2));
                $can_express_bits = length $res;
                my $s = generate_string($bits - length $res, 0);
                $res = $s . $res;
            }
=pod
            for(1 .. $bits) {
                $val *= 2;
                if($val < 1.0) {
                    $res .= "0";
                }
                elsif($val == 0) {
                    last;
                }
                else {
                    $res .= "1";
                    $val -= 1;
                }
                $can_express_bits++;
            }
            $can_express_bits++ unless($val == 0);
=cut
        }
        else {
            $res = $val->as_bin();
            # 先頭の 0b を削除
            $res = substr($res, 2, ((length $res)-2));
        }
    }

    return ($res, $can_express_bits);
}

# 2進数 (String) -> 10進数 (BigFloat, BigInt)
sub bin2dec {
    my ($type, $val) = @_;
    my $res;

    if($val =~ m/^(0b[01]+|[01]+)$/i) {
        if($val =~ m/^0b/i) {
            $val = substr($val, 2, ((length $val)-2));
        }
        else {
            ;
        }
    }
    else {
        Carp::croak "bin2dec can receive only a binary num: $val";
    }

    $val = "0b$val";
    my $dec = Math::BigInt->from_bin($val);

    if ($type =~ m/(float|double)$/) {
        my $n = _execute_with_cache("SCALAR", \&_pow, 2, -(length($val)-2)); # 正規化された数を処理するので 2 を引く
        my $m = Math::BigFloat->new($dec);
        $res = $n*$m;
    }
    else {
        $res = $dec;
    }
=pod
    if($type =~ m/(float|double)$/) {
        my $base_tmp = Math::BigFloat->new(0.5);
        for my $i (1 .. length $val) {
            if((substr($val, $i-1, 1)) eq '1') {
                $res += $base_tmp;
            }
            else {
                ;
            }
            $base_tmp *= 0.5;
        }
    }
    else {
        #$val = reverse $val;
        $val = "0b$val";

        $res = Math::BigInt->from_bin($val);
    }
=cut
    return $res;
}

# 型の最大値, 最小値を BigInt / BigFloat で返す
sub get_type_min_max {
    my ($self, $res_type) = @_;
    my $min = 0;
    my $max = 0;

    my $type = $self->{config}->get('type');
    ($min, $max) = _execute_with_cache("ARRAY", \&_get_type_min_max_without_self, $type, $res_type);

    return ($min, $max);
}

sub _get_type_min_max_without_self {
    my ($type, $res_type) = @_;
    my $min = 0;
    my $max = 0;

    if($res_type =~ m/(float|double)$/) {
        $min = _execute_with_cache("SCALAR", \&_to_big_num, $res_type, $type->{$res_type}->{p_max});
        $max = $min;
        $min = -$min;
    }
    else {
        $min = _execute_with_cache("SCALAR", \&_to_big_num, $res_type, $type->{$res_type}->{min});
        $max = _execute_with_cache("SCALAR", \&_to_big_num, $res_type, $type->{$res_type}->{max});
    }

    return ($min, $max);
}

# 値を BigInt, BigFloat で返す
sub _to_big_num {
    my ($type, $val) = @_;

    if($type =~ m/signed/ && can_express_integer($val)) {
        $val = Math::BigInt->new("$val")
            unless((ref $val) eq 'Math::BigInt');
    }
    else {
        $val = Math::BigFloat->new("$val")
            unless((ref $val) eq 'Math::BigFloat');
    }

    return $val;
}

# 除算・論理演算の rand_min < 0 < rand_max の場合分けはここで
# 予約した演算子に合った rand_min, rand_max に修正
sub make_rand_info {
    my ($self, $n, $rand_min, $rand_max, $nxt_op) = @_;
    my $config = $self->{config};
    my $type = $config->get('type');
    my $op = $n->{otype};
    my $max_type = $n->{out}->{type};
    $max_type = $self->get_max_inttype('unsigned')
        if($op =~ m/^(<|<=|==|!=|>=|>|&&|\|\|)$/);
#    $max_type = $config->get('types')->[-1]
#        if($op =~ m/^(<|<=|==|!=|>=|>|&&|\|\|)$/);
    # rand_min, rand_max 絶対値が大きい方
    my $rand_val = (abs $rand_min < abs $rand_max) ? $rand_max : $rand_min;
    my $res_type = $self->select_type($op, $max_type, $rand_val, 0); # この型の範囲で値を生成
    my ($min, $max) = $self->get_type_min_max($res_type);
    my $rand_info = {
        type => $res_type,
    };

    if($rand_min == $rand_max) {
        $rand_info->{val} = $rand_min;
    }
    else {
        # 乱数の幅を選択した型に合わせる
        if($rand_min <= $min && $min <= $rand_max) {
            $rand_min = $min;
        }
        else {
            ;
        }
        if($rand_min <= $max && $max <= $rand_max) {
            $rand_max = $max;
        }
        else {
            ;
        }

        my $bit = 0; # シフト演算用. 要調整

        # 関係・論理演算子を予約している場合 0|1 を返す
        # 浮動小数点数型の場合は値生成時に調整
        if(defined $nxt_op && $nxt_op =~ m/^(<|<=|==|!=|>=|>|&&|\|\|)$/) {
            if($res_type =~ m/signed/) {
                if(1 < $rand_min || $rand_max < 0) {
                    Carp::croak "Invalid rand_info with nxt_op: $nxt_op, $rand_min, $rand_max";
                }
                elsif(0 < $rand_min) {
                    $rand_info->{val} = 1;
                }
                elsif($rand_max < 1) {
                    $rand_info->{val} = 0;
                }
                else {
                    $rand_info->{val} = (int rand 2) ? 0 : 1;
                }

                # 除算の左オペランドは 0 以外(一応)
                if($op eq '/' && $rand_min == 0) {
                    $rand_info->{val} = 1;
                }
                else {
                    ;
                }
            }
            elsif($res_type =~ m/(float|double)$/) {
                my $orig_val = $n->{out}->{val};
                if($op =~ m/^(\+|-)$/) {
                    # 1は不可
                    $rand_info->{val} = 0;
                }
                elsif($op eq '*' && $orig_val == 0) {
                    $rand_info->{val} = (int rand 2) ? 0 : 1;
                }
                elsif($op =~ m/^(\/|&&|\|\|)$/) {
                    $rand_info->{val} = 1;
                }
                else {
                    ;
                }
            }
            else {
                Carp::croak "Invalid type: $rand_info->{type}";
            }
        }
        # 左シフト用の値を返す
        elsif(defined $nxt_op && $nxt_op eq '<<') {
            #elsif( $rand_min <= $shift_width && $shift_width <= $rand_max )
            #$shift_width = 1 << $bit;
            my $sft_res = Math::BigInt->new(1);
            my $max_bit = $type->{$max_type}->{bits}-1;
            while($bit < $max_bit || $rand_max < $sft_res) {
                $bit++;
                $sft_res <<= 1;

                #何故か無限ループになることがあるので追加
                #last if($rand_max < $sft_res || $bit < 63);
            }
            $sft_res >>= 1 if($rand_max < $sft_res);

            if($rand_min <= $sft_res && $sft_res <= $rand_max) {
                # 暫定. 左シフト可な最大の値
                $rand_min = $sft_res;
                $rand_max = $sft_res;
                if($op =~ m/^(\/|%)$/ && $sft_res == 0) {
                    $rand_min = 1;
                    $rand_max = 1;
                }
                else {
                    ;
                }
            }
            else {
                ;
            }
        }
        elsif(defined $nxt_op && $nxt_op eq '%') {
            my $min_mid = $min / 2 + 1;
            my $max_mid = int($max / 2);

            # 一応
            if($max_type ne $res_type &&
               ($rand_max < $min_mid || $max_mid < $rand_min)) {
                $res_type = $max_type;
                $rand_info->{type} = $res_type;
                ($min, $max) = $self->get_type_min_max($max_type);
                $min_mid = $min / 2 + 1;
                $max_mid = int($max / 2);
            }
            else {
                ;
            }

            if($rand_max < 0) {
                # 必ず orig_val < 0
                $rand_min = $min_mid if($rand_min < $min_mid);
                $rand_max = $min_mid if($rand_max < $min_mid);
            }
            else {
                $rand_min = $min_mid if($rand_min < $min_mid);
                $rand_max = $max_mid if($max_mid < $rand_max);
            }
        }
        elsif(defined $nxt_op && $nxt_op =~ m/^(&|\||\^|>>)$/) {
            $rand_min = 0 if($rand_min < 0);
            $rand_max = $max if($max < $rand_max);
        }
        else {
            ;
        }

        if(!defined $rand_info->{val} && $rand_min == $rand_max) {
            $rand_info->{val} = $rand_min;
        }
        else {
            $rand_info->{rand_min} = _to_big_num($res_type, $rand_min);
            $rand_info->{rand_max} = _to_big_num($res_type, $rand_max);
        }
    }

    return $rand_info;
}

# rand_info から, 値を決定
sub get_random_value {
    my ($self, $n, $rand_info, $var, $nxt_op_ref) = @_;
    my $op = $n->{otype};
    #my $res_type = $n->{out}->{type};
    my $res_type = $rand_info->{type};
    my $orig_val  = $n->{out}->{val};
    my $res = Math::BigInt->new(0);
	
	# 再利用する変数が決まっている場合
    if(defined $var) {
        $res = $var->{val};

        if($rand_info->{type} !~ m/(float|double)$/) {
            my $can_express_integer = can_express_integer($res);
            #if(defined $$nxt_op_ref && $$nxt_op_ref !~ m/^(\+|-|\*|\/)$/ &&
            if($can_express_integer == 0 && defined $$nxt_op_ref) {
                # 再利用変数が浮動小数点数型の場合, 整数型へのキャストで使用する.
                if($res < 0) {
                    $res = $res->copy()->bceil();
                }
                else {
                    $res = $res->copy()->bfloor();
                }
            }
            else {
                ;
            }
        }
        else {
            ;
        }
    }
    else {
        if(defined $rand_info->{val}) {
            $res = $rand_info->{val};
        }
        else {
            if($res_type =~ m/(float|double)$/) {
                $n->{out}->{val} = Math::BigFloat->new("$orig_val")
                    unless((ref $orig_val) eq 'Math::BigFloat');

                if($op =~ m/^(\+|-|\/|<|<=|==|!=|>=|>)$/) {
                    $res = $self->generate_float_with_precision($n, $rand_info, $$nxt_op_ref);
                }

                elsif($op =~ m/^(\*|&&|\|\|)$/) { # * は orig_val == 0 の場合のみ
                    if(defined $$nxt_op_ref &&
                       $$nxt_op_ref !~ m/^(\+|-|\*|\/)$/) {
                        $res = new_random_range(
                            $rand_info->{rand_min}, $rand_info->{rand_max}
                            );
                    }
                    else {
                        if($op eq '*') {
                            $res = $self->generate_random_float($res_type, 1);
                        }
                        else {
                            $res = $self->generate_random_float($res_type, 0);
                        }
                    }
                }
                else {
                    Carp::croak "Invalid opcode: $op, with $orig_val";
                }
=comment
                # 予約した演算子が使用できない場合, 演算子を選びなおす #不要?
                if(defined $$nxt_op_ref && $$nxt_op_ref =~ m/^(<<|>>|&|\||\^)$/ &&
                   can_express_integer($res)) {
                    $$nxt_op_ref = $self->select_opcode_with_value($res);
                }
=cut
            }
            else {
                $res = new_random_range(
                    $rand_info->{rand_min}, $rand_info->{rand_max}
                    );
            }
        }
    }

    $res = _to_big_num($res_type, $res);

    return $res;
}

# 加減算, 除算の浮動小数点数演算の生成
sub generate_float_with_precision {
    my ($self, $n, $rand_info, $nxt_op) = @_;
    my $orig_type = $n->{out}->{type};
    my $orig_val = $n->{out}->{val};
    # my $type_e_size = $type->{$orig_type}->{e_bits};

    my $op = $n->{otype};
    my $sign = '';
    my $res_e = 0;
    my $res_m = 0;

    my $orig_float_info = {};
    unless($op =~ m/^(<|<=|==|!=|>=|>)$/) {
        my $max = _max($self->{config}->get('type')->{$orig_type}->{e_max}, abs $self->{config}->get('type')->{$orig_type}->{e_min});
        my $orig_val_e = _execute_with_cache("SCALAR", \&get_exponent_of_two, abs $orig_val, $max);
        my ($orig_val_m, undef) = _execute_with_cache("ARRAY", \&get_mantissa_bin, $self, $orig_type, (abs $orig_val), $orig_val_e);
        $orig_float_info = {
            sign => ($orig_val < 0) ? '-' : '+',
            exponent => $orig_val_e,
            mantissa => $orig_val_m,
        };
    }

    if($op =~ m/^(\+|-)$/) {
        ($sign, $res_e, $res_m) = $self->generate_float_with_add_sub(
            $op, $orig_type, $orig_float_info, $rand_info, $nxt_op
            );
    }
    elsif($op eq '/') {
        ($sign, $res_e, $res_m) = $self->generate_float_with_div(
            $orig_type, $orig_float_info, $rand_info, $nxt_op
            );
    }
    elsif($op =~ m/^(<|<=|==|!=|>=|>)$/) {
        ($sign, $res_e, $res_m) = $self->generate_float_with_relation(
            $rand_info, $nxt_op
            );
    }
    else {
        Carp::croak "Invalid opcode: $op";
    }

    my $res = 0;

    if($res_e == 0 && $res_m == 0) {
        $res = Math::BigFloat->new(0);
    }
    elsif($res_e == 0 && $res_m == 1) {
        $res = Math::BigFloat->new(1);
    }
    else {
        $res = $res_m *= accurate_pow_of_two($orig_type, $res_e);
    }
    die if($res_e eq "" || $res_m eq "");


    # 符号を決定
    $res = -$res if($sign eq '-');

    return $res;
}

# 10進数の値が 2の何乗かを返す
sub get_exponent_of_two {
    my ($val, $max) = @_;
    my $e = 0;

    if($val == 0) {
        ;
    }
    else {
        $val = Math::BigFloat->new("$val") unless($val eq 'Math::BigFloat');
        my $num;

         # $val が 1 未満の値のときは, 整数の値に直す
         if ($val < 1) {
             # 倍精度浮動小数点数の小数であっても 1 以上の値になるように値を掛ける
             my $n = _execute_with_cache("SCALAR", \&_pow, 2, $max);
             my $m = ($val*$n)->bfloor();
             $num = Math::BigInt->new($m);
         }
         else {
             my $m = $val->bfloor();
             $num = Math::BigInt->new($m);
         }

         # 二分探索で桁数を求める
         my $m = Math::BigInt->new(0);
         my $high = $max+1;
         my $low = 0;
         my $mid = int(($high+$low)/2);
         $m = $num>>$mid;

         while ($m != 1) {
             if (!$m) {
                 $high = $mid-1;
             }
             else {
                 $low = $mid+1;
             }
             $mid = int(($high+$low)/2);
             $m = $num>>$mid;
         }

         # $val が 1 以上の値のときはそのままでよいが, 1 未満の値のときは正しい桁数に変換する
         if (1 <= $val) {
             $e = $mid;
         }
         else {
             $e = $mid - $max;
         }
=pod
         if ($val >= 1) {
             my $i;
             my $n = Math::BigInt->new(1);
             for ($i = 0; $n < $val; $i++) {
                 $n = $n << 1;
             }
             $e = $i - 1;
         }
         else {
             my $i;
             my $n = Math::BigFloat->new(1);
             for ($i = 0; $val <= $n; $i++) {
                 $n = $n/2;
             }
             $e = -$i;
         }
=cut
=pod
        # log(2) をとる. 小数の log は blog じゃないと NG.
        $e = $val->copy()->babs()->blog(2)->bfloor();
=cut
    }
    return $e;
}

# 10進数の小数の底が 2 の仮数部を 2進数で返す
sub get_mantissa_bin {
    my ($self, $orig_type, $val, $e) = @_;
    my $type = $self->{config}->get('type');
    my $can_express_bits = 0;

    if($val == 0) {
        $val = generate_string($type->{$orig_type}->{bits} - 1, '0');
    }
    else {
        $val = _execute_with_cache("SCALAR", \&get_mantissa_of_two, $val, $e); # ####
        #extra bit
        $val -= 1;
        # to binary
        ($val, $can_express_bits) = $self->dec2bin($orig_type, $val);
    }

    return ($val, $can_express_bits);
}

sub get_mantissa_of_two {
    my ($val, $e) = @_;
    my $num = Math::BigFloat->new(0);

    my $n = _execute_with_cache("SCALAR", \&_pow, 2, -$e);
    $num = $val * $n;

    return $num;
=pod
    my $mul_num = ($e < 0) ? 2 : 0.5;

    for my $i (1 .. (abs $e)) {
        $val *= $mul_num;
    }
    return $val;
=cut
}

# 整数の冪乗を計算する
sub _pow {
    my ($num, $e) = @_;
    my @list;
    my $n;
    my $m = Math::BigFloat->new(1);

    # 2^n(n>=0)のときはシフト演算で計算する
    if ($num == 2 && $e >= 0) {
        $m = $m << $e;
        return $m;
    } 

    if ($e < 0) {
        $n = 1/$num;
        $e = -$e;
    }
    else {
        $n = $num;
    }

    while (0 < $e) {
        push(@list, $e % 2);
        $e = int($e/2);
    }

    my $l = @list;

    for (my $i = 0; $i < $l; $i++) {
        my $f = pop(@list);
        if ($f == '1') {
            $m = $n*$m*$m;
        }
        else {
            $m = $m*$m;
        }
    }
    return $m;
}

# 加減算用の浮動小数点数を生成 (底が 2 の指数部と仮数部)
sub generate_float_with_add_sub {
    my ($self, $op, $orig_type, $orig_float_info, $rand_info, $nxt_op) = @_;

    # 整数の生成
    my $only_integer = 0;
    $only_integer = 1
        if(defined $nxt_op && $nxt_op !~ m/^(\+|-|\*|\/)$/);

    my $type = $self->{config}->get('type');
    my $e_min = $type->{$orig_type}->{e_min};
    my $e_max = $type->{$orig_type}->{e_max};
    my $res_e = 0;
    my $res_m = '';
    my $sign = '';
    my (undef, $right_zero_num) = get_both_ends_zero_num_of_bin(
        $orig_float_info->{mantissa}
        );

    # 整数のみの場合 0 を生成
    if($only_integer && $orig_float_info->{exponent} + $right_zero_num < 0) {
        ($sign, $res_e, $res_m) = generate_ieee754_zero();
    }
    else {
        my $type_m_bits = $type->{$orig_type}->{bits}-1;

        # 符号を決定
        $sign = (int rand 2) ? '-' : '+';
        # -1: 負のみ, 0: 正負, 1: 正のみ
        my $can_express_sign = 0;
        if($rand_info->{rand_max} < 0) {
            $sign = '-';
            $can_express_sign = -1;
        }
        elsif(0 < $rand_info->{rand_min}) {
            $sign = '+';
            $can_express_sign = 1;
        }
        else {
            ;
        }

        # orig_float_info->{mantissa} に 0 を含まない場合, できれば減算で in0 を求めるようにする
        if($orig_float_info->{mantissa} !~ m/0/) {
            if(($op eq '+' && $orig_float_info->{sign} eq '+') ||
                $op eq '-' && $orig_float_info->{sign} eq '-') {
                $sign = '+' if(0 <= $can_express_sign);
            }
            elsif(($op eq '+' && $orig_float_info->{sign} eq '-') ||
                  ($op eq '-' && $orig_float_info->{sign} eq '+')) {
                $sign = '-' if($can_express_sign <= 0);
            }
            else {
                ;
            }
        }

        # 指数が同じ場合などに繰り下がり発生
        if(($op eq '+' && $orig_float_info->{sign} eq $sign) ||
           ($op eq '-' && $orig_float_info->{sign} ne $sign)) {
            # 指数を決定
            my $prec_min_e = 0;
            my $prec_max_e = 0;
            $prec_min_e = $orig_float_info->{exponent} - $type_m_bits;
            $prec_max_e = $orig_float_info->{exponent} + $right_zero_num - 1;
            #print "$prec_max_e, $orig_float_info->{exponent}\n";
            #$prec_max_e = $orig_float_info->{exponent};

            # rand_info の最大・最小にあわせる
            (undef, $prec_min_e, $prec_max_e, $rand_info) = $self->suppress_exponent_with_rand_info(
                $prec_min_e, $prec_max_e, $rand_info
                );
            $prec_min_e = $e_min + 1 if($prec_min_e < $e_min + 1);
            $prec_min_e = 0 if($only_integer && $prec_min_e < 0);
            $prec_max_e = $e_max - 1 if($e_max - 1 < $prec_max_e);

            my $zero_flg = 0;
            my $can_set_bits = 0;
            my $can_shift_bits = $orig_float_info->{exponent} - $e_min;
            if(($prec_max_e == $e_min && $can_shift_bits == 0) ||
               ($orig_float_info->{exponent} - $type_m_bits < $e_min)) { # 暫定
                $zero_flg = 1;
            }
            else {
                $prec_min_e++ if($can_shift_bits == 0 && $prec_min_e == $e_min);
                $res_e = int rand ($prec_max_e - $prec_min_e + 1) + $prec_min_e;

                # 仮数部を生成
                # 仮数部の使用できる bit数
                $can_set_bits = $type_m_bits + $res_e - $orig_float_info->{exponent};
                $can_set_bits = $res_e if($only_integer && $res_e < $can_set_bits);
                $can_set_bits = $type_m_bits if($type_m_bits < $can_set_bits);
                $can_set_bits--;

=comment
# x = r-y, x = y - r で場合分けが必要
                if($orig_float_info->{exponent} <= $res_e) {
                    if($can_set_bits == 0) {
                        $zero_flg = 1
                            if(substr($orig_float_info->{exponent}, 0, $can_shift_bits) !~ m/1/);
                    }
                    else {
                        # 暫定で先頭の 1bit
                        $res_m = (substr($orig_float_info->{mantissa}, 0, 1) eq '0') ? '1' :'0';
                        $type_m_bits--;
                        $can_set_bits--;
                    }
                }
                else {
                    #### orig_の指数を減らした場合
                    ;
                }
=cut
            }

            if($zero_flg == 1) {
                ($sign, $res_e, $res_m) = generate_ieee754_zero();
            }
            else {
                $can_set_bits = 0 if($can_set_bits < 0);
                $res_m = generate_mantissa($type_m_bits, $can_set_bits);

                # 必要であれば, $rand_min_m <= $m, $m <= $rand_max_m に
                ($res_e, $res_m) = suppress_mantissa_with_rand_info(
                    $res_e, $res_m, $rand_info, $can_set_bits
                    );
                $res_m = bin2dec($orig_type, $res_m);
                $res_m += 1;
            }
        }
        elsif(($op eq '+' && $orig_float_info->{sign} ne $sign) ||
              ($op eq '-' && $orig_float_info->{sign} eq $sign)) {
            my $left_one_num = get_left_ends_one_num_of_mantissa_bin(
                $orig_float_info->{mantissa}
                );
            #$left_one_num++;

            # orig_float_info->{mantissa} の全ビットが 1 の場合, 繰り上がりが生じないよう 0
            if($orig_float_info->{mantissa} !~ m/0/ ||
               $orig_float_info->{exponent} - $left_one_num < $e_min) {
                ($sign, $res_e, $res_m) = generate_ieee754_zero();
            }
            else {
                $res_e = $orig_float_info->{exponent};
                $res_m = generate_no_carry_mantissa(
                    $type_m_bits, $orig_float_info->{mantissa}
                    );

                $res_m = bin2dec($orig_type, $res_m);
            }
        }
        else {
            ;
        }
    }

    return ($sign, $res_e, $res_m);
}

# 加算で繰り上がりが発生しない仮数部を生成
sub generate_no_carry_mantissa {
    my ($max_bits, $orig_val_m) = @_;
    my $res_m = '';

    for my $i (0 .. $max_bits-1) {
        if(substr($orig_val_m, $i, 1) eq '0') {
            # 先頭は必ず 1
            if($res_m =~ m/1/) {
                $res_m .= (int rand 2) ? '0' : '1';
            }
            else {
                $res_m .= '1';
            }
        }
        elsif(substr($orig_val_m, $i, 1) eq '1') {
            $res_m .= '0';
        }
        else {
            Carp::croak "Invalid orig_val_m: $orig_val_m";
        }
    }

    return $res_m;
}

# 除算用の浮動小数点数を生成
sub generate_float_with_div {
    my ($self, $orig_type, $orig_float_info, $rand_info, $nxt_op) = @_;
    my $only_integer = 0;
    $only_integer = 1
        if(defined $nxt_op && $nxt_op !~ m/^(\+|-|\*|\/)$/);

    my $sign = '';
    my $res_e = 0;
    my $res_m = 0;

    my $type = $self->{config}->get('type');

    # 指数部を生成
    my $e_min = $type->{$orig_type}->{e_min};
    my $e_max = $type->{$orig_type}->{e_max};
    my $prec_min_e = 0;
    my $prec_max_e = 0;

    # 指数部の和が型の指数部の型の最大最小に収まるように
    $prec_min_e = $e_min - $orig_float_info->{exponent};
    $prec_max_e = $e_max - $orig_float_info->{exponent} - 1;

    ($sign, $prec_min_e, $prec_max_e, $rand_info) = $self->suppress_exponent_with_rand_info(
        $prec_min_e, $prec_max_e, $rand_info
        );

    my $type_m_size = $type->{$orig_type}->{bits}-1;
    $prec_min_e = $type_m_size
        if($only_integer && $prec_min_e < $type_m_size);

    if($prec_max_e < $prec_min_e) {
        ($sign, $res_e, $res_m) = generate_ieee754_zero();
        $sign = (int rand 2) ? '+' : '-';
        $res_e = 0;
        $res_m = 1;
    }
    else {
        # 一応
        $prec_min_e = $e_min if($prec_min_e < $e_min);
        $prec_max_e = $e_max - 1 if($e_max - 1 < $prec_max_e);

        $res_e = int rand ($prec_max_e - $prec_min_e + 1) + $prec_min_e;

        # 仮数部を生成
        my (undef, $right_zero_num) = get_both_ends_zero_num_of_bin(
            $orig_float_info->{mantissa}
            );

        # 右端の立てられるビット数
        my $can_set_bits = $right_zero_num - 3; # ケチ表現, 繰り上がり分
        $can_set_bits = 0 if($can_set_bits < 0);
        $res_m = generate_mantissa($type_m_size, $can_set_bits);

        # 必要であれば, $rand_min_m <= $m, $m <= $rand_max_m に
        ($res_e, $res_m) = suppress_mantissa_with_rand_info(
            $res_e, $res_m, $rand_info, $can_set_bits
            );

        $res_m = bin2dec($orig_type, $res_m);
        $res_m += 1;
    }

    return ($sign, $res_e, $res_m);
}

# 関係演算子
sub generate_float_with_relation {
    my ($self, $rand_info, $nxt_op) = @_;
    my $e = 0;
    my $m = '';

    if(defined $nxt_op &&
       $nxt_op !~ m/^(\+|-|\*|\/)$/) {
        new_random_range($rand_info->{rand_min}, $rand_info->{rand_max});
    }
    else {
        my $type = $self->{config}->get('type');
        my $rand_type = $rand_info->{type};
        my $e_min = $type->{$rand_type}->{e_min};
        my $e_max = $type->{$rand_type}->{e_max};
        my $sign = '';
        ($sign, $e_min, $e_max, $rand_info) = $self->suppress_exponent_with_rand_info(
            $e_min, $e_max, $rand_info
            );
        $e = int(rand($e_max - $e_min + 1)) + $e_min;

        my $type_m_bits = $type->{$rand_type}->{bits} - 1;
        $m = generate_mantissa($type_m_bits, $type_m_bits);
        ($e, $m) = suppress_mantissa_with_rand_info(
            $e, $m, $rand_info, $type_m_bits
            );
    }

    return ($e, $m);
}

sub generate_ieee754_zero {
    my $sign = '+';
    my $e = 0;
    my $m = 0;

    return ($sign, $e, $m);
}

# 左端の 1
sub get_left_ends_one_num_of_mantissa_bin {
    my $val = shift;
    my $left_one_num  = 1;

    if($val =~ m/^(0b[01]+|[01]+)$/i) {
        if($val =~ m/^0b/i) {
            $val = substr($val, 2, ((length $val)-2));
        }
        else {
            ;
        }
    }
    else {
        Carp::croak "get_left_ends_one_num_of_mantissa_bin can receive only a binary num: $val";
    }

    for my $i (1 .. length $val) {
        if(substr($val, $i-1, 1) eq '1') {
            $left_one_num++;
        }
        else {
            last;
        }
    }

    return $left_one_num;
}

# 2進数の右端の 0 の数を調べる
sub get_both_ends_zero_num_of_bin {
    my $val = shift;
    my $left_zero_num  = 0;
    my $right_zero_num = 0;

    if($val =~ m/^(0b[01]+|[01]+)$/i) {
        if($val =~ m/^0b/i) {
            $val = substr($val, 2, ((length $val)-2));
        }
        else {
            ;
        }
    }
    else {
        Carp::croak "get_both_ends_zero_num_of_bin can receive only a binary num: $val";
    }

    for my $i (1 .. length $val) {
        if(substr($val, $i-1, 1) eq '0') {
            $left_zero_num++;
        }
        else {
            last;
        }
    }

    for(my $i = -1; $i >= -(length $val); $i--) {
        if(substr($val, $i, 1) eq '0') {
            $right_zero_num++;
        }
        else {
            last;
        }
    }

    return ($left_zero_num, $right_zero_num);
}

# 浮動小数点数を rand_info の範囲に抑える
sub suppress_exponent_with_rand_info {
    my ($self, $prec_min_e, $prec_max_e, $rand_info) = @_;
    my $sign = '';

    $rand_info = $self->_get_float_info_of_rand_info($rand_info);
    if($rand_info->{rand_max} < 0) {
        $sign = '-';
    }
    elsif($rand_info->{rand_min} < 0 && 0 <= $rand_info->{rand_max}) {
        # 負の値にできる場合
        if(($prec_min_e <= $rand_info->{neg}->{rand_min_e} &&
            $rand_info->{neg}->{rand_min_e} <= $prec_max_e) ||
           ($prec_min_e <= $rand_info->{neg}->{rand_max_e} &&
            $rand_info->{neg}->{rand_max_e} <= $prec_max_e)) {

            $sign = (int rand 2) ? '+' : '-';
        }
        else {
            $sign = '+';
        }
    }
    elsif(0 <= $rand_info->{rand_min}) {
        $sign = '+';
    }
    else {
        Carp::croak "Invalid rand_info: $rand_info->{rand_min}, $rand_info->{rand_max}";
    }

    my ($rand_min_e, $rand_max_e) = 0;
    if($sign eq '+') {
        $rand_min_e = $rand_info->{pos}->{rand_min_e};
        $rand_max_e = $rand_info->{pos}->{rand_max_e};
        $rand_info->{rand_min_m} = $rand_info->{pos}->{rand_min_m};
        $rand_info->{rand_max_m} = $rand_info->{pos}->{rand_max_m};
    }
    elsif($sign eq '-') {
        $rand_min_e = $rand_info->{neg}->{rand_min_e};
        $rand_max_e = $rand_info->{neg}->{rand_max_e};
        $rand_info->{rand_min_m} = $rand_info->{neg}->{rand_min_m};
        $rand_info->{rand_max_m} = $rand_info->{neg}->{rand_max_m};
    }
    else {
        Carp::croak "Invalid sign of float: $sign";
    }

    $rand_info->{rand_min_e} = $rand_min_e;
    $rand_info->{rand_max_e} = $rand_max_e;

    $prec_min_e = $rand_min_e if($prec_min_e < $rand_min_e);
    $prec_max_e = $rand_max_e if($rand_max_e < $prec_max_e);

    return ($sign, $prec_min_e, $prec_max_e, $rand_info);
}

# 指数部・仮数部を乱数の幅に合わせる mantissa
sub suppress_mantissa_with_rand_info {
    my ($e, $m, $rand_info, $can_set_bits) = @_;
    my $orig_m = $m;
    my $m_bit = '';
    my $rand_bit = '';

    # $rand_min_m <= $m に
    if($e == $rand_info->{rand_min_e}) {
        my $rand_min_m = $rand_info->{rand_min_m};
        $rand_min_m .= generate_string($can_set_bits - length $rand_min_m, '0')
            if(length $rand_min_m < $can_set_bits);

        for my $i (0 .. $can_set_bits-1) {
            $m_bit = substr($m, $i, 1);
            $rand_bit = substr($rand_min_m, $i, 1);

            if($rand_bit eq '0' && $m_bit eq '0') {
                substr($m, $i, 1, '1');
                last;
            }
            elsif($rand_bit eq '0' && $m_bit eq '1') {
                last;
            }
            elsif($rand_bit eq '1' && $m_bit eq '0') {
                substr($m, $i, 1, '1');
            }
            else {
                ;
            }
        }
        #$e++ if($orig_m eq $m);
    }
    # $m <= $rand_max_m に
    elsif($e == $rand_info->{rand_max_e}) {
        my $rand_max_m = $rand_info->{rand_max_m};
        $rand_max_m .= generate_string(length $m - length $rand_max_m, '0')
            if(length $rand_max_m < length $m);

        for my $i (0 .. length $m-1) {
            $m_bit = substr($m, $i, 1);
            $rand_bit = substr($rand_max_m, $i, 1);

            if($rand_bit eq '0' && $m_bit eq '1') {
                substr($m, $i, 1, '0');
            }
            elsif($rand_bit eq '1' && $m_bit eq '0') {
                last;
            }
            else {
                ;
            }
        }
    }

    return ($e, $m);
}

# 乱数の範囲に, 指数部・仮数部を抑える
sub _get_float_info_of_rand_info {
    my ($self, $rand_info) = @_;
    my $type = $self->{config}->get('type');

    my $res_type = $rand_info->{type};
    my $e_min = $type->{$res_type}->{e_min};
    my $e_max = $type->{$res_type}->{e_max};
    my $type_m_bits = $type->{$res_type}->{bits} - 1;
    my $rand_min = $rand_info->{rand_min};
    my $rand_max = $rand_info->{rand_max};

    my $max = _max($self->{config}->get('type')->{$res_type}->{e_max}, abs $self->{config}->get('type')->{$res_type}->{e_min});
    my $rand_min_e = _execute_with_cache("SCALAR", \&get_exponent_of_two, abs $rand_min, $max);
    my ($rand_min_m, undef) = _execute_with_cache("ARRAY", \&get_mantissa_bin, $self, $res_type, (abs $rand_min), $rand_min_e);
    my $rand_max_e = _execute_with_cache("SCALAR", \&get_exponent_of_two, abs $rand_max, $max);
    my ($rand_max_m, undef) = _execute_with_cache("ARRAY", \&get_mantissa_bin, $self, $res_type, (abs $rand_max), $rand_max_e);
    my $all_zero_m = generate_string($type_m_bits, '0');
    my $all_one_m  = generate_string($type_m_bits, '1');

    # rand_min, rand_max 両方負の値
    if($rand_max < 0) {
        $rand_info->{neg}->{rand_min_e} = $rand_max_e;
        $rand_info->{neg}->{rand_min_m} = $self->add_bit_binary(
            $res_type, $rand_max_m, 1
            );
        if($rand_max_m eq $rand_info->{neg}->{rand_min_m}) {
            $rand_info->{neg}->{rand_min_e}++;
            $rand_info->{neg}->{rand_min_m} = $all_one_m;
        }
        else {
            ;
        }

        $rand_info->{neg}->{rand_max_e} = $rand_min_e;
        $rand_info->{neg}->{rand_max_m} = $self->add_bit_binary(
            $res_type, $rand_min_m, -1
            );
        if($rand_min_m eq $rand_info->{neg}->{rand_max_m}) {
            $rand_info->{neg}->{rand_max_e}--;
            $rand_info->{neg}->{rand_max_m} = $all_zero_m;
        }
        else {
            ;
        }
    }
    elsif($rand_min < 0 && 0 <= $rand_max) {
        # 負の値, 最小値
        $rand_info->{neg}->{rand_min_e} = $e_min;
        $rand_info->{neg}->{rand_min_m} = $all_zero_m;

        # 最大値
        $rand_info->{neg}->{rand_max_e} = $rand_min_e;
        $rand_info->{neg}->{rand_max_m} =  $self->add_bit_binary(
            $res_type, $rand_min_m, 1
            );
        if($rand_min_m eq $rand_info->{neg}->{rand_max_m}) {
            $rand_info->{neg}->{rand_max_e}++;
            $rand_info->{neg}->{rand_max_m} = $all_one_m;
        }
        else {
            ;
        }

        # 正の値, 最小値
        $rand_info->{pos}->{rand_min_e} = $e_min;
        $rand_info->{pos}->{rand_min_m} = $all_zero_m;
        # 最大値
        $rand_info->{pos}->{rand_max_e} = $rand_max_e;
        $rand_info->{pos}->{rand_max_m} = $self->add_bit_binary(
            $res_type, $rand_max_m, -1
            );
        if($rand_max_m eq $rand_info->{pos}->{rand_max_m}) {
            $rand_info->{pos}->{rand_max_e}--;
            $rand_info->{pos}->{rand_max_m} = $all_zero_m;
        }
        else {
            ;
        }
    }
    elsif(0 <= $rand_min) {
        $rand_info->{pos}->{rand_min_e} = $rand_min_e;
        $rand_info->{pos}->{rand_min_m} = $self->add_bit_binary(
            $res_type, $rand_min_m, 1
            );
        if($rand_min_m eq $rand_info->{pos}->{rand_min_m}) {
            $rand_info->{pos}->{rand_min_e}++;
            $rand_info->{pos}->{rand_min_m} = $all_zero_m;
        }
        else {
            ;
        }

        $rand_info->{pos}->{rand_max_e} = $rand_max_e;
        $rand_info->{pos}->{rand_max_m} = $self->add_bit_binary(
            $res_type, $rand_max_m, -1
            );
        if($rand_max_m eq $rand_info->{pos}->{rand_max_m}) {
            $rand_info->{pos}->{rand_max_e}--;
            $rand_info->{pos}->{rand_max_m} = $all_one_m;
        }
        else {
            ;
        }
    }
    else {
        Carp::croak "Invalid rand_info: $rand_info->{rand_min}, $rand_info->{rand_max}";
    }

    return $rand_info;
}

# 引数の文字で文字列を生成
sub generate_string {
    my ($l, $c) = @_;
    my $str = '';

    for(1 .. $l) {
        $str = "$c$str";
    }

    return $str;
}

# 2進数に +/- 1bit する
sub add_bit_binary {
    my ($self, $bin_type, $bin, $add_bit) = @_;
    my $type = $self->{config}->get('type');
    my $bits = $type->{$bin_type}->{bits};
    $bits-- if($bin_type =~ m/(float|double)$/);

    if($bin =~ m/^(0b[01]+|[01]+)$/i) {
        if($bin =~ m/^0b/i) {
            $bin = substr($bin, 2, ((length $bin)-2));
        }
        else {
            ;
        }
    }
    else {
        Carp::croak "add_bit_binary can receive only a binary num: $bin";
    }

    for(my $i = -1; $i >= -$bits; $i--) {
        if(substr($bin, $i) eq '1') {
            if($add_bit == -1){
                substr($bin, $i, 1, '0');
            }
            elsif($add_bit == 1) {
                if($i != -1) {
                    substr($bin, $i+1, 1, '1');
                }
                else {
                    ;
                }
            }
            else {
                Carp::croak "add_bit_binary can add 1 or -1 : $add_bit";
            }

            last;
        }
        else {
            ;
        }
    }

    return $bin;
}

# 仮数部を 2進数で生成
sub generate_mantissa {
    my ($type_m_size, $can_set_bits) = @_;
    my $m = _generate_random_binary($can_set_bits);

    $m .= generate_string($type_m_size-$can_set_bits, '0');

    return $m;
}

# 浮動小数点数型の指数部の最大・最小値を 10進数で返す
sub get_min_max_exponent_of_ten {
    my ($self, $float_type) = @_;
    my $type = $self->{config}->get('type');
    my $p_min = Math::BigFloat->new("$type->{$float_type}->{p_min}");
    my $p_max = Math::BigFloat->new("$type->{$float_type}->{p_max}");

    return ($p_min->exponent(), $p_max->exponent());
}

# 引数の型より小さく, 引数の値を表現できる型を選ぶ.
sub select_type {
    my ($self, $op, $max_type, $val, $prec_flg) = @_;
    my @typelist = ();

    # 値が溢れず, かつ元の型を超えない型のリストをつくる.
    @typelist = _execute_with_cache("ARRAY", \&_make_available_type_list, $self, $op, $max_type, $val, 1);

    return $typelist [rand @typelist];
}

# 使用可能な型のリストをつくる.
# floatは型の最大最小に含まれれば
sub _make_available_type_list {
	# prec_flag ... 精度を考慮するフラグ
    my ($self, $op, $max_type, $val, $prec_flg) = @_;
    my @typelist = ();
    my $type = $self->{config}->get('type');
    my $val_e = 0;
    my $val_m = 0;
    my $can_express_bits = 0;

    # 浮動小数点型の場合は, 整数で表せるかどうかチェック
    my $can_use_integer = 1;
    if($max_type =~ m/(float|double)$/) {
        $val = Math::BigFloat->new("$val") if((ref $val) ne 'Math::BigFloat');
        $can_use_integer = can_express_integer($val);
		
		# 2のべき乗で表した時の指数を返す(val = ● x 2 ^ x ... x を返す)
        my $max = _max($self->{config}->get('type')->{$max_type}->{e_max}, abs $self->{config}->get('type')->{$max_type}->{e_min});
        $val_e = _execute_with_cache("SCALAR", \&get_exponent_of_two, abs $val, $max);
        
        # 仮数部を2進数で返す
        ($val_m, $can_express_bits) = _execute_with_cache("ARRAY", \&get_mantissa_bin, $self, $max_type, (abs $val), $val_e);

		# 2進数で表現した仮数部で精度が足りていないときは, 末尾が 0 か判定
        for(1 .. length $val_m) {
            if(substr($val_m, -1) eq '0') {
                chop($val_m);
            }
            else {
                last;
            }
        }
    }
    else {
        ;
    }
    # どの型を選択した場合汎整数拡張が起こるか判定
    my ($lower_type, $upper_type) = $self->judge_integral_promotion();

    # 使用可能な型の配列を作成
    my ($min, $max) = 0;
    for my $i (@{$self->{config}->get('types')}) {
        ($min, $max) = $self->get_type_min_max($i);

        if($type->{$i}->{order} <= $type->{$max_type}->{order}) {
            if($max_type !~ m/(float|double)$/ && $i =~ m/signed/ && $can_use_integer) {
                if($i =~ m/^signed/) {
                    push @typelist, $i if($min <= $val && $val <= $max);
                }
                elsif($i =~ m/^unsigned/) {
                    # 汎整数拡張が発生する型は選択しない.
                    if($op =~ m/^(\+|-|\*|\/|%|&|\||\^)$/ && $max_type eq $upper_type &&
                       ($i eq $lower_type ||
                        ($lower_type eq 'unsigned char' && $i eq 'unsigned short'))) {
                        ;
                    }
                    else {
	                    push @typelist, $i if($min <= $val && $val <= $max);
                    }
                }
                else {
                    Carp::croak "Wrong types: $i";
                }
            }
            elsif($i =~ m/(float|double)$/ && $op !~ m/^(%|<<|>>|&|\||\^)$/) {
                # 型の最小・最大値だけで, 使用できる型を選択
                if($prec_flg == 0) {
                    if($min <= $val && $val <= $max) {
                        push @typelist, $i;
                    }
                    else {
                        Carp::croak "Wrong type: $i";
                    }
                }
                else { # 精度を考慮して, 使用できる型を選択
                    my $type_max = Math::BigFloat->new("$type->{$i}->{p_max}");
                    my $type_max_e = $type->{$i}->{e_max};
                    #my $type_min_e = -($type_max_e - 1);
                    my $type_min_e = $type->{$i}->{e_min};
                    my $type_max_m_bits = $type->{$i}->{bits} - 1;

                    push @typelist, $i
                        if(($type_min_e <= $val_e && $val_e <= $type_max_e) &&
                           (length $val_m <= $type_max_m_bits));

                }
            }
            else {
                ;
            }
        }
        else {
            last;
        }
    }

    Carp::croak "Can not select type with $op, $val, max type is $max_type"
        unless(@typelist);

    return @typelist;
}

# 浮動小数点数の場合, 整数で表現できる値かどうかチェック
sub can_express_integer {
    my $val = shift;
    my $res = 0;
    my $str = "$val";

    if($str =~ m/\d\.\d/) {
        ;
    }
    else {
        $res = 1;
    }

    return $res;
}

# 演算子ノードの {in} に型や値などを入れる
sub set_opnodein {
    my ($self, $n, $vars_sorted_by_value) = @_;
    my $op = $n->{otype};

    # 型, print_value をセット. 型は導出前の変数の型
    for my $i (0 .. 1) {
        $n->{in}->[$i]->{type} = $n->{out}->{type};
        $n->{in}->[$i]->{val}  = $n->{out}->{val};
        $n->{in}->[$i]->{print_value} = 0
            unless(defined $n->{in}->[$i]->{print_value});
    }

    # 演算子ノードの in の値・演算子を決める. in0 = {val, nxt_op};
    $self->make_opnodein($n, $vars_sorted_by_value);

    # オペランドの値が左右入れ替わってもよい演算は入れ替え
    my $rand = int rand 9;
    if($op =~ m/^(\+|\*|==|!=|&|\||\^|&&|\|\|)$/) {
        # 左 6/9 の確率 5 -> 6
        if($rand < 6) {
            ;
        }
        else { # 右 3/9 4 -> 3
            swap_opnodein($n);
        }
    }
    else {
        ;
    }
}

# オペランドを opノードに繋げる
sub set_operand {
    my ($self, $n) = @_;

    # オペランドの変数ノードを作成
    my ($left, $right) = $self->make_operand($n);

    # 演算子ノードに変数ノードをつなぐ.
    $n->{in}->[0]->{ref} = $left;
    $n->{in}->[1]->{ref} = $right;
}

# オペランドの変数ノードを生成
sub make_operand {
    my ($self, $n) = @_;
    my $op = $n->{otype};

    # 演算子ノードのオペランドの型を決める
    my ($l_type, $r_type) = $self->define_operand_type($n);

    my $left  = $self->make_new_varnode($n->{in}->[0], $l_type, $op);
    my $right = $self->make_new_varnode($n->{in}->[1], $r_type, $op);

    for my $i (@{$n->{in}}) {
        delete $i->{multi_ref_var};
        delete $i->{nxt_op};
    }

    return ($left, $right);
}

# オペランドの型を選択. 汎整数拡張を考慮.
sub define_operand_type {
    my ($self, $n) = @_;
    my $op = $n->{otype};
    my $orig_type = $n->{out}->{type};
    my $in0_val = $n->{in}->[0]->{val};
    my $in1_val = $n->{in}->[1]->{val};
    my $l_type = '';
    my $r_type = '';
    my $max_type = $self->get_max_inttype('unsigned');

    # 型変換を考慮
    if($op =~ m/^(\+|-|\*|\/|%|&|\||\^)$/) {
        ($l_type, $r_type) = $self->define_types4arithmetic_type_convertion($n);
    }
    elsif($op =~ m/^(>>|<<)$/) {
        $l_type = $orig_type;
        $r_type = $self->select_type($op, $max_type, $in1_val, 0);
    }
    elsif($op =~ m/^(>|>=|==|!=|<|<=|&&|\|\|)$/) {
        $l_type = $self->select_type($op, $max_type, $in0_val, 1);
        $r_type = $self->select_type($op, $max_type, $in1_val, 1);
    }
    else {
        Carp::croak "Invalid opcode: $op";
    }

    return ($l_type, $r_type);
}

# 通常の型変換を利用
sub define_types4arithmetic_type_convertion {
    my ($self, $n) = @_;
    my $op = $n->{otype};
    my $orig_type = $n->{out}->{type};
    my $in0_val = $n->{in}->[0]->{val};
    my $in1_val = $n->{in}->[1]->{val};
    my $l_type = '';
    my $r_type = '';

    # もし汎整数拡張を利用できるならば利用
    ($l_type, $r_type) = $self->use_integral_promotion($n)
        if($orig_type eq 'unsigned long'); ###############################

    # 通常の算術型変換
    if($l_type eq '' || $r_type eq '') {
        if(int rand 2) {
            $l_type = $self->select_type($op, $orig_type, $in0_val, 1);
            $r_type = $orig_type;
        }
        else {
            $l_type = $orig_type;
            $r_type = $self->select_type($op, $orig_type, $in1_val, 1);
        }
    }
    else {
        ;
    }

    return ($l_type, $r_type);
}

# 汎整数拡張を利用して型変換 (ulong = slong + uint)
# 利用できない場合は, 引数の値を変更せず返す
sub use_integral_promotion {
    my ($self, $n) = @_;
    my $orig_type = $n->{out}->{type};
    my $orig_val = $n->{out}->{val};
    my $type = $self->{config}->get('type');
    my $l_type = '';
    my $r_type = '';

    my ($lower_type, $upper_type) = $self->judge_integral_promotion();

    # 汎整数拡張を利用するかどうか判断
    if($type->{$lower_type}->{bits} == $type->{$upper_type}->{bits} &&
       int rand 2) {
       #$type->{$upper_type}->{max} < $orig_val && int rand 2) {
        my $in0_val = $n->{in}->[0]->{val};
        my $in1_val = $n->{in}->[1]->{val};
        my $utype_min = $type->{$upper_type}->{min};
        my $utype_max = $type->{$upper_type}->{max};

        # 左オペランドのみ upper_type を使える場合
        if(($utype_min <= $in0_val && $in0_val <= $utype_max) &&
           ($utype_max <  $in1_val)) {
            $l_type = $upper_type;
            $r_type = $lower_type;
        }
        # 右オペランドのみ upper_type 可
        elsif(($utype_max <  $in0_val) &&
              ($utype_min <= $in1_val && $in1_val <= $utype_max)) {
            $l_type = $lower_type;
            $r_type = $upper_type;
        }
        # 両オペランドで upper_type 可
        elsif(($utype_min <= $in0_val && $in0_val <= $utype_max) &&
              ($utype_min <= $in1_val && $in1_val <= $utype_max)) {
            if(int rand 2) {
                $l_type = $upper_type;
                $r_type = $lower_type;
            }
            else {
                $l_type = $lower_type;
                $r_type = $upper_type;
            }
        }
        # 両オペランドで upper_type 不可
        else {
            ;
        }
    }
    else {
        ;
    }

    return ($l_type, $r_type);
}

# 新しい変数ノードを生成.
sub make_new_varnode {
    my ($self, $in, $type, $op) = @_;
    my $val = $in->{val};

    $val = _to_big_num($type, $val)
        unless((ref $val) =~ m/^Math::Big/);

    # 新規に変数をつくる
    my $var = $in->{multi_ref_var};
    if(defined $in->{multi_ref_var}) {
        ;
    }
    else {
        my $config = $self->{config};

        # ラップアラウンドを起こす値の生成
        if($type =~ m/^unsigned/) {
            my $max = $config->get('type')->{$type}->{max};
            $val %= $max + 1;
        }
        else {
            ;
        }

        $var = {
            name_type => 'x',
            name_num  => scalar(@{$self->{vars}}),
            type      => $type,
            ival      => $val,
            val       => $val,
            class     => $config->get('classes')->[rand @{$config->get('classes')}],
            modifier  => $config->get('modifiers')->[rand @{$config->get('modifiers')}],
            scope     => $config->get('scopes')->[rand @{$config->get('scopes')}],
			used      => 1,
        };

        push @{$self->{vars}}, $var;
		push @{$self->{vars_on_path}}, $var;
    }

    # 変数ノードの形に整える
    my $varnode = {
        ntype => 'var',
        var => $var,
        out => { type => $var->{type}, val => $var->{val} },
        nxt_op => $in->{nxt_op},
    };

    # 変数の再利用時, 型が合わなければ必要に応じてキャストを挿入
    $varnode = $self->adapt_type_of_multi_ref_var($varnode, $type, $op)
        if(defined $in->{multi_ref_var});

    return $varnode;
}

# 選んだ変数の型が合わなければ, 必要に応じてキャストを挿入
sub adapt_type_of_multi_ref_var {
    my ($self, $vn, $type, $op) = @_;
    my $tmp = $vn->{var}->{val};

=comment
    # 将来的に
    if($op =~ m/^(<|<=|==|!=|>=|>|&&|\|\|)$/) {
        ;
    }
    else {
=cut
        if($vn->{var}->{type} eq $type) {
            ;
        }
        else {
            insert_cast4derive($vn, $vn->{var}->{type}, $type);
        }
#    }

    return $vn;
}

# 値でソートした変数の配列を更新
sub update_sorted_vars {
    my ($self, $vars_sorted_by_value, $added_vars_num) = @_;

    my $idx = 0;
    my $add_var = 0;
    for(my $i=0; $i < $added_vars_num; $i++) {
        $add_var = $self->{vars}->[$#{$self->{vars}} - $i];

        if($add_var->{name_type} eq 'x') {
            # 追加する index を探索
            $idx = bin_search($add_var->{val}, $vars_sorted_by_value->{x}, 1);
            # 要素の追加
            splice(@{$vars_sorted_by_value->{x}}, $idx, 0, $add_var);
        }
        elsif($add_var->{name_type} eq 't') {
            $idx = bin_search($add_var->{val}, $vars_sorted_by_value->{t}, 1);
            splice(@{$vars_sorted_by_value->{t}}, $idx, 0, $add_var);
        }
        else {
            Carp::croak "Invalid var: $add_var->{name_type}$add_var->{name_num}";
        }
    }
}

# 変数ノードの値を二分探索
# insert_flg == 1 で, かつ一致する値がなければ, 値が最も近く引数より小さい値の index を返す
# insert_flg == 0 で, かつ一致する値がなければ, -1 を返す
sub bin_search {
    my ($val, $array, $insert_flg) = @_;

    my $head = 0;
    my $tail = scalar @$array;
    my $idx = 0;

    while($head < $tail) {
        $idx = int( ($head+$tail)/2 );

        if((ref $val) eq 'Math::BigFloat') {
            if($val < $array->[$idx]->{val})     { $tail = $idx; }
            elsif($val == $array->[$idx]->{val}) { return  $idx; }
            else                                 { $head = $idx+1; }
        }
        else {
            if($array->[$idx]->{val} > $val)     { $tail = $idx; }
            elsif($array->[$idx]->{val} == $val) { return  $idx; }
            else                                 { $head = $idx+1; }
        }
    }

    if($insert_flg == 1) { return $head; }
    else                 { return -1; }
}

# 整数拡張が起こるかどうかチェック
sub judge_integral_promotion {
    my $self = shift;
    my $type = $self->{config}->get('type');
    my $sint_bits = $type->{'signed int'}->{bits};

    my $lower_type = '';
    my $upper_type = '';

    if($type->{'unsigned char'}->{bits} == $sint_bits) {
        $lower_type = 'unsigned char';
        $upper_type = 'signed int';
    }
    elsif($type->{'unsigned short'}->{bits} == $sint_bits) {
        $lower_type = 'unsigned short';
        $upper_type = 'signed int';
    }
    elsif($type->{'unsigned int'}->{bits} == $type->{'signed long'}->{bits}) {
        $lower_type = 'unsigned int';
        $upper_type = 'signed long';
    }
    elsif($type->{'unsigned long'}->{bits} == $type->{'signed long long'}->{bits}) {
        $lower_type = 'unsigned long';
        $upper_type = 'signed long long';
    }
    else {
        ;
    }

    return ($lower_type, $upper_type);
}

sub get_max_inttype{
    my ($self, $ts) = @_;
    my $type = '';

    for(reverse @{$self->{config}->get('types')}) {
        if($_ =~ m/^$ts/) {
            $type = $_;
            last;
        }
        else {
            ;
        }
    }

    return $type;
}

# temp
# 既存の random_range がラップアラウンドを考慮し,
# 渡した範囲を超えた値を返すことがあるため.
sub new_random_range
{
    my ($rand_min, $rand_max) = @_;

    my $rand_val = Math::BigFloat->new(1);
    $rand_val += $rand_max - $rand_min;
    $rand_val *= rand();

    if(0 < $rand_val) {
        $rand_val = $rand_val->bfloor();
    }
    else {
        $rand_val = $rand_val->bceil();
    }
    $rand_val += $rand_min;

    unless($rand_min <= $rand_val && $rand_val <= $rand_max ) {
        Carp::croak "rand_min < ans < rand_max: $rand_min < $rand_val < $rand_max";
    }

    return $rand_val;
}

sub _max
{
    my ($a, $b) = @_;

    if ($a > $b) {
        return $a;
    }
    else {
        return $b;
    }
}

# キャッシュを取り実行する. 計算済みの引数の組が渡された時, キャッシュから値を返す.
my %_cache;
my $count = 0;
sub _execute_with_cache {
    my ($type, $sub, @a) = @_;

    if ($count == 0) {
        %_cache = ();
    }

    if (! defined $_cache{$sub, @a}) {
        $count = ($count+1) % CACHE_CHECK_CYCLE;
        if ($type eq "ARRAY") {
            my @b = &$sub(@a);
            $_cache{$sub, @a} = \@b;
        }
        else {
            $_cache{$sub, @a} = &$sub(@a);
        }
    }

    if ($type eq "ARRAY") {
        return @{$_cache{$sub, @a}};
    }
    else {
        return $_cache{$sub, @a};
    }
}

1;
