package Orange4::Generator;

use strict;
use warnings;

use Carp ();
use Math::BigInt lib => 'GMP';

use Orange4::Dumper;
use Orange4::Log;
use Orange4::Generator::Derive;
use Smart::Comments;

use Data::Dumper;
use Clone qw(clone);
use Storable qw/dclone/;

sub new {
    my ( $class, %args ) = @_;

    my $vars  = $args{vars}  || [];
    my $statements = $args{statements} || [];
    my $unionstructs = $args{unionstructs} || [];
    my $replace_vars = $args{replace_vars} || {};
    my $func_vars = $args{func_vars} || [];
    my $func_list = $args{func_list} || [];

     bless {
        root         => {}, # unnecessary ?
        statements   => $statements,
        replace_vars => $replace_vars, # 最小化で使用する代理変数
        undef_seeds  => [],
        vars         => $vars,
        vars_on_path => {
                          x                => [],
                          t                => [],
                          func_return_vars => [],
                        },
        func_list      => $func_list,
        func_vars      => $func_vars,
        called         => [], # 現在生成中の関数内ですでに呼んだ関数群
        x_arrays       => {},
        t_arrays       => {},
        unionstructs   => $unionstructs,
        x_structs      => undef,
        t_structs      => undef,
        struct_vars     => {
          x => {},
          t => {},
        },
        called_struct_args => [],
        avoide_undef   => 2,
        %args
    }, $class;
}

sub run {
    my $self = shift;

    $self->_init();
    $self->generate_unionstructs($self->{config});
    $self->generate_main_vars();
    $self->generate_funcs() if $self->{func_root_max} > 0;

    my $statements = $self->generate_statements(1, $self->{root_max}, 1, -1);

    if( ref($statements) eq 'ARRAY' ) {
        push @{$self->{statements}}, @$statements;
    }
    else {
        push @{$self->{statements}}, $statements;
    }

    $self->reset_references();

    unless ( $self->{config}->get('debug_mode') ) {
        local $| = 1;
        print "seed : $self->{seed}\t                                     ";
        print "\r";
        local $| = 0;
        print "seed : $self->{seed}\t";
    }

    for my $func (@{$self->{func_list}}){
        my $func_depth = $func->{depth};
        if( $func_depth > $self->{config}->get('max_depth') ){
            Carp::croak("over max depth");
        }
    }

}

sub generate_main_vars {
  my $self = shift;

  $self->generate_x_vars();
  $self->generate_arrays('', $self->{vars}, $self->{x_arrays}, $self->{t_arrays});
  $self->generate_unionstruct_vars($self->{config}, '', $self->{vars}, $self->{x_structs}, $self->{t_structs}, $self->{struct_vars});

}

sub generate_funcs {
    my $self = shift;

    my $max_funcs_num = $self->{config}->get('max_funcs_num');
    while( $self->{func_root_max} > 0 ){
        $self->{depth} = 1;
        $self->{called_funcs} = [];
        $self->{called} = [];

        my $rest_of_roots = int( rand($self->{func_root_max}) )+1;

        my $func_st = $self->generate_func_statement(1, 1, $rest_of_roots);
        $func_st->{depth} = $self->{depth};
        push(@{$self->{func_list}}, $func_st);

        if( $func_st->{type} ne 'void' ){
            push @{$self->{vars_on_path}->{func_return_vars}}, $func_st->{return_var};
        }

        my $st->{called} = $self->{called};

        for my $func ( @{$self->{func_list}} ){
            $func->{called_flag} = 0;
        }
        $self->{called} = [];

        $self->{func_root_max} -= $rest_of_roots;
    }
}

sub _init {
    my $self = shift;

    $self->{expression_size} = _get_expression_size( $self->{config} );
    $self->{tarray_expression_size} = int($self->{expression_size} * $self->{config}->get('tarray_expression_size') );
    $self->_get_root_size();

    my $root_max = $self->{root_max};
    $self->{func_root_max} = $self->{config}->get('func_generate_flag') ? int rand $self->{root_max} : 0;
    $self->{root_max} -= $self->{func_root_max};

    $self->_get_var_size();
    $self->_get_array_size();
    $self->{tvar_count} = 0;
    $self->{func_count} = -1;
    $self->{called_funcs} = [];
    $self->{pushed} = {};

}

sub _get_expression_size {
    my $config = shift;

    my $e_size_num = $config->get('e_size_num');
    my $e_size_param = rand( ( log($e_size_num) / log(2) ) );

    return int( ( 2**$e_size_param ) );
}

sub _get_root_size {
    my $self = shift;

    $self->{root_max} = int( $self->{config}->get('e_size_num') / $self->{expression_size} ) ;
}

sub _get_var_size {
    my $self = shift;

    unless($self->{derive}) {
        my $var_num_min = $self->{expression_size} + 1;
        my $var_num_max = $self->{root_max} * 3;

        if ($var_num_min < $var_num_max) { # ??
            ( $var_num_min, $var_num_max ) = ( $var_num_max, $var_num_min )
        }
        $self->{var_max} = int(($var_num_max - $var_num_min + 1) * rand() + $var_num_min);
    }
    else {
        $self->{var_max} = $self->{root_max} - 1;
    }
}

sub _get_array_size {
  my $self = shift;

  $self->{array_dim_max} = $self->{config}->get('array_dim_max');
  $self->{array_element_max} = $self->{config}->get('array_element_max');
  $self->{t_array_max} = $self->{config}->get('t_array_max');
}

sub generate_x_vars {
    my $self = shift;

    my $derive = Orange4::Generator::Derive->new(
        config => $self->{config},
    );

    for my $number ( 0 .. $self->{var_max} ) {
        my $var = $self->_generate_x_var($number);

        if ( $var->{type} =~ m/(float|double)$/ ) {
            $var->{ival} = $derive->generate_random_float($var->{type}, 1);
        }
        else {
            $var->{scope} = 'LOCAL';
            $var->{ival} = $self->define_value( $var->{type} );
        }
        $var->{val}  = $var->{ival};
        push @{ $self->{vars} }, $var;
        push @{ $self->{vars_on_path}->{x} }, $var;
        unless ( $self->{config}->get('debug_mode') ) { #unless or if??
            if ( $number % 100 == 0 ) {
                local $| = 1;
                print "seed : $self->{seed}\t";
                print "generate var now.. ($number/$self->{var_max})                             ";
                print "\r";
                local $| = 0;
            }
        }
    }
    @{$self->{vars_on_path}->{x}} = sort {$a->{val} <=> $b->{val}} @{$self->{vars_on_path}->{x}};
    $self->{xvar_count} = scalar(@{$self->{vars}});
}

sub generate_x_vars_in_func {
    my ( $self, $var_max, $func_name_num ) = @_;
    my $local_vars = [];
    my $derive = Orange4::Generator::Derive->new(
        config => $self->{config}
        );

    for my $number ( $self->{xvar_count} .. $self->{xvar_count} + $var_max ){
        my $var = $self->_generate_x_var( $self->{xvar_count} );
        $self->{xvar_count}++;

        if ( $var->{type} =~ m/(float|double)$/ ) {
            $var->{ival} = $derive->generate_random_float($var->{type}, 1);
        }
        else {
            $var->{scope} = 'LOCAL';
            $var->{ival} = $self->define_value( $var->{type} );
        }
        $var->{val} = $var->{ival};
        push @{ $local_vars }, $var;

        unless ( $self->{config}->get('debug_mode') ) { #unless or if??
            if ( $number % 100 == 0 ) {
                my $total = $var_max + $self->{xvar_count};
                local $| = 1;
                print "seed : $self->{seed}\t";
                print "generate var in func$func_name_num now.. ($number/$total)                 ";
                print "\r";
                local $| = 0;
            }
        }
    }
    @{$local_vars} = sort {$a->{val} <=> $b->{val}} @{$local_vars};
    return $local_vars;
}

sub _generate_x_var {
    my ( $self, $number ) = @_;

    my $config = $self->{config};

    return +{
        name_type => 'x',
        name_num  => $number,
        type      => random_select( $config->get('types') ),
        ival      => undef,
        val       => undef,
        elements  => undef,
        class     => random_select( $config->get('classes') ),
        modifier  => random_select( $config->get('modifiers') ),
        scope     => random_select( $config->get('scopes') ),
        used      => 1,
        replace_flag => 0,
        used_count => undef,
    };
}

sub _generate_a_var {
    my ( $self, $number, $type ) = @_;

    my $config = $self->{config};

    return +{
        name_type => 'a',
        name_num  => $number,
        type      => $type,
        ival      => $self->define_value($type),
        val       => $self->define_value($type),
        class     => random_select( $config->get('classes') ),
        modifier  => random_select( $config->get('modifiers') ),
        scope     => 'LOCAL',
        print_arg => 1,
        replace_flag => 0,
        used      => 1,
    };
}

