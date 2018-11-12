package Orange4::Mini::VariableLengthArray;

use strict;
use warnings;
use Carp ();
use Data::Dumper;

use Orange4::Mini::Backup;
use Orange4::Mini::Util;

sub new {
    my ( $class, $config, $vars, $unionstructs, $assigns, $func_list, $func_vars, $func_assigns, %args ) = @_;

    bless {
        config       => $config,
        vars         => $vars,
        unionstructs => $unionstructs,
        assigns      => $assigns,
        func_list    => $func_list,
        func_vars    => $func_vars,
        func_assigns => $func_assigns,
        run          => $args{run},
        status       => $args{status},
        backup       => Orange4::Mini::Backup->new( $vars, $assigns ),
        minimize_var => undef,
        %args,
    }, $class;
}

#可変配列の最小化
sub variable_length_array_minimize {
   my ($self, $variable_length_arrays) = @_;
   my $update = 0;

   # 使われていない可変配列を全て消す
   $self->delete_unused_variable_length_array_all($variable_length_arrays);
   if ($self->_generate_and_test) {
     $update = 1;
   }
   else {
     #エラーが消えれば元に戻して前から消していく
     $self->reset_used($variable_length_arrays);
     if ($self->delete_unused_variable_length_array_1by1($variable_length_arrays)) {
       $update = 1;
     }
   }

   return $update;
}

sub delete_unused_variable_length_array_1by1 {
  my ($self, $statements) = @_;
  my $update = 0;
  for my $st (@$statements) {
    if ($st->{array}->{used} == 0 && $st->{print_statement} == 1) {
      $st->{print_statement} = 0;
      if ($self->_generate_and_test) {
        $update = 1;
      }
      else {
        $st->{print_statement} = 1;
      }
    }
  }

  return $update;
}

sub delete_unused_variable_length_array_all {
  my ($self, $statements) = @_;

  for my $vla (@$statements) {
    if ($vla->{array}{used} == 0) {
      $vla->{print_statement} = 0;
    }
  }
}

sub reset_used {
  my ($self, $ARRAY) = @_;

  for my $i (@$ARRAY) {
      $i->{print_statement} = 1;
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

sub _print {
    my ( $self, $body ) = @_;

    Orange4::Mini::Util::print( $self->{status}->{debug}, $body );
}

1;
