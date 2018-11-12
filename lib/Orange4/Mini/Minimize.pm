package Orange4::Mini::Minimize;

use strict;
use warnings;
use Carp ();
use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);

use Orange4::Dumper;

use Data::Dumper;

use Orange4::Mini::Bottomup;
use Orange4::Mini::Constant;
use Orange4::Mini::Compute;
use Orange4::Mini::Expression;
use Orange4::Mini::Topdown;
use Orange4::Mini::Var;
use Orange4::Mini::Util;
use Orange4::Mini::For;
use Orange4::Mini::If;
use Orange4::Mini::Unionstruct;
use Orange4::Mini::Array;
use Orange4::Mini::VariableLengthArray;
use Orange4::Mini::While;
use Orange4::Mini::Switch;
use Orange4::Mini::Function_declaration;
use Orange4::Mini::Function_call;

sub new {
    my ( $class, $config, $statements, $vars, $func_list, $func_vars, $unionstructs, $assigns, $func_assigns, $variable_length_arrays, %args ) = @_;

    bless {
        config     => $config,
        statements => $statements,
        vars       => $vars,
        func_list  => $func_list,
        func_vars  => $func_vars,
        unionstructs => $unionstructs,
        assigns    => $assigns,
        func_assigns => $func_assigns,
        variable_length_arrays => $variable_length_arrays,
        run        => $args{run},
        status     => $args{status},
        backup     => Orange4::Mini::Backup->new( $vars, $assigns , $func_vars, $func_assigns ),
        %args,
    }, $class;
}

sub new_minimize {
    my $self = shift;

    if ( !$self->first_check ) {
        return 1;
    }
    if ( Orange4::Mini::Util::_count_defined_assign( $self->{assigns} ) == @{ $self->{assigns} } ) {
        $self->_new_minimize_first;
    }
    $self->_new_minimize_second_and_after;
    $self->_delete_unused_function;
    $self->final_check;
}

sub final_check {
    my $self = shift;

    if ( $self->_generate_and_test ) {
        $self->_print("\n****** COMPLETE MINIMIZE ******");
    }
    else {
        $self->_print("\n****** FAILED MINIMIZE ******");
    }
}

sub first_check {
    my $self = shift;

    $self->_print("\n****** REPRODUCIBLE CHECK ******");
    $self->{status}->{time_out} = 999;
    my $t0 = [gettimeofday];
    my $rreproducible = $self->_generate_and_test ? 1 : 0;
    my $t1 = [gettimeofday];
    if ($rreproducible) { $self->_print("\n****** START MINIMIZE ******"); }
    else {
        $self->_print("\n****** FAILED MINIMIZE (irreproducible) ******");
        $self->{status}->{program} = "FAILED MINIMIZE. (IRREPRODUCIBLE)";
    }
    my $execTime = int tv_interval( $t0, $t1 );
    $self->{status}->{time_out} = $execTime * 2 > 5 ? $execTime * 2 : 5;

    return $rreproducible;
}

sub _delete_unused_function{
    my $self = shift;

    $self->_must_print("------ DELETE UNUSED FUNCTIONS ------\n");
    my $function_declaration = Orange4::Mini::Function_declaration->new(
        $self->{config}, $self->{vars}, $self->{assigns}, $self->{func_vars}, $self->{func_assigns},
        run    => $self->{run},
        status => $self->{status},
        );
    $function_declaration->delete_unused_function($self->{statements}, $self->{func_list});
}

sub _new_minimize_function_return {
    my $self = shift;

    my $update = 0;

    for my $i ( 0 .. $#{ $self->{func_assigns} } ){
        if( defined($self->{func_list}->[$i]->{return_val_expression}) && $self->{func_list}->[$i]->{print_tree} == 1 ){
            $self->_must_print("------ [FUNC$i] RETURN EXP REDUCE ------\n");
            my $bottomup = Orange4::Mini::Bottomup->new(
                $self->{config},
                $self->{func_vars}->[$i]->{vars},
                $self->{func_assigns}->[$i],
                main_vars => $self->{vars},
                main_assigns => $self->{assigns},
                func_vars => $self->{func_vars},
                func_assigns => $self->{func_assigns},
                run    => $self->{run},
                status => $self->{status},
                );

            do {
                $update = $bottomup->minimize_inorder_head( $self->{func_list}->[$i]->{return_val_expression}->{root}, 0 );
            } while ( $update == 1 );
        }
    }
}