# 構造体変数の生成
sub generate_unionstruct_vars {
  my ($self, $config, $scope, $vars, $x_structs, $t_structs, $struct_vars) = @_;
  if (scalar @{$self->{unionstructs}} > 0){
    my $x_union_struct_var_num = int rand($config->get('x_union_struct_var_max'));
    for my $i (0..$x_union_struct_var_num) {
      my $number = $self->{xvar_count};
      my $struct_var = $self->generate_unionstruct_var($config, $number, 'x', $scope, $struct_vars);
      push @{ $vars }, $struct_var;
      push @{ $x_structs }, $struct_var;
      $self->{xvar_count}++;
    }
    my $t_union_struct_var_num = int rand($config->get('t_union_struct_var_max'));
    for my $i (0..$t_union_struct_var_num) {
      my $number = $self->{tvar_count};
      my $struct_var = $self->generate_unionstruct_var($config, $number, 't', $scope, $struct_vars);
      push @{ $vars }, $struct_var;
      push @{ $t_structs }, $struct_var;
      $self->{tvar_count}++;
    }
  }
}

sub generate_unionstruct_var {
  my ($self, $config, $number, $name_type, $scope, $struct_vars) = @_;
    my $ival = [];
    my $elements = undef;
    my $used_count = undef;

    # 先に生成した構造体の中からランダムに選択
    my $type = $self->{unionstructs}->[rand @{$self->{unionstructs}}];

    # 確率で配列に 構造体変数の要素数がすごいことになるのでコメントアウト
    # my $rand = int(rand(10)) + 1;
    # if ($rand <= $config->get('prob_array')) {
    #   ($elements, $used_count) = $self->define_element_num();
    # }

    my $struct_var = {
      name_type => $name_type,
      name_num  => $number,
      type      => $type,
      ival      => undef,
      val       => undef,
      class     => '',
      modifier  => random_select(
          [ 'volatile', 'volatile', '', '', '', '', '', '', '', '', '', '', '' ]
      ),
      scope     => $scope eq '' ? random_select( $config->get('scopes') ) : $scope,
      elements  => $elements,
      used_count => $used_count,
      replace_flag => 0,
      used      => 1,
    };

    #初期値の決定
    my $memname = [];
    $ival = $self->define_unionstruct_var_vals($type, $elements, $memname, $struct_var, $struct_vars);
    $struct_var->{ival} = $struct_var->{val} = $ival;

    return $struct_var;
}

#構造体（型枠）の生成
sub generate_unionstructs {
  my ($self, $config) = @_;

  my $struct_num = int (rand($config->get('max_structs')));
  my $union_num = int (rand($config->get('max_unions')));
  my $struct;
  if ($struct_num > 0) {
    for my $i (0..$struct_num) {
      $struct = $self->generate_unionstruct($i, 's');
      $struct_num++;
      push @{ $self->{unionstructs} }, $struct;
    }
  }
  if ($union_num > 0) {
    for my $i (0..$union_num) {
      $struct = $self->generate_unionstruct($i, 'u');
      $union_num++;
      push @{ $self->{unionstructs} }, $struct;
    }
  }
}

#引数の構造体共用体が配列かどうかによって処理が違う
sub define_unionstruct_var_vals {
  my ($self, $type, $elements, $memname, $struct_var, $struct_vars) = @_;
    my $val = [];

    #構造体共用体が配列なら配列要素ごとに構造体共用体の要素を決定
    if (defined $elements) {
      $val = $self->define_unionstruct_array_val($type, $elements, 0, $memname, $struct_var, $struct_vars);
    }
    else {
      $val = $self->define_unionstruct_mem_val($type, $memname, $struct_var, $struct_vars);
    }
    return $val;
}

#配列要素ごとに構造体共用体の要素を決定
sub define_unionstruct_array_val {
  my ($self, $type, $elements, $ele_num, $memname, $struct_var, $struct_vars) = @_;
  my $val = [];

  if (defined $elements->[$ele_num + 1]) {
    for my $i (1..$elements->[$ele_num]) {
      my $name = $i - 1;
      my $memname_clone = clone($memname);
      push @$memname_clone, $name;
      my $v = $self->define_unionstruct_array_val($type, $elements, $ele_num + 1, $memname_clone, $struct_var, $struct_vars);
      push @$val, $v;
    }
    return $val;
  }
  else {
    for my $i (1..$elements->[$ele_num]) {
      my $name = $i - 1;
      my $memname_clone = clone($memname);
      push @$memname_clone, $name;
      my $v = $self->define_unionstruct_mem_val($type, $memname_clone, $struct_var, $struct_vars);
      push @$val, $v;
    }
    return $val;
  }
}

#構造体共用体のメンバー変数の決定
sub define_unionstruct_mem_val {
  my ($self, $type, $memname, $struct_var, $struct_vars) = @_;
  my $val = [];

  for my $mem (@{$type->{member}}) {
    my $name = $mem->{name_type} . $mem->{name_num};
    my $memname_clone = clone($memname);
    push @$memname_clone, $name;
    if (ref($mem->{type}) eq 'HASH') { #メンバ変数が構造体の場合
      my $v = $self->define_unionstruct_var_vals($mem->{type}, $mem->{elements}, $memname_clone, $struct_var, $struct_vars);
      push @$val, $v;
    }
    elsif (defined $mem->{elements}) { #メンバ変数が配列の場合
      my $v = $self->generate_elements_val_for_unionstruct($mem, 0);
      $self->make_member_list($memname_clone, $mem->{elements}, 0, $struct_var, $mem, $v, $struct_vars);
      push @$val, $v;
    }
    else { #メンバ変数が普通の変数の場合
      my $v = $self->define_value($mem->{type});
      my $ref_v = \$v;
      $self->make_member_list($memname_clone, undef, 0, $struct_var, $mem, $ref_v, $struct_vars);
      push @$val, $ref_v;
    }

    if ($type->{name_type} eq 'u') { last; }
  }
  return $val;
}

#メンバ変数をderiveで参照しやすくするために型毎にメンバ変数を格納
sub make_member_list {
  my ($self, $memname, $elements, $ele_num, $struct_var, $mem, $val, $struct_vars) = @_;

  #メンバ変数が配列の場合, 全ての要素を格納
  if (defined $elements->[$ele_num + 1]) {
    for my $ele (1..$elements->[$ele_num]) {
      my $memname_clone = clone($memname);
      my $name = $ele - 1;
      push @$memname_clone, $name;
      $self->make_member_list($memname_clone, $elements, $ele_num + 1, $struct_var, $mem, $val->[$ele - 1], $struct_vars);
    }
  }
  elsif (defined $elements->[$ele_num]){
    for my $ele (1..$elements->[$ele_num]) {
      my $memname_clone = clone($memname);
      my $name = $ele - 1;
      push @$memname_clone, $name;
      my $usname = $struct_var->{type}->{name_type} . $struct_var->{type}->{name_num};
      my $var =  {
        name_type => $struct_var->{name_type},
        name_num  => $struct_var->{name_num},
        elements  => $memname_clone,
        type      => $mem->{type},
        ival      => $val->[$ele - 1],
        val       => $val->[$ele - 1],
        class     => $struct_var->{class},
        modifier  => $mem->{modifier},
        scope     => $struct_var->{scope},
        unionstruct => $usname,
        replace_flag => 0,
        used      => 1,
      };
      if ($struct_var->{name_type} eq 'x' || $struct_var->{name_type} eq 'a') {
        push @{ $struct_vars->{x}->{$mem->{type}} }, $var;
      }
      elsif ($struct_var->{name_type} eq 't') {
        push @{ $struct_vars->{t}->{$mem->{type}} }, $var;
      }
    }
  }
  else { #メンバ変数が普通の変数の場合
    my $usname = $struct_var->{type}->{name_type} . $struct_var->{type}->{name_num};
    my $var =  {
      name_type => $struct_var->{name_type},
      name_num  => $struct_var->{name_num},
      elements  => $memname,
      type      => $mem->{type},
      ival      => $val,
      val       => $val,
      class     => $struct_var->{class},
      modifier  => $mem->{modifier},
      scope     => $struct_var->{scope},
      unionstruct => $usname,
      replace_flag => 0,
      used      => 1,
    };
    if ($struct_var->{name_type} eq 'x' || $struct_var->{name_type} eq 'a') {
      push @{ $struct_vars->{x}->{$mem->{type}} }, $var;
    }
    elsif ($struct_var->{name_type} eq 't') {
      push @{ $struct_vars->{t}->{$mem->{type}} }, $var;
    }
  }
}

