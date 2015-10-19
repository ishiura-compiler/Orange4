package Orange4::Dumper;

use strict;
use warnings;

use Carp ();
use Math::BigInt;

use Data::Dumper;

sub new {
  my ( $class, %args ) = @_;

  for my $key (qw(vars roots)) {
    unless ( exists $args{$key} ) {
      Carp::croak("Missing mandatory parameter: $key");
    }
  }

  my $vars  = delete $args{vars};
  my $roots = delete $args{roots};

  bless {
    vars  => $vars,
    roots => $roots,
    %args
  }, $class;
}

sub all {
  my ( $self, %args ) = @_;

  my @params;
  for my $key ( keys %args ) {
    push @params, "$key => $args{$key},";
  }
  return join "\n", "+{", @params, $self->_vars, $self->_roots, "}";
}

sub vars_and_roots {
  my $self = shift;

  return join "\n", $self->_vars, $self->_roots;
}

sub _vars {
  my $self = shift;

  my $varset = $self->{vars};

  my $s      = "vars => [\n";
  my $indent = ' ';
  my $n      = "\n";

  for my $i ( 0 .. $#{$varset} ) {
    $s .= "{\n";
    my $v = $varset->[$i];
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
  
  #    my $sign = $val->sign;
  #    my $value = $val->babs->bstr; # destructive...
  #    my $content = "bless({'value'=>[$value], 'sign'=>'$sign'}, 'Math::BigInt')";
  my $content = "'$val'";
  
  return $content;
}

sub _roots {
    my $self = shift;
    
    my $roots = $self->{roots};
    my $indent = '';
    
    my $s = "roots => [\n";
    $s .= _roots_dumper($roots, $indent);
    $s .= "],";
    
    return $s;
}

sub _roots_dumper {
    my ($roots, $pre_indent) = @_;
    
    my $indent1 = $pre_indent . ' ';
    my $indent2 = $pre_indent . '  ';
    my $indent3 = $pre_indent . '   ';
    my $n = "\n";
    my $s = '';
    
    for my $st (@$roots) {
        if ($st->{st_type} eq 'for') {
            $s .= $pre_indent . '{' . $n;
            $s .= $indent1 . "'st_type'=>'$st->{st_type}'," . $n;
            $s .= $indent1 . "'print_tree'=>'$st->{print_tree}'," . $n; ###
            $s .= $indent1 . "'loop_var_name'=>'$st->{loop_var_name}'," . $n;
            $s .= $indent1 . "'inequality_sign'=>'$st->{inequality_sign}'," . $n;
            $s .= $indent1 . "'operator'=>'$st->{operator}'," . $n;
            $s .= $indent1 . "'init_st'=>{" . $n;
            $s .= $indent2 . "'root'=>{" . $n;
            $s .= _root_dumper($st->{init_st}->{root}, $indent3);
            $s .= $indent2 . "}," . $n;
            $s .= $indent2 . "'type'=>'$st->{init_st}->{type}'," . $n;
            $s .= $indent2 . "'val'=>'$st->{init_st}->{val}'," . $n;
            #$s .= $indent2 . "'ival'=>'$st->{init_st}->{ival}'," . $n; ###
            $s .= $indent1 . "}," . $n;
            $s .= $indent1 . "'continuation_cond'=>{" . $n;
            $s .= $indent2 . "'root'=>{" . $n;
            $s .= _root_dumper($st->{continuation_cond}->{root}, $indent3);
            $s .= $indent2 . "}," . $n;
            $s .= $indent2 . "'type'=>'$st->{continuation_cond}->{type}'," . $n;
            $s .= $indent2 . "'val'=>'$st->{continuation_cond}->{val}'," . $n;
            #$s .= $indent2 . "'ival'=>'$st->{continuation_cond}->{ival}'," . $n; ###
            $s .= $indent1 . "}," . $n;
            $s .= $indent1 . "'re_init_st'=>{" . $n;
            $s .= $indent2 . "'root'=>{" . $n;
            $s .= _root_dumper($st->{re_init_st}->{root}, $indent3);
            $s .= $indent2 . "}," . $n;
            $s .= $indent2 . "'type'=>'$st->{re_init_st}->{type}'," . $n;
            $s .= $indent2 . "'val'=>'$st->{re_init_st}->{val}'," . $n;
            #$s .= $indent2 . "'ival'=>'$st->{re_init_st}->{ival}'," . $n; ###
            $s .= $indent1 . "}," . $n;
            $s .= $indent1 . "'statements'=> [\n";
            $s .= _roots_dumper($st->{statements}, $indent2);
            $s .= $indent1 . "]," . $n;
            $s .= $pre_indent . '},' . $n;
        }
        elsif ($st->{st_type} eq 'if') {
            $s .= $pre_indent . '{' . $n;
            $s .= $indent1 . "'st_type'=>'$st->{st_type}'," . $n;
            $s .= $indent1 . "'print_tree'=>'$st->{print_tree}'," . $n; ###
            $s .= $indent1 . "'exp_cond'=>{" . $n;
            $s .= $indent2 . "'root'=>{" . $n;
            $s .= _root_dumper($st->{exp_cond}->{root}, $indent3);
            $s .= $indent2 . "}," . $n;
            $s .= $indent2 . "'type'=>'$st->{exp_cond}->{type}'," . $n;
            $s .= $indent2 . "'val'=>'$st->{exp_cond}->{val}'," . $n;
            #$s .= $indent2 . "'ival'=>'$st->{exp_cond}->{ival}'," . $n; ###
            $s .= $indent1 . "}," . $n;
            $s .= $indent1 . "'st_then'=> [\n";
            $s .= _roots_dumper($st->{st_then}, $indent2);
            $s .= $indent1 . "]," . $n;
            $s .= $indent1 . "'st_else'=> [\n";
            $s .= _roots_dumper($st->{st_else}, $indent2);
            $s .= $indent1 . "]," . $n;
            $s .= $pre_indent . '},' . $n;
        }
	    elsif ($st->{st_type} eq 'assign') {
            if (defined $st->{root}) {
                $s .= $pre_indent . '{' . $n;
                $s .= $indent1 . "'val'=>'$st->{val}'," . $n;
                $s .= $indent1 . "'type'=>'$st->{type}'," . $n;
                $s .= $indent1 . "'st_type'=>'$st->{st_type}'," . $n;
                $s .= $indent1 . "'path'=>'$st->{path}'," . $n;
                $s .= $indent1 . "'name_num'=>'$st->{name_num}'," . $n;
                $s .= $indent1 . "'print_statement'=>'$st->{print_statement}'," . $n;
                $s .= $indent1 . "'var'=>{" . $n;
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
                $s .= $indent1 . "}," . $n;
                
                $s .= $indent1 . "'root' => {" . $n;
                if($st->{print_statement}) {
                	$s .= _root_dumper($st->{root}, $indent2);
                }
                $s .= $indent1 . "}," . $n;
                $s .= $pre_indent . "}," . $n;
             }
            else {
                $s .= 'undef;' . $n;
            }
        }
        else { Carp::croak( "Invalid st_type $st->{st_type}" ); }
    }
    
    return $s;
}

sub _root_dumper {
  my ( $ref, $indent ) = @_;

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
    $s .=
      $indent1 . "'val'=>" . _bigint_dumper( $ref->{out}->{val} ) . "," . $n;
  }
  $s .= $indent1 . "'type'=>'$ref->{out}->{type}'," . $n;
  $s .= $indent . "}," . $n;

  $s .= $indent . "'ntype'=>'$ref->{ntype}'," . $n;

  if ( $ref->{ntype} eq 'op' ) {
    $s .= $indent . "'otype'=>'$ref->{otype}'," . $n;
    $s .= $indent . "'ins_add'=>'$ref->{ins_add}'," . $n
      if ( defined( $ref->{ins_add} ) );
    $s .= $indent . "'in'=>[" . $n;
    for my $r ( @{ $ref->{in} } ) {
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
      $s .= _root_dumper( $r->{ref}, $indent3 );
      $s .= $indent2 . "}," . $n;
      $s .= $indent1 . "}," . $n;
    }
    $s .= $indent . "]," . $n;
  }
  elsif ( $ref->{ntype} eq 'var' ) {
    $s .= $indent . "'var'=>{" . $n;
    $s .= $indent1 . "'type'=>'$ref->{var}->{type}'," . $n;
    if ( ref $ref->{var}->{ival} ne 'Math::BigInt' ) {
      $s .= $indent1 . "'ival'=>'$ref->{var}->{ival}'," . $n;
    }
    else {
      $s .=
          $indent1 . "'ival'=>" . _bigint_dumper( $ref->{var}->{ival} ) . "," . $n;
    }
    if ( ref $ref->{var}->{val} ne 'Math::BigInt' ) {
      $s .= $indent1 . "'val'=>'$ref->{var}->{val}'," . $n;
    }
    else {
      $s .=
        $indent1 . "'val'=>" . _bigint_dumper( $ref->{var}->{val} ) . "," . $n;
    }
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

