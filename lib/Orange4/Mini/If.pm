package Orange4::Mini::If;

use strict;
use warnings;
use Carp ();

use Orange4::Mini::Backup;
use Orange4::Mini::Util;

use Data::Dumper;

sub new {
    my ( $class, $config, $vars, $assigns, %args ) = @_;
    
    bless {
        config       => $config,
        vars         => $vars,
        assigns      => $assigns,
        run          => $args{run},
        status       => $args{status},
        backup       => Orange4::Mini::Backup->new( $vars, $assigns ),
        minimize_var => undef,
        %args,
    }, $class;
}

sub if_tree_minimize { 
    my ($self, $roots) = @_;
    
    my $update = 0;
    
########
# print_tree の値
# 0 ... if 文を消して, then と else のパスが通っている方を一段上に出力する
# 1 ... すべて出力
# 2 ... if 文は出力し, パスが通っていない方を空にする
########

    foreach my $st (@$roots) {
        
        if ( $update != 1 && $st->{st_type} eq "if" ) {
            if ( $st->{print_tree} == 1 ) {
                $st->{print_tree} = 0;
                if ( $self->_generate_and_test ) {
                    $update = 1;
                }
                else {
                    $st->{print_tree} = 3;
                    if ( $self->_generate_and_test ) {
                        $update = 1;
                    }
                    else {
                        $st->{print_tree} = 2;
                        if ( $self->_generate_and_test ) {
                            $update = 1;
                        }
                        else {
                            $st->{print_tree} = 4;
                        }
                    }
                }
            }
            elsif ( $st->{print_tree} == 0 || $st->{print_tree} == 2 || $st->{print_tree} == 3 ) {
                if ( $st->{exp_cond}->{val} != 0 ) {
                    $self->if_tree_minimize($st->{st_then});
                }
                else {
                    $self->if_tree_minimize($st->{st_else});
                }
            }
            elsif ( $st->{print_tree} == 4 ) {
                $self->if_tree_minimize($st->{st_then});
                $self->if_tree_minimize($st->{st_else});
            }
            else {;}
        }
        else {;}
    }
    
    return $update;
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

1;