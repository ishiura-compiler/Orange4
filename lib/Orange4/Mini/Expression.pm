package Orange4::Mini::Expression;

use strict;
use warnings;
use Carp ();
use Data::Dumper;
use Orange4::Mini::Backup;
use Orange4::Mini::Util;
use Orange4::Mini::Compute;

sub new {
    my ( $class, $config, $vars, $assigns, %args ) = @_;

    bless {
        config  => $config,
        vars    => $vars,
        assigns => $assigns,
        main_vars => $args{main_vars},
        main_assigns => $args{main_assigns},
        func_vars => $args{func_vars},
        func_assigns => $args{func_assigns},
        func_list => $args{func_list},
        run     => $args{run},
        status  => $args{status},
        backup  => Orange4::Mini::Backup->new( $vars, $assigns, $args{func_vars}, $args{func_assigns}),
        %args,
    }, $class;
}

sub binary_texpression_cut_first {
    my $self   = shift;

    my $number = @{ $self->{assigns} };
    $self->{backup}->_backup_var_and_assigns;
    $self->{expression}->{left_begin}   = 0;
    $self->{expression}->{left_number}  = int $number / 2;
    $self->{expression}->{right_begin}  = $self->{expression}->{left_number};
    $self->{expression}->{right_number} =
        $number - $self->{expression}->{left_number};
    $self->binary_texpression_cut;
}

sub binary_texpression_cut_right {
    my $self = shift;

    $self->{expression}->{left_begin}   = $self->{expression}->{right_begin};
    $self->{expression}->{left_number}  = int $self->{expression}->{right_number} / 2;
    $self->{expression}->{right_begin}  = $self->{expression}->{left_begin} + $self->{expression}->{left_number};
    $self->{expression}->{right_number} = $self->{expression}->{right_number} - $self->{expression}->{left_number};
    $self->binary_texpression_cut;
}

sub binary_texpression_cut_left {
    my $self    = shift;

    my $total = $self->{expression}->{left_number};
    $self->{expression}->{left_begin}   = $self->{expression}->{left_begin};
    $self->{expression}->{left_number}  = int $self->{expression}->{left_number} / 2;
    $self->{expression}->{right_begin}  = $self->{expression}->{left_begin} + $self->{expression}->{left_number};
    $self->{expression}->{right_number} = $total - $self->{expression}->{left_number};
    $self->binary_texpression_cut;
}

sub binary_texpression_cut_both {
    my $self = shift;

    my $expression;
    $expression = $self->_clone_expression_number( $self->{expression}, $expression );
    $self->binary_texpression_cut_left;
    $self->{expression} = $self->_clone_expression_number( $expression, $self->{expression} );
    $self->binary_texpression_cut_right;
}

sub _clone_expression_number {
    my ( $self, $expression, $clone_expression ) = @_;

    $clone_expression->{left_begin}   = $expression->{left_begin};
    $clone_expression->{left_number}  = $expression->{left_number};
    $clone_expression->{right_begin}  = $expression->{right_begin};
    $clone_expression->{right_number} = $expression->{right_number};
    return $clone_expression;
}

sub binary_texpression_cut {
    my $self = shift;

    if ( $self->{expression}->{left_number} + $self->{expression}->{right_number} > 1 ) {
        $self->_expression_tree_off_right;
        $self->texpression_cut_mask;
        if ( !$self->_generate_and_test ) {
            $self->_expression_tree_on_right;
            $self->_expression_tree_off_left;
            $self->texpression_cut_mask;
            if ( !$self->_generate_and_test ) {
                $self->_expression_tree_on_left;
                $self->binary_texpression_cut_both;
            }
            else {
                $self->binary_texpression_cut_right;
            }
        }
        else {
            $self->binary_texpression_cut_left;
        }
    }
}

sub _expression_tree_off_right {
    my $self = shift;

    $self->_expression_tree_off( $self->{expression}->{right_begin},
        $self->{expression}->{right_begin} + $self->{expression}->{right_number} - 1 );
}

sub _expression_tree_off_left {
    my $self = shift;

    $self->_expression_tree_off( $self->{expression}->{left_begin},
        $self->{expression}->{left_begin} + $self->{expression}->{left_number} - 1 );
}

sub _expression_tree_on_right {
    my $self = shift;

    $self->_expression_tree_on( $self->{expression}->{right_begin},
        $self->{expression}->{right_begin} + $self->{expression}->{right_number} - 1 );
}

sub _expression_tree_on_left {
    my $self = shift;

    $self->_expression_tree_on( $self->{expression}->{left_begin},
        $self->{expression}->{left_begin} + $self->{expression}->{left_number} - 1 );
}

sub lossy_texpression_cut_possible {
    my $self = shift;

    my $all_update = 0;
    my $one_update = 0;
    $self->{backup}->_backup_var_and_assigns;
    do {
        $one_update = $self->lossy_texpression_cut;
        $all_update = $one_update ? 1 : $all_update;
        } while ( Orange4::Mini::Util::_count_defined_assign( $self->{assigns} ) > 1
        && $one_update );

    return $all_update;
}

