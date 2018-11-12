package Orange4::Dumper;

use strict;
use warnings;

use Carp ();
use Math::BigInt;
use Data::Dumper;

sub new {
    my ( $class, %args ) = @_;

    for my $key (qw(vars unionstructs statements)) {
        unless ( exists $args{$key} ) {
            Carp::croak("Missing mandatory parameter: $key");
        }
    }

    my $vars  = delete $args{vars};
    my $unionstructs = delete $args{unionstructs};
    my $statements = delete $args{statements};

    bless {
        vars  => $vars,
        unionstructs => $unionstructs,
        statements => $statements,
        %args
    }, $class;
}

sub all {
    my ( $self, %args ) = @_;

    my @params;

    for my $key ( keys %args ) {
        push @params, "$key => '$args{$key}',";
    }

    return join "\n", "+{", @params, $self->_unionstructs, $self->_vars($self->{vars}), $self->_func_vars, $self->_func_list, $self->_statements, "}";
}

sub vars_and_statements {
    my $self = shift;

    return join "\n", $self->_vars, $self->_func_vars, $self->_func_list, $self->_statements;
}

sub _unionstructs {
  my $self = shift;


  my $s = "unionstructs => [\n";
  my $indent = '';
  my $n = "\n";

  for my $us ( @{$self->{unionstructs}} ) {
    $s .= $self->_unionstruct($us, $indent);
  }
  $s .= "],";

  return $s;
}

sub _unionstruct {
  my ($self, $unionstruct, $indent) = @_;
  my $s = "";
  my $n = "\n";

  $s .=  $indent . "{\n";

  my $indent2 = $indent . '  ';

  $s .= $indent2 . "'name_type'=>'$unionstruct->{name_type}'," . $n;
  $s .= $indent2 . "'name_num'=>'$unionstruct->{name_num}'," . $n;
  $s .= $indent2 . "'level'=>'$unionstruct->{level}'," . $n;
  $s .= $indent2 . "'member'=> ";
  $s .=  $self->_unionstructs_members($unionstruct->{member}, $indent2);
  $s .= $indent2 . "'print_unionstruct'=>'$unionstruct->{print_unionstruct}'," . $n;
  $s .= $indent2 . "'used'=>'$unionstruct->{used}'," . $n;
  $s .=  $indent . "}," . $n;

  return $s;
}

sub _unionstructs_members {
  my ($self, $member, $indent) = @_;
  my $s = "";
  my $n = "\n";
  my $indent2 = $indent . '  ';
  $s = " [\n";
  for my $i (@$member) {
    $s .= $indent . "{\n";
    $s .= $indent2 . "'name_type'=>'$i->{name_type}'," . $n;
    $s .= $indent2 . "'name_num'=>'$i->{name_num}'," . $n;
    if (ref $i->{type} eq "HASH") {
      $s .= $indent2 . "'type'=> " . $self->_unionstruct($i->{type}, $indent2);
    }
    else {
      $s .= $indent2 . "'type'=>'$i->{type}'," . $n;
    }
    $s .= $indent2 . "'modifier'=>'$i->{modifier}'," . $n;
    if (defined $i->{elements}) {
      $s .= $indent2 . "'elements' => [";
      for my $e (@{$i->{elements}}) {
        $s .= $e . ", ";
      }
      chop $s;
      chop $s;
      $s .= "]," . $n;
    }
    else {
      $s .= $indent2 . "'elements' => undef, " . $n;
    }
    $s .= $indent2 . "'print_member' => '$i->{print_member}'," . $n;
    $s .= $indent2 . "'used' => '$i->{used}'," . $n;

    $s .= $indent . "}, " . $n;


  }
  $s .= $indent . "],\n";

  return $s;
}

sub _func_list {
    my $self = shift;
    my $func_list = $self->{func_list};

    my $s = "'func_list' => [\n";
    my $indent1 = ' ';
    my $indent2 = '  ';
    my $indent3 = '   ';
    my $indent4 = '    ';
    my $n = "\n";

    for my $func ( @$func_list ){
        $s .= $indent1 . '{' . $n;
        $s .= $indent2 . "'st_type'=>'$func->{st_type}'," . $n;
        $s .= $indent2 . "'st_num'=>'$func->{st_num}'," . $n;
        $s .= $indent2 . "'type'=>'$func->{type}'," . $n;
        $s .= $indent2 . "'args_list'=>[\n";
        for my $arg ( @{$func->{args_list}} ){
            $s .= $self->_var($arg, $indent3);
        }
        $s .= $indent2 . "]," . $n;

        $s .= $indent2 . "'statements'=>[\n";
        $s .= $self->_statements_dumper($func->{statements}, $indent3);
        $s .= $indent2 . "]," . $n;

        $s .= $indent2 . "'print_tree'=>'$func->{print_tree}'," . $n;
        $s .= $indent2 . "'fixed_args_flag'=>'$func->{fixed_args_flag}'," . $n;
        if( defined $func->{return_var} ){
            $s .= $indent2 . "'return_var'=>'$func->{return_var}'," . $n;
            $s .= $indent2 . "'return_val_expression'=>{" . $n;
            $s .= $indent3 . "'root'=>{" . $n;
            $s .= $self->_root_dumper($func->{return_val_expression}->{root}, $indent4);
            $s .= $indent3 . "}," . $n;
            $s .= $indent3 . "'type'=>'$func->{return_val_expression}->{type}'," . $n;
            $s .= $indent3 . "'val'=>'$func->{return_val_expression}->{val}'," . $n;
            $s .= $indent2 . "}," . $n;
        }

        $s .= $indent2 . "'args_num_type'=>'$func->{args_num_type}'," . $n;
        $s .= $indent1 . '},' . $n;
    }

    $s .= "]," . $n;

    return $s;
}

