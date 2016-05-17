package Orange4::Generator;

use strict;
use warnings;

use Carp ();
use Math::BigInt;

use Orange4::Dumper;
use Orange4::Log;
use Orange4::Generator::Derive;

sub new {
    my ( $class, %args ) = @_;
    
    my $vars  = $args{vars}  || [];
    my $statements = $args{statements} || [];
    
    bless {
        root         => {}, # unnecessary ?
        statements   => $statements,
        undef_seeds  => [],
        vars         => $vars,
        vars_on_path => { x_current_vars_size =>  undef,
                          t_current_vars_size =>  undef, #いらんけど今後使うかもしれないから
                          x => [],
                          t => [],
                        },
        avoide_undef => 2,
        %args
    }, $class;
}

sub run {
    my $self = shift;
    
    $self->_init();
    $self->generate_x_vars();
    my $statements = $self->generate_statements(1, $self->{root_max}, 1);
    if( ref($statements) eq 'ARRAY' ) {
        push @{$self->{statements}}, @$statements;
    }
    else {
        push @{$self->{statements}}, $statements;
    }
    
    unless ( $self->{config}->get('debug_mode') ) {
        local $| = 1;
        print "seed : $self->{seed}\t                                    ";
        print "\r";
        local $| = 0;
        print "seed : $self->{seed}\t";
    }
}

sub _init {
    my $self = shift;
    
    #do {
        $self->{expression_size} = _get_expression_size( $self->{config} );
        $self->_get_root_size();
    #} while ( $self->{root_max} > 200 );
    $self->_get_var_size();
    $self->{tval_count} = 0;
}

sub _get_expression_size {
    my $config = shift;
    
    my $e_size_num = $config->get('e_size_num');
    my $e_size_param = rand( ( log($e_size_num) / log(2) ) );
    
    return int( ( 2**$e_size_param ) );
}

sub _get_root_size {
    my $self = shift;
    
    $self->{root_max} = int( $self->{config}->get('e_size_num') / $self->{expression_size} );
}

sub _get_var_size {
    my $self = shift;
    
    unless($self->{derive}) {
        my $var_num_min = $self->{expression_size} + 1;
        my $var_num_max = $self->{root_max} * 5;
        
        if ($var_num_min < $var_num_max) { # ??
            ( $var_num_min, $var_num_max ) = ( $var_num_max, $var_num_min )
        }
        
        $self->{var_max} =  int(($var_num_max - $var_num_min + 1) * rand() + $var_num_min);
    }
    else {
        $self->{var_max} = $self->{root_max} - 1;
    }
}

sub generate_x_vars {
    my $self = shift;
    
    my $derive = Orange4::Generator::Derive->new(
        config => $self->{config}
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
                print "generate var now.. ($number/$self->{var_max})      ";
                print "\r";
                local $| = 0;
            }
        }
    }
    @{$self->{vars_on_path}->{x}} = sort {$a->{val} <=> $b->{val}} @{$self->{vars_on_path}->{x}};
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
        class     => random_select( $config->get('classes') ),
        modifier  => random_select( $config->get('modifiers') ),
        scope     => random_select( $config->get('scopes') ),
        used      => 1,
    };
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
        $value = Math::BigInt->new(0);
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
  my ( $self, $type, $value, $tval_count ) = @_;
    
    return +{
        name_type => 't',
        name_num  => $tval_count,
        type      => $type,
        ival      => $self->define_value($type),
        val       => $value,
        class     => random_select( $self->{config}->get('classes') ),
        modifier  => random_select(
            [ 'volatile', '', '', '', '', '', '', '', '', '', '', '', '' ]
        ),
        scope => 'GLOBAL',
        used  => 1,
    };
}