sub lossy_texpression_cut {
    my $self = shift;

    my $update = 0;

    for my $i ( 0 .. $#{ $self->{assigns} } ) {
        my $expression = Orange4::Mini::Util::_count_assign_exp( $self->{assigns} );
        my $expression_only =
            Orange4::Mini::Util::_count_assign_exp_only( $self->{assigns} );
        my $ps = $self->{assigns}->[$i]->{print_statement};
        if ( $expression > 1
            && Orange4::Mini::Util::_check_assign( $self->{assigns}->[$i] ) )
        {
            $self->_expression_tree_off( $i, $i );
            $self->texpression_cut_mask;
            if ( !$self->_generate_and_test ) {
                if ( $ps != 2 && $expression - $expression_only > 1 ) {
                    $self->_expression_tree_exp_only_on( $i, $i );
                    $self->texpression_cut_mask;
                    if ( !$self->_generate_and_test ) {
                        $self->{assigns}->[$i]->{print_statement} = $ps;
                    }
                    else {
                        $update = 1;
                    }
                }
                else {
                    $self->{assigns}->[$i]->{print_statement} = $ps;
                }
            }
            else {
                $expression--;
                $update = 1;
            }
        }
    }

    return $update;
}

sub _expression_tree_on {
    my ( $self, $start, $end ) = @_;

    $self->{backup}->_restore_var;
    for my $i ( $start .. $end ) {

        $self->{backup}->_restore_assign_number($i);
        $self->{assigns}->[$i]->{print_statement} = 1;
    }
}

sub _expression_tree_off {
    my ( $self, $start, $end ) = @_;

    $self->{backup}->_backup_var;

    for my $i ( $start .. $end ) {
        my $assign_i = $self->{assigns}->[$i];
        if ( Orange4::Mini::Util::_check_assign($assign_i) ) {
            $self->varset_t_val_reset($i);

            # delete $assign_i->{root};
            $assign_i->{print_statement} = 0;
        }
    }
}

sub _expression_tree_exp_only_on {
    my ( $self, $start, $end ) = @_;

    $self->{backup}->_restore_var;
    for my $i ( $start .. $end ) {
        $self->{backup}->_restore_assign_number($i);
        $self->{assigns}->[$i]->{print_statement} = 2;
    }
}

sub varset_t_val_reset {
    my ( $self, $i ) = @_;

    my $assign_i = $self->{assigns}->[$i];
    for my $var ( @{ $self->{vars} } ) {
        if ( $var->{name_type} eq 't' && $var->{name_num} eq $assign_i->{name_num} ) {
          if (defined $var->{elements} ) {
            # 左辺配列
            $self->reset_array_val($var->{ival}, $assign_i->{var}->{elements}, 0, $assign_i->{root}->{out}->{val});
          }
          elsif (defined $assign_i->{var}->{elements}) {
            # 左辺構造体
            my $struct_members = $self->replace_elements($assign_i->{var}->{elements});
            $self->reset_array_val($var->{ival}, $struct_members, 0, $assign_i->{root}->{out}->{val});
          }
          else {
            # 左辺変数
            $var->{type} = $assign_i->{root}->{out}->{type};
            $var->{ival} = $assign_i->{root}->{out}->{val};
            $var->{val}  = $assign_i->{root}->{out}->{val};

            $assign_i->{var} = $var;
          }
            last;
        }
    }
}

sub replace_elements {
  my ($self, $elements) = @_;
  my $re_ele = [];

  for my $ele (@$elements)
  {
    if ($ele =~ /[0-9]{1,}/)
    {
      push @$re_ele, $&;
    }
  }
  return $re_ele;
}


sub reset_array_val {
  my ($self, $var_elements, $element, $ele_num, $val) = @_;

  if (defined $element->[$ele_num + 1]) {
    $self->reset_array_val($var_elements->[$element->[$ele_num]], $element, $ele_num + 1, $val);
  }
  else {
    $var_elements->[$element->[$ele_num]] = $val;
    return;
  }
}

sub texpression_cut_mask {
    my $self = shift;

    my $s = "t(";
    for my $i ( 0 .. @{ $self->{assigns} } - 1 ) {
        my $assign_i = $self->{assigns}->[$i];
        if ( Orange4::Mini::Util::_check_assign($assign_i) ) {
            if ( $assign_i->{print_statement} == 1 ) {
                $s .= "@";
            }
            elsif ( $assign_i->{print_statement} == 2 ) {
                $s .= "%";
            }
        }
        else {
            $s .= "+";
        }
    }
    $s .= ")";
    $self->_print("$s");
}

sub _generate_and_test {
    my $self = shift;
    return Orange4::Mini::Compute->new(
        $self->{config},
        $self->{main_vars},
        $self->{main_assigns},
        $self->{func_vars},
        $self->{func_assigns},
        run    => $self->{run},
        status => $self->{status},
    )->_generate_and_test;
}

sub _print {
    my ( $self, $body ) = @_;

    Orange4::Mini::Util::print( $self->{status}->{debug}, $body );
}

1;
