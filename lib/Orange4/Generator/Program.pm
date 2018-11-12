package Orange4::Generator::Program;

use strict;
use warnings;
no warnings 'recursion';
use Data::Dumper;
use Carp ();
use Clone qw(clone);
use Smart::Comments;

sub new {
    my ( $class, $config ) = @_;

    bless { config => $config,
            used_array => [],
            used_unionstruct => [],
            varset_hash => [],
          }, $class;
}

sub _check_structure {
    my ( $self, $statements ) = @_;

    foreach my $st ( @$statements ) {
        if ( defined ( $st->{st_type} ) ) {
            if ( $st->{st_type} eq 'array' ) {
              unless ( defined ($st->{type}) )     { Carp::croak( "undefined type" ); }
              unless ( defined ($st->{array}) )           { Carp::croak( "undefined array" ); }
              unless ( defined ($st->{name_num}) ) { Carp::croak( "undefined name_num" ); }
              unless ( defined ($st->{sub_root}) )        { Carp::croak( "undefined sub_root" ); }
            }
            elsif( $st->{st_type} eq 'for' ) {
                unless ( defined ($st->{loop_var_name}) )     { Carp::croak( "undefined loop_var_name" ); }
                unless ( defined ($st->{st_init}) )           { Carp::croak( "undefined st_init" ); }
                unless ( defined ($st->{continuation_cond}) ) { Carp::croak( "undefined continuation_cond" ); }
                unless ( defined ($st->{st_reinit}) )        { Carp::croak( "undefined st_reinit" ); }
                unless ( defined ($st->{inequality_sign}) )   { Carp::croak( "undefined inequality_sign" ); }
                unless ( defined ($st->{statements}) )        { Carp::croak( "undefined statements" ); }
            }
            elsif( $st->{st_type} eq 'if' ) {
                unless (defined ($st->{exp_cond}) ) { Carp::croak( "undefined exp_cond" ); }
                unless (defined ($st->{st_then}) )  { Carp::croak( "undefined st_then" ); }
                unless (defined ($st->{st_else}) )  { Carp::croak( "undefined st_else" ); }
            }
            elsif ( $st->{st_type} eq 'assign' ) {
                if ( defined ( $st->{print_statement} ) && $st->{print_statement} ) {
                    if ( $st->{var}->{type} eq $st->{type} ) { ; }
                    else { Carp::croak( "type ne assgign-var-type($st->{name_num})" ); }
                    if ( $st->{var}->{val} eq $st->{val} ) { ; }
                    else { Carp::croak( "val ne assgign-var-val($st->{name_num})" ); }
                    if ( defined ( $st->{root}->{out}->{type} ) ) { ; }
                    else { Carp::croak( "undefined root-out-type($st->{name_num})" ); }
                    if ( defined ( $st->{root}->{out}->{val} ) ) { ; }
                    else { Carp::croak( "undefined root-out-val($st->{name_num})" ); }
                    if ( defined ( $st->{root}->{ntype} ) ) { ; }
                    else { Carp::croak( "undefined root-ntype($st->{name_num})" ); }
                    if ( defined ( $st->{root}->{otype} ) ) { ; }
                    else { Carp::croak( "undefined root-otype($st->{name_num})" ); }
                    if ( $st->{root}->{out}->{type} eq $st->{type} ) { ; }
                    else { Carp::croak( "type ne root-out-type($st->{name_num})" ); }
                    if ( $st->{root}->{out}->{val} eq $st->{val} ) { ; }
                    else { Carp::croak( "val ne root-out-val($st->{name_num})" ); }
                }
                elsif ( defined ( $st->{print_statement} ) && !$st->{print_statement} ) { ; }
                else { Carp::croak( "undefined print_statement($st->{name_num})" ); }
                if ( defined ( $st->{var} ) ) { ; }
                else { Carp::croak( "undefined assgign-var($st->{name_num})" ); }
                if ( defined ( $st->{type} ) ) { ; }
                else { Carp::croak( "undefined assgign-type($st->{name_num})" ); }
                if ( defined ( $st->{val} ) ) { ; }
                else { Carp::croak( "undefined assgign-val($st->{name_num})" ); }
            }
            elsif ( $st->{st_type} eq 'function_call' ) {
              if (defined $st->{name_num}) { ; }
              else { Carp::croak( "undefined name_num");}
              if (defined $st->{args_list}) { ; }
              else { Carp::croak( "undefined args_list");}
              if (defined $st->{args_expressions}) { ; }
              else { Carp::croak( "undefined args_expressions");}
              if (defined $st->{fixed_args_flag}) { ; }
              else { Carp::croak( "undefined fixed_args_flag");}
              if (defined $st->{args_num_expression}) { ; }
              else { Carp::croak( "undefined args_num_expression");}
              if (defined $st->{selected_func_num}) { ; }
              else { Carp::croak( "undefined selected_func_num");}
              if (defined $st->{args_var}) { ; }
              else { Carp::croak( "undefined args_var");}
              if (defined $st->{print_tree}) { ; }
              else { Carp::croak( "undefined print_tree");}
            }
            elsif ( $st->{st_type} eq 'while' ){
              if (defined $st->{continuation_cond}) { ; }
              else { Carp::croak( "undefined continuation_cond");}
              if (defined $st->{st_condition_for_break}) { ; }
              else { Carp::croak( "undefined st_condition_for_break");}
              if (defined $st->{statements}) { ; }
              else { Carp::croak( "undefined statements");}
              if (defined $st->{print_tree}) { ; }
              else { Carp::croak( "undefined print_tree");}
              if (defined $st->{loop_path}) { ; }
              else { Carp::croak( "undefined loop_path");}
            }
            elsif ( $st->{st_type} eq 'switch' ){
              if (defined $st->{continuation_cond}) { ; }
              else { Carp::croak( "undefined continuation_cond");}
              if (defined $st->{cases}) { ; }
              else { Carp::croak( "undefined cases");}
              if (defined $st->{print_tree}) { ; }
              else { Carp::croak( "undefined print_tree");}
            }
            else {
                Carp::croak( "unexpected st_type($st->{st_type})" );
            }
        }
        else {
            Carp::croak( "undefined st_type $st->{st_type}" );
        }
    }
}