sub _new_minimize_first_binary_texpression_cut {
    my $self = shift;

    for my $i ( 0 .. $#{ $self->{func_assigns} } ){
        if ( Orange4::Mini::Util::_count_defined_assign( $self->{func_assigns}->[$i] ) > 1 && $self->{func_list}->[$i]->{print_tree} == 1) {
            $self->_must_print("------ [FUNC$i] BINARY EXPRESSION CUT ------\n");
            my $expression = Orange4::Mini::Expression->new(
                $self->{config},
                $self->{func_vars}->[$i]->{vars},
                $self->{func_assigns}->[$i],
                main_vars => $self->{vars},
                main_assigns => $self->{assigns},
                func_vars => $self->{func_vars},
                func_assigns => $self->{func_assigns},
                func_list => $self->{func_list},
                run    => $self->{run},
                status => $self->{status},
                );
            $expression->binary_texpression_cut_first;
        }
    }

    if ( Orange4::Mini::Util::_count_defined_assign( $self->{assigns} ) > 1 ) {
        $self->_must_print("------ BINARY EXPRESSION CUT ------\n");
        my $expression = Orange4::Mini::Expression->new(
            $self->{config}, $self->{vars},
            $self->{assigns},
            main_vars => $self->{vars},
            main_assigns => $self->{assigns},
            func_vars => $self->{func_vars},
            func_assigns => $self->{func_assigns},
            func_list => $self->{func_list},
            run    => $self->{run},
            status => $self->{status},
            );
        $expression->binary_texpression_cut_first;
    }
}

sub _new_minimize_first_assign_minimize {
    my $self = shift;

    # if ( $self->_new_minimize_top_down ) { $self->_new_minimize_first_inorder; }
    # else                                 { $self->_new_minimize_first_preorder; }

    $self->_new_minimize_first_inorder;
    $self->_new_minimize_for_and_if_arguments;
    $self->_new_minimize_function_return;
}

sub _new_minimize_top_down {
    my $self = shift;

    my $update = 0;
    $self->_must_print("------ TOP-DOWN EXPRESSION REDUCE ------\n");
    for my $i ( 0 .. $#{ $self->{assigns} } ) {
        if ( Orange4::Mini::Util::_check_assign( $self->{assigns}->[$i] ) ) {
            $self->_print("\n------ TOP-DOWN EXPRESSION REDUCE(t$i) ------\n");
            my $topdown = Orange4::Mini::Topdown->new(
                $self->{config}, $self->{vars}, $self->{assigns},
                run    => $self->{run},
                status => $self->{status},
            );
            $update = $topdown->top_down_prepare($i) ? 1 : $update;
        }
    }

    return $update;
}

sub _new_minimize_final_top_down {
    my $self = shift;

    my $update = 0;
    $self->_must_print("------ TOP-DOWN FINAL EXPRESSION REDUCE ------\n");
    for my $i ( 0 .. $#{ $self->{assigns} } ) {
        if ( Orange4::Mini::Util::_check_assign( $self->{assigns}->[$i] ) ) {
            $self->_print("\n------ TOP-DOWN FINAL EXPRESSION REDUCE(t$i) ------\n");
            my $topdown = Orange4::Mini::Topdown->new(
                $self->{config}, $self->{vars}, $self->{assigns},
                run    => $self->{run},
                status => $self->{status},
            );
            $update = $topdown->top_down_final_prepare($i) ? 1 : $update;
        }
    }

    return $update;
}

