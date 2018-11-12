package Orange4::Mini::Function_declaration;

use strict;
use warnings;
use Carp ();

use Orange4::Mini::Backup;
use Orange4::Mini::Util;
use Smart::Comments;

sub new {
    my ( $class, $config, $vars, $assigns, $func_vars, $func_assigns, %args ) = @_;

    bless {
        config       => $config,
        vars         => $vars,
        assigns      => $assigns,
        func_vars    => $func_vars,
        func_assigns => $func_assigns,
        run          => $args{run},
        status       => $args{status},
        used_func    => [],
        backup       => Orange4::Mini::Backup->new( $vars, $assigns, $func_vars, $func_assigns ),
        minimize_var => undef,
        %args,
    }, $class;
}

sub delete_unused_function {
    my ($self, $statements, $func_list) = @_;

    $self->reset_used_func($func_list);
    $self->search_used_function($statements, $func_list);
    for my $func ( @{$func_list} ){
        if ($func->{print_tree} >= 0) {
            $self->search_used_function($func->{statements}, $func_list);
        }
    }
    if( $self->check($func_list) == 0 ){
        for my $func ( @$func_list ){
            $func->{print_tree} = 1;
        }
    }
    $self->delete_expected_statement($func_list);
}

sub delete_expected_statement {
  my ($self, $func_list) = @_;

  for my $func ( @$func_list ){
      if( $func->{print_tree} == 1 ){
          for my $arg (@{$func->{args_list}}) {
            $arg->{print_arg} = 0;
          }
      }
      if( $self->_generate_and_test == 1 ){ ; }
      else {
        for my $arg (@{$func->{args_list}}) {
          $arg->{print_arg} = 1;
          if( $self->_generate_and_test == 1 ){
            last;
          }
        }
      }
  }
}

sub check {
    my ($self, $func_list) = @_;

    if( $self->_generate_and_test == 1 ){
        return 1;
    }
    else{
        for my $func ( @$func_list ){
            if( $func->{print_tree} == 0 ){
                $func->{print_tree} = 1;
                if( $self->_generate_and_test ){
                    return 1;
                }
            }
        }
    }
    return 0;
}

sub reset_used_func {
    my ($self, $func_list) = @_;

    for my $func ( @$func_list ){
        $func->{print_tree}--;
    }
}

sub search_used_function {
    my ($self, $statements, $func_list) = @_;
    $self->search_void_function($statements, $func_list);
}

