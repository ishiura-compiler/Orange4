package Orange4::Mini::Switch;

use strict;
use warnings;
use Carp ();

use Orange4::Mini::Backup;
use Orange4::Mini::Util;

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
        backup       => Orange4::Mini::Backup->new( $vars, $assigns, $func_vars, $func_assigns ),
        minimize_var => undef,
        %args,
    }, $class;
}

sub tree_minimize {
    my ($self, $statements) = @_;
    my $update = 0;

    #########################################################################
    # print_tree の値
    # 0 ... switch文を消して, パスが通っているcaseのみ一段上に出力する
    # 1 ... 全て出力
    # 4 ... pathの通っているcase句のみを表示する
    # 5 ... pathの通っていないcaseを一つずつ消していく
    # 6 ... 全て出力
    ##########################################################################

    for my $st ( @$statements ) {
        if( $st->{st_type} eq "switch" ){
            if( $st->{print_tree} == 1 ){
                $st->{print_tree} = 0;
                if( $self->_generate_and_test ){
                    $update = 1;
                    for my $case ( @{$st->{cases}} ){
                        if( $case->{path} == 1 ){
                            $self->tree_minimize($case->{statements});
                        }
                    }   
                }
                else {
                    $st->{print_tree} = 4;
                    if( $self->_generate_and_test ){
                        $update = 1;
                    }
                    else{
                        $st->{print_tree} = 5;
                        for my $case ( @{$st->{cases}} ){
                            if( $case->{path} == 0 ){
                                $case->{print_case} = 0;
                                if( $self->_generate_and_test ){ ; }
                                else{
                                    $case->{print_case} = 1;
                                }
                            }
                        }
                        if( $self->_generate_and_test ){
                            $update = 1;
                        }
                        else{
                            $st->{print_tree} = 6;
                        }
                    }
                }
            }
            elsif( $st->{print_tree} == 0 || $st->{print_tree} == 4 ){
                for my $case ( @{$st->{cases}} ){
                    if( $case->{path} == 1 ){
                        $self->tree_minimize($case->{statements});
                    }
                }
            }
            elsif( $st->{print_tree} == 5 ){
                for my $case ( @{$st->{cases}} ){
                    if( $case->{print_case} == 1 ){
                        $self->tree_minimize($case->{statements});
                    }
                }
            }
            elsif( $st->{print_tree} == 6 ){
                for my $case ( @{$st->{cases}} ){
                    $self->tree_minimize($case->{statements});
                }
            }
        }
        elsif( $st->{st_type} eq "if" ){
            $self->tree_minimize( $st->{st_then} );
            $self->tree_minimize( $st->{st_else} );
        }
        elsif( $st->{st_type} eq "for" ){
            $self->tree_minimize( $st->{statements} );
        }
        elsif( $st->{st_type} eq "while" ){
            $self->tree_minimize( $st->{statements} );
        }
        else{ ; }
    }
    return $update;
}

# プログラムを実行してNGが残っていれば1を返し, そうでなければ0を返す
sub _generate_and_test {
    my $self = shift;

    return Orange4::Mini::Compute->new(
        $self->{config}, $self->{vars}, $self->{assigns}, $self->{func_vars}, $self->{func_assigns},
        run    => $self->{run},
        status => $self->{status},
        )->_generate_and_test;
}

sub _print {
    my ( $self, $body ) = @_;

    Orange4::Mini::Util::print( $self->{status}->{debug}, $body );
}

1;
