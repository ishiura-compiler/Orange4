package Orange4::Generator::Program;

use strict;
use warnings;

use Carp ();

sub new {
    my ( $class, $config ) = @_;
    
    bless { config => $config }, $class;
}

sub _check_structure {
    my ( $self, $roots ) = @_;
    
    foreach my $i ( 0 .. $#{$roots} ) {
        my $root_i = $roots->[$i];
        if ( defined( $root_i->{st_type} ) ) {
            if( $root_i->{st_type} eq 'for' ) {
                unless (defined ($root_i->{loop_var_name})) { Carp::croak("undefined loop_var_name($i)"); }
                unless (defined ($root_i->{init_st})) { Carp::croak("undefined init_st($i)"); }
                unless (defined ($root_i->{continuation_cond})) { Carp::croak("undefined continuation_cond($i)"); }
                unless (defined ($root_i->{re_init_st})) { Carp::croak("undefined re_init_st($i)"); }
                unless (defined ($root_i->{inequality_sign})) { Carp::croak("undefined inequality_sign($i)"); }
                unless (defined ($root_i->{statements})) { Carp::croak("undefined statements($i)"); }
            }
            elsif( $root_i->{st_type} eq 'if' ) {
                unless (defined ($root_i->{exp_cond})) { Carp::croak("undefined exp_cond($i)"); }
                unless (defined ($root_i->{st_then})) { Carp::croak("undefined st_then($i)"); }
                unless (defined ($root_i->{st_else})) { Carp::croak("undefined st_else($i)"); }
            }
            elsif ( $root_i->{st_type} eq 'assign' ) {
                if ( defined( $root_i->{print_statement} )
                && $root_i->{print_statement} )
                {
                    if ( $root_i->{var}->{type} eq $root_i->{type} ) { ; }
                    else { Carp::croak("type ne assgign-var-type($i)"); }
                    if ( $root_i->{var}->{val} eq $root_i->{val} ) { ; }
                    else { Carp::croak("val ne assgign-var-val($i)"); }
                    if ( defined( $root_i->{root}->{out}->{type} ) ) { ; }
                    else { Carp::croak("undefined root-out-type($i)"); }
                    if ( defined( $root_i->{root}->{out}->{val} ) ) { ; }
                    else { Carp::croak("undefined root-out-val($i)"); }
                    if ( defined( $root_i->{root}->{ntype} ) ) { ; }
                    else { Carp::croak("undefined root-ntype($i)"); }
                    if ( defined( $root_i->{root}->{otype} ) ) { ; }
                    else { Carp::croak("undefined root-otype($i)"); }
                    if ( $root_i->{root}->{out}->{type} eq $root_i->{type} ) { ; }
                    else { Carp::croak("type ne root-out-type($i)"); }
                    if ( $root_i->{root}->{out}->{val} eq $root_i->{val} ) { ; }
                    else { Carp::croak("val ne root-out-val($i)"); }
                }
                elsif ( defined( $root_i->{print_statement} )
                && !$root_i->{print_statement} ) { ; }
                else { Carp::croak("undefined print_statement($i)"); }
                if ( defined( $root_i->{var} ) ) { ; }
                else { Carp::croak("undefined assgign-var($i)"); }
                if ( defined( $root_i->{type} ) ) { ; }
                else { Carp::croak("undefined assgign-type($i)"); }
                if ( defined( $root_i->{val} ) ) { ; }
                else { Carp::croak("undefined assgign-val($i)"); }
            }
            else {
                Carp::croak("unexpected st_type($i)");
            }
        }
        else {
            Carp::croak("undefined st_type($i)");
        }
    }
}