sub _func_vars {
    my $self = shift;

    my $func_vars = $self->{func_vars};
    my $indent1 = ' ';
    my $indent2 = '  ';
    my $indent3 = '   ';
    my $indent4 = '    ';
    my $n = "\n";

    my $s = "'func_vars' => [\n";
    for my $func_var ( @$func_vars ){
        $s .= $indent1 . "{" . $n;
        $s .= $indent1 . "'replace_vars' => {},\n";
        $s .= $indent2 . $self->_vars($func_var->{vars});
        $s .= $indent1 . "}," . $n;
    }
    $s .= "]," . $n;

    return $s;
}

sub _var {
    my ($self, $var, $pre_indent) = @_;

    my $s = "";
    my $indent = $pre_indent . ' ';
    my $n      = "\n";

    $s .= $pre_indent . "{\n";
    my $v = $var;

  if (ref $v->{type} eq "HASH") {
        $s .= $indent . "'ival' => " . $self->check_elements($v, $v->{ival}) . ",\n";
        $s .= $indent . "'val' => " . $self->check_elements($v, $v->{val}) . ",\n";
        $s .= $indent . "'type'=>" . $self->_unionstruct($v->{type}, $indent);
        if (defined $v->{elements} && scalar @{$v->{elements}} > 0) {
          $s .= $indent . "'elements' => [";
          for my $e (@{$v->{elements}}) {
            $s .= $e . ", ";
          }
          chop $s;
          chop $s;
          $s .= "]," . $n;
        }
      }
      elsif (defined $v->{elements}) {
        $s .= $indent . "'type'=>'$v->{type}'," . $n;
        $s.= $indent . "'ival' => " . $self->_array_erements_dumper($v->{ival}, $v->{elements}, 0) . $n;
        $s.= $indent . "'val' => " . $self->_array_erements_dumper($v->{val}, $v->{elements}, 0) . $n;
        $s .= $indent . "'elements' => [";
        for my $e (@{$v->{elements}}) {
          $s .= $e . ", ";
        }
        chop $s;
        chop $s;
        $s .= "]," . $n;
        $s .= $indent . "'used_count' => ";
        $s .= "[";
        for my $num (@{$v->{used_count}}) {
          $s .= $num . ", ";
        }
        chop $s;
        chop $s;
        $s .= "]," . $n;
      } 
    else {

    $s .= $indent . "'type'=>'$v->{type}'," . $n;
    if ( ref $v->{val} ne 'Math::BigInt' ) {
        $s .= $indent . "'ival'=>'$v->{ival}'," . $n;
    }
    else {
        $s .= $indent . "'ival'=>" . _bigint_dumper( $v->{ival} ) . "," . $n;
    }
    if ( ref $v->{val} ne 'Math::BigInt' ) {
        $s .= $indent . "'val'=>'$v->{val}'," . $n;
    }
    else {
        $s .= $indent . "'val'=>" . _bigint_dumper( $v->{val} ) . "," . $n;
    }
  }
    $s .= $indent . "'name_type'=>'$v->{name_type}'," . $n;
    $s .= $indent . "'name_num'=>'$v->{name_num}'," . $n;
    $s .= $indent . "'class'=>'$v->{class}'," . $n;
    $s .= $indent . "'modifier'=>'$v->{modifier}'," . $n;
    $s .= $indent . "'scope'=>'$v->{scope}'," . $n;
    $s .= $indent . "'used'=>'$v->{used}'," . $n;
    if (defined $v->{print_arg}) {
      $s .= $indent . "'print_arg'=>'$v->{print_arg}'" . $n;
    }
    $s .= $pre_indent . "}," . $n;

    return $s;
}