sub _new_minimize_first_inorder {
    my $self = shift;

    for my $i ( 0 .. $#{ $self->{func_assigns} } ){
        if ($self->{func_list}->[$i]->{print_tree} == 1) {

        $self->_must_print("------ [FUNC$i] BOTTOM-UP INORDER EXPRESSION REDUCE ------\n");
        for my $j ( 0 .. $#{ $self->{func_assigns}->[$i] } ) {
            if ( Orange4::Mini::Util::_check_assign( $self->{func_assigns}->[$i]->[$j] ) ) {
                $self->_print(
                    "\n------ BOTTOM-UP INORDER EXPRESSION REDUCE(t$j) ------\n");
                my $bottomup = Orange4::Mini::Bottomup->new(
                    $self->{config},
                    $self->{func_vars}->[$i]->{vars},
                    $self->{func_assigns}->[$i],
                    main_vars => $self->{vars},
                    main_assigns => $self->{assigns},
                    func_vars => $self->{func_vars},
                    func_assigns => $self->{func_assigns},
                    run    => $self->{run},
                    status => $self->{status},
                    );
                $bottomup->minimize_inorder_head( $self->{func_assigns}->[$i]->[$j]->{root}, $j );
            }
        }
        }
    }

    $self->_must_print("------ BOTTOM-UP INORDER EXPRESSION REDUCE ------\n");
    for my $i ( 0 .. $#{ $self->{assigns} } ) {
        if ( Orange4::Mini::Util::_check_assign( $self->{assigns}->[$i] ) ) {
            $self->_print(
                "\n------ BOTTOM-UP INORDER EXPRESSION REDUCE(t$i) ------\n");
            my $bottomup = Orange4::Mini::Bottomup->new(
                $self->{config},
                $self->{vars},
                $self->{assigns},
                main_vars => $self->{vars},
                main_assigns => $self->{assigns},
                func_vars => $self->{func_vars},
                func_assigns => $self->{func_assigns},
                run    => $self->{run},
                status => $self->{status},
                );
            $bottomup->minimize_inorder_head( $self->{assigns}->[$i]->{root}, $i );
        }
    }
}

sub _new_minimize_first_left_array {
    my $self = shift;

    for my $i ( 0 .. $#{ $self->{func_assigns} } ){
        if ($self->{func_list}->[$i]->{print_tree} == 1) {
            $self->_must_print("------ [FUNC$i] BOTTOM-UP INORDER EXPRESSION REDUCE ------\n");
            for my $j ( 0 .. $#{ $self->{func_assigns}->[$i] } ) {
                if ( Orange4::Mini::Util::_check_assign( $self->{func_assigns}->[$i]->[$j] ) ) {
                    if (defined $self->{func_assigns}->[$i]->[$j]->{sub_root} && $self->{func_assigns}->[$i]->[$j]->{print_statement}) {
                        if ($self->{func_assigns}->[$i]->[$j]->{var}->{replace_flag} !=  1){


                        $self->_print(
                            "\n------ BOTTOM-UP INORDER EXPRESSION REDUCE(t$j) ------\n");
                        my $bottomup = Orange4::Mini::Bottomup->new(
                            $self->{config},
                            $self->{func_vars}->[$i]->{vars},
                            $self->{func_assigns}->[$i],
                            main_vars => $self->{vars},
                            main_assigns => $self->{assigns},
                            func_vars => $self->{func_vars},
                            func_assigns => $self->{func_assigns},
                            run    => $self->{run},
                            status => $self->{status},
                            );
                        $bottomup->minimize_inorder_head( $self->{func_assigns}->[$i]->[$j]->{sub_root}, $j );
                        }
                    }
                }
            }
        }
    }

    $self->_must_print("------ BOTTOM-UP LEFT ARRAY EXPRESSION REDUCE ------\n");
    for my $i ( 0 .. $#{ $self->{assigns} } ) {
        if ( Orange4::Mini::Util::_check_assign( $self->{assigns}->[$i] ) ) {
          if (defined $self->{assigns}->[$i]->{sub_root} && $self->{assigns}->[$i]->{print_statement} ){
            if ($self->{assigns}->[$i]->{var}->{replace_flag} !=  1){
                $self->_print(
                    "\n------ BOTTOM-UP INORDER EXPRESSION REDUCE(t$i) ------\n");
                my $bottomup = Orange4::Mini::Bottomup->new(
                    $self->{config}, $self->{vars}, $self->{assigns},
                    main_vars => $self->{vars},
                    main_assigns => $self->{assigns},
                    func_vars => $self->{func_vars},
                    func_assigns => $self->{func_assigns},
                    run    => $self->{run},
                    status => $self->{status},
                );
                $bottomup->minimize_inorder_head( $self->{assigns}->[$i]->{sub_root}, $i );
            }
          }
        }
    }
}

