package Orange4::Mini::Bottomup;

use strict;
use warnings;
use Carp ();

use Orange4::Mini::Backup;
use Orange4::Mini::Util;
use Orange4::Mini::Compute;

use Data::Dumper;

sub new {
    my ( $class, $config, $vars, $assigns, %args ) = @_;

    bless {
        config       => $config,
        vars         => $vars,
        assigns      => $assigns,
        main_vars    => $args{main_vars},
        main_assigns => $args{main_assigns},
        func_vars    => $args{func_vars},
        func_assigns => $args{func_assigns},
        run          => $args{run},
        status       => $args{status},
        backup       => Orange4::Mini::Backup->new( $vars, $assigns ),
        %args,
    }, $class;
}

# inorder; only parent on the No. 1 special
sub minimize_inorder_head {
    my ( $self, $ref, $i ) = @_;

    $self->{st_root} = $ref;
    my $reduced = 0;

    if ( $ref->{ntype} eq "op" ) {
        for my $k ( @{ $ref->{in} } ) {
            if ( $k->{print_value} == 0 ) {
                $reduced = $self->minimize_inorder( $k->{ref}, $i );
                if ( $reduced == -1 || $reduced == 2 ) {
                    if ( $self->try_reduce( $k, $i ) ) {
                        $reduced = 1;
                    }
                    else {
                        # Check the right grandson of child
                        $reduced = $self->minimize_inorder( $k->{ref}, $i );
                        if ( $reduced > 0 ) {
                            $reduced = 1;
                        }
                        else {
                            $reduced = 0;
                        }
                    }
                }
            }
        }
    }

    return $reduced;
}

# inorder; Try to top-down if successful examines only one child
sub minimize_inorder {
    my ( $self, $ref, $i ) = @_;

    my $reduced = -1;

    if ( $ref->{ntype} eq "op" ) {
        for my $k ( @{ $ref->{in} } ) {
            if ( defined $k->{print_value} && $k->{print_value} == 0 ) {
                # Check the left grandson of child
                $reduced = $self->minimize_inorder( $k->{ref}, $i );
                if ( $reduced == -1 || $reduced == 2 ) {
                    # Check child
                    if ( $self->try_reduce( $k, $i ) ) {
                        $reduced = 2;
                        return $reduced;
                    }
                    else {
                        # Check the right grandson of child
                        $reduced = $self->minimize_inorder( $k->{ref}, $i );
                        if ( $reduced > 0 ) {
                            $reduced = 1;
                        }
                        else {
                            $reduced = 0;
                        }
                    }
                }
            }
        }
    }

    return $reduced;
}

# preorder, Bisection exploration version (top-down manner I examine)
sub minimize_preorder {
    my ( $self, $ref, $i ) = @_;

    my $reduced = 0;

    if ( $ref->{ntype} eq "op" ) {
        for my $k ( @{ $ref->{in} } ) {
            if ( $k->{print_value} == 0 ) {
                if ( $self->try_reduce( $k, $i ) ) {
                    $reduced = 1;
                }
                elsif ( $self->minimize_preorder( $k->{ref}, $i ) ) {
                    $reduced = 1;
                }
                else { ; }
            }
        }
    }

    return $reduced;
}

# Solid plate of the bottom-up
# (I find out one by one minimization from the node below)
sub minimize_postorder {
    my ( $self, $ref, $i, $s, $assign_in_locate ) = @_;

    my $reduced      = -1;
    my $reduced_next = 0;

    if ( $ref->{ntype} eq "op" ) {
        $s .= "{'in'}";
        my $ii = 0;
        for my $k ( @{ $ref->{in} } ) {
            my $sr = $s . "[$ii]";
            if ( $sr eq $$assign_in_locate || $$assign_in_locate eq 'SKIP' ) {
                $reduced           = 0;
                $$assign_in_locate = 'SKIP';
                return $reduced;
            }
            elsif ( $k->{print_value} == 0 ) {
                $sr .= "{'ref'}";
                $reduced_next =
                    $self->minimize_postorder( $k->{ref}, $i, $sr, $assign_in_locate );
                if ( $reduced_next == -1 || $reduced_next == 2 ) {
                    if ( $self->try_reduce( $k, $i ) ) {
                        $$assign_in_locate = 'BLANK';
                        $reduced_next      = 2;
                    }
                    else {
                    # To leave the OK after NG.
                    # (Recompile prevention of the same type)
                        if ( $$assign_in_locate eq 'BLANK' ) {
                            $$assign_in_locate = "$sr";
                        }
                        if ( $reduced_next == 2 ) { $reduced_next = 1; }
                        else                      { $reduced_next = 0; }
                    }
                }
            }
            else { ; }
            if ( $reduced < $reduced_next ) {
                $reduced = $reduced_next;
            }
            $ii++;
        }
    }

    return $reduced;
}