sub generate_unionstruct {
  my ($self, $number, $name_type) = @_;
  my $config = $self->{config};

  my $struct = {
    name_type => $name_type,
    name_num => $number,
    member => undef,
    level => 0, #ネスト
    print_unionstruct => 1,
    used => 1,
  };

  #メンバ変数の生成
  my $member_set = $self->generate_unionstruct_member_vars();

  #ネストレベルの更新
  for my $mem ( @{$member_set} ) {
    if ( ref($mem->{type}) eq 'HASH') {
      if ( $mem->{type}->{level} > $struct->{level} ) {
        $struct->{level} = $mem->{type}->{level};
      }
    }
  }
  $struct->{level}++;

  $struct->{member} = $member_set;
  return $struct;
}

sub generate_unionstruct_member_vars {
  my $self = shift;
  my $config = $self->{config};
  my $memset = [];
  my $member_num = int rand($config->get('member_max') );
  for my $i (0..$member_num) {
    my $type = $config->get('types')->[rand @{$config->get('types')}];
    my $elements = undef; #メンバ変数が配列なら要素数が入る
    my $used_count = undef;

    #確率で現存の共用体・構造体をメンバ変数に
    my $rand = int(rand(10)) + 1;
    if ($rand <= $config->get('prob_struct') && (scalar @{$self->{unionstructs}}) > 0) {
      do {
        $type = $self->{unionstructs}->[rand @{$self->{unionstructs}}];
      } while ($type->{level} > $config->get('nest_max'))
    }
    #確率でメンバ変数を配列に
    if ($rand <= $config->get('prob_array') && $config->get('generate_array_flag')) {
      ($elements, $used_count) = $self->define_element_num();
      # 構造体配列が3次元以上＋ネストでプログラムが大きくなりシステムが落ちることが多々ある
      if (ref $type eq 'HASH' && scalar @$elements > 2) {
          pop @$elements for scalar @$elements > 2
      }
    }

    my $member = {
      name_type => 'm',
      name_num => $i,
      type => $type,
      modifier  => random_select(
          [ 'volatile', 'volatile', '', '', '', '', '', '', '', '', '', '', '' ]
      ),
      elements => $elements,
      print_member => 1,
      used => 1,
    };
    push @$memset, $member;
  }

  return $memset;

}

sub generate_arrays {
  my ($self, $scope, $vars, $x_arrays, $t_arrays) = @_;

  my $config = $self->{config};

  if($config->get('generate_array_flag')) {
    #x配列生成 全ての型の配列を最低１つ生成
    for my $type ( @{$config->get('types')} ) {
      my $array = $self->generate_array($self->{xvar_count}, $type, 'x', $scope);
      # derive.pmで配列の要素を参照させるために配列は型ごとにリストに格納
      push @{ $x_arrays->{$array->{type}} }, $array;
      # Program.pmの変数宣言の生成で使うためにvarsに格納
      push @{ $vars }, $array;
      $self->{xvar_count}++;
    }
    my $x_array_num = int (rand($self->{config}->get('x_array_max')) + 1 );
    for my $i (1..$x_array_num ) {
      my $type = random_select( $config->get('types') );
      my $array = $self->generate_array($self->{xvar_count}, $type, 'x', $scope);
      push @{ $x_arrays->{$array->{type}} }, $array;
      push @{ $vars }, $array;
      $self->{xvar_count}++;
    }

    # t配列生成
    for my $type ( @{$config->get('types')} ) {
      my $array = $self->generate_array($self->{tvar_count}, $type, 't', $scope);
      push @{ $t_arrays->{$array->{type}} }, $array;
      push @{ $vars }, $array;
      $self->{tvar_count}++;
    }
    my $t_array_num = int (rand($self->{config}->get('t_array_max')) + 1);
    for my $i (1..$t_array_num) {
      my $type = random_select( $config->get('types') );
      my $array = $self->generate_array($self->{tvar_count}, $type, 't', $scope);
      push @{ $t_arrays->{$array->{type}} }, $array;
      push @{ $vars }, $array;
      $self->{tvar_count}++;
    }
  }
}

sub generate_array {
  my ($self, $number, $type, $name_type, $scope) = @_;
  my $config = $self->{config};
  my $array = {
      name_type => $name_type,
      name_num  => $number,
      type      => $type,
      ival      => [],
      val       => [],
      class     => random_select( $config->get('classes') ),
      modifier  => random_select( $config->get('modifiers') ),
      scope     => $scope eq 'LOCAL'? 'LOCAL' : random_select( $config->get('scopes') ),
      elements  => [],
      used_count => [], #derive.pmで配列の要素を参照させるとき前から参照させるために必要 何番目まで参照したかの情報が入っている
      replace_flag => 0,
      used      => 1,
  };


  if ($name_type eq 't') { # t 変数には const は使えない
    $array->{modifier} =  random_select( [ 'volatile', 'volatile', '', '', '', '', '', '', '', '', '', '', '' ]);
    $array->{scope} = 'GLOBAL';
  }

  # 配列の次元数と要素数の決定
  ($array->{elements}, $array->{used_count}) = $self->define_element_num();

  # 初期値の決定 valの殆どは後で式展開時の参照で更新される
  $array->{val} = $self->generate_elements_val($array, 0);
  $array->{ival} = $array->{val};

  return $array;
}

# 配列の次元数と要素数の決定
sub define_element_num {
  my ($self) = @_;

  my $elements = [];
  my $used_count = [];
  my $dim = (int rand( $self->{array_dim_max} )) + 1; #次元数

  # それぞれの次元の要素数の決定
  for my $tmp (1..$dim) {
    my $element_num = (int rand($self->{array_element_max}) ) + 1;
    push @{$elements}, $element_num;
    push @{$used_count}, 0;
  }
  return $elements, $used_count;
}

#配列の初期値の決定
sub generate_elements_val {
  my ($self, $array, $ele_num) = @_;

  my $elements = [];
  # 要素の値を再帰で決定
  if (defined $array->{elements}->[$ele_num + 1]) {
    for my $i (1..$array->{elements}->[$ele_num]) {
      my $element = $self->generate_elements_val($array, $ele_num+1);
      push @$elements, $element;
    }
    return $elements;
  } else {
    for my $i (1..$array->{elements}->[$ele_num]) {
      my $ele = $self->define_value($array->{type});
      push @$elements, $ele;
    }
    return $elements;
  }
}

# 値の更新のために変数のリファレンスを使用
sub generate_elements_val_for_unionstruct {
  my ($self, $array, $ele_num) = @_;

  my $elements = [];
  # 要素の値を再帰で決定
  if (defined $array->{elements}->[$ele_num + 1]) {
    for my $i (1..$array->{elements}->[$ele_num]) {
      my $element = $self->generate_elements_val_for_unionstruct($array, $ele_num+1);
      push @$elements, $element;
    }
    return $elements;
  } else {
    for my $i (1..$array->{elements}->[$ele_num]) {
      my $ele = $self->define_value($array->{type});
      push @$elements, \$ele; #ここがgenerate_elements_valと違いリファレンスになっている
    }
    return $elements;
  }
}

sub random_select {
    my $resource = shift;

    my $index = rand @$resource;

    return $resource->[$index];
}

sub _generate_value {
    my $bit = shift;

    my $value;
    if ( $bit == 0 ) {
        $value = 0 ;
    }
    else {
        $value = 1;#Math::BigInt->new(1);
        for ( 1 .. $bit - 1 ) {
            $value *= 2;
            $value += int( rand(2) );
        }
        $value = Math::BigInt->new($value);
    }

    return $value;
}

sub generate_t_var {
  my ( $self, $type, $value, $tvar_count ) = @_;
  my $config = $self->{config};

    return +{
        name_type => 't',
        name_num  => $tvar_count,
        type      => $type,
        ival      => $self->define_value($type),
        val       => $value,
        class     => random_select( $self->{config}->get('classes') ),
        modifier  => random_select(
            ['volatile', 'volatile', '', '', '', '', '', '', '', '', '', '', '',]
        ),
        scope => random_select( $config->get('scopes') ),
        used  => 1,
        replace_flag => 0,
        used_count => undef,
    };
}

sub define_value {
    my ( $self, $type ) = @_;

    my $value = 0; 
    my $bit = int( rand( $self->{config}->get('type')->{$type}->{bits} ) );

    if ( $type eq 'float' || $type eq 'double' || $type eq 'long double' ) {
        $value = _generate_value($bit);
        $value = _random_change_sign($value);
    }
    else {
        my ( $operand, $typename ) = split / /, $type, 2;

        if ( $operand eq 'signed' ) {
            $value = _generate_value( $bit - 1 );
            $value = _random_change_sign($value);
        }
        elsif ( $operand eq 'unsigned' ) {
            $value = _generate_value($bit);
        }
        else {
            Carp::croak("Invalid operand $operand");
        }
    }

    return $value;
}

sub _random_change_sign {
    my $value = shift;

    if ( int( rand(2) ) ) {
        $value = -$value;
    }

    return $value;
}