sub _new_minimize_for_and_if_arguments {
    my $self = shift;

    my $update = 0;
    for my $i ( 0 .. $#{ $self->{func_assigns} } ){
        if ($self->{func_list}->[$i]->{print_tree} == 1) {
            $self->_must_print("------ [FUNC$i] CONTROL FLOW STATEMENTS ARGUMENTS REDUCE ------\n");
            my $bottomup = Orange4::Mini::Bottomup->new(
                $self->{config},
                $self->{func_vars}->[$i]->{vars},
                $self->{func_assigns}->[$i],
                main_vars => $self->{vars},
                main_assigns => $self->{assigns},
                func_vars => $self->{func_vars},
                func_assigns => $self->{func_assigns},
                run    => $self->{run},
                status => $self->{status},
                );
            do {
                $update = $bottomup->minimize_for_and_if_arguments( $self->{func_list}->[$i]->{statements} );
            } while ( $update == 1 );
        }
    }

    $update = 0;
    $self->_must_print("------ FOR AND IF ARGUMENTS REDUCE ------\n");
    my $bottomup = Orange4::Mini::Bottomup->new(
        $self->{config},
        $self->{vars},
        $self->{assigns},
        main_vars => $self->{vars},
        main_assigns => $self->{assigns},
        func_vars => $self->{func_vars},
        func_assigns => $self->{func_assigns},
        run    => $self->{run},
        status => $self->{status},
        );
    do {
        $update = $bottomup->minimize_for_and_if_arguments( $self->{statements} );
    } while ( $update == 1 );
}

sub _new_minimize_first_preorder {
    my $self = shift;

    $self->_must_print("------ BOTTOM-UP PREORDER EXPRESSION REDUCE ------\n");
    for my $i ( 0 .. $#{ $self->{assigns} } ) {
        if ( Orange4::Mini::Util::_check_assign( $self->{assigns}->[$i] ) ) {
            $self->_print(
                "\n------ BOTTOM-UP PREORDER EXPRESSION REDUCE(t$i) ------\n");
            my $bottomup = Orange4::Mini::Bottomup->new(
                $self->{config}, $self->{vars}, $self->{assigns},
                run    => $self->{run},
                status => $self->{status},
            );
            $bottomup->minimize_preorder( $self->{assigns}->[$i]->{root}, $i );
        }
    }
}

sub _new_minimize_first_for_tree_minimize {
    my $self = shift;

    my $update = 0;

    $self->_must_print("------ FOR TREE MINIMIZE ------\n");

    my $for = Orange4::Mini::For->new(
        $self->{config}, $self->{vars}, $self->{assigns},
        $self->{func_vars}, $self->{func_assigns},
        run    => $self->{run},
        status => $self->{status},
    );
    $update = $for->tree_minimize($self->{statements});

    my $count = 0;
    for my $func ( @{$self->{func_list}} ){
        if ($func->{print_tree} == 1) {

        $self->_must_print("------ [FUNC$count] FOR TREE MINIMIZE ------\n");
        $update = $for->tree_minimize($func->{statements});
        $count++;
        }
    }

    return $update;
}

sub _new_minimize_first_if_tree_minimize {
    my $self = shift;

    my $update = 0;

    $self->_must_print("------ IF TREE MINIMIZE ------\n");

    my $if = Orange4::Mini::If->new(
        $self->{config}, $self->{vars}, $self->{assigns}, $self->{func_vars}, $self->{func_assigns},
        run    => $self->{run},
        status => $self->{status},
    );
    $update = $if->tree_minimize($self->{statements});
    my $count = 0;
    for my $func( @{$self->{func_list}} ){
        if ($func->{print_tree} == 1) {

            $self->_must_print("------ [FUNC$count] IF TREE MINIMIZE ------\n");
            $update = $if->tree_minimize($func->{statements});
            $count++;
        }
    }

    return $update;
}

sub _new_minimize_first_function_call_statements_minimize {
    my $self = shift;

    my $update = 0;

    $self->_must_print("------ [MAIN] FUNCTION CALL TREE MINIMIZE ------\n");

    my $while = Orange4::Mini::Function_call->new(
        $self->{config}, $self->{vars}, $self->{assigns}, $self->{func_vars}, $self->{func_assigns},
        run    => $self->{run},
        status => $self->{status},
        );

    $update = $while->tree_minimize($self->{statements});

    my $count = 0;
    for my $func( @{$self->{func_list}} ){
        if ($func->{print_tree} == 1)   {

            $self->_must_print("------ [FUNC$count] FUNCTION CALL TREE MINIMIZE ------\n");
            $update = $while->tree_minimize($func->{statements});
            $count++;
        }
    }

    return $update;
}