sub try_reduce {
    my ( $self, $vn, $i ) = @_;

    my $update = 0;
    my $o      = $vn->{ref}->{out};

    #if ( $vn->{type} eq $o->{type} && $vn->{val} == $o->{val} ) {

    #    $vn->{print_value} = 2;
    #}
    # else {
        $vn->{print_value} = 1;
    # }
    my $obj = Orange4::Generator::Program->new( $self->{config} );
    my $tree_sprint =
        "$i: " . $obj->tree_sprint( $self->{st_root} ) . "\n";
         $self->_print($tree_sprint);
    my $ans = $self->_generate_and_test;
    if ( $ans == 1 ) {
        # if ( $vn->{print_value} == 1 ) {
            # $vn->{print_value} = 2;
            # $tree_sprint =
                # "$i: " . $obj->tree_sprint( $self->{assigns}->[$i]->{root} ) . "\n";
            # $self->_print($tree_sprint);
            # $ans = $self->_generate_and_test;
            # if ( $ans == 0 ) {
                # $vn->{print_value} = 1;
                # $self->_print("");
            # }
        # }
        $update = 1;
    }
    elsif ( $ans == 0 ) {
        $vn->{print_value} = 0;    # return to the original
    }

    return $update;
}

sub minimize_for_and_if_arguments {
    my ( $self, $statements ) = @_;

    my $update = 0;

    foreach my $st ( @$statements ) {
        if ( $st->{st_type} eq "for" ) {
            if ($st->{print_tree} != 0) {
                $update = $self->minimize_inorder_head( $st->{st_init}->{root}, 0 );
                $update = $self->minimize_inorder_head( $st->{continuation_cond}->{root}, 0 );
                $update = $self->minimize_inorder_head( $st->{st_reinit}->{root}, 0 );
            }  
            $update = $self->minimize_for_and_if_arguments( $st->{statements} );
        }
        elsif ( $st->{st_type} eq "if" ) {
            if ($st->{print_tree} != 0) {
	            $self->minimize_inorder_head($st->{exp_cond}->{root}, 0);
            }
            if ( ($st->{print_tree} == 1)
              || ($st->{print_tree} == 2 && $st->{exp_cond}->{val} != 0)
              || ($st->{print_tree} == 3 && $st->{exp_cond}->{val} != 0)
              || ($st->{print_tree} == 4)
              || ($st->{print_tree} == 0 && $st->{exp_cond}->{val} != 0)) {
	            $self->minimize_for_and_if_arguments( $st->{st_then});
            }
            if ( ($st->{print_tree} == 1)
              || ($st->{print_tree} == 2 && $st->{exp_cond}->{val} == 0)
              || ($st->{print_tree} == 3 && $st->{exp_cond}->{val} == 0)
              || ($st->{print_tree} == 4)
              || ($st->{print_tree} == 0 && $st->{exp_cond}->{val} == 0)) {
	            $self->minimize_for_and_if_arguments( $st->{st_else} );
            }
            # $update = $self->minimize_inorder_head( $st->{exp_cond}->{root}, 0 );
            # $update = $self->minimize_for_and_if_arguments( $st->{st_then} );
            # $update = $self->minimize_for_and_if_arguments( $st->{st_else} );
        }
        elsif( $st->{st_type} eq "while" ){
            if ($st->{print_tree} != 0) {
                $update = $self->minimize_inorder_head( $st->{continuation_cond}->{root}, 0 );
                if( defined $st->{st_condition_for_break} ){
                    $update = $self->minimize_inorder_head( $st->{st_condition_for_break}->{root}, 0 );
                }
            }
            $update = $self->minimize_for_and_if_arguments( $st->{statements} );
        }
        elsif( $st->{st_type} eq "switch" ){
            if ($st->{print_tree} != 0) {
                $update = $self->minimize_inorder_head( $st->{continuation_cond}->{root}, 0 );
            }
            for my $case ( @{$st->{cases}} ){
                $update = $self->minimize_for_and_if_arguments( $case->{statements} );
            }
        }
        elsif( $st->{st_type} eq "function_call" ){
            if ($st->{print_tree} != 0) {
                if( defined $st->{args_num_expression} ){
                    $update = $self->minimize_inorder_head( $st->{args_num_expression}->{root}, 0 );
                }
                for my $arg_expression ( @{$st->{args_expressions}} ){
                    $update = $self->minimize_inorder_head( $arg_expression->{root}, 0 );
                }
            }
        }
        elsif( $st->{st_type} eq "array") {
            if ($st->{print_statement} != 0) {
                # print Dumper $st->{sub_root}->{in};
                for my $in (@{$st->{sub_root}->{in}}) {
                    $update = $self->minimize_inorder_head($in->{ref}, 0);
                }
            }
        }
        else { ; }
    }

    return $update;
}

sub _generate_and_test {
    my $self = shift;
# print Dumper $self->{func_assigns};
    return Orange4::Mini::Compute->new(
        $self->{config},
        # $self->{vars},
        # $self->{assigns},
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