sub generate_statements {
    my ($self, $depth, $rest_of_roots, $path, $func_name_num) = @_;

    my $statements = [];
    my $root_use_num;
    my @void_funcs = grep{ $_->{type} eq 'void' } @{$self->{func_list}};


    do {
        if ( $depth == 1 ) {
            if ( !($self->{config}->get('debug_mode')) ) {
                local $| = 1;
                print "seed : $self->{seed}\t";
                print "generate statements now.. (", $self->{root_max} - $rest_of_roots, "/$self->{root_max})           ";
                print "\r";
                local $| = 0;
            }
        }

        my $nest_path = 1; # 再帰呼び出し時に渡す path

        # ブロック内の文数がかたよらないように調整
        if ( $rest_of_roots != 0 && $rest_of_roots < 20 ) {
            $root_use_num = int(rand($rest_of_roots)) + 1;
        }
        elsif ( $rest_of_roots >= 20 ) {
            $root_use_num = int(rand(19)) + 1;
        }
        else {
            $root_use_num = 0;
        }
        $rest_of_roots -= $root_use_num;

        # for, if はそれぞれ20%の確率で出現
        my $st_type_rand = int(rand 100);

        if ( $depth <= $#{$self->{config}->get('loop_var_name')} + 1
            && $st_type_rand > 85
            && $root_use_num >= 3 ) {
            my $st = $self->generate_for_statement($depth, $path, $root_use_num, $func_name_num);
            push @$statements, $st;
        }
        elsif ( $depth <= $#{$self->{config}->get('loop_var_name')} + 1
            && $st_type_rand > 70
            && $root_use_num >= 1 ) {
            my $st = $self->generate_if_statement($depth, $path, $root_use_num, $func_name_num);
            push @$statements, $st;
        }
        elsif ( $st_type_rand > 55
                && $st_type_rand <= 70
                && $root_use_num > $self->{config}->get('max_args_num')
                && scalar(@{$self->{func_list}}) != 0
                && @void_funcs ){
                # && 0){
            my ($st, $expression_size) = $self->generate_func_call_statement($path, $func_name_num, $root_use_num);
            push @$statements, $st;

            my $new_called_funcs = [];
            if( $self->judge_called($st->{selected_func_num}) && $path ){
                push @$new_called_funcs, $st->{selected_func_num};
                $new_called_funcs = $self->new_call_funcs( $new_called_funcs );
                $self->push_global_t_vars($func_name_num, $new_called_funcs);
            }
            $self->exec_depth($new_called_funcs);
            $root_use_num -= $expression_size;
            if( $root_use_num > 0 ){
                $rest_of_roots += $root_use_num;
            }
        }
        elsif( $st_type_rand  <= 55
               && $st_type_rand > 40
               && $root_use_num > 2 ){
               #&& 0 ){
            my $st = $self->generate_while_statement($depth, $path, $root_use_num, $func_name_num);
            push @$statements, $st;
        }
        elsif( $st_type_rand <= 40
               && $st_type_rand > 25
               && $root_use_num >= 1 ){
            #   && 0 ){
            my $st = $self->generate_switch_statement($depth, $path, $root_use_num, $func_name_num);
            push @$statements, $st;
        }
        else {
            for ( 1 .. $root_use_num ) {
                my $r = (int rand(10)) + 1;
                if ( $r <= $self->{config}->get('prob_vla') && $depth <= 1) {
                    my $st = $self->generate_variable_length_array($path, $func_name_num);
                    if ( $path <= 1 && $depth <= 1 ) #パスが通っていてforif文中じゃなければ左辺で使うことができる
                    {
                        if ($func_name_num == -1) {
                            push @{ $self->{t_arrays}->{$st->{array}->{type}} }, $st->{array};
                        } 
                        else {
                            push @{ $self->{func_list}->[$func_name_num]->{t_arrays}->{$st->{array}->{type}}}, $st->{array};
                        }
                    } 
                    push @$statements, $st;
                }
                else {
                    my ($exp, $sub_exp) = $self->generate_expressions(1, $path, undef, $func_name_num);

                    if ( $path == 1 ) {
                        if( $func_name_num == -1 ){
                            my $idx = bin_search($exp->{var}->{val}, $self->{vars_on_path}->{t});
                            splice (@{$self->{vars_on_path}->{t}}, $idx, 0, $exp->{var});
                        }
                        else{
                            my $idx = bin_search($exp->{var}->{val}, $self->{func_vars}->[$func_name_num]->{vars_on_path}->{t});
                            splice (@{$self->{func_vars}->[$func_name_num]->{vars_on_path}->{t}}, $idx, 0, $exp->{var});
                        }
                    }
                    my $assign = +{
                        st_type         => 'assign',
                        path            => $path,
                        type            => $exp->{type},
                        val             => $exp->{val},
                        root            => $exp->{root},
                        var             => $exp->{var},
                        name_num        => $exp->{var}->{name_num},
                        print_statement => 1,
                    };
                    $assign->{sub_root} = $sub_exp->{root} if (defined $sub_exp);
                    push @$statements, $assign;
                }
            }
        }
    } while ( $rest_of_roots > 0 );
        return $statements;
}

  sub exec_depth {
      my ($self, $called_funcs) = @_;

      for my $called_func ( @$called_funcs ){
          if( $self->{depth} >= $self->{func_list}->[$called_func]->{depth}+1 ){ ; }
          else{
              $self->{depth} = $self->{func_list}->[$called_func]->{depth}+1;
          }
      }
  }

  # 引数で指定した関数がすでに呼ばれていれば0を, そうでなければ1を返す
  sub judge_called {
      my ($self, $selected_func_num) = @_;

      for my $called ( @{$self->{called}} ){
          if( $called == $selected_func_num ){
              return 0;
          }
      }
      return 1;
  }

  # switch文を生成する
  sub generate_switch_statement {
      my ($self, $depth, $path, $root_use_num, $func_name_num) = @_;

      my $constant_val = []; # 定数式で使う値を保存する用
      #  my $case_num = int(rand(1023))+1; # case句の個数は1から1023個からランダム
      my $case_num = int(rand(5))+1; # 1から3個 (defaultこみの数)
      my $continuation_var;
      my $var = +{
          name_type => 'switch',
          name_num  => 0,
          type      => "signed int",
          ival      => undef,
          val       => undef,
          class     => "",
          modifier  => "",
          scope     => "",
          used      => 1,
      };

      # 定数式の値はsigned intの範囲でランダムに生成
      for( 0 .. $case_num-2 ){ # 最後の一つはdefaultなので定数式がいらない
          my $value;
          while( 1 ){
              $value = $self->define_value( "signed int" );
              if( $self->check_multiple( $constant_val, $value ) == 0 ){
                  last;
              }
          }
          push @$constant_val, $value;
      }

      # caseの何番目にパスを通すかをランダムに決める
      my $path_num = int rand $case_num;

      # 条件式の根になる変数の値は case 句の定数式の中からランダムで選ぶ
      if( $path_num != $case_num-1 ){ # default句以外にパスを通す時
          $var->{ival} = $constant_val->[$path_num];
          $var->{val} = $constant_val->[$path_num];
      }
      else{ # default句にパスを通す時
          my $value;
          while( 1 ){
              $value = $self->define_value( "signed int" );
              if( $self->check_multiple( $constant_val, $value ) == 0 ){
                  last;
              }
          }
          $var->{ival} = $value;
          $var->{val} = $value;
      }

      #条件式を展開
      my $continuation_cond = $self->generate_expressions(0, $path, $var, $func_name_num);

      return +{
          st_type                  => 'switch',
          continuation_cond        => $continuation_cond,
          cases                    => $self->generate_cases($depth+2, $path_num, $constant_val, $root_use_num-1, $case_num, $path, $func_name_num),
          print_tree               => 1,
      };
  }

  sub shuffleArray {
      my $array = shift;
      my $len = scalar(@$array);

      for(my $i = $len-1 ; $i >= 0; --$i) {
          my $j = int( rand($i+1) );
          next if( $i == $j );
          @$array[$i, $j] = @$array[$j, $i];
      }
      return $array
  }

  # 各case文の中のstatementを生成していく
  sub generate_cases {
      my ($self, $depth, $path_num, $constant_val, $root_use_num, $case_num, $path, $func_name_num) = @_;

      my $cases = [];
      my $case_path;
      my $expsize = [];
      for my $i( 0 .. $case_num-1 ){
          if( $i == $case_num-1 ){
              $expsize->[$i] = $root_use_num;
          }
          else{
              $expsize->[$i] = int rand($root_use_num);
          }
          $root_use_num -= $expsize->[$i];
      }
      $expsize = shuffleArray($expsize);

      my $case_root_num;
      for my $i( 0 .. $case_num-1 ){
          my $case = {};

          $case_root_num = $expsize->[$i];

          if( $path_num == $i &&
              $path == 1){
              $case_path = 1;
          }
          else{
              $case_path = 0;
          }

          my $statement = $self->generate_statements($depth, $case_root_num, $case_path, $func_name_num);

          $case->{statements} = $statement;
          $case->{path} = $case_path;
          $case->{constant_val} = $constant_val->[$i];
          $case->{print_case} = 1;
          push @$cases, $case;
      }

      return $cases;
  }

  # 第一引数の配列内に, 第二引数の値が存在するかを判定 (存在すれば1, そうでなければ0を返す)
  sub check_multiple {
      my ($self, $constant_val, $value) = @_;

      for my $val ( @$constant_val ){
          if( $val == $value ){
              return 1;
          }
      }

      return 0;
  }

  # while文を生成する
  sub generate_while_statement {
      my ($self, $depth, $path, $root_use_num, $func_name_num) = @_;

      my ($continuation_cond, $st_condition_for_break);
      my $var = +{
          name_type => 'while',
          name_num  => 0,
          type      => 'signed int',
          ival      => undef,
          val       => undef,
          class     => "",
          modifier  => "",
          scope     => "",
          used      => 1,
      };
      my $used_root_num = 0;
      my $nest_path;

      # while文は2種類のパターン (1回ループと0回ループ)
      my ( $loop_type ) = int( rand(2) );
      if( $loop_type == 1 ) { # ループ回数1回
          # whileの条件文の生成
          $var->{val} = 1;
          $continuation_cond = $self->generate_expressions(0, $path, $var, $func_name_num);

          $nest_path = 1;

          # 一回ループから抜け出すためのif文の生成
          $var->{val} = 1;
          $used_root_num = 2;
      }
      else { # ループ回数0回
          # whileの条件文の生成
          $var->{val} = 0;
          $continuation_cond = $self->generate_expressions(0, $path, $var, $func_name_num);

          $used_root_num = 1;
          $nest_path = 0;
      }

      $st_condition_for_break = $self->generate_expressions(0, $path, $var, $func_name_num);

      if( $path == 0 ){
          $nest_path = 0;
      }

      return +{
          st_type                => 'while',
          continuation_cond      => $continuation_cond,
          st_condition_for_break => $st_condition_for_break,
          statements             => $self->generate_statements($depth+1, $root_use_num-$used_root_num, $nest_path, $func_name_num),
          print_tree             => 1,
          loop_path              => $nest_path,
      };
  }

  # 呼び出す関数をランダムに選択し, 関数呼び出し文を返す
  sub generate_func_call_statement {
      my ($self, $path, $func_name_num, $root_use_num) = @_;
      my $args_list = [];
      my @void_funcs = grep{ $_->{type} eq 'void' } @{$self->{func_list}};
      my $args_num_expression = {};
      my $var = +{
          name_type => 'arg',
          name_num  => 0,
          type      => undef,
          ival      => undef,
          val       => undef,
          class     => '',
          modifier  => "",
          scope     => "",
          used      => 1,
      };
      my $expression_size = 0;

      my $selected_func_num;
      if( $func_name_num == -1 ){
          $selected_func_num = $void_funcs[int rand scalar(@void_funcs)]->{st_num};
      }
      else{
          my $max_depth = $self->{config}->get('max_depth');
          while ( 1 ){
              my $rand_func = int rand scalar(@void_funcs);
              if( $void_funcs[$rand_func]->{depth} < $max_depth ){
                  $selected_func_num = $void_funcs[$rand_func]->{st_num};
                  last;
              }
              else{
                  next;
              }
          }
      }

      my $args_expressions = $self->generate_args($selected_func_num, $func_name_num, $var, $path);

      # 可変引数の場合は関数の引数の個数を展開 (個数の数の型はsigned int 固定)
      if( $self->{func_list}->[$selected_func_num]->{fixed_args_flag} == 0 ){
          ( $var->{type}, $var->{ival}, $var->{val} ) = ( "signed int", scalar(@{$args_expressions}), scalar(@{$args_expressions}) );
          $args_num_expression = $self->generate_expressions(0, $path, $var, $func_name_num);
      }

      $expression_size = $self->{func_list}->[$selected_func_num]->{fixed_args_flag} ? scalar(@{$args_expressions}) : scalar(@{$args_expressions})+1;

      $self->{func_list}->[$selected_func_num]->{called_flag} = 1;
      return (+{
          st_type             => 'function_call',
          name_num            => $selected_func_num,
          args_list           => $args_list,
          args_expressions    => $args_expressions,
          fixed_args_flag     => $self->{func_list}->[$selected_func_num]->{fixed_args_flag},
          args_num_expression => $args_num_expression,
          selected_func_num   => $selected_func_num,
          args_var            => $var,
          print_tree          => 1,
              },
              $expression_size
              )
}