sub _new_minimize_first_while_tree_minimize {
    my $self = shift;

    my $update = 0;

    $self->_must_print("------ [MAIN] WHILE TREE MINIMIZE ------\n");

    my $while = Orange4::Mini::While->new(
        $self->{config}, $self->{vars}, $self->{assigns}, $self->{func_vars}, $self->{func_assigns},
        run    => $self->{run},
        status => $self->{status},
        );

    $update = $while->tree_minimize($self->{statements});

    my $count = 0;
    for my $func( @{$self->{func_list}} ){
        if ($func->{print_tree} == 1) {

            $self->_must_print("------ [FUNC$count] WHILE TREE MINIMIZE ------\n");
            $update = $while->tree_minimize($func->{statements});
            $count++;
        }
    }

    return $update;
}

sub _new_minimize_first_switch_tree_minimize {
    my $self = shift;

    my $update = 0;

    $self->_must_print("------ [MAIN] SWITCH TREE MINIMIZE ------\n");
    my $switch = Orange4::Mini::Switch->new(
        $self->{config}, $self->{vars}, $self->{assigns}, $self->{func_vars}, $self->{func_assigns},
        run    => $self->{run},
        status => $self->{status},
        );
    $update = $switch->tree_minimize($self->{statements});

    my $count= 0;
    for my $func( @{$self->{func_list}} ){
        if ($func->{print_tree} == 1) {

            $self->_must_print("------ [FUNC$count] SWITCH TREE MINIMIZE ------\n");
            $update = $switch->tree_minimize($func->{statements});
            $count++;
        }
    }

    return $update;
}

sub _new_minimize_first_unionstruct_minimize {
  my $self = shift;

  my $update = 0;

  $self->_must_print("------ UNIONSTRUCT MINIMIZE ------\n");

  my $us = Orange4::Mini::Unionstruct->new(
      $self->{config},
      $self->{vars},
      $self->{unionstructs},
      $self->{assigns},
      $self->{func_list},
      $self->{func_vars},
      $self->{func_assigns},
      run    => $self->{run},
      status => $self->{status},
  );
  $update = $us->unionstructs_minimize();

  return $update;
}

sub _new_minimize_first_variable_length_array_minimize {
  my $self = shift;

  my $update = 0;

  $self->_must_print("------ VARIABE LENGTH ARRAY MINIMIZE ------\n");

  my $us = Orange4::Mini::VariableLengthArray->new(
      $self->{config}, $self->{vars}, $self->{unionstructs}, $self->{assigns},
      $self->{func_list},
      $self->{func_vars},
      $self->{func_assigns},
      run    => $self->{run},
      status => $self->{status},
  );
  $update = $us->variable_length_array_minimize($self->{variable_length_arrays});

  return $update;
}

sub _new_minimize_first_unionstruct_replace_minimize {
  my $self = shift;

  my $update = 0;

  $self->_must_print("------ UNIONSTRUCT REPLACE MINIMIZE ------\n");

  my $us = Orange4::Mini::Unionstruct->new(
      $self->{config},
      $self->{vars},
      $self->{unionstructs},
      $self->{assigns},
      $self->{func_list},
      $self->{func_vars},
      $self->{func_assigns},
      run    => $self->{run},
      status => $self->{status},
  );
  $update = $us->replace_unionstruct(-1);

  my $count = 0;
  for my $func_vars ( @{$self->{func_vars}} ){
      if ($self->{func_list}->[$count]->{print_tree} == 1) {

        $self->_must_print("------ [FUNC$count] UNIONSTRUCT REPLACE MINIMIZE ------\n");
        $update = $us->replace_unionstruct($count);
        $count++;
      }
  }

  return $update;
}

sub _new_minimize_first_array_minimize {
  my $self = shift;

  my $update = 0;

  $self->_must_print("------ ARRAY MINIMIZE ------\n");

  my $array = Orange4::Mini::Array->new(
      $self->{config}, $self->{vars}, $self->{unionstructs}, $self->{assigns}, $self->{func_list}, $self->{func_vars}, $self->{func_assigns},
      run    => $self->{run},
      status => $self->{status},
  );
  $update = $array->array_minimize($self->{vars}, -1);

  my $count = 0;
  for my $func_vars ( @{$self->{func_vars}} ){
      if ($self->{func_list}->[$count]->{print_tree} == 1) {

        $self->_must_print("------ [FUNC$count] ARRAY MINIMIZE ------\n");
        $update = $array->array_minimize($func_vars->{vars}, $count);
        $count++;
      }
  }


  return $update;
}