sub define_value {
    my ( $self, $type ) = @_;
    
    my $value = Math::BigInt->new(0); # is this line necessary??
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
    my ($self, $depth, $rest_of_roots, $path) = @_;
    
    my $statements = [];
    my $root_use_num;
    
    do {
        if ( $depth == 1 ) {
            if ( !($self->{config}->get('debug_mode')) ) {
                local $| = 1;
                print "seed : $self->{seed}\t";
                print "generate statements now.. (", $self->{root_max} - $rest_of_roots, "/$self->{root_max})";
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
        my $st_type_rand = int(rand 10);
        
        if ( $depth <= $#{$self->{config}->get('loop_var_name')} + 1
            && $st_type_rand > 7
            && $root_use_num >= 3 ) {
            my $st = $self->generate_for_statement($depth, $path, $root_use_num);
            push @$statements, $st;
        }
        elsif ( $depth <= $#{$self->{config}->get('loop_var_name')} + 1
            && $st_type_rand > 5 && $st_type_rand <= 7
            && $root_use_num >= 1 ) {
            my $st = $self->generate_if_statement($depth, $path, $root_use_num);
            push @$statements, $st;
        }
        else {
            for ( 1 .. $root_use_num ) {
                my $exp = $self->generate_expressions(1, $path, undef);
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
                push @$statements, $assign;
            }
        }
    } while ( $rest_of_roots > 0 );
    
    return $statements;
}

sub generate_for_statement {
    my ($self, $depth, $path, $root_use_num) = @_;
    
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
        $st_init = $self->generate_expressions(0, $path, $var);
        $var->{val} = $self->define_value( $var->{type} );
        $continuation_cond = $self->generate_expressions(0, $path, $var);
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
        $st_reinit = $self->generate_expressions(0, $path, $var);
        
        if ( $path == 0 ) { $nest_path = 0; }
    }
    else { # ループ回数0回
        $loop_path = 0;
        $var->{val} = $self->define_value( $var->{type} );
        $st_init = $self->generate_expressions(0, $path, $var);
        $var->{val} = $self->define_value( $var->{type} );
        $continuation_cond = $self->generate_expressions(0, $path, $var);
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
        $st_reinit = $self->generate_expressions(0, $path, $var);
        
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
        statements        => $self->generate_statements($depth+1, $root_use_num-3, $nest_path),
        loop_path         => $loop_type,
        print_tree        => 1,
    };
}

sub generate_if_statement {
    my ($self, $depth, $path, $root_use_num) = @_;
    
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
        $exp_cond = $self->generate_expressions(0, $path, $var);
        if ( $path == 0 ) { $nest_path = 0; }
        else { $nest_path = 1; }
        $st_then = $self->generate_statements($depth+1, $root_use_num, $nest_path);
        $st_else = [];
    }
    elsif ( $if_type == 1 ) { # ifのみ && 偽
        $var->{val} = 0;
        $exp_cond = $self->generate_expressions(0, $path, $var);
        $nest_path = 0;
        $st_then = $self->generate_statements($depth+1, $root_use_num, $nest_path);
        $st_else = [];
    }
    elsif ( $if_type == 2 ) { # elseあり && 真
        $var->{val} = $self->define_value( $var->{type} );
        if ( $var->{val} == 0 ) { $var->{val} = 1; $var->{type} = 'signed int'; }
        $exp_cond = $self->generate_expressions(0, $path, $var);
        if ( $path == 0 ) { $nest_path = 0; }
        else { $nest_path = 1; }
        my $root_use_num_then = int(rand($root_use_num));
        $st_then = $self->generate_statements($depth+1, $root_use_num_then, $nest_path);
        $st_else = $self->generate_statements($depth+1, $root_use_num - $root_use_num_then, 0);
    }
    else { # elseあり && 偽
        $var->{val} = 0;
        $exp_cond = $self->generate_expressions(0, $path, $var);
        if ( $path == 0 ) { $nest_path = 0; }
        else { $nest_path = 1; }
        my $root_use_num_then = int(rand($root_use_num));
        $st_then = $self->generate_statements($depth+1, $root_use_num_then, 0);
        $st_else = $self->generate_statements($depth+1, $root_use_num - $root_use_num_then, $nest_path);
    }
    
    return +{
        st_type    => 'if',
        exp_cond   => $exp_cond,
        st_then    => $st_then,
        st_else    => $st_else,
        print_tree => 1,
    };
}