sub generate_args {
    my ($self, $selected_func_num, $func_name_num, $var, $path) = @_;

    my $arg_count = 0;
    my $args_expressions = [];
    for my $arg ( @{$self->{func_list}->[$selected_func_num]->{args_list}} ){
        if (ref $arg->{val} eq 'ARRAY') {
            if ($self->{func_list}->[$selected_func_num]->{called_flag} == 0) {
                my $arg_clone = dclone $arg;
                $arg_clone->{name_type} = 'x';
                $arg_clone->{name_num} = $self->{xvar_count};
                $self->{xvar_count}++ ;
                
                if ($func_name_num == -1) {
                    push @{$self->{vars}}, $arg_clone;
                    if (ref $arg->{val} eq 'ARRAY' && ref $arg->{type} ne 'HASH') {
                        push @{$self->{x_arrays}->{$arg->{type}}}, $arg_clone;
                    }
                }
                else {
                    push @{$self->{func_vars}->[$func_name_num]->{vars}}, $arg_clone;
                    if (ref $arg->{val} eq 'ARRAY' && ref $arg->{type} ne 'HASH') {
                        push @{$self->{func_list}->[$selected_func_num]->{x_arrays}->{$arg->{type}}}, $arg_clone;
                    }
                }
                push @$args_expressions, $arg_clone;
                $self->{called_struct_args}->[$selected_func_num]->[$arg_count] = $arg_clone;
            }
            else {
                push @$args_expressions, $self->{called_struct_args}->[$selected_func_num]->[$arg_count];
            }
            $arg_count++;
        }
        else {
            ( $var->{type}, $var->{ival}, $var->{val} ) = ( $arg->{type}, $arg->{val}, $arg->{val} );
            my $arg_expression = $self->generate_expressions(0, $path, $var, $func_name_num);
            push @$args_expressions, $arg_expression;
        }
    }
    return $args_expressions;
}

  #  関数宣言部の作成
  sub generate_func_statement {
      my ($self, $depth, $path, $root_use_num) = @_;
      my $args_num = int(rand($self->{config}->get('max_args_num'))+1);
      my $func_name_num = $self->{func_count}+1;
      $self->{func_count}++;
      my @args_list;
      my $local_vars;
      my $func_name = "func$func_name_num";
      my $vars = [];
      my $var_x;
      my $var_a;
      my $x_arrays = {};
      my $t_arrays = {};
      my $x_structs = [];
      my $t_structs = [];
      my $struct_vars = {
        x => {},
        t => {},
      };
      my $config = $self->{config};

      my $vars_on_path = +{
          x_current_vars_size =>  undef,
          t_current_vars_size =>  undef,
          func_return_vars    => [],
          x                   => [],
          t                   => [],
      };
      my $called_func = [];
      my $fixed_args_flag = int rand ( 2 );
      my $void_flag = int rand 2;
      my $return_value;  ## 返り値の値
      my $return_type;  ## 返り値の型
      my $func_ret_var;  ## 関数の返り値のオブジェクトが入る
      my $func_var = +{
          vars         => undef,
          vars_on_path => undef,
          replace_vars => {}, # 最小化で使用する
      };

      my $var_num_min = $self->{expression_size} + 1;
      my $var_num_max = $self->{func_root_max} * 3;
      if( $var_num_max < $var_num_min ){
          ($var_num_min, $var_num_max) = ($var_num_max, $var_num_min);
      }
      my $var_max = int(($var_num_max - $var_num_min + 1) * rand() + $var_num_min);
      $local_vars = $self->generate_x_vars_in_func( $var_max, $func_name_num );
      $self->generate_arrays('LOCAL', $vars, $x_arrays, $t_arrays);
      $self->generate_unionstruct_vars($config, 'LOCAL', $vars, $x_structs, $t_structs, $struct_vars);

      #関数内のlocalの追加
      for my $local_var ( @$local_vars ){
          push @$vars, $local_var;
          push @{$vars_on_path->{x}}, $local_var;
      }

      # 引数生成
      for (my $i = 0; $i < $args_num; $i++) {
        my $rand = random_select( $self->{config}->get('prob_func_arg') );
        if ($rand eq 'struct' && scalar @{$self->{unionstructs}}) {
            $var_x = $self->generate_unionstruct_var($config, $i, 'a', 'LOCAL', $struct_vars);
        } elsif ($rand eq 'array' && $config->get('generate_array_flag')) {
          my @types_except_char_and_short = grep{ $_ !~ /char|short/ } @{$self->{config}->get('types')};
            $var_x = $self->generate_array($i, $types_except_char_and_short[int rand @types_except_char_and_short], 'a', 'LOCAL');
            push @{$x_arrays->{$var_x->{type}}}, $var_x;
        }
        else {
          my @types_except_char_and_short = grep{ $_ !~ /char|short/ } @{$self->{config}->get('types')};
          $var_x = $self->_generate_a_var( $i, $types_except_char_and_short[int rand @types_except_char_and_short] );
          push @{$vars_on_path->{x}}, $var_x;
        }
        push (@args_list, $var_x);
      }

      #GLOBALのx変数を関数内で展開に使用する変数群に追加
      for my $var (@{$self->{vars_on_path}->{x}}){
          if( $var->{scope} eq "GLOBAL" ){
            if (!(defined $var->{unionstruct})) {
              push @$vars, $var;
            }
            if( $var->{name_type} eq "x" ){
              push @{$vars_on_path->{x}}, $var;
            }
          }
      }
      $func_var->{vars} = $vars;
      $func_var->{vars_on_path} = $vars_on_path;
      $func_var->{x_arrays} = $x_arrays;
      $func_var->{t_arrays} = $t_arrays;
      $func_var->{x_structs} = $x_structs;
      $func_var->{t_structs} = $t_structs;
      $func_var->{struct_vars} = $struct_vars;
      push @{$self->{func_vars}}, $func_var;

      my $func_vars = $self->{func_vars};

      #void関数でなければ, 返り値を決める
      if( $void_flag == 0 ){
          $return_type = random_select( $self->{config}->get('types') );
          $return_value = $self->define_value( $return_type );
          $func_ret_var =  +{
              name_type        => 'func_ret_var',
              name_num         => $func_name_num,
              type             => $return_type,
              ival             => $return_value,
              val              => $return_value,
              class            => "",
              modifier         => "",
              scope            => "",
              used             => 1,
              args_vars => [],  #引数として使用した変数が入る
          };
      }

      my $statements;
      if( $void_flag ){
          $statements = $self->generate_statements($depth+1, $root_use_num, $path, $func_name_num);
      }
      else{
          $statements = $self->generate_statements($depth+1, $root_use_num-1, $path, $func_name_num);
      }
      my $called_struct_args = [];
      for my $i (0..(scalar @{$self->{func_list}})) {
        push @$called_struct_args, [];
      }

      return +{
          st_type               => 'func',
          st_num                => $func_name_num,
          type                  => $void_flag ? 'void' : $return_type,
          args_list             => \@args_list,
          statements            => $statements,
          vars                  => $vars,
          vars_on_path          => $vars_on_path,
          print_tree            => 1,
          called_funcs          => [], #関数内で呼び出した関数群
          called_flag           => 0,
          fixed_args_flag       => $fixed_args_flag,
          return_var            => $void_flag ? undef : $func_ret_var,
          return_val_expression => $void_flag ? undef : $self->generate_expressions(0, $path, $func_ret_var, $func_name_num), ## returnに使う値も展開する
          args_num_type         => 'signed int', #可変引数の場合の引数の数の型
          depth                 => 0,
          called_struct_args => $called_struct_args,

      };
  }

