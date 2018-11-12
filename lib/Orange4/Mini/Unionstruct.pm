package Orange4::Mini::Unionstruct;

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
        replace_vars => $args{run}->{generator}->{replace_vars},
        %args,
    }, $class;
}

# 構造体共用体の最小化
sub unionstructs_minimize {
    my ($self) = @_;
    my $unionstructs = $self->{unionstructs};
    my $update = 0;

    # 最小化のために構造体共用体のused情報をセット
    my $obj = Orange4::Generator::Program->new( $self->{config}, $self->{func_list} );

    $obj->reset_varset_used( $self->{vars},
                             $unionstructs,
                             $self->{run}->{generator}->{statements},
                             $self->{func_vars},
                             $self->{func_list}
        );

    # 使われていない構造体共用体を全て消す
    $self->delete_unused_unionstruct_all($unionstructs);
    if ($self->_generate_and_test) {
      $update = 1;
    }
    else {
      #エラーが消えれば元に戻して前から消していく
      $self->reset_print_unionstruct($unionstructs);
      if ($self->delete_unused_unionstruct_1by1($unionstructs)) {
        $update = 1;
      }
    }
    #メンバ変数の最小化
    $self->delete_unused_mem_all($unionstructs);
    if ($self->_generate_and_test) {
      $update = 1;
    }
    else {
      $self->reset_print_member($unionstructs);
      if ($self->delete_unused_mem_1by1($unionstructs)) {
        $update = 1;
      }
    }

    return $update;
}

#算術式中の構造体共用体を変数に置換
sub replace_unionstruct {
  my ($self, $func_num) = @_;
  my $vars = $func_num == -1 ? $self->{vars} : $self->{func_vars}->[$func_num]->{vars};
  my $update = 0;
  my $avoid = [];
  my $replace_var;
  my $replace_vars = $func_num == -1 ? $self->{replace_vars} : $self->{func_vars}->[$func_num]->{replace_vars};
  my $used_unionstruct = $self->get_used_unionstruct();

  for my $i (@$used_unionstruct) {
    $update = 0;
    my $key = $i->{name_type} . $i->{name_num} . "_" . join("_", @{$i->{elements}});

    if (grep {$_ eq $key} @$avoid) { next; }

    for my $j (@$vars) {
      if ($j->{name_type} eq $i->{name_type} && $j->{name_num} eq $i->{name_num}) {
        # print "key $key";
        $i->{replace_flag} = 1;

        if (defined $replace_vars->{$key}) {
          $replace_var = $replace_vars->{$key};
          $replace_var->{used_num} += 1;
        }
        else {
          $replace_var = {
            name_type => 'replace',
            replace_name => $key,
            ival => $i->{val},
            type => $i->{type},
            modifier => $i->{modifier},
            class => $i->{class},
            scope => $i->{scope},
            used_num => 1,
            changed_scope => 0,
            used => 1,
          };
          $replace_vars->{$key} = $replace_var;

          #print_flg = 1 : mod = 無し class = 無し
          #print_flg = 2 : mod = あり class = 無し
          #print_flg = 3 : mod = 無し class = あり
          #print_flg = 4 : mod = あり class = あり
          if ( $i->{modifier} eq "" && $i->{class} eq "") { $replace_var->{print_flg} = 4; }
          elsif ( $i->{modifier} ne "" && $i->{class} eq "" ) { $replace_var->{print_flg} = 3;}
          elsif ( $i->{modifier} eq "" && $i->{class} ne "" ) { $replace_var->{print_flg} = 2;}
          else { $replace_var->{print_flg} = 1;}

        }


        my $uus = $self->get_used_unionstruct();
        if (scalar @$uus != scalar @$used_unionstruct) {
          $self->avoid_unionstruct($uus, $used_unionstruct, $avoid);
        }

          $self->_print("REPLACE : $replace_var->{replace_name}");
        if ($self->_generate_and_test) {
          $update = 1;
        }
        elsif ($self->change_modifier_and_class_and_test($replace_var)) {
          $update = 1;
        }
        elsif ($replace_var->{changed_scope} == 0) {
          $self->change_scope($replace_var);
          if ($self->_generate_and_test) {
            $update = 1;
          }
          elsif ($self->change_modifier_and_class_and_test($replace_var)) {
            $update = 1;
          }
          else {
            $self->change_scope($replace_var);
          }
        }

        if ($replace_var->{used_num} <= 1 && $update == 0) {
            $replace_vars->{$key} = undef;
        }

        if ($update == 0) {
          $replace_var->{used_num}--;
          $i->{replace_flag} = 0;
        }
        last;
      }
    }
  }
  return $update;
}