sub _vars {
    my ($self, $varset) = @_;

    my $s      = "vars => [\n";
    my $indent = ' ';
    my $n      = "\n";

    for my $i ( 0 .. $#{$varset} ) {
      my $v = $varset->[$i];
      $s .= "{\n";
      if (ref $v->{type} eq "HASH") {
        $s .= $indent . "'ival' => " . $self->check_elements($v, $v->{ival}) . ",\n";
        $s .= $indent . "'val' => " . $self->check_elements($v, $v->{val}) . ",\n";
        $s .= $indent . "'type'=>" . $self->_unionstruct($v->{type}, $indent);
        if (defined $v->{elements}) {
          $s .= $indent . "'elements' => [";
          for my $e (@{$v->{elements}}) {
            $s .= $e . ", ";
          }
          chop $s;
          chop $s;
          $s .= "]," . $n;
        }
      }
      elsif (defined $v->{elements}) {
        $s .= $indent . "'type'=>'$v->{type}'," . $n;
        $s.= $indent . "'ival' => " . $self->_array_erements_dumper($v->{ival}, $v->{elements}, 0) . $n;
        $s.= $indent . "'val' => " . $self->_array_erements_dumper($v->{val}, $v->{elements}, 0) . $n;
        $s .= $indent . "'elements' => [";
        for my $e (@{$v->{elements}}) {
          $s .= $e . ", ";
        }
        chop $s;
        chop $s;
        $s .= "]," . $n;
        $s .= $indent . "'used_count' => ";
        $s .= "[";
        for my $num (@{$v->{used_count}}) {
          $s .= $num . ", ";
        }
        chop $s;
        chop $s;
        $s .= "]," . $n;
      } else {
        $s .= $indent . "'type'=>'$v->{type}'," . $n;
        $s .= $indent . "'replace_flag' => $v->{replace_flag}," . $n  if (defined $v->{replace_flag});
      if ( ref $v->{val} ne 'Math::BigInt' ) {
          $s .= $indent . "'ival'=>'$v->{ival}'," . $n;
      }
      else {
          $s .= $indent . "'ival'=>" . _bigint_dumper( $v->{ival} ) . "," . $n;
      }
      if ( ref $v->{val} ne 'Math::BigInt' ) {
          $s .= $indent . "'val'=>'$v->{val}'," . $n;
      }
      else {
          $s .= $indent . "'val'=>" . _bigint_dumper( $v->{val} ) . "," . $n;
      }
    }
      $s .= $indent . "'name_type'=>'$v->{name_type}'," . $n;
      $s .= $indent . "'name_num'=>'$v->{name_num}'," . $n;
      $s .= $indent . "'class'=>'$v->{class}'," . $n;
      $s .= $indent . "'modifier'=>'$v->{modifier}'," . $n;
      $s .= $indent . "'scope'=>'$v->{scope}'," . $n;
      $s .= $indent . "'used'=>'$v->{used}'," . $n;
      $s .= "}," . $n;
    }

    $s .= "],";

    return $s;
}

sub _bigint_dumper {
    my $val = shift;

    # my $sign    = $val->sign;
    # my $value   = $val->babs->bstr; # destructive...
    # my $content = "bless({'value'=>[$value], 'sign'=>'$sign'}, 'Math::BigInt')";
    my $content = "'$val'";

    return $content;
}

sub _array_erements_dumper {
  my ($self, $elements, $elements_num, $depth) = @_;
  my $print = "";

  $print .= "[";
  if (defined $elements_num->[$depth + 1]) {
    for my $i ( 0..($elements_num->[$depth] - 1) ) {
      $print .= $self->_array_erements_dumper($elements->[$i], $elements_num, $depth + 1);
    }
    chop $print;
    chop $print;
  } else {
    for my $val (@$elements) {
        $print .= "$val, ";
    }
    chop $print;
    chop $print;
  }
  $print .= "], ";

  return $print;
}

sub check_elements {
  my ($self, $k, $ival) = @_;

    my $print_val = "";
    if (defined $k->{elements} && scalar @{$k->{elements}} > 0) {
      $print_val .= $self->print_struct_array($k->{type}, $ival, $k->{elements}, 0);
      if (substr($print_val, -2, 2) eq ",]") {
        substr($print_val, -2, 1,"");
      }
      if ( substr($print_val, -3, 3) eq ", ]") {
        substr($print_val, -3, 2,"");
      }
    }
    else {
      $print_val .= $self->print_struct_member_value($k->{type}, $ival);
      if (substr($print_val, -2, 2) eq ",]") {
        substr($print_val, -2, 1,"");
      }
      if ( substr($print_val, -3, 3) eq ", ]") {
        substr($print_val, -3, 2,"");
      }
    }

  return $print_val;
}

sub print_struct_array {
  my ($self, $type, $ival, $elements, $ele_num) = @_;

  my $print_val = "";
  if ($elements->[$ele_num + 1]) {
    $print_val .= "[";
    for my $i (1..$elements->[$ele_num]) {
      $print_val .= $self->print_struct_array($type, $ival->[$i - 1], $elements, $ele_num + 1);
      $print_val .= ", ";

    }
    if (substr($print_val, -2, 2) eq ",]") {
      substr($print_val, -2, 1,"");
    }
    if ( substr($print_val, -3, 3) eq ", ]") {
      substr($print_val, -3, 2,"");
    }
    substr($print_val, -1, 1,"");
    $print_val .= "]";

  }
  else {
    $print_val .= "[";

    for my $i (1..$elements->[$ele_num]) {
      $print_val .= $self->print_struct_member_value($type, $ival->[$i - 1]);
      $print_val .= ", ";
    }
    substr($print_val, -2, 2,"");
    $print_val .= "]";

    if (substr($print_val, -2, 2) eq ",]") {

      substr($print_val, -2, 1,"");
    }
    if ( substr($print_val, -3, 3) eq ", ]") {
      substr($print_val, -3, 2,"");
    }
  }
  return $print_val;
}

