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
    my $roots = $args{roots} || [];
    
    bless {
        root         => {}, # unnecessary ?
        roots        => $roots,
        undef_seeds  => [],
        vars         => $vars,
        vars_on_path => [],
        avoide_undef => 2,
        %args
    }, $class;
}

sub run {
    my $self = shift;
    
    $self->_init();
    $self->generate_x_vars();
    $self->generate_statements();
    
    unless ( $self->{config}->get('debug_mode') ) {
        local $| = 1;
        print "seed : $self->{seed}\t                                   ";
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
        push @{ $self->{vars_on_path} }, $var;
        
        unless ( $self->{config}->get('debug_mode') ) { #unless or if??
            if ( $number % 100 == 1 ) {
                local $| = 1;
                print "seed : $self->{seed}\t";
                print "generate var now.. ($number/$self->{var_max})      ";
                print "\r";
                local $| = 0;
            }
        }
    }
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
        $value = Math::BigInt->new(1);
        for ( 1 .. $bit - 1 ) {
            $value *= 2;
            $value += int( rand(2) );
        }
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
    my $self = shift;
    
    my $undef_root = 0;
    my $rest_of_roots = $self->{root_max};
    
    my $statements = $self->generate_statement(1, $rest_of_roots, 1);
    if( ref($statements) eq 'ARRAY' ) {
        push @{$self->{roots}}, @$statements;
    }
    else {
        push @{$self->{roots}}, $statements;
    }
}

