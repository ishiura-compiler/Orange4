package Orange4::Mini::For;

use strict;
use warnings;
use Carp ();

use Orange4::Mini::Backup;
use Orange4::Mini::Util;

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

sub tree_minimize { 
    my ($self, $roots) = @_;
    
    my $update = 0;
    
########
# print_tree の値
# 0 ... for 文を消して, パスが通っている場合は一段上に出力する
# 1 ... 全て出力
# 2 ... for 文は出力し, パスが通っていない場合は空にする
# 3 ... for 文の引数に式が残っていた場合に, 代入文にする
# 4 ... 全て出力
########
    
    foreach my $st ( @$roots ) {
        if ( $st->{st_type} eq "for" ) {
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
                if ( $st->{loop_path} == 1 ) {
                    $self->tree_minimize($st->{statements});
                }
            }
            elsif ( $st->{print_tree} == 4 ) {
                $self->tree_minimize($st->{st_then});
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