sub print_struct_member_value {
  my ($self, $type, $ival) = @_;

  my $print_val = "";

  $print_val .= "[";

  for my $i (0..(scalar(@$ival)-1)) {
    if (ref($type->{member}->[$i]->{type}) eq 'HASH') {
      $print_val .= $self->check_elements($type->{member}->[$i], $ival->[$i]);
      $print_val .= ", ";
      if (substr($print_val, -2, 2) eq ",]") {
        substr($print_val, -2, 1,"");
      }
      if ( substr($print_val, -3, 3) eq ", ]") {
        substr($print_val, -3, 2,"");
      }
    }
    elsif (defined $type->{member}->[$i]->{elements}) {
      $print_val .= $self->_array_erements_dumper($ival->[$i], $type->{member}->[$i]->{elements}, 0);
    }
    else {
      $print_val .= "$ival->[$i],";
    }
  }

  $print_val .= "]";
  if (substr($print_val, -2, 2) eq ",]") {
    substr($print_val, -2, 1,"");
  }
  if ( substr($print_val, -3, 3) eq ", ]") {
    substr($print_val, -3, 2,"");
  }
  return $print_val;
}
sub _statements {
    my $self = shift;

    my $statements = $self->{statements};
    my $indent = '';

    my $s = "statements => [\n";
    $s .= $self->_statements_dumper($statements, $indent);
    $s .= "],";

    return $s;
}

