package Orange4::Mini::Array;

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

sub array_minimize {
    my ($self, $vars, $func_num) = @_;

    my $update = 0;
    my $avoid = []; #t配列は要素の式ごと置換するので, それによってt配列の要素の式中の配列の参照するをする必要がなくなる
    my $replace_vars = $func_num == -1 ? $self->{replace_vars} : $self->{func_vars}->[$func_num]->{replace_vars};
    my $replace_var;
    my $used_array = $self->get_used_array();
    for my $i (@$used_array) {
      $update = 0;

      my $array;
      my $key = $i->{name_type} . $i->{name_num} . "_" . join("_", @{$i->{elements}});

      if (grep {$_ eq $key} @$avoid) {
          next;
      }

      for my $j (@$vars) {
        if ($j->{name_type} eq $i->{name_type} && $j->{name_num} eq $i->{name_num}) {
          $array = $j;
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

            #print_flg = 1 : mod = あり class = あり
            #print_flg = 2 : mod = 無し class = あり
            #print_flg = 3 : mod = あり class = 無し
            #print_flg = 4 : mod = 無し class =  無し
            if ( $i->{modifier} eq "" && $i->{class} eq "") { $replace_var->{print_flg} = 4; }
            elsif ( $i->{modifier} ne "" && $i->{class} eq "" ) { $replace_var->{print_flg} = 3;}
            elsif ( $i->{modifier} eq "" && $i->{class} ne "" ) { $replace_var->{print_flg} = 2;}
            else { $replace_var->{print_flg} = 1;}
          }
          #t配列は要素の式ごと置換するので, それによってt配列の要素の式中の配列の参照するをする必要がなくなる
          my $ua = $self->get_used_array();
          if (scalar @$ua != scalar @$used_array) {
            $self->avoid_array($ua, $used_array, $avoid);
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


#print_flg = 1 : mod = あり class = あり
#print_flg = 2 : mod = 無し class = あり
#print_flg = 3 : mod = あり class = 無し
#print_flg = 4 : mod = 無し class =  無し
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

sub avoid_array {
  my ($self, $ua, $used_array, $avoid) = @_;


    my @ua_keys = map {$_->{name_type} . $_->{name_num} . "_" . join("_", @{$_->{elements}})} @$ua;
    my @used_array_keys = map {$_->{name_type} . $_->{name_num} . "_" . join("_", @{$_->{elements}})} @$used_array;
    my %count;
    my @unique;
    $count{$_}++ for (@ua_keys, @used_array_keys);
    @unique = grep { $count{$_} < 2 } keys %count;
    push @$avoid, @unique;
}

sub get_used_array {
  my $self = shift;

  my $obj = Orange4::Generator::Program->new( $self->{config}, $self->{func_list} );
  $obj->reset_varset_used( $self->{vars}, $self->{unionstructs},  $self->{run}->{generator}->{statements}, $self->{func_vars}, $self->{func_list} );
  return $obj->used_array();
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