sub generate_program {
    my ( $self, $varset, $unionstructs, $func_list, $func_vars, $statements, $replace_varset) = @_;

    my $config = $self->{config};
    my %declared_name = ();
    my $COMPARE;
    my $specifier;
    my $specification_part;
    my $suffix = '';

    my $DR_mode                = 1;
    my $GLOBAL_VAR_DECLARATION = "";
    my $LOCAL_VAR_DECLARATION  = "";
    my $STRUCT_DECLARATION     = "";

    my $flt_eq  = "";
    my $dbl_eq  = "";
    my $ldbl_eq = "";
    my $abs     = "";
    my $max     = "";

    my $header = $config->get('headers');
    my $main_type = ($config->get('main_type')) ? $config->get('main_type') : "int";
    my $retval = ($main_type eq "void") ? "" : 0;

    my $macrosd  = "";
    my $MACROS   = "";
    my $MACROS_2 = "";

    my $func_arg = "";
    my $func_par = "";

    my $tests = "";
    my $funcr = "";

    my $gvar_set  = [];
    my $lvar_set  = [];
    my $test_name = "";
    my $test      = "";
    my $check     = "";
    my $fmt       = "";

    my $func_declaration = "";

    my $cvar_check = "";
    my $cvar_declaration = "";

    my $macro_ok = $config->get('macro_ok');
    my $macro_ng = $config->get('macro_ng');
    if ( $macro_ok =~/printf/ || $macro_ng =~/printf/ ) {
        if ( defined $header && grep{/#include<stdio\.h>/} @$header ) {
            $MACROS = "";
        }
        else {
            $MACROS = "#include <stdio.h>\n";
            $MACROS .= "#include <stdarg.h>\n";
        }
    }

    $macrosd .= "#define OK()  $macro_ok\n";
    $macrosd .= "#define NG(test,fmt,val)  $macro_ng\n";

    $MACROS .= $macrosd;

    chomp ($MACROS);
    chomp ($MACROS_2);

    #chomp($header);

    # statements structure check
    $self->_check_structure($statements);

    # not display variables that are not used
    $self->reset_varset_used($varset, $unionstructs, $statements, $func_vars, $func_list);

    $self->{tvar_count} = 0;
    $self->{used_loop_var_name_tmp} = ();
    $self->{cvar_count} = 0;

    for my $func ( @$func_list ){
        if( $func->{print_tree} == 1 ){
            $func_declaration .= $self->generate_func_declaration($func, $varset, "\t", $func_vars );
        }
    }
    chomp ($func_declaration);


    #プログラムの生成
    my $st = $self->generate_statements($statements, $varset, "\t");
    $test .= $st->{test};
    $check .= $st->{check};
    $cvar_check .= $st->{cvar_check};
    $cvar_declaration .= $st->{cvar_declaration};

    for my $k (@$varset) {
        $k->{used} = 0 unless ( defined ( $k->{used} ) );
        push @$lvar_set, $k if ( $k->{scope} eq "LOCAL" );
        push @$gvar_set, $k if ( $k->{scope} eq "GLOBAL" && $self->search_in_array($k, $gvar_set));

    }

    #最小化で生成した代理変数
    if (defined $replace_varset) {
      for my $key (sort keys %$replace_varset) {
          push @$lvar_set, $replace_varset->{$key} if ( defined $replace_varset->{$key} && $replace_varset->{$key}->{scope} eq "LOCAL" );
          push @$gvar_set, $replace_varset->{$key} if ( defined $replace_varset->{$key} && $replace_varset->{$key}->{scope} eq "GLOBAL");
      }
    }

    for my $vars ( @$func_vars ) {
        for my $var (@{$vars->{vars}}){
            if( $self->search_in_array($var, $gvar_set) &&
                $var->{scope} eq "GLOBAL"){
                push @$gvar_set, $var;
            }
        }
    }

    # DR_mode:2 CLASS:extern(Forcing)
    $STRUCT_DECLARATION = $self->make_struct_declaration($unionstructs);
    $GLOBAL_VAR_DECLARATION = $self->make_c_var_declaration( $DR_mode, $gvar_set, '' );
    $LOCAL_VAR_DECLARATION  = $self->make_c_var_declaration( $DR_mode, $lvar_set, "\t" );

    $GLOBAL_VAR_DECLARATION .= $cvar_declaration;

    # 使ったループ変数の重複を排除
    $self->{used_loop_var_name} = ();
    my %exist = ();
    foreach my $element (@{$self->{used_loop_var_name_tmp}}) {
        unless ( exists $exist{$element} ) {
            push @{$self->{used_loop_var_name}}, $element;
            $exist{$element} = 1;
        }
    }

    if( defined ($self->{used_loop_var_name} ) ) {
        # 変数名をソート
        @{$self->{used_loop_var_name}} = sort @{$self->{used_loop_var_name}};
        # ループ変数の宣言
        $LOCAL_VAR_DECLARATION .= "\tsigned int ";
        foreach my $element ( @{$self->{used_loop_var_name}} ) {
            $LOCAL_VAR_DECLARATION .= "$element, ";
        }
        chop $LOCAL_VAR_DECLARATION; chop $LOCAL_VAR_DECLARATION;
        $LOCAL_VAR_DECLARATION .= ";\n";
    }
    chomp ($LOCAL_VAR_DECLARATION);
    chomp ($GLOBAL_VAR_DECLARATION);

    my $C_PROGRAM_1 = ( $config->get('headers') ) ? join '\n', @$header : "";
    $C_PROGRAM_1 .= ( $MACROS eq "" ) ? "" : $MACROS . "\n\n";
    $C_PROGRAM_1 .= $STRUCT_DECLARATION . "\n";
    $C_PROGRAM_1 .= ( $GLOBAL_VAR_DECLARATION eq "" ) ? "" : $GLOBAL_VAR_DECLARATION . "\n\n";
    $C_PROGRAM_1 .= $func_declaration . "\n";

    my $C_PROGRAM_2 = ( $LOCAL_VAR_DECLARATION eq "" ) ? "" : $LOCAL_VAR_DECLARATION . "\n\n";
    $C_PROGRAM_2 .= ( $test eq "" )  ? "" : $test . "\n";
    $C_PROGRAM_2 .= ( $check eq "" )  ? "" : $check . "\n";
    $C_PROGRAM_2 .= ( $cvar_check eq "" )  ? "" : $cvar_check . "\n";
# Program ###############################
my $C_PROGRAM = <<"__END__";
$C_PROGRAM_1
$main_type main (void)
{
$C_PROGRAM_2
	return $retval;
}
__END__
    system "rm -f $config->{source_file} > /dev/null";
    my $source_file = $self->{config}->get('source_file');
    open( OUT, ">$source_file" );
    print OUT "$C_PROGRAM";
    close OUT;
    $self->{program} = $C_PROGRAM;
}

#構造体共用体の型枠の生成
sub make_struct_declaration {
  my ($self, $unionstructs) = @_;
  my $indent = "\t";
  my $declaration = "";

  for my $struct (@$unionstructs) {
      if ($struct->{print_unionstruct} == 1 ) {
        if ($struct->{used} == 1) {
        my $def = "";
        if ($struct->{name_type} eq 's') {
          $def = "struct ";
        }
        else {
          $def = "union ";
        }
        $declaration .= $def . $struct->{name_type} . $struct->{name_num} . " {\n";
        $declaration .= $self->make_member_declaration($struct, $indent);
        $declaration .= "};\n\n";
      }
    }
  }
  return $declaration;
}

#メンバ変数の生成
sub make_member_declaration {
  my ($self, $struct, $indent) = @_;
  my $declaration = "";
  for my $mem (@{$struct->{member}}) {
    if ($mem->{print_member} == 1) {
      $declaration .= $indent;
      $declaration .= "$mem->{modifier} " if ($mem->{modifier} ne '');

      if (ref($mem->{type}) eq 'HASH') {
        my $def2 = "";
        if ($mem->{type}->{name_type} eq 's') {
          $def2 = "struct ";
        }
        else {
          $def2 = "union ";
        }
        $declaration .= $def2 . "$mem->{type}->{name_type}" . "$mem->{type}->{name_num} ";
      }
      else {
        $declaration .= "$mem->{type} ";
      }
      $declaration .= "$mem->{name_type}" . "$mem->{name_num}";
      if ( defined $mem->{elements} ) {
        for my $num (@{ $mem->{elements} }) {
          $declaration.= "[$num]";
        }
      }
      $declaration .= ";\n";
    }
  }
  return $declaration;
}

sub search_in_array{
    my ($self, $var, $g_vars) = @_;

    for my $g_var (@$g_vars){
        if($var->{name_type} eq $g_var->{name_type} &&
           $var->{name_num} == $g_var->{name_num}){
            return 0;
        }
    }
    return 1;
}

# 関数宣言部の生成
sub generate_func_declaration {
    my ( $self, $statement, $varset, $tab, $func_vars ) = @_;

    my $declaration_st = "";
    my $args_list = "";
    my $args_check_st = "";
    # my $arg_count = 1;

    #引数の期待値計算文を生成
    for my $arg ( @{$statement->{args_list}} ){
      my $def;
        if (ref $arg->{type} eq "HASH") {
          if ($arg->{type}->{name_type} eq 's') {
            $def = "struct ";
          }
          else {
            $def = "union ";
          }
          $def .= "$arg->{type}->{name_type}" . "$arg->{type}->{name_num} " ;
        }
        else {
          $def = $arg->{type};
        }
        $args_list .= "$def a$arg->{name_num}";
        if(ref $arg->{val} eq 'ARRAY') {
            for my $num (@{$arg->{elements}}) {
                $args_list .= "[$num]";
            }
        }
        $args_list .= ", ";
        if ($arg->{print_arg} && ref $arg->{val} ne "ARRAY") {
          $args_check_st .= $self->generate_check_st($arg, $arg->{name_num}) if $arg->{print_arg};
        }
    }

    #関数名宣言と引数宣言の作成
    $declaration_st .= "$statement->{type}" . " " . "$statement->{st_type}" . "$statement->{st_num}" . "(";
    if( $statement->{fixed_args_flag} == 1 ){
        $args_list =~ s/,\s+$//;
        $declaration_st .= $args_list;
        $declaration_st .= ") {\n";
    }
    else{
        $declaration_st .= "signed int" . " args_num, ... ) {\n";
        $declaration_st .= "\tva_list args;\n";
        my $va_arg = "";
        for my $arg( @{$statement->{args_list}} ){
          my $def;
            if (ref $arg->{type} eq "HASH") {
              if ($arg->{type}->{name_type} eq 's') {
                $def = "struct ";
              }
              else {
                $def = "union ";
              }
              $def .= "$arg->{type}->{name_type}" . "$arg->{type}->{name_num} " ;
            }
            else {
                $def = $arg->{type};
                if (ref $arg->{val} eq 'ARRAY') {
                    for  my $e (@{$arg->{elements}}) {
                    $def .= '*';
                    }
                }
            }
            $declaration_st .= "\t$def " .  "a$arg->{name_num}" . ";\n";
            $va_arg .= "\ta$arg->{name_num}" . " = va_arg( args, $def );\n";
        }
        $declaration_st .= "\tva_start( args, args_num );\n" . "$va_arg";
        $declaration_st .= "\tva_end( args );\n\n";
    }

    $self->{used_loop_var_name_tmp} = ();

    #関数内のstatementsの作成スタート
    my $st = $self->generate_statements($statement->{statements}, $varset, "$tab");

    # 使ったループ変数の重複を排除
    $self->{used_loop_var_name} = ();
    my %exist = ();
    foreach my $element (@{$self->{used_loop_var_name_tmp}}) {
        unless ( exists $exist{$element} ) {
            push @{$self->{used_loop_var_name}}, $element;
            $exist{$element} = 1;
        }
    }

    my $dec_vars = [];
    for my $local_var (@{$func_vars->[$statement->{st_num}]->{vars}}){
        if($local_var->{scope} eq "LOCAL" &&
           # $local_var->{name_type} ne 'a' &&
           $local_var->{used} == 1){
             push @{$dec_vars} , $local_var;
        }
    }
    my $replace_varset = $func_vars->[$statement->{st_num}]->{replace_vars};
    for my $key (sort keys %$replace_varset) {
        push @{$dec_vars}, $replace_varset->{$key} if ( defined $replace_varset->{$key} );
    }
    $declaration_st .= $self->make_c_var_declaration(1, $dec_vars, "$tab");


    if( defined ($self->{used_loop_var_name} ) ) {
        # 変数名をソート
        @{$self->{used_loop_var_name}} = sort @{$self->{used_loop_var_name}};
        # ループ変数の宣言
        $declaration_st .= "\tsigned int ";
        foreach my $element ( @{$self->{used_loop_var_name}} ) {
            $declaration_st .= "$element, ";
        }
        chop $declaration_st; chop $declaration_st;
        $declaration_st .= ";\n";
    }

    $declaration_st .= $st->{cvar_declaration};

    $declaration_st .= $st->{test};
    $declaration_st .= $st->{check};
    $declaration_st .= $st->{cvar_check};

    $declaration_st .= $args_check_st;

    #void関数以外はreturn文を作成
    if( defined $statement->{return_val_expression} ){
        $declaration_st .= "\treturn ";
        $declaration_st .= "@{[$self->tree_sprint($statement->{return_val_expression}->{root})]}";
        $declaration_st .= ";\n";
    }

    $declaration_st .= "}\n\n";

    return $declaration_st;
}

sub generate_check_st {
  my ($self, $var, $arg_count) = @_;
  my $st = "";
  my $test_name = "";
  my $specifier = "";
  my $fmt = "";

  $test_name = "a$arg_count";
  $specifier = $self->{config}->get('type')->{$var->{type}}->{printf_format};
  $fmt = "\"@{[$specifier]}\"";

  $st .= "\t" . "if (a" . "$arg_count" .  " == " . "$var->{val}" . ") { OK(); } ";
  $st .= "else { NG(" . "\"$test_name\", " . "$fmt, a$arg_count); }\n";

  return $st;
}

sub generate_statements {
    my ( $self, $statements, $varset, $tab, $func_list ) = @_;

    my $test = "";
    my $check = "";
    my $cvar_check = "";
    my $cvar_declaration = "";

    if ( defined ( $statements ) ) {
        for my $st ( @$statements ) {
          if ($st->{st_type} eq 'array') {
            my $array_st = $self->generate_variable_length_array_statement($st, $varset, "$tab");
            $test .= $array_st->{test};
          }
          elsif ( $st->{st_type} eq 'for' ) {
            my $for_st = $self->generate_for_statement($st, $varset, "$tab");
            $test .= $for_st->{test};
            $check .= $for_st->{check};
            $cvar_check .= $for_st->{cvar_check};
            $cvar_declaration .= $for_st->{cvar_declaration};
          }
          elsif ( $st->{st_type} eq 'if' ) {
            my $if_st = $self->generate_if_statement($st, $varset, "$tab");
            $test .= $if_st->{test};
            $check .= $if_st->{check};
            $cvar_check .= $if_st->{cvar_check};
            $cvar_declaration .= $if_st->{cvar_declaration};
          }
          elsif ( $st->{st_type} eq 'while' ) {
              my $while_st = $self->generate_while_statement($st, $varset, "$tab");
              $test .= $while_st->{test};
              $check .= $while_st->{check};
              $cvar_check .= $while_st->{cvar_check};
              $cvar_declaration .= $while_st->{cvar_declaration};
          }
          elsif ( $st->{st_type} eq 'switch' ) {
              my $switch_st = $self->generate_switch_statement($st, $varset, "$tab");
              $test .= $switch_st->{test};
              $check .= $switch_st->{check};
              $cvar_check .= $switch_st->{cvar_check};
              $cvar_declaration .= $switch_st->{cvar_declaration};
          }
          elsif ( $st->{st_type} eq 'function_call' ){
              my $func_st = $self->generate_func_statement($st, $func_list, "$tab");
              $test .= $func_st->{test};
          }
          elsif ( $st->{print_statement} && $st->{st_type} eq 'assign' ) {
            my $assign_st = $self->generate_assign_statement($st, $varset, "$tab");
            $test .= $assign_st->{test};
            $check .= $assign_st->{check};
          }
          else {;}
        }
    }
    else { ; }

    return +{
        test             => $test,
        check            => $check,
        cvar_check       => $cvar_check,
        cvar_declaration => $cvar_declaration,
    };
}

sub generate_switch_statement {
    my ($self, $statement, $varset, $tab) = @_;

    my $compare;
    my $specifier;
    my $fmt = "";
    my $test_name = "";
    my $test = "";
    my $check = "";
    my $cvar_check = "";
    my $cvar_declaration = "";
    my $st;
    my $val;
    my $type;

    if( $statement->{print_tree} == 1 ||
        $statement->{print_tree} == 4 ||
        $statement->{print_tree} == 5 ||
        $statement->{print_tree} == 6 ) {
        $test .= "$tab" . "switch( @{[$self->tree_sprint($statement->{continuation_cond}->{root})]} ){ \n";
        if( $statement->{print_tree} == 1 ||
            $statement->{print_tree} == 6 ) {
            my $count = 0;
            for my $case ( @{$statement->{cases}} ){
                if( $count == $#{$statement->{cases}} ){
                    $test .= "$tab\t" . "default:\n";
                    $st = $self->generate_statements($case->{statements}, $varset, "$tab\t\t");
                    $test .= $st->{test};
                    $check .= $st->{check};
                    $cvar_check .= $st->{cvar_check};
                    $cvar_declaration .= $st->{cvar_declaration};

                    $test .= "$tab\t" . "break;\n";
                }
                else{
                    $test .= "$tab\t" . "case $case->{constant_val}" . ":\n";
                    $st = $self->generate_statements($case->{statements}, $varset, "$tab\t\t");
                    $test .= $st->{test};
                    $check .= $st->{check};
                    $cvar_check .= $st->{cvar_check};
                    $cvar_declaration .= $st->{cvar_declaration};

                    $test .= "$tab\t" . "break;\n";
                }
                $count++;
            }
        }
        elsif( $statement->{print_tree} == 4) {
            my $count = 0;
            for my $case ( @{$statement->{cases}} ){
                if( $count == $#{$statement->{cases}} &&
                    $case->{path} == 1 ){
                    $test .= "$tab\t" . "default:\n";
                    $st = $self->generate_statements($case->{statements}, $varset, "$tab\t\t");
                    $test .= $st->{test};
                    $check .= $st->{check};
                    $cvar_check .= $st->{cvar_check};
                    $cvar_declaration .= $st->{cvar_declaration};
                    $test .= "$tab\t" . "break;\n";
                }
                elsif( $case->{path} == 1 ){
                    $test .= "$tab\t" . "case $case->{constant_val}" . ":\n";
                    $st = $self->generate_statements($case->{statements}, $varset, "$tab\t\t");
                    $test .= $st->{test};
                    $check .= $st->{check};
                    $cvar_check .= $st->{cvar_check};
                    $cvar_declaration .= $st->{cvar_declaration};

                    $test .= "$tab\t" . "break;\n";
                }
                else{ ; }
                $count++;
            }
        }
        elsif( $statement->{print_tree} == 5 ){
            my $count = 0;
            for my $case ( @{$statement->{cases}} ){
                if( $count == $#{$statement->{cases}} &&
                    $case->{print_case} == 1 ){
                    $test .= "$tab\t" . "default:\n";
                    $st = $self->generate_statements($case->{statements}, $varset, "$tab\t\t");
                    $test .= $st->{test};
                    $check .= $st->{check};
                    $cvar_check .= $st->{cvar_check};
                    $cvar_declaration .= $st->{cvar_declaration};

                    $test .= "$tab\t" . "break;\n";
                }
                elsif( $case->{print_case} == 1 ){
                    $test .= "$tab\t" . "case $case->{constant_val}" . ":\n";
                    $st = $self->generate_statements($case->{statements}, $varset, "$tab\t\t");
                    $test .= $st->{test};
                    $check .= $st->{check};
                    $cvar_check .= $st->{cvar_check};
                    $cvar_declaration .= $st->{cvar_declaration};

                    $test .= "$tab\t" . "break;\n";
                }
                else{ ; }
                $count++;
            }
        }
        $test .= "$tab" . "}\n";
    }
    elsif( $statement->{print_tree} == 0 ){
        for my $case ( @{$statement->{cases}} ){
            if( $case->{path} == 1 && @{$case->{statements}} ){
                $st = $self->generate_statements($case->{statements}, $varset, "$tab");
                $test .= $st->{test};
                $check .= $st->{check};
                $cvar_check .= $st->{cvar_check};
                $cvar_declaration .= $st->{cvar_declaration};
            }
        }
    }
    else{ ; }

    return +{
        test => $test,
        check => $check,
        cvar_check => $cvar_check,
        cvar_declaration => $cvar_declaration,
    };
}

# 関数呼び出し文
sub generate_func_statement {
    my ( $self, $statement, $varset, $tab ) = @_;

    my $test = "";
    my $args_num = scalar @{$statement->{args_expressions}};
    my $compare;
    my $specifier;
    my $fmt = "";
    my $test_name = "";
    my $check = "";
    my $cvar_check = "";
    my $cvar_declaration = "";
    my $st;
    my $val;
    my $type;

    if( $statement->{print_tree} == 1 ||
        $statement->{print_tree} == 3 ){
        $test .= "$tab" . "func$statement->{name_num}(";

        #可変引数の場合は引数の数を展開した式を第一引数に
        $test .= $statement->{fixed_args_flag} ? "" : "@{[$self->tree_sprint($statement->{args_num_expression}->{root})]}, ";

        #引数の値を展開した式を作っていく
        if( @{$statement->{args_expressions}} ){
            for my $arg_expression ( @{$statement->{args_expressions}} ){
              my $expression;
            #   if (defined $arg_expression->{type} && ref $arg_expression->{type} eq "HASH") {
                if (ref $arg_expression->{val} eq 'ARRAY') {
                $expression = $arg_expression->{name_type} . $arg_expression->{name_num};
              }
              else {
                $expression = "@{[$self->tree_sprint($arg_expression->{root})]}";
              }
                $test .= $expression;
                $test .= ", ";
            }
        }
        else{
            for my $arg ( @{$statement->{args_list}} ){
                $test .= "$arg->{name_type}$arg->{name_num}, ";
            }
        }
        $test =~ s/,\s+$//;
        $test .= ");\n";
    }
    elsif( $statement->{print_tree} == 0 ){
    }
    elsif( $statement->{print_tree} == 2){ # 今は使ってない

        #可変引数の場合は引数の個数の式を代入文に変える
        if( $statement->{fixed_args_flag} == 0 ){
            $test_name = "c$self->{cvar_count}";
            $test .= "$tab$test_name = @{[$self->tree_sprint($statement->{args_num_expression}->{root})]};\n";
            $val = Math::BigInt->new(0);
            $type = $statement->{args_num_expression}->{type};
            $val = $self->val_with_suffix($statement->{args_num_expression}->{val},$type);
            $specifier = $self->{config}->get('type')->{$type}->{printf_format};
            $compare = "$test_name == $val";
            $fmt = "\"@{[$specifier]}\"";
            $cvar_check .= "$tab" . "if ($compare) { OK(); } ";
            $cvar_check .= "$tab" . "else { NG(" . "\"$test_name\", " . "$fmt, $test_name ); }\n";
            $cvar_declaration .= "$type $test_name = $val;\n";
            $self->{cvar_count}++;
        }

        #引数の式を代入文に変える
        for my $arg_st ( @{$statement->{args_expressions}} ){
            $test_name = "c$self->{cvar_count}";
            $test .= "$tab$test_name = @{[$self->tree_sprint($statement->{arg_st}->{root})]};\n";
            $val = Math::BigInt->new(0);
            $type = $statement->{arg_st}->{type};
            $val = $self->val_with_suffix($statement->{arg_st}->{val},$type);
            $specifier = $self->{config}->get('type')->{$type}->{printf_format};
            $compare = "$test_name == $val";
            $fmt = "\"@{[$specifier]}\"";
            $cvar_check .= "$tab" . "if ($compare) { OK(); } ";
            $cvar_check .= "$tab" . "else { NG(" . "\"$test_name\", " . "$fmt, $test_name ); }\n";
            $cvar_declaration .= "$type $test_name = $val;\n";
            $self->{cvar_count}++;
        }
    }

    return +{
        test => $test,
        cvar_check => $cvar_check,
        cvar_declaration => $cvar_declaration,
    };
}

sub generate_variable_length_array_statement {
  my ( $self, $statement, $varset, $tab ) = @_;

  my $test = "";

  if ($statement->{print_statement}  && $statement->{st_type} eq 'array' ) {
    $test .= $tab;
    $test .= $statement->{array}->{type} . " ";
    $test .= $statement->{array}->{name_type} . $statement->{array}->{name_num} ;

    if ($statement->{sub_root}->{ntype} eq 'op' && $statement->{sub_root}->{otype} ne 'a') {
      #左辺配列の添字の式(頭にキャスト付き)
      my $i = 0;
      for my $num (@{$statement->{array}->{elements}} ) {
        if ($statement->{sub_root}->{in}->[0]->{ref}->{in}->[$i]->{print_value} == 0) {
            $test .= "[" . "@{[$self->tree_sprint($statement->{sub_root}->{in}->[0]->{ref}->{in}->[$i]->{ref})]}" . "]";  #$self->tree_sprint($statement->{sub_root}->{in}->[0]->{ref}->{in}->[$i]->{ref}) ."]"; #添字[][]
          }
          else {
            $test .= "[" . "$statement->{sub_root}->{in}->[0]->{ref}->{in}->[$i]->{val}" . "]";
          }
        $i++;
      }
    }
    else {
      #左辺配列の添字の式(頭にキャスト無し)
      my $i = 0;
      for my $num (@{$statement->{array}->{elements}} ) {
        if ($statement->{sub_root}->{in}->[$i]->{print_value} == 0) {

            $test .= "[" . "@{[$self->tree_sprint($statement->{sub_root}->{in}->[$i]->{ref})]}" . "]";# $self->tree_sprint($statement->{sub_root}->{in}->[$i]->{ref}) ."]"; #添字[][]
          } 
          else {
              $test .= "[" ."$statement->{sub_root}->{in}->[$i]->{val}" . "]";
          }
        $i++;
      }
    }

    $test .= ";\n";
  }

  return +{
    test => $test,
  };

}
# int t1[式];

sub generate_for_statement {
    my ( $self, $statement, $varset, $tab ) = @_;

    my $compare;
    my $specifier;
    my $fmt = "";
    my $test_name = "";
    my $test = "";
    my $check = "";
    my $cvar_check = "";
    my $cvar_declaration = "";
    my $st;
    my $val;
    my $type;

    if ( $statement->{print_tree} == 1 ||
         $statement->{print_tree} == 2 ||
         $statement->{print_tree} == 4 ) {
        if ( @{$statement->{statements}} ) {
            $test .= "$tab" . "for( $statement->{loop_var_name} = @{[$self->tree_sprint($statement->{st_init}->{root})]}; ";
            $test .= "$statement->{loop_var_name} $statement->{inequality_sign} @{[$self->tree_sprint($statement->{continuation_cond}->{root})]}; ";
            $test .= "$statement->{loop_var_name} $statement->{operator} @{[$self->tree_sprint($statement->{st_reinit}->{root})]}) {\n";
            push @{$self->{used_loop_var_name_tmp}}, $statement->{loop_var_name};

            if ( $statement->{print_tree} == 1 || $statement->{print_tree} == 4 ||
                ($statement->{print_tree} == 2 && $statement->{loop_path}  == 1) ) {
                $st = $self->generate_statements($statement->{statements}, $varset, "$tab\t");
                $test .= $st->{test};
                $check .= $st->{check};
                $cvar_check .= $st->{cvar_check};
                $cvar_declaration .= $st->{cvar_declaration};
            }
            $test .= "$tab}\n";
        }
	    else {
            $test .= "$tab" . "for( $statement->{loop_var_name} = @{[$self->tree_sprint($statement->{st_init}->{root})]}; ";
            $test .= "$statement->{loop_var_name} $statement->{inequality_sign} @{[$self->tree_sprint($statement->{continuation_cond}->{root})]}; ";
            $test .= "$statement->{loop_var_name} $statement->{operator} @{[$self->tree_sprint($statement->{st_reinit}->{root})]}) { ; }\n";
            push @{$self->{used_loop_var_name_tmp}}, $statement->{loop_var_name};
        }
    }
    elsif ( $statement->{print_tree} == 0 ) {
        if ( $statement->{loop_path} == 1 ) {
            $st = $self->generate_statements($statement->{statements}, $varset, "$tab");
            $test .= $st->{test};
            $check .= $st->{check};
            $cvar_check .= $st->{cvar_check};
            $cvar_declaration .= $st->{cvar_declaration};
        }
    }
    elsif ( $statement->{print_tree} == 3 ) {
        $test_name = "c$self->{cvar_count}";
        $test .= "$tab$test_name = @{[$self->tree_sprint($statement->{st_init}->{root})]};\n";
        $val = Math::BigInt->new(0);
        $type = $statement->{st_init}->{type};
        $val = $self->val_with_suffix($statement->{st_init}->{val},$type);
        $specifier = $self->{config}->get('type')->{$type}->{printf_format};
        $compare = "$test_name == $val";
        $fmt = "\"@{[$specifier]}\"";
        $cvar_check .= "$tab" . "if ($compare) { OK(); } ";
        $cvar_check .= "$tab" . "else { NG(" . "\"$test_name\", " . "$fmt, $test_name ); }\n";
        $cvar_declaration .= "$type $test_name = $val;\n";
        $self->{cvar_count}++;

        $test_name = "c$self->{cvar_count}";
        $test .= "$tab$test_name = @{[$self->tree_sprint($statement->{continuation_cond}->{root})]};\n";
        $val = Math::BigInt->new(0);
        $type = $statement->{continuation_cond}->{type};
        $val = $self->val_with_suffix($statement->{continuation_cond}->{val},$type);
        $specifier = $self->{config}->get('type')->{$type}->{printf_format};
        $compare = "$test_name == $val";
        $fmt = "\"@{[$specifier]}\"";
        $cvar_check .= "$tab" . "if ($compare) { OK(); } ";
        $cvar_check .= "$tab" . "else { NG(" . "\"$test_name\", " . "$fmt, $test_name ); }\n";
        $cvar_declaration .= "$type $test_name = $val;\n";
        $self->{cvar_count}++;

        $test_name = "c$self->{cvar_count}";
        $test .= "$tab$test_name = @{[$self->tree_sprint($statement->{st_reinit}->{root})]};\n";
        $val = Math::BigInt->new(0);
        $type = $statement->{st_reinit}->{type};
        $val = $self->val_with_suffix($statement->{st_reinit}->{val},$type);
        $specifier = $self->{config}->get('type')->{$type}->{printf_format};
        $compare = "$test_name == $val";
        $fmt = "\"@{[$specifier]}\"";
        $cvar_check .= "$tab" . "if ($compare) { OK(); } ";
        $cvar_check .= "$tab" . "else { NG(" . "\"$test_name\", " . "$fmt, $test_name ); }\n";
        $cvar_declaration .= "$type $test_name = $val;\n";
        $self->{cvar_count}++;

        if ( $statement->{loop_path} == 1 ) {
            $st = $self->generate_statements($statement->{statements}, $varset, "$tab");
            $test .= $st->{test};
            $check .= $st->{check};
            $cvar_check .= $st->{cvar_check};
            $cvar_declaration .= $st->{cvar_declaration};
        }
    }
    else { ; }

    return +{
        test => $test,
        check => $check,
        cvar_check => $cvar_check,
        cvar_declaration => $cvar_declaration,
    };
}

sub generate_if_statement {
    my ( $self, $statement, $varset, $tab ) = @_;

    my $compare;
    my $specifier;
    my $fmt = "";
    my $test_name = "";
    my $test = "";
    my $check = "";
    my $cvar_check = "";
    my $cvar_declaration = "";
    my $st;

    if ( $statement->{print_tree} == 1 ||
         $statement->{print_tree} == 2 ||
         $statement->{print_tree} == 4 ) {
        if ( @{$statement->{st_then}} ) {
            $test .= "$tab" . "if( @{[$self->tree_sprint($statement->{exp_cond}->{root})]} ) {\n";
            if ( $statement->{print_tree} == 1 || $statement->{print_tree}  == 4 ||
                ($statement->{print_tree} == 2 && $statement->{exp_cond}->{val} != 0) ) {
                $st = $self->generate_statements($statement->{st_then}, $varset, "$tab\t");
                $test .= $st->{test};
                $check .= $st->{check};
                $cvar_check .= $st->{cvar_check};
                $cvar_declaration .= $st->{cvar_declaration};
            }
            $test .= "$tab}\n";
        }
	    else {
            $test .= "$tab" . "if( @{[$self->tree_sprint($statement->{exp_cond}->{root})]} ) { ; }\n";
        }
        if ( @{$statement->{st_else}} ) {
            $test .= "$tab" . "else {\n";
            if ( $statement->{print_tree} == 1 || $statement->{print_tree}  == 4 ||
                ($statement->{print_tree} == 2 && $statement->{exp_cond}->{val} == 0) ) {
                $st = $self->generate_statements($statement->{st_else}, $varset, "$tab\t");
                $test .= $st->{test};
                $check .= $st->{check};
                $cvar_check .= $st->{cvar_check};
                $cvar_declaration .= $st->{cvar_declaration};
            }
            $test .= "$tab}\n";
        }
        else {;}
    }
    elsif ( $statement->{print_tree} == 0 ) {
        if ( $statement->{exp_cond}->{val} != 0 ) {
            $st = $self->generate_statements($statement->{st_then}, $varset, "$tab");
            $test .= $st->{test};
            $check .= $st->{check};
            $cvar_check .= $st->{cvar_check};
            $cvar_declaration .= $st->{cvar_declaration};
        }
        else {
            $st = $self->generate_statements($statement->{st_else}, $varset, "$tab");
            $test .= $st->{test};
            $check .= $st->{check};
            $cvar_check .= $st->{cvar_check};
            $cvar_declaration .= $st->{cvar_declaration};
        }
    }
    elsif ( $statement->{print_tree} == 3 ) {
        $test_name = "c$self->{cvar_count}";
        $test .= "$tab$test_name = @{[$self->tree_sprint($statement->{exp_cond}->{root})]};\n";

        # c変数の比較 (条件式を代入文にした時に代入される変数)
        my $val = Math::BigInt->new(0);
        my $type = $statement->{exp_cond}->{type};
        $val = $self->val_with_suffix($statement->{exp_cond}->{val},$type);
        $specifier = $self->{config}->get('type')->{$type}->{printf_format};
        $compare = "$test_name == $val";

        $fmt = "\"@{[$specifier]}\"";
        $cvar_check .= "if ($compare) { OK(); } ";
        $cvar_check .= "else { NG(" . "\"$test_name\", " . "$fmt, $test_name ); }\n";

        $cvar_declaration .= "$type ";
        $cvar_declaration .= "$test_name";
        $cvar_declaration .= " = $val";
        $cvar_declaration .= ";\n";
        $self->{cvar_count}++;

        if ( $statement->{exp_cond}->{val} != 0 ) {
            $st = $self->generate_statements($statement->{st_then}, $varset, "$tab");
            $test .= $st->{test};
            $check .= $st->{check};
            $cvar_check .= $st->{cvar_check};
            $cvar_declaration .= $st->{cvar_declaration};
        }
        else {
            $st = $self->generate_statements($statement->{st_else}, $varset, "$tab");
            $test .= $st->{test};
            $check .= $st->{check};
            $cvar_check .= $st->{cvar_check};
            $cvar_declaration .= $st->{cvar_declaration};
        }
    }
    else { ; }

    return +{
        test => $test,
        check => $check,
        cvar_check => $cvar_check,
        cvar_declaration => $cvar_declaration,
    };
}

sub generate_while_statement {
    my ($self, $statement, $varset, $tab) = @_;

    my $compare;
    my $specifier;
    my $fmt = "";
    my $test_name = "";
    my $test = "";
    my $check = "";
    my $cvar_check = "";
    my $cvar_declaration = "";
    my $st;
    my $val;
    my $type;

    if( $statement->{print_tree} == 1 ||
        $statement->{print_tree} == 2 ||
        $statement->{print_tree} == 4 ){
        if( @{$statement->{statements}} ){
            $test .= "$tab" . "while( @{[$self->tree_sprint($statement->{continuation_cond}->{root})]} ){\n";

            if( $statement->{print_tree} == 1 || $statement->{print_tree} == 4 ||
                ($statement->{print_tree} == 2 && $statement->{loop_path} == 1) ){
                $st = $self->generate_statements( $statement->{statements}, $varset, "$tab\t" );
                $test .= $st->{test};
                $check .= $st->{check};
                $cvar_check .= $st->{cvar_check};
                $cvar_declaration .= $st->{cvar_declaration};
            }
            if( defined $statement->{st_condition_for_break} ){
                $test .= "$tab\t" . "if( @{[$self->tree_sprint($statement->{st_condition_for_break}->{root})]} ){\n";
                $test .= "$tab\t\t" . "break;\n";
                $test .= "$tab\t" . "}\n";
            }
            $test .= "$tab" . "}\n";
        }
        else{
            $test .= "$tab" . "while( @{[$self->tree_sprint($statement->{continuation_cond}->{root})]} ){\n";
            if( defined $statement->{st_condition_for_break} ){
                $test .= "$tab" . "if( @{[$self->tree_sprint($statement->{st_condition_for_break}->{root})]} ){\n";
                $test .= "$tab" . "break;\n";
                $test .= "}\n";
            }
            $test .= "$tab" . "}\n";
        }
    }
    elsif( $statement->{print_tree} == 0 ){
        if( $statement->{loop_path} == 1 ){
            $st = $self->generate_statements($statement->{statements}, $varset, "$tab");
            $test .= $st->{test};
            $check .= $st->{check};
            $cvar_check .= $st->{cvar_check};
            $cvar_declaration .= $st->{cvar_declaration};
        }
        else{ ; }
    }
    elsif( $statement->{print_tree} == 3 ){
        $test_name = "c$self->{cvar_count}";
        $test .= "$tab$test_name = @{[$self->tree_sprint($statement->{continuation_cond}->{root})]};\n";

        $val = Math::BigInt->new(0);
        $type = $statement->{continuation_cond}->{type};
        $val = $self->val_with_suffix($statement->{continuation_cond}->{val},$type);
        $specifier = $self->{config}->get('type')->{$type}->{printf_format};
        $compare = "$test_name == $val";
        $fmt = "\"@{[$specifier]}\"";
        $cvar_check .= "$tab" . "if ($compare) { OK(); } ";
        $cvar_check .= "$tab" . "else { NG(" . "\"$test_name\", " . "$fmt, $test_name ); }\n";
        $cvar_declaration .= "$type $test_name = $val;\n";
        $self->{cvar_count}++;

        if( defined $statement->{st_condition_for_break} ){
            $test_name = "c$self->{cvar_count}";
            $test .= "$tab$test_name = @{[$self->tree_sprint($statement->{st_condition_for_break}->{root})]};\n";
            $val = Math::BigInt->new(0);
            $type = $statement->{continuation_cond}->{type};
            $val = $self->val_with_suffix($statement->{st_condition_for_break}->{val},$type);
            $specifier = $self->{config}->get('type')->{$type}->{printf_format};
            $compare = "$test_name == $val";
            $fmt = "\"@{[$specifier]}\"";
            $cvar_check .= "$tab" . "if ($compare) { OK(); } ";
            $cvar_check .= "$tab" . "else { NG(" . "\"$test_name\", " . "$fmt, $test_name ); }\n";
            $cvar_declaration .= "$type $test_name = $val;\n";
            $self->{cvar_count}++;
        }

        if( $statement->{loop_path} == 1 ){
            $st = $self->generate_statements($statement->{statements}, $varset, "$tab");
            $test .= $st->{test};
            $check .= $st->{check};
            $cvar_check .= $st->{cvar_check};
            $cvar_declaration .= $st->{cvar_declaration};
        }
    }
    else { ; }

    return +{
        test  => $test,
        check => $check,
        cvar_check => $cvar_check,
        cvar_declaration => $cvar_declaration,
    };
}


sub generate_assign_statement {
    my ($self, $statement, $varset, $tab) = @_;

    my $type = $statement->{root}->{out}->{type};

    my $COMPARE;
    my $specifier;
    my $test_name = "";
    my $test = "";
    my $check = "";
    my $fmt = "";

    my $check_t_name = $statement->{var}->{name_type} . $statement->{name_num};
    if ( $statement->{print_statement} && $statement->{st_type} eq 'assign' ) {
        my $type = $statement->{root}->{out}->{type};
        my $val = Math::BigInt->new(0);
        $val = $self->val_with_suffix( $statement->{val}, $statement->{type} );
        # $self->mark_used_vars( $statement->{root}, $varset );

        #左辺が配列、構造体・共用体のとき
        if (defined $statement->{var}->{elements} ) {
          for my $num (@{$statement->{var}->{elements}} ) {
            unless ($num =~ /^[0-9]{1,}$/) { #構造体共用体ののメンバ
              $check_t_name .= '.' . $num;
            }
            else {
              $check_t_name .= "[$num]"; #添字[][]
            }
          }
          ($test_name, $check_t_name) = $self->generate_sub_root_expression($statement, $test_name, $check_t_name);
        }
        else{
          #普通のt変数
          $test_name = $statement->{var}->{name_type};
          $test_name .= $statement->{name_num};
        }
        $test .= "$tab$test_name = @{[$self->tree_sprint($statement->{root})]};\n";
        if ( $statement->{print_statement} && $statement->{path} == 1) {
            $specifier = $self->{config}->get('type')->{$type}->{printf_format};
            $COMPARE   = "$check_t_name == $val";
            $fmt       = "\"@{[$specifier]}\"";
            $check .= "\t";
            $check .= "if ($COMPARE) { OK(); } ";
            $check .= "else { NG(" . "\"$check_t_name\", " . "$fmt,  $check_t_name";

            $check .= "); }\n";
        }
        $self->{tvar_count}++;
    }

    return +{
        test => $test,
        check => $check,
    };
}

#左辺添字
sub generate_sub_root_expression {
  my ($self, $statement, $test_name, $check_t_name) = @_;

  if ((defined $statement->{var}->{replace_flag} && $statement->{var}->{replace_flag} == 1) 
    ) {
    #最小化で配列,構造体共用体を普通の変数の置換したときの処理 例 t1[2][4] -> t1_2_4
    my $ele = join("_", @{$statement->{var}->{elements}});
    $test_name = $statement->{var}->{name_type} . $statement->{name_num} . "_" . $ele;
    $check_t_name = $test_name;
  }
  elsif ($statement->{sub_root}->{ntype} eq 'op' && $statement->{sub_root}->{otype} ne 'a') {
    $test_name = $statement->{var}->{name_type} . $statement->{name_num};
    #左辺配列の添字の式(頭にキャスト付き)
    my $i = 0;
    for my $num (@{$statement->{var}->{elements}} ) {
      unless ($num =~ /^[0-9]{1,}$/) { #構造体共用体ののメンバ
        $test_name .= '.' . $num;
      }
      else {
          if ($statement->{sub_root}->{in}->[0]->{ref}->{in}->[$i]->{print_value} == 0) {
            $test_name .= "[" . "@{[$self->tree_sprint($statement->{sub_root}->{in}->[0]->{ref}->{in}->[$i]->{ref})]}" . "]";  #$self->tree_sprint($statement->{sub_root}->{in}->[0]->{ref}->{in}->[$i]->{ref}) ."]"; #添字[][]
          }
          else {
            $test_name .= "[" . "$statement->{sub_root}->{in}->[0]->{ref}->{in}->[$i]->{val}" . "]";
          }
          $i++;
      }
    }
  }
  else {
    $test_name = $statement->{var}->{name_type} . $statement->{name_num};
    #左辺配列の添字の式(頭にキャスト無し)
    my $i = 0;
    for my $num (@{$statement->{var}->{elements}} ) {
      unless ($num =~ /^[0-9]{1,}$/) { #構造体共用体ののメンバ
        $test_name .= '.' . $num;
      }
      else {
          if ($statement->{sub_root}->{in}->[$i]->{print_value} == 0) {

            $test_name .= "[" . "@{[$self->tree_sprint($statement->{sub_root}->{in}->[$i]->{ref})]}" . "]";# $self->tree_sprint($statement->{sub_root}->{in}->[$i]->{ref}) ."]"; #添字[][]
          } 
          else {
              $test_name .= "[" ."$statement->{sub_root}->{in}->[$i]->{val}" . "]";
          }
        $i++;
      }
    }
  }
  return $test_name, $check_t_name;
}

sub reset_varset_used {
    my ( $self, $varset, $unionstructs, $statements, $func_vars, $func_list ) = @_;

    #varsetis Hashed (Speeding up)
    for my $var (@$varset) {
        $var->{used} = 0;
    }
    for my $us (@$unionstructs) {
      $us->{used} = 0;
      for my $mem (@{$us->{member}}) {
        $mem->{used} = 0;
      }
    }
    for my $func_var ( @$func_vars ){
        for my $var ( @{$func_var->{vars}} ){
            $var->{used} = 0;
        }
    }

    my $varset_hash = $self->hash_varset($varset, $func_vars);
    my $unionstructs_hash = $self->hash_unionstructs($unionstructs);

    $self->_hash_from_statement( $statements, $varset_hash, $unionstructs_hash );

    $self->_check_used_from_hash( $statements, $varset_hash);

    for my $i ( 0 .. $#{$func_list} ){
      if ($func_list->[$i]->{print_tree} == 1) {

      # 引数が構造体の場合
          for my $arg (@{$func_list->[$i]->{args_list}}) {
              if (ref $arg->{type} eq 'HASH') {
                my $key = $arg->{type}->{name_type} . $arg->{type}->{name_num};
                $$unionstructs_hash{$key}->{used} = 1;
                $self->reset_unionstruct_used($arg->{type}, undef, $unionstructs_hash);
              }
          }

        $self->_hash_from_statement( $func_list->[$i]->{statements}, $varset_hash, $unionstructs_hash );
        $self->_check_used_from_hash( $func_list->[$i]->{statements}, $varset_hash );
        if( defined $func_list->[$i]->{return_val_expression} ){
            $self->reset_varset_used2( $func_list->[$i]->{return_val_expression}->{root}, $varset_hash, $unionstructs_hash );
        }
      }
    }
    $self->{varset_hash} = $varset_hash; # 最小化で使う
}

sub _func_ret_exp {
    my ($self, $func_list, $varset_hash, $unionstructs_hash) = @_;

    for my $i ( 0 .. $#{$func_list} ){
        if( defined $func_list->[$i]->{return_val_expression} ){
            $self->reset_varset_used2( $func_list->[$i]->{return_val_expression}->{root}, $varset_hash, $unionstructs_hash );
        }
    }
}

sub _hash_from_statement {
    my ( $self, $statements, $varset_hash, $unionstructs_hash ) = @_;

    for my $st ( @$statements ) {
        if ( $st->{st_type} eq 'for' ) {
            if ($st->{print_tree} != 0) {
                $self->reset_varset_used2( $st->{st_init}->{root}, $varset_hash, $unionstructs_hash );
                $self->reset_varset_used2( $st->{continuation_cond}->{root}, $varset_hash, $unionstructs_hash );
                $self->reset_varset_used2( $st->{st_reinit}->{root}, $varset_hash, $unionstructs_hash );
            }
            $self->_hash_from_statement( $st->{statements}, $varset_hash, $unionstructs_hash);
        }
        elsif ( $st->{st_type} eq 'if' ) {
            if ($st->{print_tree} != 0) {
	            $self->reset_varset_used2($st->{exp_cond}->{root}, $varset_hash, $unionstructs_hash);
            }
            if ( ($st->{print_tree} == 1)
              || ($st->{print_tree} == 2 && $st->{exp_cond}->{val} != 0)
              || ($st->{print_tree} == 3 && $st->{exp_cond}->{val} != 0)
              || ($st->{print_tree} == 4)
              || ($st->{print_tree} == 0 && $st->{exp_cond}->{val} != 0)) {
	            $self->_hash_from_statement( $st->{st_then}, $varset_hash, $unionstructs_hash );
            }
            if ( ($st->{print_tree} == 1)
              || ($st->{print_tree} == 2 && $st->{exp_cond}->{val} == 0)
              || ($st->{print_tree} == 3 && $st->{exp_cond}->{val} == 0)
              || ($st->{print_tree} == 4)
              || ($st->{print_tree} == 0 && $st->{exp_cond}->{val} == 0)) {
	            $self->_hash_from_statement( $st->{st_else}, $varset_hash, $unionstructs_hash );
            }
        }
        elsif ( $st->{st_type} eq 'function_call' ) {
            if ($st->{print_tree} == 1) {

            for my $arg_expression( @{$st->{args_expressions}} ){
                if( defined $arg_expression->{root} ){
                    $self->reset_varset_used2( $arg_expression->{root}, $varset_hash, $unionstructs_hash );
                }
                elsif (defined $arg_expression->{type} && ref $arg_expression->{type} eq "HASH") {
                  my $key = $arg_expression->{type}->{name_type} . $arg_expression->{type}->{name_num};
                  $$unionstructs_hash{$key}->{used} = 1;
                  $key = $arg_expression->{name_type} . $arg_expression->{name_num};
                  $$varset_hash{$key}->{used} = 1;
                }
                else{
                    my $key = $arg_expression->{name_type} . $arg_expression->{name_num};
                    $$varset_hash{$key}->{used} = 1;
                }
            }
            if( $st->{fixed_args_flag} == 0 ){
                $self->reset_varset_used2( $st->{args_num_expression}->{root}, $varset_hash, $unionstructs_hash );
            }
            }
        }
        elsif( $st->{st_type} eq 'while' ) {
            if( $st->{print_tree} != 0 ){
                $self->reset_varset_used2( $st->{continuation_cond}->{root}, $varset_hash, $unionstructs_hash );
                if( defined $st->{st_condition_for_break} ){
                    $self->reset_varset_used2( $st->{st_condition_for_break}->{root}, $varset_hash, $unionstructs_hash );
                }
            }

            if( $st->{print_tree} == 0 ||
                $st->{print_tree} == 1 ||
                $st->{print_tree} == 2 ||
                $st->{print_tree} == 4 ){
                $self->_hash_from_statement( $st->{statements}, $varset_hash, $unionstructs_hash );
            }
            elsif( $st->{print_tree} == 3 ){ ; }
            else{ Carp::croak("Invalid while print_tree"); }
        }
        elsif( $st->{st_type} eq 'switch' ){
            if( $st->{print_tree} != 0 ){
                $self->reset_varset_used2( $st->{continuation_cond}->{root}, $varset_hash, $unionstructs_hash );
            }
            for my $case ( @{$st->{cases}} ){
                if( $st->{print_tree} == 5 && $case->{print_case} == 1 ){
                    $self->_hash_from_statement( $case->{statements}, $varset_hash, $unionstructs_hash );
                }
                # elsif( $st->{print_tree} == 3 || $st->{print_tree} == 2 ){ ; }
                elsif( ($st->{print_tree} == 4 && $case->{path} == 1) ||
                       ($st->{print_tree} == 0 && $case->{path} == 1) ){
                    $self->_hash_from_statement( $case->{statements}, $varset_hash, $unionstructs_hash );
                }
                elsif( $st->{print_tree} == 1 ||
                       $st->{print_tree} == 6 ){
                    $self->_hash_from_statement( $case->{statements}, $varset_hash, $unionstructs_hash );
                }
            }
        }
        elsif ( $st->{print_statement} && $st->{st_type} eq 'assign' ) {
            $self->reset_varset_used2( $st->{root}, $varset_hash, $unionstructs_hash );

            if ($self->check_array($st->{var})) {
                if (defined $st->{sub_root}) {
                    push @{$self->{used_array}}, $st->{var};
                    if ($st->{var}->{replace_flag} != 1) {
                        $self->reset_varset_used2( $st->{sub_root}, $varset_hash, $unionstructs_hash);
                    }
                }
            }
            elsif ((defined $st->{var}->{unionstruct})) {
                if (defined $st->{sub_root}) {
                    push @{$self->{used_unionstruct}}, $st->{var};
                }
                if ( $st->{var}->{replace_flag} != 1) {
                    $self->reset_varset_used2( $st->{sub_root}, $varset_hash, $unionstructs_hash);
                    $self->reset_unionstruct_used($st->{var}, $st->{var}->{elements},  $unionstructs_hash);
                }
            }
        }
        elsif ( $st->{print_statement} && $st->{st_type} eq 'array' ) {
          #可変長配列
          $self->reset_varset_used2( $st->{sub_root}, $varset_hash, $unionstructs_hash);

          my $key = $st->{array}->{name_type} . $st->{array}->{name_num};
          $$varset_hash{$key} = $st->{array};
          $st->{array}->{used} = 0;

        }
        else {;}
    }
}

sub _check_used_from_hash {
    my ( $self, $statements, $varset_hash ) = @_;
    for my $st ( @$statements ) {
        if ( $st->{print_statement} && $st->{st_type} eq 'assign' ) {
          if ($st->{var}->{replace_flag} != 1) {
             my $key = 't' . $st->{name_num};
             $$varset_hash{$key}->{used} = 1;
            }
        }
        elsif ( $st->{st_type} eq 'for' ) {
            $self->_check_used_from_hash( $st->{statements}, $varset_hash );
        }
        elsif ( $st->{st_type} eq 'if' ) {

          if ( ($st->{print_tree} == 1)
              || ($st->{print_tree} == 2 && $st->{exp_cond}->{val} != 0)
              || ($st->{print_tree} == 3 && $st->{exp_cond}->{val} != 0)
              || ($st->{print_tree} == 4)
              || ($st->{print_tree} == 0 && $st->{exp_cond}->{val} != 0)) {
	            $self->_check_used_from_hash( $st->{st_then}, $varset_hash);
            }
            if ( ($st->{print_tree} == 1)
              || ($st->{print_tree} == 2 && $st->{exp_cond}->{val} == 0)
              || ($st->{print_tree} == 3 && $st->{exp_cond}->{val} == 0)
              || ($st->{print_tree} == 4)
              || ($st->{print_tree} == 0 && $st->{exp_cond}->{val} == 0)) {
	            $self->_check_used_from_hash( $st->{st_else}, $varset_hash);
            }
        }
        elsif ( $st->{st_type} eq 'while' ) {
            if( ($st->{print_tree} == 0 && $st->{loop_path} == 1) ||
                ($st->{print_tree} == 1) ||
                ($st->{print_tree} == 2 && $st->{loop_path} == 1) ||
                ($st->{print_tree} == 4) ){
                $self->_check_used_from_hash( $st->{statements}, $varset_hash );
            }
        }
        elsif( $st->{st_type} eq 'switch' ){
            for my $case ( @{$st->{cases}} ){
                if( ($st->{print_tree} == 0 && $case->{path} == 1) ||
                    ($st->{print_tree} == 1) ||
                    ($st->{print_tree} == 4 && $case->{path} == 1) ||
                    ($st->{print_tree} == 5 && $case->{print_case} == 1) ||
                    ($st->{print_tree} == 6) ){
                    $self->_check_used_from_hash( $case->{statements}, $varset_hash );
                }
            }
        }
        else { ; }
    }
}

sub hash_varset {
    my ( $self, $varset, $func_vars ) = @_;

    my %varset_hash = ();
    for my $var (@$varset) {
        my $key = $var->{name_type} . $var->{name_num};
        $varset_hash{$key} = $var;
    }

    for my $i ( 0 .. $#{ $func_vars } ){
        for my $j ( 0 .. $#{$func_vars->[$i]->{vars}} ){
            my $key = $func_vars->[$i]->{vars}->[$j]->{name_type} . $func_vars->[$i]->{vars}->[$j]->{name_num};
            if( defined $varset_hash{$key} ){
                $func_vars->[$i]->{vars}->[$j] = $varset_hash{$key};
            }
            else{
                $varset_hash{$key} = $func_vars->[$i]->{vars}->[$j];
            }
        }
    }

    return \%varset_hash;
}

sub hash_unionstructs {
  my ( $self, $unionstructs) = @_;

  my %unionstructs_hash = ();
  for my $us (@$unionstructs) {
    my $key = $us->{name_type} . $us->{name_num};
    $unionstructs_hash{$key} = $us;
  }

  return \%unionstructs_hash;
}

sub reset_varset_used2 {
    my ( $self, $n, $varset_hash, $unionstructs_hash ) = @_;

    unless ( defined( $n->{ntype} ) ) {
        Carp::croak("ntype is undefined");
    }
    if ( $n->{ntype} eq 'op' ) {
        for my $r ( @{ $n->{in} } ) {
            if (ref $r->{ref}->{val} eq 'ARRAY') { 
                if (defined $r->{ref}->{type} && ref $r->{ref}->{type} eq 'HASH') {
                     my $key = $r->{ref}->{type}->{name_type} . $r->{ref}->{type}->{name_num};
                    $$unionstructs_hash{$key}->{used} = 1;
                }
                my  $key = $r->{ref}->{name_type} . $r->{ref}->{name_num};
                  $$varset_hash{$key}->{used} = 1;
            } elsif ( $r->{print_value} == 0 ) {
                if ( $r->{ref}->{ntype} eq 'var' ) {
                    my $key = "$r->{ref}->{var}->{name_type}" . "$r->{ref}->{var}->{name_num}";

                    if (defined $r->{ref}->{var}->{unionstruct}) {

                      #式中で構造体共用体が使われているかをセット(最小化で構造体を普通の変数に置き換えるときに使う)
                      my $ukey = $key . "_" . (join("_", @{$r->{ref}->{var}->{elements}}));
                      push @{$self->{used_unionstruct}}, $r->{ref}->{var} ;
                      #構造体型枠のusedをセット(最小化で普通の変数に置き換わっているときはしない)
                      if (!(defined $r->{ref}->{var}->{replace_flag}) ||  $r->{ref}->{var}->{replace_flag} != 1) {
                        $self->reset_unionstruct_used($r->{ref}->{var}, $r->{ref}->{var}->{elements},  $unionstructs_hash);
                      }
                    }
                    if ($self->check_array($r->{ref}->{var})) {
                      my $ukey = $key . "_" . (join("_", @{$r->{ref}->{var}->{elements}}));
                      push @{$self->{used_array}}, $r->{ref}->{var};
                    }
                    unless ((defined $r->{ref}->{var}->{replace_flag} && $r->{ref}->{var}->{replace_flag} == 1) || (defined $r->{ref}->{var}->{replace_flag} && $r->{ref}->{var}->{replace_flag} == 1) ) {
                      $$varset_hash{$key}->{used} = 1;
                    }
                }
                elsif ($r->{ref}->{otype} eq 'a') {
                    my $key = "$r->{ref}->{var}->{name_type}" . "$r->{ref}->{var}->{name_num}";
                    #a演算子の場合は'op'でもused=1に
                    my $ukey = $key . "_" . (join("_", @{$r->{ref}->{var}->{elements}}));
                    push @{$self->{used_array}}, $r->{ref}->{var};


                    unless (defined $r->{ref}->{var}->{replace_flag} && $r->{ref}->{var}->{replace_flag} == 1) {
                      $$varset_hash{$key}->{used} = 1;
                      $self->reset_varset_used2( $r->{ref}, $varset_hash, $unionstructs_hash);
                    } #配列が代理変数に置き換わっているところはそれ以降深く探索しない
                }
                else {
                  $self->reset_varset_used2( $r->{ref}, $varset_hash, $unionstructs_hash);
                }
            }
        }
    }
}

sub check_array {
  my ($self, $var) = @_;

  if (!(defined $var->{elements})) { return 0; }
  for my $i (@{$var->{elements}}) {
    unless ($i =~ /^[0-9]{1,}$/) {
      return 0;
    }
  }
  return 1;
}

#構造体共用体のusedをセット
sub reset_unionstruct_used {
  my ( $self, $unionstruct, $elements, $unionstructs_hash) = @_;

  my $key = "";
  my $m = 10000000; #とりあえず大きい数字

  #念の為
  if ( defined $unionstruct->{unionstruct} ) {
    $key = $unionstruct->{unionstruct};
  }
  else {
    $key = $unionstruct->{name_type} . $unionstruct->{name_num};
  }

  #引数の構造体共用体のusedを1に
  $$unionstructs_hash{$key}->{used} = 1;
  if (defined $elements) {
      #要素のusedを1に
      my $length = length($elements->[0]) - 1;
      $m = substr($elements->[0], 1, $length);

      $$unionstructs_hash{$key}->{member}->[$m]->{used} = 1;

  }
  #メンバ変数の構造体のusedをセットする
  for my $i (0..((scalar @{$$unionstructs_hash{$key}->{member}}) - 1) ) {
    if ( $i == $m ) {
      if ( ref $$unionstructs_hash{$key}->{member}->[$m]->{type} eq "HASH" ) {
        my $elements_clone = clone($elements);
        shift @$elements_clone;
        my $shift = 0;
        do {
          $shift = 0;
          if ($elements_clone->[0] =~ /^[0-9]{1,}$/) {
            shift @$elements_clone;
            $shift = 1;
          }
        } while ($shift == 1);
        $self->reset_unionstruct_used($$unionstructs_hash{$key}->{member}->[$m]->{type}, $elements_clone, $unionstructs_hash);
      }
    }
    elsif ( ref $$unionstructs_hash{$key}->{member}->[$i]->{type} eq "HASH" ) {
      $self->reset_unionstruct_used($$unionstructs_hash{$key}->{member}->[$i]->{type}, undef, $unionstructs_hash);
    }
  }
}

sub mark_used_vars {
    my ( $self, $ref, $var_set ) = @_;

    if ( $ref->{ntype} eq "var" ) { ; }
    else {
        for my $k ( @{ $ref->{in} } ) {
            if ( $k->{ref}->{ntype} eq "op" ) {
                if ( $k->{print_value} == 2 ) { ; }
                elsif ( $k->{print_value} == 1 ) {
                    $k->{ref}->{var}->{used} = 1;
                }
                else {
                    my $all_two = 1;
                    for my $i ( @{ $ref->{in} } ) {
                        # When all of the child print_value is "2"
                        if ( $i->{print_value} != 2 ) {
                            $all_two = 0;
                        }
                        if ( $all_two == 1 ) {
                            $k->{ref}->{var}->{used} = 1;
                        }
                    }

                    # when print_value is "0"
                    $self->mark_used_vars( $k->{ref}, $var_set );
                }
            }
            elsif ( $k->{ref}->{ntype} eq "var" ) {
                if ( $k->{print_value} != 2 ) {
                    $k->{ref}->{var}->{used} = 1;
                }
            }
            else { ; }
        }
    }
}

# display tree
# Tree.pm or Dumper.pm
sub tree_sprint {
    my ( $self, $n ) = @_;

    my $k;
    my $s = "";


    if ( $n->{ntype} eq 'var' ) {
      $s .= "$n->{var}->{name_type}" . "$n->{var}->{name_num}";

      if (defined $n->{var}->{elements} ) {
        # 最小化で普通の変数に置き換わっている場合(t1[3][3] -> t1_3_3, x34.m2[3] -> x34_m_2_3)
        if ((defined $n->{var}->{replace_flag} && $n->{var}->{replace_flag} == 1) ||
        (defined $n->{var}->{replace_flag} && $n->{var}->{replace_flag} == 1)) {
          my $ele = join("_", @{$n->{var}->{elements}});
          $s .= "_" . $ele;
        }
        else {
          for my $num (@ {$n->{var}->{elements}} ) {
            unless ($num =~ /^[0-9]{1,}$/) { #構造体共用体ののメンバ
              $s .= '.' . $num;
            }
            else { #配列の添字
              $s  .= "[$num]";
            }
          }
        }
      }
    }
    elsif ( $n->{ntype} eq 'op' ) {
        my $print_value;

        if ($n->{otype} eq 'a') {
          $s .= "$n->{var}->{name_type}" . "$n->{var}->{name_num}";

          if (defined $n->{var}->{replace_flag} && $n->{var}->{replace_flag} == 1) {
            my $ele = join("_", @{$n->{var}->{elements}});
            $s .= "_" . $ele;
          }
          else {
            for my $in ( @{ $n->{in} } ) {
              $s .= "[";
              $print_value = $in->{print_value};
              if ( $print_value == 0 ) {
                  my $h = $in->{ref};
                  $s .= $self->tree_sprint($h);
              }
              elsif ( $print_value == 1 ) {
                  my $o;
                  if ( $in->{ref}->{ntype} eq 'op' ) {
                      $o = $in->{ref}->{out};
                  }
                  elsif ( $in->{ref}->{ntype} eq 'var' ) {
                      # $o = $n->{in}->[0]->{ref}->{var};
                      $o = $in->{ref}->{out}; # 20141031
                  }
                  else {
                      Carp::croak("Invalid ntype: $n->{in}->[0]->{ntype}");
                  }
                  $s .= "($o->{type})" . $self->val_with_suffix( $o->{val}, $o->{type} );
              }
              elsif ( $print_value == 2 ) {
                  $s .=
                      "($in->{type})"
                      . $self->val_with_suffix( $in->{val},
                      $in->{type} );
              }
              $s .= "]";
            }
          }
        }
        elsif ($n->{otype} =~ /^\(.+\)$/ ) {
            $s.= "(";
            $s.= "$n->{otype}";
            for my $l ( @{ $n->{in} } ) {
                $print_value = $l->{print_value};
                if ( $print_value == 0 ) {
                    my $h = $l->{ref};
                    $s .= $self->tree_sprint($h);
                }
                elsif ( $print_value == 1 ) {
                    my $o = $l->{ref}->{out};
                    $s .= "($o->{type}) " . $self->val_with_suffix( $o->{val}, $o->{type} );
                }
                elsif ( $print_value == 2 ) {
                    $s .= "($l->{type})" . $self->val_with_suffix( $l->{val}, $l->{type} );
                }
                else {
                    Carp::croak("Invalid print_value: $print_value");
                }
            }
            $s .= ")";
        }
        elsif( $n->{otype} =~ /func/ ){
            my $count;
            $s .= "$n->{otype}" . "(";
            for my $operand( @{$n->{in}} ){
                if (ref $operand->{ref}->{val} eq 'ARRAY') {
                    $s .= "$operand->{ref}->{name_type}" . "$operand->{ref}->{name_num}";
                } else {

                $print_value = $operand->{print_value};
                if( $print_value == 0 ){
                    my $h = $operand->{ref};
                    $s .= $self->tree_sprint($h);
                }
                elsif( $print_value == 1){
                    my $o;
                    if ( $operand->{ref}->{ntype} eq 'op' ) {
                        $o = $operand->{ref}->{out};
                    }
                    elsif ( $operand->{ref}->{ntype} eq 'var' ) {
                        # $o = $operand->{ref}->{var};
                        $o = $operand->{ref}->{out};
                    }
                    else {
                        Carp::croak("Invalid ntype: $operand->{ntype}");
                    }
                    $s .= "($o->{type})" . $self->val_with_suffix( $o->{val}, $o->{type} );
                }
                elsif( $print_value == 2){
                    # my $o = $operand->{ref}->{out};

                    # $s .=
                    #   "($o->{type})"
                    # . $self->val_with_suffix( $o->{val},
                    # $o->{type} );

                    $s .=
                      "($operand->{type})"
                    . $self->val_with_suffix( $operand->{val},
                    $operand->{type} );
                }
                else{
                    Carp::croak("Invalid print_value: $print_value");
                }
                }
                $s .= ", ";
            }
            $s =~ s/,\s+$//;
            $s .= ")";
        }
        else {
            $s .= "(";

            $print_value = $n->{in}->[0]->{print_value};
            if ( $print_value == 0 ) {
                my $h = $n->{in}->[0]->{ref};
                $s .= $self->tree_sprint($h);
            }
            elsif ( $print_value == 1 ) {
                my $o;
                if ( $n->{in}->[0]->{ref}->{ntype} eq 'op' ) {
                    $o = $n->{in}->[0]->{ref}->{out};
                }
                elsif ( $n->{in}->[0]->{ref}->{ntype} eq 'var' ) {
                    # $o = $n->{in}->[0]->{ref}->{var};
                    $o = $n->{in}->[0]->{ref}->{out}; # 20141031
                }
                else {
                    Carp::croak("Invalid ntype: $n->{in}->[0]->{ntype}");
                }
                $s .= "($o->{type})" . $self->val_with_suffix( $o->{val}, $o->{type} );
            }
            elsif ( $print_value == 2 ) {
                $s .=
                    "($n->{in}->[0]->{type})"
                    . $self->val_with_suffix( $n->{in}->[0]->{val},
                    $n->{in}->[0]->{type} );
            }
            else {
                Carp::croak("Invalid print_value: $print_value");
            }

            $s .= "$n->{otype}";

            $print_value = $n->{in}->[1]->{print_value};

            if ( $print_value == 0 ) {
                my $h = $n->{in}->[1]->{ref};
                $s .= $self->tree_sprint($h);
            }
            elsif ( $print_value == 1 ) {
                my $o;
                if ( $n->{in}->[1]->{ref}->{ntype} eq 'op' ) {
                    $o = $n->{in}->[1]->{ref}->{out};
                }
                elsif ( $n->{in}->[1]->{ref}->{ntype} eq 'var' ) {
                    $o = $n->{in}->[1]->{ref}->{var};
                }
                else {
                    Carp::croak("Invalid ntype: $n->{in}->[1]->{ntype}");
                }
                $s .= "($o->{type})" . $self->val_with_suffix( $o->{val}, $o->{type} );
            }
            elsif ( $print_value == 2 ) {
                $s .=
                    "($n->{in}->[1]->{type})"
                    . $self->val_with_suffix( $n->{in}->[1]->{val},
                    $n->{in}->[1]->{type} );
            }
            else {
                Carp::croak("Invalid print_value: $print_value");
            }

            $s .= ")";
        }
    }
    else {
        Carp::croak("Invalid type: $n->{ntype}");
    }

    return $s;
}

sub val_with_suffix {
    my ( $self, $val, $type ) = @_;

    my $config = $self->{config};
    if ( $type eq 'float' || $type eq 'double' || $type eq 'long double' ) {
        if ( $val !~ /\./ && $val !~ /e/ ) {
            $val .= '.0';
        }
    }
    return $val . $config->get('type')->{$type}->{const_suffix};
}

sub make_c_var_declaration {
    my ( $self, $DR_mode, $varset, $indent ) = @_;

    my $declaration = "";

    for my $k (@$varset) {
      # if ($k->{name_type} eq 'a'  ) {;}
        if (ref($k->{type}) eq 'HASH')  { #構造体共用体
        my $key = 't' . $k->{name_num};
          if ( $k->{used} == 1 ) {
          my $def = "";
          if ($k->{type}->{name_type} eq 's') {
            $def = "struct ";
          }
          else {
            $def = "union ";
          }
          $declaration .= $indent;
          $declaration .= "$k->{class} " if ($k->{class} ne '');
          $declaration .= "$k->{modifier} " if ($k->{modifier} ne '');
          $declaration .= $def . "$k->{type}->{name_type}" . "$k->{type}->{name_num} " . "$k->{name_type}" . "$k->{name_num}";
          my $value = "";
          if (defined $k->{elements}) {
            for my $num (@{ $k->{elements} } ) {
              $declaration .= "[$num]";
            }
          }
          $value = $self->check_elements($k, $k->{ival});
          $declaration .= " = ". $value . ";\n";
        }
        }
        elsif (defined $k->{elements} ) { #配列
          if ( $k->{used} == 1 ) {

              $declaration .= $indent;
              $declaration .= "$k->{class} "
              if ( $DR_mode == 1 && $k->{class} ne '' );
              $declaration .= "extern "         if ( $DR_mode == 2 );
              $declaration .= "$k->{modifier} " if ( $k->{modifier} ne '' );
              $declaration .= "$k->{type} ";

              $declaration .= "$k->{name_type}" . "$k->{name_num}" . "";
              for my $num (@{ $k->{elements} } ) {
                $declaration .= "[$num]";
              }

              $declaration .= " = " unless ( $DR_mode == 2 );

              $declaration .= " { ";
              $declaration .= $self->print_array($k->{ival}, 0, $k);
              $declaration .= " } ";
              $declaration .= ";\n";
            }
        }
        elsif ( $k->{name_type} eq "t" ) {
          my $val = $self->val_with_suffix( $k->{ival}, $k->{type} );
            if ( $k->{used} == 1 ) {
                $declaration .= $indent;
                $declaration .= "$k->{class} "
                if ( $DR_mode == 1 && $k->{class} ne '' );
                $declaration .= "extern "         if ( $DR_mode == 2 );
                $declaration .= "$k->{modifier} " if ( $k->{modifier} ne '' );
                $declaration .= "$k->{type} ";
                $declaration .= "$k->{name_type}" . "$k->{name_num}";
                $declaration .= " = $val" unless ( $DR_mode == 2 );
                $declaration .= ";\n";
           }
        }
        elsif ($k->{name_type} eq 'replace' ) {

          my $val = $self->val_with_suffix( $k->{ival}, $k->{type} );
            $declaration .= $indent;
            if ($k->{print_flg} == 1) {
              $declaration .= "$k->{class} " if ( $DR_mode == 1 && $k->{class} ne '' );
              $declaration .= "$k->{modifier} " if ( $k->{modifier} ne '' );
            }
            elsif ($k->{print_flg} == 2) {
              $declaration .= "$k->{class} " if ( $DR_mode == 1 && $k->{class} ne '' );
            }
            elsif ($k->{print_flg} == 3) {
              $declaration .= "$k->{modifier} " if ( $k->{modifier} ne '' );

            }
            else {
              ;
            }
            $declaration .= "extern "         if ( $DR_mode == 2 );
            $declaration .= "$k->{type} ";
            $declaration .= "$k->{replace_name}";
            $declaration .= " = $val" unless ( $DR_mode == 2 );
            $declaration .= ";\n";
        }
        else {
          if ( $k->{used} == 1 ) {
            my $val = $self->val_with_suffix( $k->{ival}, $k->{type} );
              $declaration .= $indent;
              $declaration .= "$k->{class} "
              if ( $DR_mode == 1 && $k->{class} ne '' );
              $declaration .= "extern "         if ( $DR_mode == 2 );
              $declaration .= "$k->{modifier} " if ( $k->{modifier} ne '' );
              $declaration .= "$k->{type} ";
              $declaration .= "$k->{name_type}" . "$k->{name_num}";
              $declaration .= " = $val" unless ( $DR_mode == 2 );
              $declaration .= ";\n";
          }
        }
    }

    return $declaration;
}

sub check_elements {
  my ($self, $k, $ival) = @_;

    my $print_val = "";
    if (defined $k->{elements}) {
      $print_val .= $self->print_struct_array($k->{type}, $ival, $k->{elements}, 0);
      if (substr($print_val, -2, 2) eq ",}") {
        substr($print_val, -2, 1,"");
      }
      if ( substr($print_val, -3, 3) eq ", }") {
        substr($print_val, -3, 2,"");
      }
    }
    else {
      $print_val .= $self->print_struct_member_value($k->{type}, $ival);
      if (substr($print_val, -2, 2) eq ",}") {
        substr($print_val, -2, 1,"");
      }
      if ( substr($print_val, -3, 3) eq ", }") {
        substr($print_val, -3, 2,"");
      }
    }

  return $print_val;
}

sub print_struct_array {
  my ($self, $type, $ival, $elements, $ele_num) = @_;

  my $print_val = "";
  if ($elements->[$ele_num + 1]) {
    $print_val .= "{";
    for my $i (1..$elements->[$ele_num]) {
      $print_val .= $self->print_struct_array($type, $ival->[$i - 1], $elements, $ele_num + 1);
      $print_val .= ", ";

    }
    if (substr($print_val, -2, 2) eq ",}") {
      substr($print_val, -2, 1,"");
    }
    if ( substr($print_val, -3, 3) eq ", }") {
      substr($print_val, -3, 2,"");
    }
    substr($print_val, -1, 1,"");
    $print_val .= "}";

  }
  else {
    $print_val .= "{";

    for my $i (1..$elements->[$ele_num]) {
      $print_val .= $self->print_struct_member_value($type, $ival->[$i - 1]);
      $print_val .= ", ";
    }
    substr($print_val, -2, 2,"");
    $print_val .= "}";

    if (substr($print_val, -2, 2) eq ",}") {

      substr($print_val, -2, 1,"");
    }
    if ( substr($print_val, -3, 3) eq ", }") {
      substr($print_val, -3, 2,"");
    }
  }
  return $print_val;
}

sub print_struct_member_value {
  my ($self, $type, $ival) = @_;

  my $print_val = "";

  $print_val .= "{";

  for my $i (0..(scalar(@$ival)-1)) {
    if ($type->{member}->[$i]->{print_member} == 1) {
    if (ref($type->{member}->[$i]->{type}) eq 'HASH') {
      $print_val .= $self->check_elements($type->{member}->[$i], $ival->[$i]);
      $print_val .= ", ";
      if (substr($print_val, -2, 2) eq ",}") {
        substr($print_val, -2, 1,"");
      }
      if ( substr($print_val, -3, 3) eq ", }") {
        substr($print_val, -3, 2,"");
      }
    }
    elsif (defined $type->{member}->[$i]->{elements}) {
      $print_val .= "{";
      $print_val .= $self->print_array($ival->[$i], 0, $type->{member}->[$i]);
      $print_val .= "},";
    }
    else {
      $print_val .= "$ival->[$i],";
    }
  }else {
    }
  }

  $print_val .= "}";
  if (substr($print_val, -2, 2) eq ",}") {
  }
  if ( substr($print_val, -3, 3) eq ", }") {
    substr($print_val, -3, 2,"");
  }
  return $print_val;
}

sub print_array
{
	my ($self, $elements, $ele_num, $array) = @_;

	my $print_val = "";

	if( defined($array->{elements}->[$ele_num+1]) )
	{
		for( my $i = 0; $i < $array->{elements}->[$ele_num]; $i++ )
		{
			$print_val .= "{";
			$print_val .= $self->print_array($elements->[$i], $ele_num+1, $array);
			$print_val .= "}, ";
		}
		substr($print_val, -2, 2,"");
	}
	else
	{
		for( my $i = 0; $i < $array->{elements}->[$ele_num]; $i++ )
		{
      $print_val .= "$elements->[$i]";
			$print_val .= ",";
		}
		substr($print_val, -1, 1,"");
	}

	return $print_val;
}

sub program { shift->{program}; }
sub used_array { shift->{used_array}; }
sub used_unionstruct { shift->{used_unionstruct}; }

1;
