package Orange4::Mini::Convert;

# Mini/Convert
#未定義動作回避のため比較演算子を逆にする(ゼロ除算, ゼロ剰余算対策)
sub change_relational_operators
{
  my ($n) = @_;
  my $in1_ref = $n->{in}->[1]->{ref};
	my $otype = $in1_ref->{otype};
	
	if ($otype eq '<') { $n->{in}->[1]->{ref}->{otype} = '>=';}
	elsif ($otype eq '>') { $n->{in}->[1]->{ref}->{otype} = '<=';}
	elsif ($otype eq '<=') { $n->{in}->[1]->{ref}->{otype} = '>';}
	elsif ($otype eq '>=') { $n->{in}->[1]->{ref}->{otype} = '<';}
	elsif ($otype eq '==') { $n->{in}->[1]->{ref}->{otype} = '!=';}
	elsif ($otype eq '!=') { $n->{in}->[1]->{ref}->{otype} = '==';}
	else {die;}

}

sub change_div_to_mod
{
  my ($n) = @_;
  my $in1_ref = $n->{in}->[1]->{ref};
	my $otype = $in1_ref->{otype};
	
	if ($otype eq '/') { $n->{in}->[1]->{ref}->{otype} = '%';}
	else {die;}

}

#未定義動作回避のため四則演算, シフト演算子を逆にする(オーバーフロー対策)
sub change_arithmetic_operators
{
  my ($n) = @_;
	my $otype = $n->{otype};

	if ($otype eq '+') { $n->{otype} = '-';}
	elsif ($otype eq '-') { $n->{otype} = '+';}
	elsif ($otype eq '*') { $n->{otype} = '/';}
	elsif ($otype eq '/') { $n->{otype} = '*';}
	elsif ($otype eq '<<') { $n->{otype} = '>>';}
	elsif ($otype eq '>>') { $n->{otype} = '<<';}
	else {die;}
	
}

#未定義動作回避のため, 解析木の葉の値を変更する
sub change_value
{
	my ($n,$min,$max,$varset) = @_;
	my $n_ref = $n->{ref};
	my $ref_type = $n_ref->{out}->{type};
	my $val = &random_range($max, $min, $ref_type);
	my $num_new_var = scalar @$varset;
	my $rand_classes = rand @CLASSES;
	my $rand_modifiers = rand @MODIFIERS;
	my $scopes = rand @SCOPES;
	
	my $new_var = {
		name_type => "x",
		name_num => $num_new_var,
		type => $ref_type,
		ival => $val,
		val => $val,
		class => $CLASSES[$rand_classes],
		modifier => $MODIFIERS[$rand_modifiers],
		scope => $SCOPES[$scopes],
		used => 1,
	};
  
	push @$varset, $new_var;
	
	$n->{ref}->{var} = $new_var;
	$n->{ref}->{out}->{type} = $new_var->{type};
	$n->{ref}->{out}->{val} = $new_var->{val};
}


1;
