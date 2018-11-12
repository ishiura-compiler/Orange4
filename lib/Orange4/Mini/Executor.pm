package Orange4::Mini::Executor;

use strict;
use warnings;

use Carp ();
use Data::Dumper;

use Orange4::Mini::Minimize;
use Orange4::Util;



sub new {
    my ( $class, %args ) = @_;

    bless {
        config  => $args{config},
        vars    => $args{content}->{vars},
        unionstructs => $args{content}->{unionstructs},
        func_vars => $args{content}->{func_vars},
        assigns => [],
        func_assigns => [],
        variable_length_arrays => [],
        run     => {
            compiler  => $args{compiler},
            executor  => $args{executor},
            generator => Orange4::Generator->new(
                vars       => $args{content}->{vars},
                unionstructs => $args{content}->{unionstructs},
                statements => $args{content}->{statements},
                func_list  => $args{content}->{func_list},
                func_vars  => $args{content}->{func_vars},
                config     => $args{config},
            ),
        },
        status => {
            avoide_undef => 0,
            debug        => $args{debug},
            time_out     => $args{time_out},
            exp_size     => $args{content}->{expression_size},
            root_size    => $args{content}->{root_size},
            var_size     => $args{content}->{var_size},
            compile_command     => $args{content}->{compile_command},
            program      => undef,
            header       => undef,
            mini_dir     => $args{mini_dir},
            file         => $args{file},
        },
        %args
    }, $class;
}

sub execute {
    my $self = shift;

    $self->_var_adjustment;
    $self->_make_assigns;
    $self->_set_unionstructs;
    $self->_print("\n****** NEXT MINIMIZE: $self->{status}->{file} ******");
    my $guard = Orange4::Util::Chdir->new( $self->{mini_dir} );
    my $minimize = Orange4::Mini::Minimize->new(
        $self->{config},
        $self->{run}->{generator}->{statements},
        $self->{vars},
        $self->{run}->{generator}->{func_list},
        $self->{func_vars},
        $self->{run}->{generator}->{unionstructs},
        $self->{assigns},
        $self->{func_assigns},
        $self->{variable_length_arrays},
        run    => $self->{run},
        status => $self->{status},
    );
    $minimize->new_minimize;
    $self->_log( $self->{status}->{file} );
    $self->_message;
    $self->_print("\n****** PREV MINIMIZE: $self->{status}->{file} ******\n");
}

sub _make_assigns {
    my $self    = shift;

    my $statements = $self->{run}->{generator}->{statements};
    my $func_list = $self->{run}->{generator}->{func_list};
    $self->{array_num} = 0;

    # main 内の代入文生成
    $self->_make_assigns_from_st($statements);

    # 関数内の代入文生成
    for my $func( @$func_list ){
        $self->{tmp_func_assign} = [];
        $self->{array_num} = 0;
        $self->_make_func_assigns_from_st( $func->{statements}, $func->{st_num} );
        push @{$self->{func_assigns}}, $self->{tmp_func_assign};
    }
}

sub _zantei_var_tansaku {
    my ( $self, $i ) = @_;

    for my $v ( @{ $self->{vars} } ) {
        if ( $v->{name_type} eq "t" && $v->{name_num} eq $i ) {
            return $v;
        }
    }
}

sub _zantei_func_var_tansaku {
    my ( $self, $i, $func_num ) = @_;

    for my $v ( @{ $self->{func_vars}->[$func_num]->{vars} } ) {
        if ( $v->{name_type} eq "t" && $v->{name_num} eq $i ) {
            return $v;
        }
    }
}

