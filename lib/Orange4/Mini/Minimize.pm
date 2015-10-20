package Orange4::Mini::Minimize;

use strict;
use warnings;
use Carp ();
use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);

use Orange4::Dumper;

use Orange4::Mini::Bottomup;
use Orange4::Mini::Constant;
use Orange4::Mini::Compute;
use Orange4::Mini::Expression;
use Orange4::Mini::Topdown;
use Orange4::Mini::Var;
use Orange4::Mini::Util;
use Orange4::Mini::For;
use Orange4::Mini::If;

sub new {
    my ( $class, $config, $roots, $vars, $assigns, %args ) = @_;
    
    bless {
        config  => $config,
        roots   => $roots,
        vars    => $vars,
        assigns => $assigns,
        run     => $args{run},
        status  => $args{status},
        backup  => Orange4::Mini::Backup->new( $vars, $assigns ),
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

sub _new_minimize_first_binary_texpression_cut {
    my $self = shift;
    
    if ( Orange4::Mini::Util::_count_defined_assign( $self->{assigns} ) > 1 ) {
        $self->_must_print("------ BINARY EXPRESSION CUT ------\n");
        my $expression = Orange4::Mini::Expression->new(
            $self->{config}, $self->{vars}, $self->{assigns},
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
    
    $self->_must_print("------ BOTTOM-UP INORDER EXPRESSION REDUCE ------\n");
    for my $i ( 0 .. $#{ $self->{assigns} } ) {
        if ( Orange4::Mini::Util::_check_assign( $self->{assigns}->[$i] ) ) {
            $self->_print(
                "\n------ BOTTOM-UP INORDER EXPRESSION REDUCE(t$i) ------\n");
            my $bottomup = Orange4::Mini::Bottomup->new(
                $self->{config}, $self->{vars}, $self->{assigns},
                run    => $self->{run},
                status => $self->{status},
            );
            $bottomup->minimize_inorder_head( $self->{assigns}->[$i]->{root}, $i );
        }
    }
}

sub _new_minimize_for_and_if_arguments {
    my $self = shift;
    
    my $update = 0;
    
    $self->_must_print("------ FOR AND IF ARGUMENTS REDUCE ------\n");
    my $bottomup = Orange4::Mini::Bottomup->new(
        $self->{config}, $self->{vars}, $self->{assigns},
        run    => $self->{run},
        status => $self->{status},
    );
    do {
        $update = $bottomup->minimize_for_and_if_arguments( $self->{roots} );
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
        run    => $self->{run},
        status => $self->{status},
    );
    $update = $for->tree_minimize($self->{roots});
    
    return $update;
}

sub _new_minimize_first_if_tree_minimize {
    my $self = shift;
    
    my $update = 0;
    
    $self->_must_print("------ IF TREE MINIMIZE ------\n");
    
    my $if = Orange4::Mini::If->new(
        $self->{config}, $self->{vars}, $self->{assigns},
        run    => $self->{run},
        status => $self->{status},
    );
    $update = $if->tree_minimize($self->{roots});
    
    return $update;
}

sub _new_minimize_first {
    my $self = shift;
    
    my $update = 0;
    
    $self->_new_minimize_first_binary_texpression_cut;
    $self->_new_minimize_first_assign_minimize;
    do {
        $update = $self->_new_minimize_first_for_tree_minimize;
        $update = $self->_new_minimize_first_if_tree_minimize;
    } while ( $update == 1 );
}

sub _new_minimize_second_and_after_lossy_texpression_cut {
    my $self = shift;
    
    my $update = 0;
    if ( Orange4::Mini::Util::_count_defined_assign( $self->{assigns} ) > 1 ) {
        $self->_must_print("------ LOSSY EXPRESSION CUT ------\n");
        my $expression = Orange4::Mini::Expression->new(
            $self->{config}, $self->{vars}, $self->{assigns},
            run    => $self->{run},
            status => $self->{status},
        );
        $update = $expression->lossy_texpression_cut_possible ? 1 : 0;
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
        $self->{config}, $self->{vars}, $self->{assigns},
        run    => $self->{run},
        status => $self->{status},
    );
    
    return $var->_minimize_var ? 1 : 0;
}

sub _new_minimize_final_varset_minimize {
    my $self = shift;
    
    $self->_must_print( "------ VARIABLE FINAL MINIMIZE ------\n" );
    my $var = Orange4::Mini::Var->new(
        $self->{config}, $self->{vars}, $self->{assigns},
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
    do {
        do {
            $update = 0;
            do {
                $update = $self->_new_minimize_second_and_after_lossy_texpression_cut ? 1 : 0;
                # $update = $self->_new_minimize_second_and_after_assign_minimize ? 1 : $update;
                $count++;
            } while ( $update == 1 && $count < 10 );
            $update = $self->_new_minimize_second_and_after_var_constant_minimize ? 2 : $update;
            $count++;
        } while ( $update == 2 && $count < 20 );
        # $update = $self->_new_minimize_final_assign_minimize       ? 3 : $update;
        $update = $self->_new_minimize_final_var_constant_minimize ? 3 : $update;
        $count++;
    } while ( $update == 3 && $count < 30 );
}

sub _generate_and_test {
    my $self = shift;
    
    return Orange4::Mini::Compute->new(
        $self->{config}, $self->{vars}, $self->{assigns},
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