sub generate_variable_length_array {
  my ($self, $path, $func_name_num) = @_;

  my $config = $self->{config};
  my $type = random_select( $config->get('types') );

  my $array = $self->generate_array($self->{tvar_count}, $type, 't', 'LOCAL');

  $self->{tvar_count}++;

  my $var =  {
    name_type => 't',
    name_num  => $array->{name_num},
    elements  => $array->{elements},
    type      => $array->{type},
    ival      => 0,
    val       => 0,
    class     => $array->{class},
    modifier  => $array->{modifier},
    scope     => $array->{scope},
    replace_flag => 0,
    used      => 1,
};
  $self->generate_expression_by_derivation($self->{expression_size}, 63, $var, 0, $type, $func_name_num);

  if ($self->{root}->{otype} ne 'a' ) {
    $self->{root} = $self->{root}->{in}->[0]->{ref};
  }
  my $sub_exp = {
    type => $self->{root}->{out}->{type},
    val  => $self->{root}->{out}->{val},
    root => $self->{root},
  };
  

  return +{
    st_type => 'array',
    path => $path,
    type => $type,
    array => $array,
    name_num => $array->{name_num},
    sub_root        => $sub_exp->{root},
    print_statement => 1,
  };
}

sub generate_for_statement {
    my ($self, $depth, $path, $root_use_num, $func_name_num) = @_;

    my ($st_init, $continuation_cond, $st_reinit);
    my ($inequality_sign, $operator, $loop_path);
    my $nest_path = 1;
    my $var =  +{
        name_type => 'for',
        name_num  => 0,
        type      => 'signed int',
        ival      => undef,
        val       => undef,
        class     => "",
        modifier  => "",
        scope     => "",
        used      => 1,
    };

    # forは2種類のパターン
    my $loop_type = int(rand(2));
    if( $loop_type == 1 ) { # ループ回数1回
        $loop_path = 1;
        $var->{val} = $self->define_value( $var->{type} );
        $st_init = $self->generate_expressions(0, $path, $var, $func_name_num);
        $var->{val} = $self->define_value( $var->{type} );
        $continuation_cond = $self->generate_expressions(0, $path, $var, $func_name_num);
        if ( int(rand(2)) ) {
            $operator = '+=';
            $var->{val} = $continuation_cond->{val} - $st_init->{val};
        }
        else {
            $operator = '-=';
            $var->{val} = $st_init->{val} - $continuation_cond->{val};
        }
        if ( $st_init->{val} == $continuation_cond->{val} ) {
            if ( $st_init->{val} == $self->{config}->get('type')->{$st_init->{type}}->{max} ) {
                $inequality_sign = '>=';
                $operator = '-=';
                $var->{val} = 1;
            }
            else {
                $inequality_sign = '<=';
                $operator = '+=';
                $var->{val} = 1;
            }
        }
        elsif ( $st_init->{val} > $continuation_cond->{val} ) {
            $inequality_sign = '>';
        }
        else {
            $inequality_sign = '<';
        }
        $st_reinit = $self->generate_expressions(0, $path, $var, $func_name_num);

        if ( $path == 0 ) { $nest_path = 0; }
    }
    else { # ループ回数0回
        $loop_path = 0;
        $var->{val} = $self->define_value( $var->{type} );
        $st_init = $self->generate_expressions(0, $path, $var, $func_name_num);
        $var->{val} = $self->define_value( $var->{type} );
        $continuation_cond = $self->generate_expressions(0, $path, $var, $func_name_num);
        if ( $st_init->{val} > $continuation_cond->{val} ) {
            $inequality_sign = '<=';
        }
        else {
            $inequality_sign = '>';
        }
        if ( int(rand(2)) ) {
            $operator = '+=';
            $var->{val} = $continuation_cond->{val} - $st_init->{val};
        }
        else {
            $operator = '-=';
            $var->{val} = $st_init->{val} - $continuation_cond->{val};
        }
        $st_reinit = $self->generate_expressions(0, $path, $var, $func_name_num);

        $nest_path = 0;
    }

    return +{
        st_type           => 'for',
        loop_var_name     => $self->{config}->get('loop_var_name')->[$depth-1],
        st_init           => $st_init,
        continuation_cond => $continuation_cond,
        st_reinit         => $st_reinit,
        inequality_sign   => $inequality_sign,
        operator          => $operator,
        statements        => $self->generate_statements($depth+1, $root_use_num-3, $nest_path, $func_name_num),
        loop_path         => $loop_type,
        print_tree        => 1,
    };
}