sub _new_minimize_first {
    my $self = shift;

    my $update = 0;
    $self->_new_minimize_first_function_call_statements_minimize;
    $self->_delete_unused_function; 
    $self->_new_minimize_first_binary_texpression_cut;
    $update = $self->_new_minimize_first_if_tree_minimize;
    $update = $self->_new_minimize_first_for_tree_minimize;
    $update = $self->_new_minimize_first_while_tree_minimize;
    $update = $self->_new_minimize_first_switch_tree_minimize;
    $self->_new_minimize_first_assign_minimize;
        # $self->_new_minimize_for_and_if_arguments;
    # do {
    # } while ( $update == 1 );
    $update = $self->_new_minimize_first_unionstruct_minimize;
}

sub _new_minimize_second_and_after_lossy_texpression_cut {
    my $self = shift;

    my $update = 0;
    if ( Orange4::Mini::Util::_count_defined_assign( $self->{assigns} ) > 1 ) {
        $self->_must_print("------ LOSSY EXPRESSION CUT ------\n");
        my $expression = Orange4::Mini::Expression->new(
            $self->{config},
            $self->{vars},
            $self->{assigns},
            main_vars => $self->{vars},
            main_assigns => $self->{assigns},
            func_vars => $self->{func_vars},
            func_assigns => $self->{func_assigns},
            func_list => $self->{func_list},
            run    => $self->{run},
            status => $self->{status},
            );
        $update = $expression->lossy_texpression_cut_possible ? 1 : 0;
    }

    for my $i (0 .. $#{$self->{func_assigns}} ){
        if ($self->{func_list}->[$i]->{print_tree} == 1) {

        if ( Orange4::Mini::Util::_count_defined_assign( $self->{func_assigns}->[$i] ) > 1 ) {
            $self->_must_print("------ [FUNC$i] LOSSY EXPRESSION CUT ------\n");
            my $expression = Orange4::Mini::Expression->new(
                $self->{config},
                $self->{func_vars}->[$i]->{vars},
                $self->{func_assigns}->[$i],
                main_vars => $self->{vars},
                main_assigns => $self->{assigns},
                func_vars => $self->{func_vars},
                func_assigns => $self->{func_assigns},
                func_list => $self->{func_list},
                run    => $self->{run},
                status => $self->{status},
                );
            $update = $expression->lossy_texpression_cut_possible ? 1 : 0;
        }
        }
    }

    return $update;
}

sub _new_minimize_second_and_after_assign_minimize {
    my $self = shift;

    my $update_top_post = 0;

    my $update = 0;
    do {
        $update = $self->_new_minimize_top_down ? 1 : 0;
        $update = $self->_new_minimize_second_and_after_possible_postorder ? 1 : $update;
        $update_top_post = $update ? $update : $update_top_post;
    } while ( $update > 0 );

    return $update_top_post;
}

sub _new_minimize_final_assign_minimize {
    my $self = shift;

    my $update_top_post = 0;

    my $update = 0;
    do {
        $update = $self->_new_minimize_final_top_down ? 1 : 0;
        $update_top_post = $update ? $update : $update_top_post;
    } while ( $update > 0 );

    return $update_top_post;
}

sub _new_minimize_second_and_after_possible_postorder {
    my $self = shift;

    my $update_postorder = 0;
    $self->_must_print("------ BOTTOM-UP POSTORDER EXPRESSION REDUCE ------\n");
    for my $i ( 0 .. $#{ $self->{assigns} } ) {
        my $update = 0;
        if ( Orange4::Mini::Util::_check_assign( $self->{assigns}->[$i] ) ) {
            do {
                $update = $self->_new_minimize_second_and_after_postorder($i) ? 1 : 0;
                $update_postorder = $update ? $update : $update_postorder;
            } while ( $update == 1 );
        }
    }

    return $update_postorder;
}

sub _new_minimize_second_and_after_postorder {
    my ( $self, $i ) = @_;

    $self->_print("\n------ BOTTOM-UP POSTORDER EXPRESSION REDUCE(t$i) ------\n");
    my $bottomup = Orange4::Mini::Bottomup->new(
        $self->{config}, $self->{vars}, $self->{assigns},
        run    => $self->{run},
        status => $self->{status},
    );
    my $s = '$assigns->[' . $i . ']';
    my $assign_in_locate = 'BLANK';

    return $bottomup->minimize_postorder( $self->{assigns}->[$i]->{root}, $i, $s, \$assign_in_locate ) ? 1 : 0;
}