sub _statements_dumper {
    my ($self, $statements, $pre_indent) = @_;

    my $indent1 = $pre_indent . ' ';
    my $indent2 = $pre_indent . '  ';
    my $indent3 = $pre_indent . '   ';
    my $indent4 = $pre_indent . '    ';

    my $n = "\n";
    my $s = '';

    for my $st ( @$statements ) {
        if ( $st->{st_type} eq 'for' ) {
            $s .= $pre_indent . '{' . $n;
            $s .= $indent1 . "'st_type'=>'$st->{st_type}'," . $n;
            $s .= $indent1 . "'print_tree'=>'$st->{print_tree}'," . $n;
            $s .= $indent1 . "'loop_var_name'=>'$st->{loop_var_name}'," . $n;
            $s .= $indent1 . "'inequality_sign'=>'$st->{inequality_sign}'," . $n;
            $s .= $indent1 . "'operator'=>'$st->{operator}'," . $n;
            $s .= $indent1 . "'loop_path'=>'$st->{loop_path}'," . $n;
            $s .= $indent1 . "'st_init'=>{" . $n;
            $s .= $indent2 . "'root'=>{" . $n;
            $s .= $self->_root_dumper($st->{st_init}->{root}, $indent3);
            $s .= $indent2 . "}," . $n;
            $s .= $indent2 . "'type'=>'$st->{st_init}->{type}'," . $n;
            $s .= $indent2 . "'val'=>'$st->{st_init}->{val}'," . $n;
            $s .= $indent1 . "}," . $n;
            $s .= $indent1 . "'continuation_cond'=>{" . $n;
            $s .= $indent2 . "'root'=>{" . $n;
            $s .= $self->_root_dumper($st->{continuation_cond}->{root}, $indent3);
            $s .= $indent2 . "}," . $n;
            $s .= $indent2 . "'type'=>'$st->{continuation_cond}->{type}'," . $n;
            $s .= $indent2 . "'val'=>'$st->{continuation_cond}->{val}'," . $n;
            $s .= $indent1 . "}," . $n;
            $s .= $indent1 . "'st_reinit'=>{" . $n;
            $s .= $indent2 . "'root'=>{" . $n;
            $s .= $self->_root_dumper($st->{st_reinit}->{root}, $indent3);
            $s .= $indent2 . "}," . $n;
            $s .= $indent2 . "'type'=>'$st->{st_reinit}->{type}'," . $n;
            $s .= $indent2 . "'val'=>'$st->{st_reinit}->{val}'," . $n;
            $s .= $indent1 . "}," . $n;
            $s .= $indent1 . "'statements'=> [\n";
            $s .= $self->_statements_dumper($st->{statements}, $indent2);
            $s .= $indent1 . "]," . $n;
            $s .= $pre_indent . '},' . $n;
        }
        elsif ( $st->{st_type} eq 'if' ) {
            $s .= $pre_indent . '{' . $n;
            $s .= $indent1 . "'st_type'=>'$st->{st_type}'," . $n;
            $s .= $indent1 . "'print_tree'=>'$st->{print_tree}'," . $n;
            $s .= $indent1 . "'exp_cond'=>{" . $n;
            $s .= $indent2 . "'root'=>{" . $n;
            $s .= $self->_root_dumper($st->{exp_cond}->{root}, $indent3);
            $s .= $indent2 . "}," . $n;
            $s .= $indent2 . "'type'=>'$st->{exp_cond}->{type}'," . $n;
            $s .= $indent2 . "'val'=>'$st->{exp_cond}->{val}'," . $n;
            $s .= $indent1 . "}," . $n;
            $s .= $indent1 . "'st_then'=> [\n";
            $s .= $self->_statements_dumper($st->{st_then}, $indent2);
            $s .= $indent1 . "]," . $n;
            $s .= $indent1 . "'st_else'=> [\n";
            $s .= $self->_statements_dumper($st->{st_else}, $indent2);
            $s .= $indent1 . "]," . $n;
            $s .= $pre_indent . '},' . $n;
        }
        elsif( $st->{st_type} eq 'while' ){
            $s .= $pre_indent . '{' . $n;
            $s .= $indent1 . "'st_type'=>'$st->{st_type}'," . $n;
            $s .= $indent1 . "'print_tree'=>'$st->{print_tree}'," . $n;
            $s .= $indent1 . "'loop_path'=>'$st->{loop_path}'," . $n;
            $s .= $indent1 . "'continuation_cond'=>{" . $n;
            $s .= $indent2 . "'root'=>{" . $n;
            $s .= $self->_root_dumper($st->{continuation_cond}->{root}, $indent3);
            $s .= $indent2 . "}," . $n;
            $s .= $indent2 . "'type'=>'$st->{continuation_cond}->{type}'," . $n;
            $s .= $indent2 . "'val'=>'$st->{continuation_cond}->{val}'," . $n;
            $s .= $indent1 . "}," . $n;
            if( defined $st->{st_condition_for_break} ){
                $s .= $indent1 . "'st_condition_for_break'=>{" . $n;
                $s .= $indent2 . "'root'=>{" . $n;
                $s .= $self->_root_dumper($st->{st_condition_for_break}->{root}, $indent3);
                $s .= $indent2 . "}," . $n;
                $s .= $indent2 . "'type'=>'st->{st_condition_for_break}->{type}'," . $n;
                $s .= $indent2 . "'val'=>'$st->{st_condition_for_break}->{val}'," . $n;
                $s .= $indent1 . "}," . $n;
            }
            $s .= $indent1 . "'statements'=> [\n";
            $s .= $self->_statements_dumper($st->{statements}, $indent2);
            $s .= $indent1 . "]," . $n;
            $s .= $pre_indent . '},' . $n;
        }
        elsif ( $st->{st_type} eq 'function_call' ) {
            $s .= $pre_indent . '{' . $n;
            $s .= $indent1 . "'st_type'=>'$st->{st_type}'," . $n;
            $s .= $indent1 . "'name_num'=>'$st->{name_num}'," . $n;
            $s .= $indent1 . "'print_tree'=>'$st->{print_tree}'," . $n;
            $s .= $indent1 . "'fixed_args_flag'=>'$st->{fixed_args_flag}'," . $n;
            if( defined $st->{args_num_expression}->{root} ){
                $s .= $indent1 . "'args_num_expression'=>{" . $n;
                $s .= $indent2 . "'root'=>{" . $n;
                $s .= $self->_root_dumper($st->{args_num_expression}->{root}, $indent3);
                $s .= $indent2 . "}," . $n;
                $s .= $indent2 . "'type'=>'st->{args_num_expression}->{type}'," . $n;
                $s .= $indent2 . "'val'=>'$st->{args_num_expression}->{val}'," . $n;
                $s .= $indent1 . "}," . $n;
            }
            $s .= $indent1 . "'args_expressions'=> [\n";
            for my $arg_statement ( @{$st->{args_expressions}} ){
              $s .= $indent2 . "{" . $n;
              if (ref $arg_statement->{type} eq 'HASH') {
                $s .= $indent3 . "'ival' => " . $self->check_elements($arg_statement, $arg_statement->{ival}) . ",\n";
                $s .= $indent3 . "'val' => " . $self->check_elements($arg_statement, $arg_statement->{val}) . ",\n";
                $s .= $indent3 . "'type'=>" . $self->_unionstruct($arg_statement->{type}, $indent3);
                if (defined $arg_statement->{elements}) {
                  $s .= $indent3 . "'elements' => [";
                  for my $e (@{$arg_statement->{elements}}) {
                    $s .= $e . ", ";
                  }
                  chop $s;
                  chop $s;
                  $s .= "]," . $n;
                }
                $s .= $indent3 . "'name_type'=>'$arg_statement->{name_type}'," . $n;
                $s .= $indent3 . "'name_num'=>'$arg_statement->{name_num}'," . $n;
                $s .= $indent3 . "'class'=>'$arg_statement->{class}'," . $n;
                $s .= $indent3 . "'modifier'=>'$arg_statement->{modifier}'," . $n;
                $s .= $indent3 . "'scope'=>'$arg_statement->{scope}'," . $n;
                $s .= $indent3 . "'used'=>'$arg_statement->{used}'," . $n;
                # $s .= "}," . $n;
              }
              elsif (ref $arg_statement->{val} eq 'ARRAY') {
                $s .= $indent3 . "'name_type'=>'$arg_statement->{name_type}'," . $n;
                $s .= $indent3 . "'name_num'=>'$arg_statement->{name_num}'," . $n;
                $s .= $indent3 . "'type'=>'$arg_statement->{type}'," . $n;
                $s .= $indent3 . "'ival' => " . $self->_array_erements_dumper($arg_statement->{ival}, $arg_statement->{elements}, 0) . $n;
                $s .= $indent3 . "'val' => " . $self->_array_erements_dumper($arg_statement->{val}, $arg_statement->{elements}, 0) . $n;
                $s .= $indent3 . "'elements' => [";
                for my $e (@{$arg_statement->{elements}}) {
                  $s .= $e . ", ";
                }
                chop $s;
                chop $s;
                $s .= "]," . $n;
                $s .= $indent3 . "'used_count' => ";
                $s .= "[";
                for my $num (@{$arg_statement->{used_count}}) {
                  $s .= $num . ", ";
                }
                chop $s;
                chop $s;
                $s .= "]," . $n;
              }
              else {
                $s .= $indent3 . "'root'=>{" . $n;
                $s .= $self->_root_dumper($arg_statement->{root}, $indent4);
                $s .= $indent3 . "}," . $n;
                $s .= $indent3 . "'type'=>'$arg_statement->{type}'," . $n;
                $s .= $indent3 . "'val'=>'$arg_statement->{val}'," . $n;
              }
              $s .= $indent2 . "}," . $n;
            }
            $s .= $indent1 . "]," . $n;
            $s .= $pre_indent . '},' . $n;
        }
        elsif ( $st->{st_type} eq 'switch' ){
            $s .= $pre_indent . '{' . $n;

            $s .= $indent1 . "'st_type'=>'$st->{st_type}'," . $n;
            $s .= $indent1 . "'print_tree'=>'$st->{print_tree}'," . $n;

            $s .= $indent1 . "'continuation_cond'=>{" . $n;
            $s .= $indent2 . "'root'=>{" . $n;
            $s .= $self->_root_dumper($st->{continuation_cond}->{root}, $indent3);
            $s .= $indent2 . "}," . $n;
            $s .= $indent2 . "'type'=>'$st->{continuation_cond}->{type}'," . $n;
            $s .= $indent2 . "'val'=>'$st->{continuation_cond}->{val}'," . $n;
            $s .= $indent1 . "}," . $n;

            $s .= $indent1 . "'cases'=>[" . $n;
            for my $case ( @{$st->{cases}} ){
                $s .= $indent2 . "{" . $n;
                if( defined $case->{constant_val} ){
                    $s .= $indent3 . "'constant_val'=>'$case->{constant_val}'," . $n;
                }
                $s .= $indent3 . "'path'=> '$case->{path}'," . $n;
                $s .= $indent3 . "'print_case'=>'$case->{print_case}'," . $n;
                $s .= $indent3 . "'statements'=> [" . $n;
                $s .= $self->_statements_dumper($case->{statements}, $indent3);
                $s .= $indent3 . "]," . $n;
                $s .= $indent2 . "}," . $n;
            }
            $s .= $indent1 . "]," . $n;

            $s .= $pre_indent . '},' . $n;
        }
	    elsif ( $st->{st_type} eq 'assign' ) {
            if ( defined $st->{root} ) {
                $s .= $pre_indent . '{' . $n;
                $s .= $indent1 . "'val'=>'$st->{val}'," . $n;
                $s .= $indent1 . "'type'=>'$st->{type}'," . $n;
                $s .= $indent1 . "'st_type'=>'$st->{st_type}'," . $n;
                $s .= $indent1 . "'path'=>'$st->{path}'," . $n;
                $s .= $indent1 . "'name_num'=>'$st->{name_num}'," . $n;
                $s .= $indent1 . "'print_statement'=>'$st->{print_statement}'," . $n;
                $s .= $indent1 . "'var'=>{" . $n;
                if (defined $st->{var}->{unionstruct}) {
                  $s .= $indent1 . "'unionstruct' => '$st->{var}->{unionstruct}'," . $n;
                }
                if (defined $st->{var}->{elements}) {
                  $s .= $indent2 . "'elements' => [";
                  for my $e (@{$st->{var}->{elements}}) {
                    $s .= $e . ", ";
                  }
                  chop $s;
                  chop $s;
                  $s .= "]," . $n;
                }
                $s .= $indent2 . "'type'=>'$st->{var}->{type}'," . $n;
                if (ref $st->{var}->{ival} ne 'Math::BigInt') {
                    $s .= $indent2 . "'ival'=>'$st->{var}->{ival}'," . $n;
                }
                else {
                    $s .= $indent2 . "'ival'=>" . _bigint_dumper($st->{var}->{ival}) . "," . $n;
                }
                if (ref $st->{var}->{val} ne 'Math::BigInt') {
                    $s .= $indent2 . "'val'=>'$st->{var}->{val}'," . $n;
                }
                else {
                    $s .= $indent2 . "'val'=>" . _bigint_dumper($st->{var}->{val}) . "," . $n;
                }
                $s .= $indent2 . "'name_type'=>'$st->{var}->{name_type}'," . $n;
                $s .= $indent2 . "'name_num'=>'$st->{var}->{name_num}'," . $n;
                $s .= $indent2 . "'class'=>'$st->{var}->{class}'," . $n;
                $s .= $indent2 . "'modifier'=>'$st->{var}->{modifier}'," . $n;
                $s .= $indent2 . "'scope'=>'$st->{var}->{scope}'," . $n;
                $s .= $indent2 . "'used'=>'$st->{var}->{used}'," . $n;
                if (defined $st->{var}->{replace_flag}) {

                  $s .= $indent2 . "'replace_flag'=>'$st->{var}->{replace_flag}'," . $n;
                }

                $s .= $indent1 . "}," . $n;

                $s .= $indent1 . "'root' => {" . $n;
                if ( $st->{print_statement} ) {
                	$s .= $self->_root_dumper($st->{root}, $indent2);
                }
                $s .= $indent1 . "}," . $n;
                if (defined $st->{sub_root}) {
                  $s .= $indent1 . "'sub_root' => {" . $n;
                  $s .= $self->_root_dumper($st->{sub_root}, $indent2);
                  $s .= $indent1 . "}," . $n;
                }
                $s .= $pre_indent . "}," . $n;
             }
            else {
                $s .= 'undef;' . $n;
            }
        }
        elsif ($st->{st_type} eq 'array') {
          $s .= $pre_indent . '{' . $n;

          $s .= $indent1 . "'st_type'=>'$st->{st_type}'," . $n;
          $s .= $indent1 . "'path'=>'$st->{path}'," . $n;
          $s .= $indent1 . "'type'=>'$st->{type}'," . $n;
          $s .= $indent1 . "'name_num'=>'$st->{name_num}'," . $n;

          $s .= $indent1 . "'sub_root' => {" . $n;
          $s .= $self->_root_dumper($st->{sub_root}, $indent2);
          $s .= $indent1 . "}," . $n;

          $s .= $indent1 . "'print_statement'=>'$st->{print_statement}'," . $n;

          $s .= $indent1 . "'array'=>{" . $n;
          $s .= $indent2 . "'name_type'=>'$st->{array}{name_type}'," . $n;
          $s .= $indent2 . "'name_num'=>'$st->{array}{name_num}'," . $n;
          $s .= $indent2 . "'type'=>'$st->{array}{type}'," . $n;
          $s .= $indent2 . "'ival'=> " . $self->_array_erements_dumper($st->{array}{ival}, $st->{array}{elements}, 0) . $n;
          $s .= $indent2 . "'val'=> " . $self->_array_erements_dumper($st->{array}{val}, $st->{array}{elements}, 0) . $n;
          $s .= $indent2 . "'class'=>'$st->{array}{class}'," . $n;
          $s .= $indent2 . "'modifier'=>'$st->{array}{modifier}'," . $n;
          $s .= $indent2 . "'scope'=>'$st->{array}{scope}'," . $n;
          $s .= $indent2 . "'used'=>'$st->{array}{used}'," . $n;
          if (defined $st->{array}{elements}) {
            $s .= $indent2 . "'elements' => [";
            for my $e (@{$st->{array}->{elements}}) {
              $s .= $e . ", ";
            }
            chop $s;
            chop $s;
            $s .= "]," . $n;
          }
          $s .= $indent2 . "'used_count' => ";
          $s .= "[";
          for my $num (@{$st->{array}{used_count}}) {
            $s .= $num . ", ";
          }
          chop $s;
          chop $s;
          $s .= "]," . $n;
          $s .= $indent1 . "}," . $n;

          $s .= $pre_indent . '},' . $n;
        }
        else { Carp::croak( "Invalid st_type $st->{st_type}" ); }
    }

    return $s;
}