# 文内からvoid関数を探す
sub search_void_function {
    my ($self, $statements, $func_list) = @_;

    for my $st ( @{$statements} ){

        if( $st->{st_type} eq 'function_call' ){
            if ($st->{print_tree} == 1) {

            $func_list->[$st->{name_num}]->{print_tree} = 1;
            for my $exp ( @{$st->{args_expressions}} ){
                if (ref $exp->{val} ne "ARRAY") {
                  $self->search_non_void_function($exp->{root}, $func_list);
                }
            }
            if( defined $st->{args_num_expression} ){
                $self->search_non_void_function($st->{args_num_expression}->{root}, $func_list);
              }
            }
        }
        elsif( $st->{st_type} eq 'while' ){
            if( $st->{print_tree} != 0 ){
                $self->search_non_void_function($st->{continuation_cond}->{root}, $func_list);
                if( defined $st->{st_condition_for_break} ){
                    $self->search_non_void_function($st->{st_condition_for_break}->{root}, $func_list);
                }
            }

            if( ($st->{print_tree} == 0) ||
                ($st->{print_tree} == 1) ||
                ($st->{print_tree} == 4) ){
                $self->search_void_function($st->{statements}, $func_list);
            }
        }
        elsif( $st->{st_type} eq 'if' ){
            if( $st->{print_tree} != 0 ){
                $self->search_non_void_function($st->{exp_cond}->{root}, $func_list);
            }

            if( $st->{print_tree} == 1 ||
                $st->{print_tree} == 4 ){
                    $self->search_void_function($st->{st_then}, $func_list);
                    $self->search_void_function($st->{st_else}, $func_list);
            }
            elsif( $st->{print_tree} == 0 ||
                   $st->{print_tree} == 2 ){
                if( $st->{exp_cond}->{val} != 0 ){
                    $self->search_void_function($st->{st_then}, $func_list);
                }
                else{
                    $self->search_void_function($st->{st_else}, $func_list);
                }
            }
        }
        elsif( $st->{st_type} eq 'for' ){
            if( $st->{print_tree} != 0 ){
                $self->search_non_void_function($st->{st_init}->{root}, $func_list);
                $self->search_non_void_function($st->{continuation_cond}->{root}, $func_list);
                $self->search_non_void_function($st->{st_reinit}->{root}, $func_list);
            }

            if( ($st->{print_tree} == 0) ||
                ($st->{print_tree} == 1) ||
                ($st->{print_tree} == 2 && $st->{loop_path} == 1 ) ||
                ($st->{print_tree} == 4) ){
                $self->search_void_function($st->{statements}, $func_list);
            }
        }
        elsif( $st->{st_type} eq 'switch' ){
            if( $st->{print_tree} != 0 ){
                $self->search_non_void_function($st->{continuation_cond}->{root}, $func_list);
            }

            for my $case ( @{$st->{cases}} ){
                if( ($st->{print_tree} == 0 && $case->{path} == 1) ||
                    ($st->{print_tree} == 1) ||
                    ($st->{print_tree} == 4 && $case->{path} == 1) ||
                    ($st->{print_tree} == 5 && $case->{print_case} == 1) ){
                    $self->search_void_function($case->{statements}, $func_list);
                }
            }
        }
        elsif( $st->{st_type} eq 'array') {
            if ($st->{print_statement}) {
                $self->search_non_void_function($st->{sub_root}, $func_list);
            }
        }
        elsif( $st->{st_type} eq 'assign' ){
          if ($st->{print_statement}) {
            $self->search_non_void_function($st->{root}, $func_list);
            if (defined $st->{sub_root}) {
                $self->search_non_void_function($st->{sub_root}, $func_list);
            }
          }
        }
        else{
            Carp::croak("Invalid st_type: $st->{st_type}");
        }
    }
}

sub check_double {
    my ($self, $name_num, $array) = @_;

    for my $num ( @$array ){
        if( $num == $name_num ){
            return 0;
        }
    }

    return 1;
}

# 式内からvoid以外の関数を探す
sub search_non_void_function {
    my ($self, $n, $func_list) = @_;

    if( $n->{ntype} eq 'var' ) { ; }
    elsif( $n->{ntype} eq 'op' ){
        if( $n->{otype} =~ /func/ ){
            # print "$n->{otype}\n";
            $n->{otype} =~ /func(\d+)/;
            my $func_num = $1;
            $func_list->[$func_num]->{print_tree} = 1;
            for my $operand ( @{$n->{in}} ){
                if (ref $operand->{ref}->{val} ne 'ARRAY') {
                    my $print_value = $operand->{print_value};
                    if( $print_value == 0 ){
                        my $h = $operand->{ref};
                        $self->search_non_void_function($h, $func_list);
                    }
                    else{ ; }
                }                                                                               
            }
            $self->search_non_void_function($func_list->[$func_num]->{return_val_expression}->{root}, $func_list);
        }
        elsif ($n->{otype} =~ /^\(.+\)$/ ) {
            for my $l (@{$n->{in}}){
                my $print_value = $l->{print_value};
                if( $print_value == 0 ){
                    my $h = $l->{ref};
                    $self->search_non_void_function($h, $func_list);
                }
                else{ ; }
            }
        }
        else{
            for my $operand( @{$n->{in}}  ){
                my $print_value = $operand->{print_value};
                my $h = $operand->{ref};
                if( $print_value == 0 ){
                    $self->search_non_void_function($h, $func_list);
                }
                else{ ; }
            }
        }
    }
    else{
        Carp::croak("Invalid type: $n->{ntype}");
    }
}

sub _generate_and_test {
    my $self = shift;

    return Orange4::Mini::Compute->new(
        $self->{config}, $self->{vars}, $self->{assigns}, $self->{func_vars}, $self->{func_assigns},
        run    => $self->{run},
        status => $self->{status},
    )->_generate_and_test;
}

1;
