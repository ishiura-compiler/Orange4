package Orange4::Mini::Function_call;

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

    ###############################################################
    # print_tree の値
    # 0 ... while文を消して, パスが通っている場合は一段上に出力する
    # 1 ... 全て出力
    # 2 ... while文は出力し, パスが通っていない場合には空にする
    # 3 ... while文の条件文を代入文にする
    # 4 ... 全て出力
    ###############################################################

    for my $st ( @$statements ) {
        if ( $st->{st_type} eq "function_call" ) {
            if ( $st->{print_tree} == 1 ) {
                $st->{print_tree} = 0;
                if ( $self->_generate_and_test ) {
                    $update = 1;
                }
                else{
                    $st->{print_tree} = 1;
                }
            }
            else {;}
        }
        elsif ( $st->{st_type} eq "if" ) {
            $self->tree_minimize($st->{st_then});
            $self->tree_minimize($st->{st_else});
        }
        elsif ( $st->{st_type} eq "switch" ){
            for my $case ( @{$st->{cases}} ){
                $self->tree_minimize($case->{statements});
            }
        }
        elsif ( $st->{st_type} eq "for" ) {
            $self->tree_minimize($st->{statements});
        }
        else { ; }
    }

    return $update;
}

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