sub generate_statement {
    my ($self, $depth, $rest_of_roots, $path) = @_;
    
    
    my $statements = [];
    my $root_use_num;
    
    do {
        my $nest_path = 1; # 再帰呼び出し時に渡す$path
        if ( $depth == 1 ) {
            if ( !($self->{config}->get('debug_mode')) ) {
                local $| = 1;
                print "seed : $self->{seed}\t";
                print "generate statements now.. (", $self->{root_max} - $rest_of_roots, "/$self->{root_max})";
                print "\r";
                local $| = 0;
            }
        }
        
        # ブロック内の文数がかたよらないように調整
        if ( $rest_of_roots < 20 ) {
            $root_use_num = int(rand($rest_of_roots-1)) + 1;
        }
        else {
            $root_use_num = int(rand(19)) + 1;
        }
        $rest_of_roots -= $root_use_num;
        
        # for, ifはそれぞれ2割の確率で出現
        my $st_type_rand = int(rand 10);
        if ( $depth <= scalar(@{$self->{config}->get('loop_var_name')}) &&
            $st_type_rand > 7 &&
            $root_use_num >= 3
        ) {
            my $st_type = 'for';
            my $loop_var_name = $self->{config}->get('loop_var_name');
            my $name_type = "$loop_var_name->[$depth-1]";
            my $init_st;
            my $continuation_cond;
            my $re_init_st;
            my $inequality_sign;
            my $operator;
            my $loop_path;
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
            if( $loop_type == 0 ) { # ループ回数1回
                $loop_path = 1;
                $var->{val} = $self->define_value( $var->{type} );
                $init_st = $self->generate_expressions(0, $path, $var);
                $var->{val} = $self->define_value( $var->{type} );
                $continuation_cond = $self->generate_expressions(0, $path, $var);
                if ( int(rand(2)) ) {
                    $operator = '+=';
                    $var->{val} = $continuation_cond->{val} - $init_st->{val};
                }
                else {
                    $operator = '-=';
                    $var->{val} = $init_st->{val} - $continuation_cond->{val};
                }
                if ( $init_st->{val} == $continuation_cond->{val} ) {
                    if ( $init_st->{val} == $self->{config}->get('type')->{$init_st->{type}}->{max} ) {
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
                elsif ( $init_st->{val} > $continuation_cond->{val} ) {
                    $inequality_sign = '>';
                }
                else {
                    $inequality_sign = '<';
                }
                $re_init_st = $self->generate_expressions(0, $path, $var);
                
                if ( $path == 0 ) { $nest_path = 0; }
                else { $nest_path = 1; }
            }
            else { # ループ回数0回
                $loop_path = 0;
                $var->{val} = $self->define_value( $var->{type} );
                $init_st = $self->generate_expressions(0, $path, $var);
                $var->{val} = $self->define_value( $var->{type} );
                $continuation_cond = $self->generate_expressions(0, $path, $var);
                if ( $init_st->{val} > $continuation_cond->{val} ) {
                    $inequality_sign = '<=';
                }
                else {
                    $inequality_sign = '>';
                }
                if ( int(rand(2)) ) {
                    $operator = '+=';
                    $var->{val} = $continuation_cond->{val} - $init_st->{val};
                }
                else {
                    $operator = '-=';
                    $var->{val} = $init_st->{val} - $continuation_cond->{val};
                }
                $re_init_st = $self->generate_expressions(0, $path, $var);
                
                $nest_path = 0;
            }
            
            my $body = $self->generate_statement($depth+1, $root_use_num - 3, $nest_path);
            
            my $st = +{
                st_type           => $st_type,
                loop_var_name     => $name_type,
                init_st           => $init_st,
                continuation_cond => $continuation_cond,
                re_init_st        => $re_init_st,
                inequality_sign   => $inequality_sign,
                operator          => $operator,
                statements        => $body,
                loop_path         => $loop_path,
                print_tree        => 1,
            };
            
            push @$statements, $st;
        }
        elsif( $st_type_rand <= 7 && $st_type_rand > 5 && $root_use_num >= 1 ) {
            my $st_type = 'if';
            my $exp_cond;
            my $st_then;
            my $st_else;
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
            
            # ifは4種類のパターン
            my $if_type = int(rand(4));
            if ( $if_type == 0 ) { # ifのみ && 真
                $var->{val} = $self->define_value( $var->{type} );
                if ( $var->{val} == 0 ) { $var->{val} = 1; $var->{type} = 'signed int'; }
                $exp_cond = $self->generate_expressions(0, $path, $var);
                if ( $path == 0 ) { $nest_path = 0; }
                else { $nest_path = 1; }
                $st_then = $self->generate_statement($depth+1, $root_use_num - 1, $nest_path);
                $st_else = [];
            }
            elsif ( $if_type == 1 ) { # ifのみ && 偽
                $var->{val} = 0;
                $exp_cond = $self->generate_expressions(0, $path, $var);
                $nest_path = 0;
                $st_then = $self->generate_statement($depth+1, $root_use_num - 1, $nest_path);
                $st_else = [];
            }
            elsif ( $if_type == 2 ) { # elseあり && 真
                $var->{val} = $self->define_value( $var->{type} );
                if ( $var->{val} == 0 ) { $var->{val} = 1; $var->{type} = 'signed int'; }
                $exp_cond = $self->generate_expressions(0, $path, $var);
                if ( $path == 0 ) { $nest_path = 0; }
                else { $nest_path = 1; }
                $st_then = $self->generate_statement($depth+1, $root_use_num - 1, $nest_path);
                $st_else = $self->generate_statement($depth+1, $root_use_num - 1, 0);
            }
            else { # elseあり && 偽
                $var->{val} = 0;
                $exp_cond = $self->generate_expressions(0, $path, $var);
                if ( $path == 0 ) { $nest_path = 0; }
                else { $nest_path = 1; }
                $st_then = $self->generate_statement($depth+1, $root_use_num - 1, 0);
                $st_else = $self->generate_statement($depth+1, $root_use_num - 1, $nest_path);
            }
            
            my $st = +{
                st_type    => $st_type,
                exp_cond   => $exp_cond,
                st_then    => $st_then,
                st_else    => $st_else,
                print_tree => 1,
            };
            
            push @$statements, $st;
        }
        else {
            for ( 0 .. $root_use_num ) {
                my $st_type = 'assign';
                my $expression = $self->generate_expressions(1, $path, undef);
                my $assign = +{
                    st_type         => $st_type,
                    path            => $path,
                    type            => $expression->{type},
                    val             => $expression->{val},
                    root            => $expression->{root},
                    var             => $expression->{var},
                    name_num        => $expression->{var}->{name_num},
                    print_statement => 1,
                };
                push @$statements, $assign;
            }
        }
    } while ( $rest_of_roots > 0 );
    
    return $statements;
}

sub generate_expressions {
    my ($self, $gen_tvar, $path, $var) = @_;
    
    my $vars_sorted_by_value = {
        current_vars_size => $self->{root_max} - 1,
        x => [],
        t => [],
    };
    
    @{$vars_sorted_by_value->{t}} = sort {$a->{val} <=> $b->{val}} @{$self->{vars_on_path}};
    
    # 値を展開し, 式を生成
    $self->generate_expression_by_derivation(
        $self->{vars}, $self->{vars_on_path}, $self->{expression_size}, 63, $self->{tval_count}, $vars_sorted_by_value, $var, $gen_tvar
    );
    $vars_sorted_by_value->{current_vars_size} = $#{$self->{vars_on_path}};
    
    # t式の場合とforやifの引数の場合で分岐
    if ( $gen_tvar ) {
        my $t_var = $self->generate_t_var(
            $self->{root}->{out}->{type},
            $self->{root}->{out}->{val},
            $self->{tval_count}
        );
        if ( $path == 0 ) { $t_var->{ival} = $self->{root}->{out}->{val}; }
        if ( $path == 1 ) { push @{$self->{vars_on_path}}, $t_var }
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
            val => $self->{root}->{out}->{val},
            root => $self->{root},
        };
    }
}

sub _select_varnode {
    my $self = shift;
    
    my $number = 0;
    do {
        $number = int( rand( $self->vars ) );
    } while ( $self->{vars}->[$number]->{name_type} eq 'k' );
    
    return +{
        ntype => 'var',
        var   => $self->{vars}->[$number],
    };
}

sub generate_expression_by_derivation {
    my ($self, $vars, $vars_on_path, $expsize, $depth, $i, $vars_sorted_by_value, $var, $gen_tvar) = @_;
    
    my $derive = Orange4::Generator::Derive->new(
        config => $self->{config}, vars => $self->{vars}, vars_on_path => $self->{vars_on_path}
    );
    
    if ( !defined($var) ) {
        my $var_i = $vars->[$i];
        $self->{root} = {
            ntype => 'var',
            var => $var_i,
            ival => $var_i->{val},
            nxt_op => $derive->select_opcode_with_value($var_i->{val}),
        };
    }
    else {
        $self->{root} = {
            ntype => 'var',
            var => $var,
            ival => $var->{val},
            nxt_op => $derive->select_opcode_with_value($var->{val}),
        };
    }
    
    my $node_info = {
        ref => $self->{root},
        expsize => $expsize,
        depth => $depth,
    };
    
    my $leaf_nodes = [];
    push @$leaf_nodes, $node_info;
    
    my $n = 0;
    my $current_vars_size = $vars_sorted_by_value->{current_vars_size};
    
    print "------------------------- exp $i\n"
    if($self->{config}->get('debug_mode'));
    
    while(0 <= $#$leaf_nodes) {
        #$derive->update_sorted_vars(
        #    $vars_sorted_by_value, $#$vars - $current_vars_size
        #);
        $current_vars_size = $#$vars;
        
        if ( !$gen_tvar ) {
            $vars_sorted_by_value->{t} = [];
        }
        $n = $derive->derive_expression(
            $leaf_nodes->[0]->{ref}, $vars_sorted_by_value
        );
        
        $derive->make_leaf_nodes_info($leaf_nodes, $n);
        
        shift @$leaf_nodes;
    }
}

# Accessor
sub vars            { @{ shift->{vars} }; }
sub roots           { @{ shift->{roots} }; }
sub expression_size { shift->{expression_size}; }
sub root_max        { shift->{root_max}; }
sub var_max         { shift->{var_max}; }

1;