sub generate_expressions {
    my ($self, $gen_tvar, $path, $var) = @_;
    
    
    # 値を展開し, 式を生成
    $self->generate_expression_by_derivation(
        $self->{expression_size}, 63, $var, $gen_tvar
    );
    
    # t式の場合とforやifの引数の場合で分岐
    if ( $gen_tvar ) {
        my $t_var = $self->generate_t_var(
            $self->{root}->{out}->{type},
            $self->{root}->{out}->{val},
            $self->{tval_count}
        );
        if ( $path == 1 ) { 
            my $idx = bin_search($t_var->{val}, $self->{vars_on_path}->{t});
            splice (@{$self->{vars_on_path}->{t}}, $idx, 0, $t_var);
        }
        push @{$self->{vars}}, $t_var;
        $self->{tval_count}++;
        
        return +{
            type => $self->{root}->{out}->{type},
            val  => $self->{root}->{out}->{val},
            root => $self->{root},
            var  => $self->{vars}->[$#{$self->{vars}}],
        };
    }
    else {
        return +{
            type => $self->{root}->{out}->{type},
            val  => $self->{root}->{out}->{val},
            root => $self->{root},
        };
    }
}

sub generate_expression_by_derivation {
    my ($self, $expsize, $depth, $var, $gen_tvar) = @_;
    
    my $derive = Orange4::Generator::Derive->new(
        config       => $self->{config}, 
        vars         => $self->{vars_on_path}, 
        vars_to_push => $self->{vars}, 
        gen_tvar     => $gen_tvar, 
        conf_type    => $self->{config}->get('type'), 
        conf_types   => $self->{config}->get('types')
    );
    
    if ( !defined($var) ) {
        my $var_i = $self->{vars}->[$self->{tval_count}];
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
            ival   => $var->{val},
            nxt_op => $derive->select_opcode_with_value($var->{val}),
        };
    }
    
    my $node_info = {
        ref     => $self->{root},
        expsize => $expsize,
        depth   => $depth,
    };
    
    my $leaf_nodes = [];
    push @$leaf_nodes, $node_info;
    
    my $n = 0;
    $self->{vars_on_path}->{x_current_vars_size} = $#{$self->{vars_on_path}->{x}};
    print "------------------------- exp $self->{tval_count}\n"
    if($self->{config}->get('debug_mode'));
    
    while(0 <= $#$leaf_nodes) {
        $n = $derive->derive_expression(
            $leaf_nodes->[0]->{ref}#, $vars_sorted_by_value
        );
        
        $derive->make_leaf_nodes_info($leaf_nodes, $n);
=comment    
    print "\n X\n";
    for my $i (0 .. $#{$self->{vars_on_path}->{x}}) {
        print "$self->{vars_on_path}->{x}->[$i]->{val}, $self->{vars_on_path}->{x}->[$i]->{name_num}, $self->{vars_on_path}->{x}->[$i]->{name_type}, $self->{vars_on_path}->{x}->[$i]->{type}\n";
    }
    print "\n\n";
    print "\n t\n";
    for my $i (0 .. $#{$self->{vars_on_path}->{t}}) {
        print "$self->{vars_on_path}->{t}->[$i]->{val}, $self->{vars_on_path}->{t}->[$i]->{name_num}, $self->{vars_on_path}->{t}->[$i]->{name_type}, $self->{vars_on_path}->{t}->[$i]->{type}\n";
    }
    print "\n\n";
=cut
        shift @$leaf_nodes;
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

# Accessor
sub vars            { @{ shift->{vars} }; }
sub statements      { @{ shift->{statements} }; }
sub expression_size { shift->{expression_size}; }
sub root_max        { shift->{root_max}; }
sub var_max         { shift->{var_max}; }

1;