sub generate_if_statement {
    my ($self, $depth, $path, $root_use_num, $func_name_num) = @_;

    my ($exp_cond, $st_then, $st_else);
    my $nest_path = 1;
    my $var =  +{
        name_type => 'if',
        name_num  => 0,
        type      => random_select( $self->{config}->get('types') ),
        ival      => undef,
        val       => undef,
        class     => "",
        modifier  => "",
        scope     => "",
        used      => 1,
    };
    $root_use_num -= 1;

    # ifは4種類のパターン
    my $if_type = int(rand(4));
    if ( $if_type == 0 ) { # ifのみ && 真
        $var->{val} = $self->define_value( $var->{type} );
        if ( $var->{val} == 0 ) { $var->{val} = 1; $var->{type} = 'signed int'; }
        $exp_cond = $self->generate_expressions(0, $path, $var, $func_name_num);
        if ( $path == 0 ) { $nest_path = 0; }
        else { $nest_path = 1; }
        $st_then = $self->generate_statements($depth+1, $root_use_num, $nest_path, $func_name_num);
        $st_else = [];
    }
    elsif ( $if_type == 1 ) { # ifのみ && 偽
        $var->{val} = 0;
        $exp_cond = $self->generate_expressions(0, $path, $var, $func_name_num);
        $nest_path = 0;
        $st_then = $self->generate_statements($depth+1, $root_use_num, $nest_path, $func_name_num);
        $st_else = [];
    }
    elsif ( $if_type == 2 ) { # elseあり && 真
        $var->{val} = $self->define_value( $var->{type} );
        if ( $var->{val} == 0 ) { $var->{val} = 1; $var->{type} = 'signed int'; }
        $exp_cond = $self->generate_expressions(0, $path, $var, $func_name_num);
        if ( $path == 0 ) { $nest_path = 0; }
        else { $nest_path = 1; }
        my $root_use_num_then = int(rand($root_use_num-1));
        $st_then = $self->generate_statements($depth+1, $root_use_num_then, $nest_path, $func_name_num);
        $st_else = $self->generate_statements($depth+1, $root_use_num - $root_use_num_then, 0, $func_name_num);
    }
    else { # elseあり && 偽
        $var->{val} = 0;
        $exp_cond = $self->generate_expressions(0, $path, $var, $func_name_num);
        if ( $path == 0 ) { $nest_path = 0; }
        else { $nest_path = 1; }
        my $root_use_num_then = int(rand($root_use_num-1));
        $st_then = $self->generate_statements($depth+1, $root_use_num_then, 0, $func_name_num);
        $st_else = $self->generate_statements($depth+1, $root_use_num - $root_use_num_then, $nest_path, $func_name_num);
    }

    return +{
        st_type    => 'if',
        exp_cond   => $exp_cond,
        st_then    => $st_then,
        st_else    => $st_else,
        print_tree => 1,
    };
}

sub generate_t_unionstruct_var {
  my ($self, $type, $val, $func_name_num) = @_;

  my $var = 0;
  my $t_struct_vars = {};
  if ($func_name_num == -1) {
    $t_struct_vars = $self->{struct_vars}->{t};
  }
  else {
    $t_struct_vars = $self->{func_vars}->[$func_name_num]->{struct_vars}->{t};
  }


  if (defined $t_struct_vars->{$type} && scalar @{$t_struct_vars->{$type}} > 0) {
    my $rand = int(rand @{$t_struct_vars->{$type}});
    my $ival = $t_struct_vars->{$type}->[$rand- 1]->{ival}; # これしないとリファレンス関連でバグる
    $var = $t_struct_vars->{$type}->[$rand - 1];
    ${$var->{ival}} = $val;
    $var->{ival} = $var->{val} = $val;
    splice(@{$t_struct_vars->{$type}}, $rand - 1, 1);
  }
  else{
    ;
  }

  return $var;
}

# t配列の参照
sub generate_t_array_var {
  my ($self, $type, $val, $func_name_num) = @_;
  # 空の配列の要素を探す
  my $arrays;
  if ($func_name_num == -1) {
    $arrays = $self->{t_arrays}->{$type};
  }
  else {
    $arrays = $self->{func_vars}->[$func_name_num]->{t_arrays}->{$type}
  }
  for my $array ( @{ $arrays } ) {

    unless ( $array->{elements}->[0] <= $array->{used_count}->[0] ) {
      my @used_count = @{$array->{used_count}};
      my $used = \@used_count;
      my $var =  {
        name_type => 't',
        name_num  => $array->{name_num},
        elements  => $used,
        type      => $array->{type},
        ival      => $val,
        val       => $val,
        class     => $array->{class},
        modifier  => $array->{modifier},
        scope     => $array->{scope},
      replace_flag => 0,
        used      => 1,
    };
    $self->update_elements($array, $array->{ival}, $array->{used_count}, 0, $val, $var);

    return $var;
    }
  }
  return 0;
}

#配列の参照に必要なフラグと値の更新
sub update_elements {
  my ($self, $array, $elements, $used_count, $ele_num, $val, $var) = @_;

  if (defined $array->{elements}->[$ele_num + 1]) {
    $self->update_elements($array, $elements->[$used_count->[$ele_num]], $used_count, $ele_num + 1, $val, $var);
    if ($array->{elements}->[$ele_num] <= $used_count->[$ele_num]) {
      if ($ele_num == 0) {
        return;
      } else {
            $used_count->[$ele_num] = 0;
        $used_count->[$ele_num - 1]++;
      }
    }
  } else {
    $var->{ival} = $elements->[$used_count->[$ele_num]];
    $elements->[$used_count->[$ele_num]] = $val;
    if ($array->{elements}->[$ele_num] - $used_count->[$ele_num] == 1) {
      if ($ele_num == 0) {
        $used_count->[$ele_num - 1]++;
        return;
      } else {
        $used_count->[$ele_num] = 0;
        $used_count->[$ele_num - 1]++;
      }
    } else {
      $used_count->[$ele_num]++;
    }
  }
}

sub generate_expressions {
    my ($self, $gen_tvar, $path, $var, $func_name_num) = @_ ;

    my $t_array_flag = 0;
    my $type = random_select( $self->{config}->get('types') );
    my $exp = undef;
    my $sub_exp = undef;
    my $t_struct_vars = {};
    my $t_arrays = {};
    if ($func_name_num == -1) {
      $t_struct_vars = $self->{struct_vars}->{t};
      $t_arrays = $self->{t_arrays}->{$type};
    }
    else {
      $t_struct_vars = $self->{func_vars}->[$func_name_num]->{struct_vars}->{t};
      $t_arrays = $self->{func_vars}->[$func_name_num]->{t_arrays}->{$type};
    }

    if ( $gen_tvar ) { #代入文の場合

      my $rand = random_select( $self->{config}->get('prob_left_var') );

      #使えるt配列がある場合参照する
      for my $array ( @{ $t_arrays } ) {
        unless ( $array->{elements}->[0] <= $array->{used_count}->[0] ) {
          $t_array_flag = 1;
          last;
        }
      }

      if ($rand eq 'array') {
        if ( $t_array_flag ) {
          return $self->generate_t_expression_with_subexp($gen_tvar, $path, $var, $type, 'array', $func_name_num);
        }
        elsif (defined $t_struct_vars->{$type} && scalar @{$t_struct_vars->{$type}} > 0) {
          return $self->generate_t_expression_with_subexp($gen_tvar, $path, $var, $type, 'unionstruct', $func_name_num);
        }
        else {
          return $self->generate_t_expression($gen_tvar, $path, $var, $type, $func_name_num);
        }
      }
      elsif ($rand eq 'unionstruct') {
        if (defined $t_struct_vars->{$type} && scalar @{$t_struct_vars->{$type}} > 0) {

          return $self->generate_t_expression_with_subexp($gen_tvar, $path, $var, $type, 'unionstruct', $func_name_num);
        }
        elsif ( $t_array_flag ) {
          return $self->generate_t_expression_with_subexp($gen_tvar, $path, $var, $type, 'array', $func_name_num);
        }
        else {
          return $self->generate_t_expression($gen_tvar, $path, $var, $type, $func_name_num);
        }
      }
      else {
        return $self->generate_t_expression($gen_tvar, $path, $var, $type, $func_name_num);
      }
    }
    else { #代入文以外の場合
      $self->generate_expression_by_derivation(
          $self->{expression_size}, 63, $var, $gen_tvar, $type, $func_name_num
      );

      $exp = {
        type => $self->{root}->{out}->{type},
        val  => $self->{root}->{out}->{val},
        root => $self->{root},
      };

      return $exp;
    }

}

sub generate_t_expression_with_subexp {
  my ($self, $gen_tvar, $path, $var, $type, $rand, $func_name_num) = @_;
  $self->generate_expression_by_derivation(
      $self->{expression_size} - $self->{tarray_expression_size}, 63, $var, $gen_tvar, $type, $func_name_num
  );
  my $t_var;

  if ($rand eq 'array') {
    $t_var = $self->generate_t_array_var(
       $self->{root}->{out}->{type},
       $self->{root}->{out}->{val},
       $func_name_num,
       );
  }
  elsif ($rand eq 'unionstruct') {
    $t_var = $self->generate_t_unionstruct_var(
       $self->{root}->{out}->{type},
       $self->{root}->{out}->{val},
       $func_name_num,
       );
  }

  my $exp = {
      type => $self->{root}->{out}->{type},
      val  => $self->{root}->{out}->{val},
      root => $self->{root},
      var  => $t_var,
  };

  #左辺添字の展開
  $self->generate_expression_by_derivation($self->{tarray_expression_size}, 63, $t_var, 0, $type, $func_name_num);

  if ($self->{root}->{otype} ne 'a' ) {
    $self->{root} = $self->{root}->{in}->[0]->{ref};
  }

  my $sub_exp = {
      type => $self->{root}->{out}->{type},
      val  => $self->{root}->{out}->{val},
      root => $self->{root},
  };

  return $exp, $sub_exp;
}