sub _var_adjustment {
    my $self = shift;

    for my $func_vars ( @{$self->{func_vars}} ){
        for my $func_var ( @{$func_vars->{vars}} ){
            if( $func_var->{name_type} eq "t" ){
                for my $tmp_func_vars ( @{$self->{func_vars}} ){
                    for my $tmp_func_var ( @{$tmp_func_vars->{vars}} ){
                        if( $func_var->{name_type} eq $tmp_func_var->{name_type} &&
                            $func_var->{name_num} eq $tmp_func_var->{name_num} ){
                            $tmp_func_var = $func_var;
                        }
                    }
                }
                $func_var->{ival} = $func_var->{val}; #すべてのt変数の初期値に期待値を代入
            }
        }
    }

    for my $main_var ( @{$self->{vars}} ){
        if( $main_var->{name_type} eq "t" ){
            for my $func_vars ( @{$self->{func_vars}} ){
                for my $func_var ( @{$func_vars->{vars}} ){
                    if( $main_var->{name_type} eq $func_var->{name_type} &&
                        $main_var->{name_num} eq $func_var->{name_num} ){
                        $main_var = $func_var;
                    }
                }
            }
            $main_var->{ival} = $main_var->{val};
        }
    }
}

sub _make_assigns_from_st {
    my ($self, $statements) = @_;

    foreach my $st ( @$statements ) {
        if ( $st->{st_type} eq 'for' ) {
             $self->_make_assigns_from_st($st->{statements});
        }
        elsif ( $st->{st_type} eq 'if' ) {
             $self->_make_assigns_from_st($st->{st_then});
             $self->_make_assigns_from_st($st->{st_else});
        }
        elsif ( $st->{st_type} eq 'while' ) {
            $self->_make_assigns_from_st($st->{statements});
        }
        elsif ( $st->{st_type} eq 'function_call' ) { ; }
        elsif ( $st->{st_type} eq 'switch' ) {
            for my $case ( @{$st->{cases}} ){
                $self->_make_assigns_from_st($case->{statements});
            }
        }
        elsif ( $st->{st_type} eq 'assign' ) {
            if ( !defined $st->{print_statement} ) {
                $st->{print_statement} = 1;
            }
            if ( !defined $st->{var} ) {
                $st->{var} = $self->_zantei_var_tansaku($st->{name_num});
            }
            if ( $st->{print_statement} ) {
                push @{$self->{assigns}}, $self->_generate_assign_set($st);
                $st->{assigns_num} = $#{$self->{assigns}};
            }
        }
        elsif ( $st->{st_type} eq 'array') {
          if ( !defined $st->{print_statement} ) {
              $st->{print_statement} = 1;
          }
          push @{$self->{variable_length_arrays}}, $st;
        }
        else{;}
    }
}

sub _make_func_assigns_from_st {
    my ($self, $statements, $func_num) = @_;
    for my $st ( @$statements ) {
        if ( $st->{st_type} eq 'for' ) {
            $self->_make_func_assigns_from_st($st->{statements}, $func_num);
        }
        elsif ( $st->{st_type} eq 'if' ) {
            $self->_make_func_assigns_from_st($st->{st_then}, $func_num);
            $self->_make_func_assigns_from_st($st->{st_else}, $func_num);
        }
        elsif ( $st->{st_type} eq 'while' ) {
            $self->_make_func_assigns_from_st($st->{statements}, $func_num);
        }
        elsif ( $st->{st_type} eq 'function_call' ) { ; }
        elsif ( $st->{st_type} eq 'switch' ) {
            for my $case ( @{$st->{cases}} ){
                $self->_make_func_assigns_from_st($case->{statements}, $func_num);
            }

        }
        elsif ( $st->{st_type} eq 'assign' ) {
            if ( !defined $st->{print_statement} ) {
                $st->{print_statement} = 1;
            }
            if( !defined $st->{var} ){
                $st->{var} = $self->_zantei_func_var_tansaku($st->{name_num}, $func_num);
            }
            if ( $st->{print_statement} ) {
                push @{$self->{tmp_func_assign}}, $self->_generate_assign_set($st);

                # $st->{assigns_num} = $#{$self->{tmp_func_assign}};
                $st->{assigns_num} = $st->{name_num};
                $st->{array_num} = $self->{array_num};
                $self->{array_num}++;
            }
        }
        elsif ( $st->{st_type} eq 'array') {
          if ( !defined $st->{print_statement} ) {
              $st->{print_statement} = 1;
          }
          push @{$self->{variable_length_arrays}}, $st;
        }
        else{;}
    }
}

