package Orange3::Generator;

use strict;
use warnings;

use Carp ();
use Math::BigInt;
use Data::Dumper;

use Orange3::Dumper;
use Orange3::Log;
use Orange3::Generator::Expect;
use Orange3::Generator::Arithmetic;

sub new {
  my ( $class, %args ) = @_;

  my $vars  = $args{vars}  || [];
  my $roots = $args{roots} || [];

  bless {
    root         => {},       # unnecessary ?
    roots        => $roots,
    undef_seeds  => [],
    vars         => $vars,
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

  $self->{expression_size} = _get_expression_size( $self->{config} );
  $self->_get_root_size();
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

  $self->{root_max} =
    int( $self->{config}->get('e_size_num') / $self->{expression_size} );
}

sub _get_var_size {
  my $self = shift;

  my $var_num_min = $self->{expression_size} + 1;
  my $var_num_max = $self->{root_max} * 5;

  if ( $var_num_min < $var_num_max ) {    # ??
    ( $var_num_min, $var_num_max ) = ( $var_num_max, $var_num_min );
  }

  $self->{var_max} =
    int( ( $var_num_max - $var_num_min + 1 ) * rand() + $var_num_min );
}

sub generate_x_vars {
  my $self = shift;

  for my $number ( 0 .. $self->{var_max} ) {
    my $var = $self->_generate_x_var($number);
    if ( defined( $self->{volatile_mode} )
      && $var->{scope} =~ /GLOBAL/
      && !( $var->{modifier} =~ /(const|volatile)/ ) )
    {
      $var->{scope} = 'LOCAL';
    }
    $var->{ival} = $self->define_value( $var->{type} );
    $var->{val}  = $var->{ival};
    push @{ $self->{vars} }, $var;

    unless ( $self->{config}->get('debug_mode') ) {    #unless or if??
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

  my $value = Math::BigInt->new(0);    # is this line necessary??
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
	
	# ループ変数の名前の数字を初期化
	for ( 0 .. scalar(@{$self->{config}->get('loop_var_name')}) - 1 ) {
		$self->{loop_var_name_num}->[$_] = 0;
	}
	
	my $statements = $self->generate_statement(1, $rest_of_roots, 1);
	if( ref($statements) eq 'ARRAY' ) {
		push @{$self->{roots}}, @$statements;
	}
	else {
		push @{$self->{roots}}, $statements;
	}
	
	unless ($self->{config}->get('debug_mode')) { #unless or if??
		local $| = 1;
		print "seed : $self->{seed}\t";
		print "generate statements now.. (", $self->{root_max} - $rest_of_roots, "/$self->{root_max})";
		print "\r";
		local $| = 0;
	}
}

sub generate_statement {
    my ($self, $depth, $rest_of_roots, $path) = @_;
	
	my $statements = [];
	my $root_use_num;
	my $nest_path = 1;
	
	do {
		# ブロック内の式数がかたよらないように調整
		if ( $rest_of_roots < 20 ) {
			$root_use_num = int(rand($rest_of_roots-1)) + 1;
		}
		else {
			$root_use_num = int(rand(19)) + 1;
		}
		
		$rest_of_roots -= $root_use_num;
		
		my $st_type_rand = int(rand 10);
		if( $depth <= scalar(@{$self->{config}->get('loop_var_name')}) &&
			$st_type_rand > 7 &&
			$root_use_num >= 3) {
			my $st_type = 'for';
			my $loop_var_name = $self->{config}->get('loop_var_name');
			my $name = "$loop_var_name->[$depth-1]" . "$self->{loop_var_name_num}->[$depth-1]";
			my $init_st;
			my $continuation_cond;
			my $re_init_st;
			my $inequality_sign;
			
			# forは2種類
			my $type = int(rand(2));
			if( $type == 0 ) { # ループ回数1回
				#暫定
				$init_st = $self->generate_expressions(0);
				$init_st->{type} = 'int';
				$init_st->{val} = 0;
				$continuation_cond = $self->generate_expressions(0);
				$continuation_cond->{type} = 'int';
				$continuation_cond->{val} = 1;
				$re_init_st = $self->generate_expressions(0);
				$re_init_st->{type} = 'int';
				$re_init_st->{val} = 1;
				$inequality_sign = '<';
				
				if ( $path == 0 ) { $nest_path = 0; }
				else { $nest_path = 1; }
			}
			else { # ループ回数0回
				#暫定
				$init_st = $self->generate_expressions(0);
				$init_st->{type} = 'int';
				$init_st->{val} = 0;
				$continuation_cond = $self->generate_expressions(0);
				$continuation_cond->{type} = 'int';
				$continuation_cond->{val} = 0;
				$re_init_st = $self->generate_expressions(0);
				$re_init_st->{type} = 'int';
				$re_init_st->{val} = 1;
				$inequality_sign = '<';
				
				$nest_path = 0;
			}
			
			my $body = $self->generate_statement($depth+1, $root_use_num - 3, $nest_path);
			
			my $st = +{
				st_type 			=> $st_type,
				loop_var_name	 	=> $name,
				init_st				=> $init_st,
				continuation_cond	=> $continuation_cond,
				re_init_st			=> $re_init_st,
				inequality_sign		=> $inequality_sign,
				statements			=> $body,
			};
			
			push @$statements, $st;
		}
		elsif( $st_type_rand <= 7 && $st_type_rand > 5 && $root_use_num >= 1 ) {
			my $st_type = 'if';
			my $exp_cond;
			my $st_then;
			my $st_else;
			
			# ifは4種類
			my $type = int(rand(4));
			if ( $type == 0 ) { # ifのみ && 真
				$exp_cond = $self->generate_expressions(0);
				$exp_cond->{type} = 'int';
				$exp_cond->{val} = 1;
				if ( $path == 0 ) { $nest_path = 0; }
				else { $nest_path = 1; }
				$st_then = $self->generate_statement($depth+1, $root_use_num - 1, $nest_path);
				$st_else = [];
			}
			elsif ( $type == 1 ) { # ifのみ && 偽
				$exp_cond = $self->generate_expressions(0);
				$exp_cond->{type} = 'int';
				$exp_cond->{val} = 0;
				$nest_path = 0;
				$st_then = $self->generate_statement($depth+1, $root_use_num - 1, $nest_path);
				$st_else = [];
			}
			elsif ( $type == 2 ) { # elseあり && 真
				$exp_cond = $self->generate_expressions(0);
				$exp_cond->{type} = 'int';
				$exp_cond->{val} = 1;
				if ( $path == 0 ) { $nest_path = 0; }
				else { $nest_path = 1; }
				$st_then = $self->generate_statement($depth+1, $root_use_num - 1, $nest_path);
				$st_else = $self->generate_statement($depth+1, $root_use_num - 1, 0);
			}
			else { # elseあり && 偽
				$exp_cond = $self->generate_expressions(0);
				$exp_cond->{type} = 'int';
				$exp_cond->{val} = 0;
				if ( $path == 0 ) { $nest_path = 0; }
				else { $nest_path = 1; }
				$st_then = $self->generate_statement($depth+1, $root_use_num - 1, 0);
				$st_else = $self->generate_statement($depth+1, $root_use_num - 1, $nest_path);
			}
			
			my $st = +{
				st_type  => $st_type,
				exp_cond => $exp_cond,
				st_then  => $st_then,
				st_else  => $st_else,
			};
			
			push @$statements, $st;
		}
		else {
			for(0 .. $root_use_num) {
				my $st_type = 'assign';
				my $expression = $self->generate_expressions(1);
				my $assign = +{
					st_type	=> $st_type,
					path	=> $path,
					type	=> $expression->{type},
					val		=> $expression->{val},
					root	=> $expression->{root},
					var		=> $expression->{var},
					print_statement => 1,
				};
				push @$statements, $assign;
			}
		}
	} while ($rest_of_roots > 0 );
	
	return $statements;
}

sub generate_expressions {
	my ($self, $gen_tvar) = @_;
	
    my $undef_root = 0;
	
	my $expression_size = $self->{expression_size};
	$self->generate_expression($expression_size, 32);
	
	$self->type_compute($self->{root});
	
	Orange3::Generator::Expect::value_compute(
		$self->{root}, $self->{vars}, $self->{config}, $self->{avoide_undef}
	);
	
	my $val = $self->{root}->{out}->{val};
	
	if ( $gen_tvar ) {
		push @{$self->{vars}}, $self->generate_t_var(
			$self->{root}->{out}->{type},
			$self->{root}->{out}->{val},
			$self->{tval_count},
		);
		$self->{tval_count}++;
	}
	
    if ($undef_root > 0) {
        push @{$self->{undef_seeds}}, $self->{seed} if $self->{config}->get('debug_mode');
    }
	if ( $gen_tvar ) {
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

sub generate_expression {
  my ( $self, $node, $depth, $slope_degree ) = @_;

  $slope_degree = ( int( rand(5) ) ) * 25;
  my $left  = 0;
  my $right = 0;
  $node--;

  if ( $node <= 0 || $depth <= 0 ) {
    $left  = $self->_select_varnode();
    $right = $self->_select_varnode();
  }
  else {
    $depth -= 1;
    my $lnode_max =
      ( $depth / 6 ) * ( $depth + 1 ) * ( ( 2 * $depth ) + 1 ) + 1;
    my $lnode_min = $node - $lnode_max;

    if ( $lnode_min < 0 ) {
      $lnode_min = 0;
    }

    my $lnode = int( ( $lnode_max - $lnode_min + 1 ) * rand() + $lnode_min );
    if ( $lnode > $node ) {
      $lnode = int( ( $node - $lnode_min + 1 ) * rand() + $lnode_min );
      $lnode = int( $node * ( $slope_degree / 100 ) );
    }

    if ( $lnode == 0 ) {
      $left = $self->_select_varnode();
    }
    else {
      $left = $self->generate_expression( $lnode, $depth, $slope_degree );
    }

    my $rnode = $node - $lnode;
    if ( $rnode == 0 ) {
      $right = $self->_select_varnode();
    }
    else {
      $right = $self->generate_expression( $rnode, $depth, $slope_degree );
    }
  }

  $self->{root} = {
    ntype => 'op',
    otype => random_select( $self->{config}->get('operators') ),
    in    => [
      {
        ref         => $left,
        print_value => 0
      },
      {
        ref         => $right,
        print_value => 0
      }
    ],
  };
  return $self->{root};    #TODO remove
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

sub type_compute {
  my ( $self, $n ) = @_;

  my $arithmetic =
    Orange3::Generator::Arithmetic->new( config => $self->{config}, );

  if ( $n->{ntype} eq 'var' ) {
    $n->{out}->{type} = $n->{var}->{type};
  }
  elsif ( $n->{ntype} eq 'op' ) {
    for my $i ( @{ $n->{in} } ) {
      if ( $i->{print_value} == 0 ) {
        $self->type_compute( $i->{ref} );
      }
    }

    # Cast float to integer
    if ( $n->{otype} eq "%"
      || $n->{otype} eq "<<"
      || $n->{otype} eq ">>"
      || $n->{otype} eq "|"
      || $n->{otype} eq "^"
      || $n->{otype} eq "&" )
    {
      for my $k ( @{ $n->{in} } ) {

        # my $type = $k->{ref}->{out}->{type};
        my $type =
          ( $k->{print_value} == 2 ) ? $k->{type} : $k->{ref}->{out}->{type};
        if ( $type eq "double" || $type eq "long double" || $type eq "float" ) {

          # Cast float to integer
          $k->{ref} = insert_cast( $k->{ref} );
        }
      }
    }

    # In the case of shift operation, arithmetic type conversion does not apply
    # The type of the result will be the type of the left operand.
    if ( $n->{otype} eq "<<" || $n->{otype} eq ">>" ) {

      # Integral extension
      for my $k ( @{ $n->{in} } ) {
        if ( $k->{print_value} == 2 ) {
          $k->{type} = $self->integral_promotion( $k->{type} );
        }
        else {
          $k->{ref}->{out}->{type} =
            $self->integral_promotion( $k->{ref}->{out}->{type} );
        }
      }

      # To become the type of the left operand
      $n->{out}->{type} =
        ( $n->{in}->[0]->{print_value} == 2 )
        ? $n->{in}->[0]->{type}
        : $n->{in}->[0]->{ref}->{out}->{type};

      for my $k ( @{ $n->{in} } ) {
        $k->{type} =
          ( $k->{print_value} == 2 ) ? $k->{type} : $k->{ref}->{out}->{type};
      }

    }

    # In the case of relational operators (to integer)
    elsif ( $n->{otype} eq "<"
      || $n->{otype} eq ">"
      || $n->{otype} eq "<="
      || $n->{otype} eq ">="
      || $n->{otype} eq "!="
      || $n->{otype} eq "=="
      || $n->{otype} eq "&&"
      || $n->{otype} eq "||" )
    {
      # Integral extension
      for my $k ( @{ $n->{in} } ) {
        if ( $k->{print_value} == 2 ) {
          $k->{type} = $self->integral_promotion( $k->{type} );
        }
        else {
          $k->{ref}->{out}->{type} =
            $self->integral_promotion( $k->{ref}->{out}->{type} );
        }
      }

      my $left_type =
        ( $n->{in}->[0]->{print_value} == 2 )
        ? $n->{in}->[0]->{type}
        : $n->{in}->[0]->{ref}->{out}->{type};
      my $right_type =
        ( $n->{in}->[1]->{print_value} == 2 )
        ? $n->{in}->[1]->{type}
        : $n->{in}->[1]->{ref}->{out}->{type};

      $n->{out}->{type} =
        $arithmetic->arithmetic_conversion( $left_type, $right_type );

      for my $k ( @{ $n->{in} } ) {
        if ( $k->{print_value} == 2 ) {
          ;
        }
        else {
          $k->{type} = $k->{ref}->{out}->{type};

          # Look at the person of the result, also change the original type
          $k->{type} = $n->{out}->{type};
        }
      }
      $n->{out}->{type} = "signed int";
    }
    elsif ( $n->{otype} eq "(signed int)" ) {
      ;
    }
    else {
      # Integral extension
      for my $k ( @{ $n->{in} } ) {
        if ( $k->{print_value} == 2 ) {
          $k->{type} = $self->integral_promotion( $k->{type} );
        }
        else {
          $k->{ref}->{out}->{type} =
            $self->integral_promotion( $k->{ref}->{out}->{type} );
        }
      }

      # Otherwise arithmetic type conversion
      my $left_type =
        ( $n->{in}->[0]->{print_value} == 2 )
        ? $n->{in}->[0]->{type}
        : $n->{in}->[0]->{ref}->{out}->{type};
      my $right_type =
        ( $n->{in}->[1]->{print_value} == 2 )
        ? $n->{in}->[1]->{type}
        : $n->{in}->[1]->{ref}->{out}->{type};

      $n->{out}->{type} =
        $arithmetic->arithmetic_conversion( $left_type, $right_type );

      for my $k ( @{ $n->{in} } ) {
        if ( $k->{print_value} == 2 ) {
          ;
        }
        else {
          $k->{type} = $k->{ref}->{out}->{type};

          # Look at the person of the result, also change the original type
          $k->{type} = $n->{out}->{type};
        }
      }
    }

    #20141108 Added.
    for my $i ( @{ $n->{in} } ) {
      if ( $i->{print_value} == 2 ) {
        $i->{ref}->{out}->{type} = $i->{type};
      }
    }
  }
}

# Integral extension
sub integral_promotion {
  my ( $self, $type ) = @_;

  my $bits            = $self->{config}->get('type')->{$type}->{bits};
  my $signed_int_bits = $self->{config}->get('type')->{'signed int'}->{bits};

  if ( $bits < $signed_int_bits ) {
    $type =~ s/^(unsigned|signed) (char|short)$/signed int/;
  }
  elsif ( $bits == $signed_int_bits ) {
    $type =~ s/(char|short)$/int/;
  }
  elsif ( $bits > $signed_int_bits ) {
    ;
  }
  else {
    Carp::croak("Invalid value: ($bits, $signed_int_bits)");
  }

  return $type;
}

sub insert_cast {
  my ($ref) = @_;

  my $i = {
    type        => $ref->{out}->{type},
    val         => undef,
    ref         => $ref,
    print_value => 0,
  };

  my $o = {
    type => 'signed int',
    val  => undef,
  };

  my $n = {
    ntype => 'op',
    otype => '(signed int)',
    in    => [$i],
    out   => $o
  };

  return $n;
}

# Accessor
sub vars            { @{ shift->{vars} }; }
sub roots           { @{ shift->{roots} }; }
sub expression_size { shift->{expression_size}; }
sub root_max        { shift->{root_max}; }
sub var_max         { shift->{var_max}; }

1;