sub generate_program {
    my ( $self, $varset, $roots ) = @_;
    
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
    
    my $header = $config->get('headers'); # 変更箇所
    my $main_type = ($config->get('main_type')) ? $config->get('main_type') : "int"; # 変更箇所
    my $retval = ($main_type eq "void") ? "" : 0; # 変更箇所
    
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
    
    my $macro_ok = $config->get('macro_ok');
    my $macro_ng = $config->get('macro_ng');
    if( $macro_ok =~/printf/ || $macro_ng =~/printf/) {
    if(defined $header && grep{/#include<stdio\.h>/} @$header) {
    $MACROS = "";
    }
    else {
    $MACROS = "#include <stdio.h>\n";
    }
    }
    
    $macrosd .= "#define OK()  $macro_ok\n";
    $macrosd .= "#define NG(test,fmt,val)  $macro_ng\n";
    
    $MACROS .= $macrosd;
    
    chomp($MACROS);
    chomp($MACROS_2);
    #chomp($header);
    
    # root structure check
    $self->_check_structure($roots);
    

    # not display variables that are not used
    $self->reset_varset_used( $varset, $roots );
    
    $self->{tval_count} = 0;
    $self->{used_loop_var_name_tmp} = ();
    
    for my $statement (@$roots) {
        if ( defined ($statement) && $statement->{st_type} eq 'for' ) {
            my $for_st = $self->generate_for_statement($statement, $varset, "\t");
            $test .= $for_st->{test};
            $check .= $for_st->{check};
        }
        elsif ( defined ($statement) && $statement->{st_type} eq 'if' ) {
            my $if_st = $self->generate_if_statement($statement, $varset, "\t");
            $test .= $if_st->{test};
            $check .= $if_st->{check};
        }
        elsif ( defined ($statement) && $statement->{st_type} eq 'assign' ) {
            my $assign_st = $self->generate_assign_statement($statement, $varset, "\t");
            $test .= $assign_st->{test};
            $check .= $assign_st->{check};
        }
        else { Carp::croak("Invalid operand $statement"); }
    }
        
    for my $k (@$varset) {
        $k->{used} = 0 unless ( defined( $k->{used} ) );
        push @$lvar_set, $k if ( $k->{scope} eq "LOCAL" );
        push @$gvar_set, $k if ( $k->{scope} eq "GLOBAL" );
    }
    
    # DR_mode:2 CLASS:extern(Forcing)
    $GLOBAL_VAR_DECLARATION =
    $self->make_c_var_declaration( $DR_mode, $gvar_set, '' );
    $LOCAL_VAR_DECLARATION =
    $self->make_c_var_declaration( $DR_mode, $lvar_set, "\t" );
    
    # 使ったループ変数の重複を排除
    $self->{used_loop_var_name} = ();
    my %exist = ();
    foreach my $element (@{$self->{used_loop_var_name_tmp}}) {
        unless (exists $exist{$element}) {
            push @{$self->{used_loop_var_name}}, $element;
            $exist{$element} = 1;
        }
    }
    
    if( defined($self->{used_loop_var_name})) {
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
    chomp($LOCAL_VAR_DECLARATION);
    chomp($GLOBAL_VAR_DECLARATION);
    
    my $C_PROGRAM_1 = ( $config->get('headers')) ? join '\n', @$header : ""; #変更箇所
    $C_PROGRAM_1 .= ( $MACROS eq "" ) ? "" : $MACROS . "\n\n";
    $C_PROGRAM_1 .=
    ( $GLOBAL_VAR_DECLARATION eq "" ) ? "" : $GLOBAL_VAR_DECLARATION . "\n";
    my $C_PROGRAM_2 =
    ( $LOCAL_VAR_DECLARATION eq "" ) ? "" : $LOCAL_VAR_DECLARATION . "\n\n";
    $C_PROGRAM_2 .= ( $test eq "" )  ? "" : $test . "\n";

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

sub generate_for_statement {
    my ($self, $statement, $varset, $tab) = @_;
    
    my $test = "";
    my $check = "";
    $test .= "$tab" . "for( $statement->{loop_var_name} = @{[$self->tree_sprint($statement->{init_st}->{root})]}; ";
    $test .= "$statement->{loop_var_name} $statement->{inequality_sign} @{[$self->tree_sprint($statement->{continuation_cond}->{root})]}; ";
    $test .= "$statement->{loop_var_name} $statement->{operator} @{[$self->tree_sprint($statement->{re_init_st}->{root})]})\n";
    $test .= "$tab" . "{\n";
    
    push @{$self->{used_loop_var_name_tmp}}, $statement->{loop_var_name};
    
    for my $st ( @{$statement->{statements}} ) {
        if ( defined($st) && $st->{st_type} eq 'for' ) {
            my $for_st = $self->generate_for_statement($st, $varset, "$tab\t");
            $test .= $for_st->{test};
            $check .= $for_st->{check};
        }
        elsif ( defined($st) && $st->{st_type} eq 'if' ) {
            my $if_st = $self->generate_if_statement($st, $varset, "$tab\t");
            $test .= $if_st->{test};
            $check .= $if_st->{check};
        }
        elsif ( defined($st) && $st->{st_type} eq 'assign' ) {
            my $assign_st = $self->generate_assign_statement($st, $varset, "$tab\t");
            $test .= $assign_st->{test};
            $check .= $assign_st->{check};
        }
        else { ; }
    }
    
    $test .= "$tab}\n";
    
    return +{
        test => $test,
        check => $check,
    };
}

sub generate_if_statement {
    my ($self, $statement, $varset, $tab) = @_;
    
    my $test = "";
    my $check = "";
    $test .= "$tab" . "if( @{[$self->tree_sprint($statement->{exp_cond}->{root})]} ) {\n";
    
    for my $st (@{$statement->{st_then}}) {
        if ( defined($st) && $st->{st_type} eq 'for' ) {
            my $for_st = $self->generate_for_statement($st, $varset, "$tab\t");
            $test .= $for_st->{test};
            $check .= $for_st->{check};
        }
        elsif ( defined($st) && $st->{st_type} eq 'if' ) {
            my $if_st = $self->generate_if_statement($st, $varset, "$tab\t");
            $test .= $if_st->{test};
            $check .= $if_st->{check};
        }
        elsif ( defined($st) && $st->{st_type} eq 'assign' ) {
            my $assign_st = $self->generate_assign_statement($st, $varset, "$tab\t");
            $test .= $assign_st->{test};
            $check .= $assign_st->{check};
        }
        else { ; }
    }
    
    $test .= "$tab}\n";
    
    if ( defined($statement->{st_else}->[0]) ) { 
        $test .= "$tab" . "else {\n";
        
        for my $st (@{$statement->{st_else}}) {
            if(defined ($st) && $st->{st_type} eq 'for') {
                my $for_st = $self->generate_for_statement($st, $varset, "$tab\t");
                $test .= $for_st->{test};
                $check .= $for_st->{check};
            }
            elsif(defined ($st) && $st->{st_type} eq 'if') {
                my $if_st = $self->generate_if_statement($st, $varset, "$tab\t");
                $test .= $if_st->{test};
                $check .= $if_st->{check};
            }
            elsif(defined ($st) && $st->{st_type} eq 'assign') {
                my $assign_st = $self->generate_assign_statement($st, $varset, "$tab\t");
                $test .= $assign_st->{test};
                $check .= $assign_st->{check};
            }
            else { ; }
        }
        
        $test .= "$tab}\n";
    }
    
    return +{
        test => $test,
        check => $check,
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
        $val = $self->val_with_suffix( $statement->{val},
        $statement->{type} );
        $self->mark_used_vars( $statement->{root}, $varset );
        $test_name = "t$self->{tval_count}";
        $test .= "$tab$test_name = @{[$self->tree_sprint($statement->{root})]};\n";
        if ( $statement->{print_statement} == 1 && $statement->{path} == 1) {
            $specifier = $self->{config}->get('type')->{$type}->{printf_format};
            $COMPARE   = "$test_name == $val";
            $fmt       = "\"@{[$specifier]}\"";
            $test .= "$tab";
            $test .= "if ($COMPARE) { OK(); } ";
            $test .= "else { NG(" . "\"$test_name\", " . "$fmt, t$self->{tval_count}); }\n";
        }
        $self->{tval_count}++;
    }
    
    return +{
        test => $test,
        check => $check,
    };
}

sub reset_varset_used {
    my ( $self, $varset, $roots ) = @_;
    
    #varsetis Hashed (Speeding up)
    my $varset_hash = $self->hash_varset($varset);
    $self->_hash_from_root( $roots, $varset_hash );
    $self->_check_used_from_hash( $roots, $varset_hash );
}

sub _hash_from_root {
    my ( $self, $roots, $varset_hash ) = @_;
    for my $i ( 0 .. $#{$roots} ) {
        my $root_i = $roots->[$i];
        if ( $root_i->{st_type} eq 'for' ) {
            $self->_hash_from_root( $root_i->{statements}, $varset_hash );
        }
        elsif ( $root_i->{st_type} eq 'if' ) {
            $self->_hash_from_root( $root_i->{statements}, $varset_hash );
        }
        elsif ( $root_i->{print_statement} && $root_i->{st_type} eq 'assign' ) {
          $self->reset_varset_used2( $root_i->{root}, $varset_hash );
        }
        else {;}
    }
}

sub _check_used_from_hash {
    my ( $self, $roots, $varset_hash ) = @_;
    for my $i ( 0 .. $#{$roots} ) {
        my $root_i = $roots->[$i];
        if ( $root_i->{print_statement} && $root_i->{st_type} eq 'assign' ) {
            my $key = 't' . $root_i->{var}->{name_num};
        $$varset_hash{$key}->{used} = 1;
        }
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
                    my $key =
                        "$r->{ref}->{var}->{name_type}" . "$r->{ref}->{var}->{name_num}";
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
                    $s .=
                        "($o->{type}) " . $self->val_with_suffix( $o->{val}, $o->{type} );
                }
                elsif ( $print_value == 2 ) {
                    $s .=
                        "($l->{type})" . $self->val_with_suffix( $l->{val}, $l->{type} );
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
    my ( $self, $DR_mode, $var_set, $indent ) = @_;
    
    my $declaration = "";
    
    for my $k (@$var_set) {
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