sub _generate_assign_set {
    my ( $self, $st ) = @_;

    return +{
        root            => $st->{root},
        sub_root        => $st->{sub_root},
        val             => $st->{val},
        type            => $st->{type},
        print_statement => $st->{print_statement},
        var             => $st->{var},
        name_num        => $st->{name_num},
        path            => $st->{path},
        funcs           => $st->{funcs},
    };
}

#構造体共用体のリファレンスを正しくセット
sub _set_unionstructs {
  my $self = shift;

  for my $us (@{ $self->{unionstructs} }) {
    for my $mem (@{ $us->{member} }) {
      if (ref $mem->{type} eq "HASH") {
        for my $us2 (@{ $self->{unionstructs} }) {
          my $name = $mem->{type}->{name_type} . $mem->{type}->{name_num};
          my $us_name = $us2->{name_type} . $us2->{name_num};
          if ($name eq $us_name) {
            $mem->{type} = $us2;
            last;
          }
        }
      }
    }
  }
  for my $v (@{ $self->{vars} }) {

    if (ref($v->{type}) eq 'HASH') {
      for my $us (@{ $self->{unionstructs} }) {

        my $name = $v->{type}->{name_type} . $v->{type}->{name_num};
        my $us_name = $us->{name_type} . $us->{name_num};
        if ($name eq $us_name) {
          $v->{type} = $us;
          last;
        }
      }
    }
  }
  for my $func_vars ( @{$self->{func_vars}} ){
      for my $v ( @{$func_vars->{vars}} ){
        if (ref($v->{type}) eq 'HASH') {
          for my $us (@{ $self->{unionstructs} }) {
            my $name = $v->{type}->{name_type} . $v->{type}->{name_num};
            my $us_name = $us->{name_type} . $us->{name_num};
            if ($name eq $us_name) {
              $v->{type} = $us;
              last;
            }
          }
        }
      }
  }
}

sub _message {
    my $self = shift;

    if ( !defined $self->{status}->{program}
        || $self->{status}->{program} =~ /TIME OUT/ )
    {
        select STDOUT;
        print "FAILED MINIMIZE. (maybe TIME OUT.)\n";
    }
    elsif ( $self->{status}->{program} =~ /FAILED/ ) {
        print $self->{status}->{program} . "\n";
    }
    else {
        print $self->{status}->{program} . "\n";
    }
}

sub _log {
    my ( $self, $file_name ) = @_;

    my $statements = $self->{run}->{generator}->{statements};
    my $func_list = $self->{run}->{generator}->{func_list};
    my $func_vars = $self->{run}->{generator}->{func_vars};
    my $to = $file_name;
    $to =~ s/\.pl$//;
    my $header  = $self->{status}->{header};
    my $program = $self->{status}->{program};
    $header  = ( defined $header )  ? $header  : "";
    $program = ( defined $program ) ? $program : "FAILED MINIMIZE.";

    Orange4::Log->new(
        name => "$to\_mini.c",
        dir  => "./",
    )->print( $header . $program );

    my $content = Orange4::Dumper->new(
        vars  => $self->{vars},
        statements => $statements,
        unionstructs => $self->{unionstructs},
        func_vars  => $self->{func_vars},
        )->all(
            expression_size => $self->{status}->{exp_size},
            root_size       => $self->{status}->{root_size},
            var_size        => $self->{status}->{var_size},
            compile_command => $self->{status}->{compile_command},
        );

    Orange4::Log->new(
        name => "$to\_mini.pl",
        dir  => "./",
    )->print($content);
}

sub _print {
    my ( $self, $body ) = @_;

    Orange4::Mini::Util::print( $self->{status}->{debug}, $body );
}

1;