sub generate_x_var_based_on_type_and_val {
    my ($self, $number, $type, $val) = @_;

    my $config = $self->{config};

    return +{
        name_type => 'x',
        name_num  => $number,
        type      => $type,
        ival      => $val,
        val       => $val,
        class     => random_select( $config->get('classes') ),
        modifier  => random_select( $config->get('modifiers') ),
        scope     => random_select( $config->get('scopes') ),
        replace_flag => 0,
        used      => 1,
    };
}

sub generate_t_expression {
    my ($self, $gen_tvar, $path, $var, $type, $func_name_num) = @_;

  $self->generate_expression_by_derivation(
      $self->{expression_size}, 63, $var, $gen_tvar, $type, $func_name_num
  );

  my $t_var = $self->generate_t_var(
  $self->{root}->{out}->{type},
  $self->{root}->{out}->{val},
  $self->{tvar_count}
  );
  $self->{tvar_count}++;

  if ( $func_name_num == -1) {
    push @{$self->{vars}}, $t_var;
  }
  else {
    push @{$self->{func_vars}->[$func_name_num]->{vars}}, $t_var;

  }

  my $exp = {
    type => $self->{root}->{out}->{type},
    val  => $self->{root}->{out}->{val},
    root => $self->{root},
    var  => $t_var,
  };
  return $exp;
}

sub generate_expression_by_derivation {
    my ($self, $expsize, $depth, $var, $gen_tvar, $type, $func_name_num) = @_;

    my $derive = Orange4::Generator::Derive->new(
        config       => $self->{config},
        vars             => $func_name_num == -1 ? $self->{vars_on_path} : $self->{func_vars}->[$func_name_num]->{vars_on_path},
        vars_to_push     => $func_name_num == -1 ? $self->{vars} : $self->{func_vars}->[$func_name_num]->{vars},
        gen_tvar     => $gen_tvar,
        conf_type    => $self->{config}->get('type'),
        conf_types   => $self->{config}->get('types'),
        x_arrays       => $func_name_num == -1 ? $self->{x_arrays} : $self->{func_vars}->[$func_name_num]->{x_arrays},
        x_struct_vars => $func_name_num == -1 ? $self->{struct_vars}->{x} : $self->{func_vars}->[$func_name_num]->{struct_vars}->{x},
        x_structs    => $func_name_num == -1 ? $self->{x_structs} : $self->{func_vars}->[$func_name_num]->{x_structs},
        main_vars        => $self->{vars},
        func_vars        => $self->{func_vars},
        func_list        => $self->{func_list},
        func_name_num    => $func_name_num,
        called           => [],
        xvar_count   => $self->{xvar_count},
        called_struct_args => $self->{called_struct_args},
    );

    if ( !defined($var) ) {
        my $var_i = {
            name_type => 't',
            name_num  => $self->{tvar_count},
            type      => $type,
            ival      => $self->define_value($type),
            val       => $self->define_value($type),
            class     => random_select( $self->{config}->get('classes') ),
            modifier  => random_select(
                [ 'volatile', 'volatile', '', '', '', '', '', '', '', '', '', '', '' ]
            ),
            scope     => 'GLOBAL',
            replace_flag => 0,
            used      => 1,
        };

        $self->{root} = {
            ntype  => 'var',
            var    => $var_i,
            ival   => $var_i->{val},
            nxt_op => $derive->select_opcode_with_value($var_i->{val}),
        };
    }
    else {
        $self->{root} = {
            ntype  => 'var',
            var    => $var,

        };
        if (defined $var->{elements}) { #配列の場合は最初の演算子をaに
          $self->{root}->{nxt_op} = 'a';
          $self->{root}->{elements} = $var->{elements};
        }
        else {
          $self->{root}->{nxt_op} = $derive->select_opcode_with_value($var->{val}),
          $self->{root}->{ival} = $var->{val};
        }
    }

    my $node_info = {
        ref     => $self->{root},
        expsize => $expsize,
        depth   => $depth,
    };

    my $leaf_nodes = [];
    push @$leaf_nodes, $node_info;

    my $n = 0;
    # $self->{vars_on_path}->{x_current_vars_size} = $#{$self->{vars_on_path}->{x}};
    print "------------------------- exp $self->{tvar_count}\n"
    if($self->{config}->get('debug_mode'));

    while(0 <= $#$leaf_nodes) {
        $n = $derive->derive_expression(
            $leaf_nodes->[0]->{ref}
        );

        $derive->make_leaf_nodes_info($leaf_nodes, $n);

        shift @$leaf_nodes;
    }
    $self->{xvar_count} = $derive->{xvar_count};
}

# 呼んだ関数内で呼ばれる関数を探し, 過去に呼ばれたか否かに関係なく呼ばれる関数をすべて返す
sub total_call_funcs {
    my ($self, $called_funcs) = @_;

    my $total_called_funcs = [];
    for my $called_func ( @$called_funcs ){
        push @$total_called_funcs, $called_func;
        for my $func( @{$self->{func_list}->[$called_func]->{called_funcs}} ){
            push @$total_called_funcs, $func;
        }
    }
    return $total_called_funcs;
}

# 呼んだ関数内で呼ばれる関数を探し, 結果的に新たに呼ばれることになる関数をすべて返す
sub new_call_funcs {
    my ($self, $new_called_funcs) = @_;

    my $total_called_funcs = [];
    for my $new_called_func ( @$new_called_funcs ){
        push @$total_called_funcs, $new_called_func;
        push @{$self->{called}}, $new_called_func;
        for my $func( @{$self->{func_list}->[$new_called_func]->{called_funcs}} ){
            if( $self->judge_called($func) ){
                push @{$self->{called}}, $func;
                push @$total_called_funcs, $func;
            }
        }
    }
    return $total_called_funcs;
}

# 関数内で代入文が生成されたGLOBALのt変数を呼び出し元で使えるようにする
sub push_global_t_vars {
    my ($self, $func_name_num, $new_called_funcs) = @_;

    for my $new_called_func ( @$new_called_funcs ){
        for my $var ( @{$self->{func_vars}->[$new_called_func]->{vars_on_path}->{t}} ){
            if( $var->{scope} eq "GLOBAL" && !(defined $var->{elements})){
                if( $func_name_num == -1 ){
                    push @{$self->{vars_on_path}->{t}}, $var;
                    push @{$self->{vars}}, $var;
                }
                else{
                    push @{$self->{func_vars}->[$func_name_num]->{vars_on_path}->{t}}, $var;
                    push @{$self->{func_vars}->[$func_name_num]->{vars}}, $var;
                }
            }
        }
    }
}

sub _insertion_sort {
    my ( $self, $var ) = @_;

    my $pushed = 0;

    for my $pos ( 0 .. $#{$self->{vars_on_path}} ) {
        if ( $self->{vars_on_path}->[$pos]->{val} >= $var->{val} ) {
            splice @{$self->{vars_on_path}}, $pos, 0, $var;
            $pushed = 1;
            last;
        }
    }
    push @{$self->{vars_on_path}}, $var if ( $pushed == 0 );
}

sub bin_search {
    my ( $val, $array ) = @_;

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

    return $head;
}

sub reset_references {
    my ($self) = @_;

    $self->reset_refs($self->{vars});
    for my $func_var (@{$self->{func_vars}}) {
      $self->reset_refs($func_var->{vars});
    }
    for my $func (@{$self->{func_list}}) {
      $self->reset_refs($func->{args_list});
    }
}

sub reset_refs {
  my ($self, $vars) = @_;

  for my $var (@$vars) {
    if (ref $var->{type} eq "HASH") {
      $self->reset_ref($var->{ival});
      $self->reset_ref($var->{val});
    }
  }
}

sub reset_ref {
  my ($self, $ARRAY) = @_;

  for my $i (0.. ((scalar @$ARRAY) - 1)) {
    if (ref $ARRAY->[$i] eq "ARRAY") {
      $self->reset_ref($ARRAY->[$i]);
    }
    elsif (ref $ARRAY->[$i] eq "REF" || ref $ARRAY->[$i] eq "SCALAR") {
      $ARRAY->[$i] = ${$ARRAY->[$i]};
    }
  }
}

# Accessor
sub vars            { @{ shift->{vars} }; }
sub statements      { @{ shift->{statements} }; }
sub expression_size { shift->{expression_size}; }
sub root_max        { shift->{root_max}; }
sub var_max         { shift->{var_max}; }
sub func_vars       { @{ shift->{func_vars} }; }
sub func_list       { @{ shift->{func_list} }; }

1;