sub _new_minimize_second_and_after_var_constant_minimize {
    my $self = shift;

    my $update = $self->_new_minimize_second_and_after_varset_minimize ? 1 : 0;
    $update = $self->_new_minimize_second_and_after_constant_minimize ? 1 : $update;

    return $update;
}

sub _new_minimize_final_var_constant_minimize {
    my $self = shift;

    my $update = $self->_new_minimize_final_varset_minimize ? 1 : 0;
    $update = $self->_new_minimize_final_constant_minimize ? 1 : $update;

    return $update;
}

sub _new_minimize_second_and_after_varset_minimize {
    my $self = shift;

    $self->_must_print( "------ VARIABLE MINIMIZE ------\n" );
    my $var = Orange4::Mini::Var->new(
        $self->{config}, $self->{vars}, $self->{unionstructs}, $self->{assigns}, $self->{func_vars}, $self->{func_assigns},
        run    => $self->{run},
        status => $self->{status},
    );

    return $var->_minimize_var ? 1 : 0;
}

sub _new_minimize_final_varset_minimize {
    my $self = shift;

    $self->_must_print( "------ VARIABLE FINAL MINIMIZE ------\n" );
    my $var = Orange4::Mini::Var->new(
        $self->{config}, $self->{vars}, $self->{unionstructs}, $self->{assigns},
        run    => $self->{run},
        status => $self->{status},
    );

    return $var->_minimize_var_final ? 1 : 0;
}

sub _new_minimize_second_and_after_constant_minimize {
    my $self = shift;

    $self->_must_print( "------ CONSTANT MINIMIZE ------\n" );
    my $constant = Orange4::Mini::Constant->new(
        $self->{config}, $self->{vars}, $self->{assigns},
        run    => $self->{run},
        status => $self->{status},
    );

    return $constant->_minimize_constant ? 1 : 0;
}

sub _new_minimize_final_constant_minimize {
    my $self = shift;

    $self->_must_print( "------ CONSTANT FINAL MINIMIZE ------\n" );
    my $constant = Orange4::Mini::Constant->new(
        $self->{config}, $self->{vars}, $self->{assigns},
        run    => $self->{run},
        status => $self->{status},
    );

    return $constant->_minimize_constant_final ? 1 : 0;
}

sub _new_minimize_second_and_after {
    my $self = shift;

    my $update = 0;
    my $count  = 0;
    $self->_new_minimize_first_function_call_statements_minimize;
    do {
        do {
            $update = 0;
            do {
                $update = $self->_new_minimize_second_and_after_lossy_texpression_cut ? 1 : 0;
                # $update = $self->_new_minimize_second_and_after_assign_minimize ? 1 : $update;
                $count++;
            } while ( $update == 1 && $count < 10 );
            # $update = $self->_new_minimize_second_and_after_var_constant_minimize ? 2 : $update; Orange4 ではやらない
            $count++;
        } while ( $update == 2 && $count < 20 );
        # $update = $self->_new_minimize_final_assign_minimize     ? 3 : $update;
        # $update = $self->_new_minimize_final_var_constant_minimize ? 3 : $update;
        $count++;
    } while ( $update == 3 && $count < 30 );
    $update = 0;
    $count  = 0;
    do {
      $update = $self->_new_minimize_first_for_tree_minimize;
      $update = $self->_new_minimize_first_if_tree_minimize;
      $update = $self->_new_minimize_first_switch_tree_minimize;
      $update = $self->_new_minimize_first_while_tree_minimize;
      $count++;
    } while ( $update == 1 && $count < 10 );
    $update = $self->_new_minimize_first_variable_length_array_minimize;
    $update = $self->_new_minimize_first_array_minimize;
    $update = $self->_new_minimize_first_unionstruct_minimize;
    $update = $self->_new_minimize_first_unionstruct_replace_minimize;
    $update = $self->_new_minimize_first_unionstruct_minimize;
    $self->_new_minimize_first_left_array; 
}

sub _generate_and_test {
    my $self = shift;

    return Orange4::Mini::Compute->new(
        $self->{config},
        $self->{vars},
        $self->{assigns},
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

sub _must_print {
    my ( $self, $body ) = @_;

    print $body;
}

1;