sub change_modifier_and_class_and_test {
  my ($self, $replace_var) = @_;

  if ($replace_var->{print_flg} == 1) {
    $replace_var->{print_flg} = 2;
    $self->_print("MODIFIED : $replace_var->{replace_name} -> {modifier} = '$replace_var->{modifier}' => ''");
    if ($self->_generate_and_test) { return 1; }
    $replace_var->{print_flg} = 3;
    $self->_print("MODIFIED : $replace_var->{replace_name} -> {class} = '$replace_var->{class}' => ''");
    $self->_print("         : $replace_var->{replace_name} -> {modifier} = '' => '$replace_var->{modifier}");
    if ($self->_generate_and_test) { return 1; }
    $replace_var->{print_flg} = 4;
    $self->_print("MODIFIED : $replace_var->{replace_name} -> {class} = '$replace_var->{class}' => ''");
    if ($self->_generate_and_test) { return 1; }
    $replace_var->{print_flg} = 1;
    $self->_print("MODIFIED : $replace_var->{replace_name} -> {class} = '' => '$replace_var->{class}'");
    $self->_print("         : $replace_var->{replace_name} -> {modifier} = '' => '$replace_var->{modifier}'");
  }
  elsif ($replace_var->{print_flg} == 2) {
    $replace_var->{print_flg} = 4;
    $self->_print("MODIFIED : $replace_var->{replace_name} -> {class} = '$replace_var->{class}' => ''");
    if ($self->_generate_and_test) { return 1; }
    $replace_var->{print_flg} = 2;
    $self->_print("MODIFIED : $replace_var->{replace_name} -> {class} = '' => '$replace_var->{class}'");
  }
  elsif ($replace_var->{print_flg} == 3) {
    $replace_var->{print_flg} = 4;
    $self->_print("MODIFIED : $replace_var->{replace_name} -> {modifier} = '$replace_var->{modifier}' => ''");
    if ($self->_generate_and_test) { return 1; }
    $replace_var->{print_flg} = 3;
    $self->_print("MODIFIED : $replace_var->{replace_name} -> {modifier} = '' => '$replace_var->{modifier}'");
  }
  elsif ($replace_var->{print_flg} == 4) {
    ;
  }

  return 0;
}

sub change_scope {
  my ($self, $replace_var) = @_;
  my $update = 0;

  if ($replace_var->{scope} eq 'LOCAL') {
    $self->_print("MODIFIED : $replace_var->{replace_name} -> {scope} = '$replace_var->{scope}' => 'GLOBAL'");
    $replace_var->{scope} = 'GLOBAL';
  }
  elsif ($replace_var->{scope} eq 'GLOBAL') {
    $self->_print("MODIFIED : $replace_var->{replace_name} -> {scope} = '$replace_var->{scope}' => 'LOCAL'");
    $replace_var->{scope} = 'LOCAL';
  }
  $replace_var->{changed_scope} = 1;
}

sub avoid_unionstruct {
  my ($self, $uus, $used_unionstruct, $avoid) = @_;

  my @uus_keys = map {$_->{name_type} . $_->{name_num} . "_" . join("_", @{$_->{elements}})} @$uus;
  my @used_unionstruct_keys = map {$_->{name_type} . $_->{name_num} . "_" . join("_", @{$_->{elements}})} @$used_unionstruct;
  my %count;
  my @unique;
  $count{$_}++ for (@uus_keys, @used_unionstruct_keys);
  @unique = grep { $count{$_} < 2 } keys %count;
  push @$avoid, @unique;
}

sub get_used_unionstruct {
  my $self = shift;

  my $obj = Orange4::Generator::Program->new( $self->{config}, $self->{func_list} );
  $obj->reset_varset_used( $self->{vars}, $self->{unionstructs},  $self->{run}->{generator}->{statements}, $self->{func_vars}, $self->{func_list} );
  return $obj->used_unionstruct();
}

sub reset_print_member {
  my ($self, $unionstructs) = @_;

  for my $us (@$unionstructs) {
    if ($us->{print_unionstruct} == 1) {
      for my $mem (@{$us->{member}}) {
        if ($mem->{used} == 0 && $mem->{print_member} == 0) {
          $mem->{print_member} = 1;
        }
      }
    }
  }
}

sub delete_unused_mem_all {
  my ($self, $unionstructs) = @_;

  $self->_print("DELETE : ALL MEMBERS");
  for my $us (@$unionstructs) {
    if ($us->{print_unionstruct} == 1) {
      for my $mem (@{$us->{member}}) {
        if ($mem->{used} == 0 && $mem->{print_member} == 1) {
          $mem->{print_member} = 0;
        }
      }
    }
  }
}

#使用していないメンバーを前からひとつずつ消す
sub delete_unused_mem_1by1 {
  my ($self, $unionstructs) = @_;
  my $update = 0;

  $self->_print("DELETE : UNSED MEMBER 1 BY 1");
  for my $us (@$unionstructs) {
    if ($us->{print_unionstruct} == 1) {
      for my $mem (@{$us->{member}}) {
        if ($mem->{used} == 0 && $mem->{print_member} == 1) {
          $mem->{print_member} = 0;
          if ($self->_generate_and_test) {
            $update = 1;
          }
          else {
            $mem->{print_member} = 1;
          }
        }
      }
    }
  }
  return $update;
}

# 使われていない構造体共用体を前からひとつずつ消す
sub delete_unused_unionstruct_1by1 {
  my ($self, $unionstructs) = @_;
  my $update = 0;
  $self->_print("DELETE : UNSED STRUCTS 1 BY 1");
  for my $us (@$unionstructs) {
    if ($us->{used} == 0 && $us->{print_unionstruct} == 1) {
      $us->{print_unionstruct} = 0;
      if ($self->_generate_and_test) {
        $update = 1;
      }
      else {
        $us->{print_unionstruct} = 1;
      }
    }
  }

  return $update;
}

# 使われていない構造体共用体を全部消す
sub delete_unused_unionstruct_all {
  my ($self, $unionstructs) = @_;
  $self->_print("DELETE : ALL STRUCTS AND UNIONS");
  for my $us (@$unionstructs) {
    if ($us->{used} == 0) {
      $us->{print_unionstruct} = 0;
    }
  }
}

# 構造体共用体のusedを１に
sub reset_print_unionstruct {
  my ($self, $ARRAY) = @_;

  for my $i (@$ARRAY) {
    $i->{print_unionstruct} = 1;
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
