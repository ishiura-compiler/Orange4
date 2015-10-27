package Orange4::Generator::Program;

use strict;
use warnings;

use Carp ();

sub new {
    my ( $class, $config ) = @_;
    
    bless { config => $config }, $class;
}

sub _check_structure {
    my ( $self, $statements ) = @_;
    
    foreach my $st ( @$statements ) {
        if ( defined ( $st->{st_type} ) ) {
            if( $st->{st_type} eq 'for' ) {
                unless ( defined ($st->{loop_var_name}) )     { Carp::croak( "undefined loop_var_name" ); }
                unless ( defined ($st->{init_st}) )           { Carp::croak( "undefined init_st" ); }
                unless ( defined ($st->{continuation_cond}) ) { Carp::croak( "undefined continuation_cond" ); }
                unless ( defined ($st->{re_init_st}) )        { Carp::croak( "undefined re_init_st" ); }
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
            else {
                Carp::croak( "unexpected st_type($st->{st_type})" );
            }
        }
        else {
            Carp::croak( "undefined st_type" );
        }
    }
}

sub generate_program {
    my ( $self, $varset, $statements ) = @_;
    
    my $config = $self->{config};
    my %declared_name = ();
    my $COMPARE;
    my $specifier;
    my $specification_part;
    my $suffix = '';
    
    my $DR_mode                = 1;
    my $GLOBAL_VAR_DECLARATION = "";
    my $LOCAL_VAR_DECLARATION  = "";
    
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
    $self->reset_varset_used($varset, $statements);
    
    $self->{tvar_count} = 0;
    $self->{used_loop_var_name_tmp} = ();
    $self->{cvar_count} = 0;
    
    my $st = $self->generate_statements($statements, $varset, "\t");
    $test .= $st->{test};
    $check .= $st->{check};
    $cvar_check .= $st->{cvar_check};
    $cvar_declaration .= $st->{cvar_declaration};
    
    for my $k (@$varset) {
        $k->{used} = 0 unless ( defined ( $k->{used} ) );
        push @$lvar_set, $k if ( $k->{scope} eq "LOCAL" );
        push @$gvar_set, $k if ( $k->{scope} eq "GLOBAL" );
    }
    
    # DR_mode:2 CLASS:extern(Forcing)
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
    $C_PROGRAM_1 .= ( $GLOBAL_VAR_DECLARATION eq "" ) ? "" : $GLOBAL_VAR_DECLARATION . "\n";
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

sub generate_statements {
    my ( $self, $statements, $varset, $tab ) = @_;
    
    my $test = "";
    my $check = "";
    my $cvar_check = "";
    my $cvar_declaration = "";
    
    if ( defined ( $statements ) ) {
        for my $st ( @$statements ) {
            if ( $st->{st_type} eq 'for' ) {
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
            elsif ( $st->{print_statement} && $st->{st_type} eq 'assign' ) {
                my $assign_st = $self->generate_assign_statement($st, $varset, "$tab");
                $test .= $assign_st->{test};
                $check .= $assign_st->{check};
            }
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
            $test .= "$tab" . "for( $statement->{loop_var_name} = @{[$self->tree_sprint($statement->{init_st}->{root})]}; ";
            $test .= "$statement->{loop_var_name} $statement->{inequality_sign} @{[$self->tree_sprint($statement->{continuation_cond}->{root})]}; ";
            $test .= "$statement->{loop_var_name} $statement->{operator} @{[$self->tree_sprint($statement->{re_init_st}->{root})]}) {\n";
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
            $test .= "$tab" . "for( $statement->{loop_var_name} = @{[$self->tree_sprint($statement->{init_st}->{root})]}; ";
            $test .= "$statement->{loop_var_name} $statement->{inequality_sign} @{[$self->tree_sprint($statement->{continuation_cond}->{root})]}; ";
            $test .= "$statement->{loop_var_name} $statement->{operator} @{[$self->tree_sprint($statement->{re_init_st}->{root})]}) { ; }\n";
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
        $test .= "$tab$test_name = @{[$self->tree_sprint($statement->{init_st}->{root})]};\n";
        $val = Math::BigInt->new(0);
        $type = $statement->{init_st}->{type};
        $val = $self->val_with_suffix($statement->{init_st}->{val},$type);
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
        $test .= "$tab$test_name = @{[$self->tree_sprint($statement->{re_init_st}->{root})]};\n";
        $val = Math::BigInt->new(0);
        $type = $statement->{re_init_st}->{type};
        $val = $self->val_with_suffix($statement->{re_init_st}->{val},$type);
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
        $self->{cvar_count}++;
    }
    else { ; }
    
    return +{
        test => $test,
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
    
    if ( $statement->{print_statement} && $statement->{st_type} eq 'assign' ) {
        my $type = $statement->{root}->{out}->{type};
        my $val = Math::BigInt->new(0);
        $val = $self->val_with_suffix( $statement->{val}, $statement->{type} );
        $self->mark_used_vars( $statement->{root}, $varset );
        #$statement->{var}->{used} = 1;
        $test_name = "t$statement->{name_num}";
        $test .= "$tab$test_name = @{[$self->tree_sprint($statement->{root})]};\n";
        if ( $statement->{print_statement} && $statement->{path} == 1) {
            $specifier = $self->{config}->get('type')->{$type}->{printf_format};
            $COMPARE   = "$test_name == $val";
            $fmt       = "\"@{[$specifier]}\"";
            $check .= "\t";
            $check .= "if ($COMPARE) { OK(); } ";
            $check .= "else { NG(" . "\"$test_name\", " . "$fmt, t$statement->{name_num}); }\n";
        }
        $self->{tvar_count}++;
    }
    
    return +{
        test => $test,
        check => $check,
    };
}

sub reset_varset_used {
    my ( $self, $varset, $statements ) = @_;
    
    #varsetis Hashed (Speeding up)
    my $varset_hash = $self->hash_varset($varset);
    for my $var (@$varset) {
        $var->{used} = 0;
    }
    $self->_hash_from_statement( $statements, $varset_hash );
    $self->_check_used_from_hash( $statements, $varset_hash );
}

sub _hash_from_statement {
    my ( $self, $statements, $varset_hash ) = @_;
    for my $st ( @$statements ) {
        if ( $st->{st_type} eq 'for' ) {
            $self->reset_varset_used2( $st->{init_st}->{root}, $varset_hash );
            $self->reset_varset_used2( $st->{continuation_cond}->{root}, $varset_hash );
            $self->reset_varset_used2( $st->{re_init_st}->{root}, $varset_hash );
            $self->_hash_from_statement( $st->{statements}, $varset_hash );
        }
        elsif ( $st->{st_type} eq 'if' ) {
            if ($st->{print_tree} != 0) {
	            $self->reset_varset_used2($st->{exp_cond}->{root}, $varset_hash);
            }
            if ( ($st->{print_tree} == 1)
              || ($st->{print_tree} == 2 && $st->{exp_cond}->{val} != 0) 
              || ($st->{print_tree} == 3 && $st->{exp_cond}->{val} != 0)
              || ($st->{print_tree} == 4)
              || ($st->{print_tree} == 0 && $st->{exp_cond}->{val} != 0)) {
	            $self->_hash_from_statement( $st->{st_then}, $varset_hash );
            }
            if ( ($st->{print_tree} == 1)
              || ($st->{print_tree} == 2 && $st->{exp_cond}->{val} == 0)
              || ($st->{print_tree} == 3 && $st->{exp_cond}->{val} == 0)
              || ($st->{print_tree} == 4)
              || ($st->{print_tree} == 0 && $st->{exp_cond}->{val} == 0)) {
	            $self->_hash_from_statement( $st->{st_else}, $varset_hash );
            }
        }
        elsif ( $st->{print_statement} && $st->{st_type} eq 'assign' ) {
            $self->reset_varset_used2( $st->{root}, $varset_hash );
            $st->{var}->{used} = 1;
        }
        else {;}
    }
}

sub _check_used_from_hash {
    my ( $self, $statements, $varset_hash ) = @_;
    for my $st ( @$statements ) {
        if ( $st->{print_statement} && $st->{st_type} eq 'assign' ) {
            my $key = 't' . $st->{name_num};
            $$varset_hash{$key}->{used} = 1;
        }
        elsif ( $st->{st_type} eq 'for' ) {
            $self->_check_used_from_hash( $st->{statements}, $varset_hash );
        }
        elsif ( $st->{st_type} eq 'if' ) {
            $self->_check_used_from_hash( $st->{st_then}, $varset_hash );
            $self->_check_used_from_hash( $st->{st_else}, $varset_hash );
        }
        else { ; }
    }
}

sub hash_varset {
    my ( $self, $varset ) = @_;
    
    my %varset_hash = ();
    for my $var (@$varset) {
        my $key = $var->{name_type} . $var->{name_num};
        $varset_hash{$key} = $var;
    }
    
    return \%varset_hash;
}

sub reset_varset_used2 {
    my ( $self, $n, $varset_hash ) = @_;
    
    unless ( defined( $n->{ntype} ) ) {
        Carp::croak("ntype is undefined");
    }
    
    if ( $n->{ntype} eq 'op' ) {
        for my $r ( @{ $n->{in} } ) {
            if ( $r->{print_value} == 0 ) {
                if ( $r->{ref}->{ntype} eq 'var' ) {
                    my $key = "$r->{ref}->{var}->{name_type}" . "$r->{ref}->{var}->{name_num}";
                    $$varset_hash{$key}->{used} = 1;
                }
                else {
                    $self->reset_varset_used2( $r->{ref}, $varset_hash );
                }
            }
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
    }
    elsif ( $n->{ntype} eq 'op' ) {
        my $print_value;
        if ($n->{otype} =~ /^\(.+\)$/ ) {
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
        my $val = $self->val_with_suffix( $k->{ival}, $k->{type} );
        if ( $k->{name_type} eq "t" ) {
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
        else {
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
    }
    
    return $declaration;
}

sub program { shift->{program}; }

1;