sub _root_dumper {
    my ($self, $ref, $indent ) = @_;

    my $s          = '';
    my $new_indent = ' ';
    my $indent1    = $indent . $new_indent x 2;
    my $indent2    = $indent . $new_indent x 3;
    my $indent3    = $indent . $new_indent x 4;
    my $n          = "\n";
    $s .= $indent . "'out'=>{" . $n;
    if ( ref $ref->{val} ne 'Math::BigInt' ) {
        $s .= $indent1 . "'val'=>'$ref->{out}->{val}'," . $n;
    }
    else {
        $s .= $indent1 . "'val'=>" . _bigint_dumper( $ref->{out}->{val} ) . "," . $n;
    }
    $s .= $indent1 . "'type'=>'$ref->{out}->{type}'," . $n;
    $s .= $indent . "}," . $n;

    $s .= $indent . "'ntype'=>'$ref->{ntype}'," . $n;

    if ( $ref->{ntype} eq 'op' ) {
      if ($ref->{otype} eq 'a') {
        $s .= $indent . "'var'=>{" . $n;
        if (defined $ref->{var}->{elements}) {
          $s .= $indent1 . "'elements' => [";
          for my $e (@{$ref->{var}->{elements}}) {
            $s .= $e . ", ";
          }
          chop $s;
          chop $s;
          $s .= "]," . $n;
          $s .= $indent1 . "'print_array' => $ref->{var}->{print_array}," . $n  if (defined $ref->{var}->{print_array});
        }
        $s .= $indent1 . "'type'=>'$ref->{var}->{type}'," . $n;
        if ( ref $ref->{var}->{ival} ne 'Math::BigInt' ) {
            $s .= $indent1 . "'ival'=>'$ref->{var}->{ival}'," . $n;
        }
        else {
            $s .= $indent1 . "'ival'=>" . _bigint_dumper( $ref->{var}->{ival} ) . "," . $n;
        }
        if ( ref $ref->{var}->{val} ne 'Math::BigInt' ) {
            $s .= $indent1 . "'val'=>'$ref->{var}->{val}'," . $n;
        }
        else {
            $s .= $indent1 . "'val'=>" . _bigint_dumper( $ref->{var}->{val} ) . "," . $n;
        }
        if (defined $ref->{var}->{unionstruct}) {
            $s .= $indent1 . "'unionstruct'=>$ref->{var}->{unionstruct}," . $n;
        }
        $s .= $indent1 . "'replace_flag'=>$ref->{var}->{replace_flag}," . $n;
        $s .= $indent1 . "'name_type'=>'$ref->{var}->{name_type}'," . $n;
        $s .= $indent1 . "'name_num'=>'$ref->{var}->{name_num}'," . $n;
        $s .= $indent1 . "'class'=>'$ref->{var}->{class}'," . $n;
        $s .= $indent1 . "'modifier'=>'$ref->{var}->{modifier}'," . $n;
        $s .= $indent1 . "'scope'=>'$ref->{var}->{scope}'," . $n;
        $s .= $indent . "}," . $n;
      }
        $s .= $indent . "'otype'=>'$ref->{otype}'," . $n;
        $s .= $indent . "'ins_add'=>'$ref->{ins_add}'," . $n
            if ( defined( $ref->{ins_add} ) );
        $s .= $indent . "'in'=>[" . $n;
        for my $r ( @{ $ref->{in} } ) {
          if (ref $r->{ref}->{val} eq 'ARRAY') {
            $s .= $indent1 . "{'ref'=>" . $n;
            $s .= $self->_var($r->{ref}, $indent1);
            $s .= $indent1 . "}," . $n;
          } else {
            $s .= $indent1 . "{" . $n;
            $s .= $indent2 . "'print_value'=>$r->{print_value}," . $n;
            if ( ref $r->{val} ne 'Math::BigInt' ) {
                $s .= $indent2 . "'val'=>'$r->{val}'," . $n;
            }
            else {
                $s .= $indent2 . "'val'=>" . _bigint_dumper( $r->{val} ) . "," . $n;
            }
            $s .= $indent2 . "'type'=>'$r->{type}'," . $n;
            $s .= $indent2 . "'ref'=>{" . $n;
            $s .= $self->_root_dumper( $r->{ref}, $indent3 );
            $s .= $indent2 . "}," . $n;
            $s .= $indent1 . "}," . $n;
          }
        }
        $s .= $indent . "]," . $n;
    }
    elsif ( $ref->{ntype} eq 'var' ) {
        $s .= $indent . "'var'=>{" . $n;
        if (defined $ref->{var}->{elements}) {
          $s .= $indent1 . "'elements' => [";
          for my $e (@{$ref->{var}->{elements}}) {
            $s .= $e . ", ";
          }
          chop $s;
          chop $s;
          $s .= "]," . $n;
          $s .= $indent1 . "'print_array' => $ref->{var}->{print_array}," . $n  if (defined $ref->{var}->{print_array});
        }
        $s .= $indent1 . "'type'=>'$ref->{var}->{type}'," . $n;
        if ( ref $ref->{var}->{ival} ne 'Math::BigInt' ) {
            $s .= $indent1 . "'ival'=>'$ref->{var}->{ival}'," . $n;
        }
        else {
            $s .= $indent1 . "'ival'=>" . _bigint_dumper( $ref->{var}->{ival} ) . "," . $n;
        }
        if ( ref $ref->{var}->{val} ne 'Math::BigInt' ) {
            $s .= $indent1 . "'val'=>'$ref->{var}->{val}'," . $n;
        }
        else {
            $s .= $indent1 . "'val'=>" . _bigint_dumper( $ref->{var}->{val} ) . "," . $n;
        }
        if (defined $ref->{var}->{unionstruct}) {
            $s .= $indent1 . "'unionstruct'=>$ref->{var}->{unionstruct}," . $n;
        }
        $s .= $indent1 . "'replace_flag'=>$ref->{var}->{replace_flag}," . $n;
        $s .= $indent1 . "'name_type'=>'$ref->{var}->{name_type}'," . $n;
        $s .= $indent1 . "'name_num'=>'$ref->{var}->{name_num}'," . $n;
        $s .= $indent1 . "'class'=>'$ref->{var}->{class}'," . $n;
        $s .= $indent1 . "'modifier'=>'$ref->{var}->{modifier}'," . $n;
        $s .= $indent1 . "'scope'=>'$ref->{var}->{scope}'," . $n;
        $s .= $indent . "}," . $n;
    }
    else {
        Carp::croak("$ref->{ntype} is undefined");
    }

    return $s;
}

1;
