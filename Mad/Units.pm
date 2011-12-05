#
# NBGC Project
# 
# Units.pm - units and unit balancing
# 
# Author: Michael McClennen
# Copyright (c) 2010 University of Wisconsin-Madison
# 
# The variables and routines in this file handle units and unit balancing.
# Units are represented as strings (e.g. "km", "ohm") with each unit having a
# matching reciprocal unit, signified by an initial '/' (e.g. "/km", "/ohm".)
# Furthermore, each unit is assigned a unique prime number, and its reciprocal
# is also assigned to the same number.  This allows for a simple
# unit-balancing algorithm: the units on one side of an equation can be
# quickly reduced to a rational number in lowest terms, with common (prime)
# factors cancelled between numerator and denominator.  If the rational
# numbers representing the left and right sides of the equation are equal,
# then the equation is in balance.  Otherwise, the excess factors correspond
# to the missing (or excess) units.


package Mad::Model;

use strict;
use warnings;


our @INITIAL_UNITS = ( 'km', 'm', 'cm', 'mm', 'µm', 'nm', 'Å',
		       'mi', 'yd', 'ft', 'in', 'ha', 'acre',
		       'kg', 'g', 'mg', 'µg', 'ng',
		       'yr', 'mo', 'wk', 'day', 'hr', 'min', 
		       's', 'ms', 'µs', 'ns',
		       'V', 'A', 'W', 'C', 'F', 'H', 'Ω', 'S', 'Wb', 'T',
		       '℃', '℉', 'K',
		       'mol', 'mmol', 'µmol', 'nmol',
		       'arcdeg', 'arcmin', 'arcsec',
		       'cd', 'lm', 'lx',
		       'Bq', 'Gy', 'Sv', 'kat',
		       'rad', 'sr',
		       'N', 'dyn',
		       'Pa', 'kPa', 'hPa', 'MPa', 'atm', 'bar', 'psi',
		       'MJ', 'kJ', 'J', 'mJ', 'µJ', 'nJ');

our @UNIT_ALIASES = ( 'um' => 'µm',
		      'ug' => 'µg',
		      'mcg' => 'µg',
		      'us' => 'µs',
		      'year' => 'yr',
		      'mon' => 'mo',
		      'week' => 'wk',
		      'sec' => 's',			# '',
		      'umol' => 'µmol',
		      'uJ' => 'µJ',
		      'ohm' => 'Ω',
		      'degC' => '℃',
		      'degF' => '℉',
		      );


# setup_units ( )
# 
# This routine is called for each new object of class Model, to set up the
# initial hash of unit names.

sub setup_units {
    
    my ($self) = @_;
    $self->{unit_index} = 0;
    
    foreach my $unit (@INITIAL_UNITS) {
	$self->{unit}{$unit} = 1;
    }
    
    while (@UNIT_ALIASES) {
	my $new = shift @UNIT_ALIASES;
	my $old = shift @UNIT_ALIASES;
	
	$self->{unit}{$new} = $old;
    }
}


# declare_unit ( $new, $old )
# 
# Process a new unit declaration.  $new is the new unit name.  If $old
# is defined, it specifies an existing unit to which the new one
# should be aliased.  Returns 1 on success, 0 on failure.

sub declare_unit {
    
    my ($self, $new, $old) = @_;
    
    $self->{err} = undef;
    
    # First check to see if the new unit has already been defined.
    
    if ( $self->{unit}{$new} ) {
	#$self->{err} = 'UNIT_DECL_REPEATED';
	#return 0;
	return $self->{unit}{$new};
    }
    
    # Then check to see if we are aliasing to an existing unit.
    
    if ( $old ) {
	if ( $self->{unit}{$old} ) {
	    $self->{unit}{$new} = $old;
	    return $old;
	}
	else {
	    $self->{err} = 'UNIT_NOT_FOUND';
	    return 0;
	}
    }
    
    # Otherwise, we are declaring an entirely new unit.  The unit and its
    # inverse get assigned a unique prime number, which will be used to
    # unit-balance each equation.
    
    else {
	$self->{unit}{$new} = 1;
	return $self->{unit}{$new};
    }
}


# has_unit ( $unit )
# 
# If the given unit is defined in this model, return the prime number that has
# been assigned to it (true).  Otherwise, return 0 (false).

sub has_unit {

    my ($self, $unit) = @_;

    if ( defined $self->{unit}{$unit} ) {
	if ( $self->{unit}{$unit} eq '1' ) {
	    return $unit;
	} else {
	    return $self->{unit}{$unit};
	}
    }
    else {
	return undef;
    }
}


our ($UNIT_WILDCARD) = bless { '*' => 1 }, 'Units';

# equiv_units ( $units1, $units2 )
# 
# Return true if $units1 is equivalent to $units2, false otherwise.

sub equiv_units {
    
    my ($u1, $u2) = @_;
    
    return undef unless ref $u1 eq 'Units';
    return undef unless ref $u2 eq 'Units';
    
    foreach my $k ( keys %{$u1} ) {
	return undef unless defined $u2->{$k} && $u1->{$k} == $u2->{$k};
    }
    
    foreach my $k ( keys %{$u2} ) {
	return undef unless defined $u1->{$k} && $u1->{$k} == $u2->{$k};
    }

    return 1;
}


# check_units ( $u1, $u2, $string )
# 
# Return silently if the two sets of units are compatible.  This is true if
# one or both are null, and also if the two are equivalent.  Otherwise, signal
# a warning (or an error, depending upon the strictness level).  $string, if
# given, is used to make the message more specific.

sub check_units {
    
    my ($self, $node, $u1, $u2, $string) = @_;
    
    return 1 unless ref $u1 eq 'Units';
    return 1 unless ref $u2 eq 'Units';
    
    return 1 if equiv_units($u1, $u2);
    
    my $str1 = print_units($u1);
    my $str2 = print_units($u2);
    $self->unit_warning($node, "$string redefined from <$str1> to <$str2>");
    return undef;
}


# print_units ( $u )
# 
# Generate an output string for the given unit expression.

sub print_units {

    my ($u1) = @_;
    
    return 'NULL' unless ref $u1 eq 'Units';
    return '/' if exists $u1->{'/'};
    return '*' if exists $u1->{'*'};
    
    my $str = '';
    my (@a, @b);
    
    foreach my $u ( keys %{$u1} ) {
	if ( $u1->{$u} > 0 ) {
	    push @a, $u;
	} elsif ( $u1->{$u} < 0 ) {
	    push @b, $u;
	}
    }
    
    my @c;
    push @c, sort @a;
    push @c, sort @b;
    
    foreach my $u ( @c ) {
	$str .= ' ' if $str ne '';
	if ( $u1->{$u} == 1 ) {
	    $str .= $u;
	} else {
	    $str .= $u . $u1->{$u};
	}
    }
    
    return $str;
}


# compare_units ( $node, $units1, $units2 )
# 
# Handle the conjunction of two terms in a relational expression.  If the two
# sets of units are not compatible, then signal an error.  Otherwise, return
# silently. 

sub check_units_compare {

    my ($self, $node, $u1, $u2) = @_;
    
    # If both unit expressions are null, return null
    
    !defined $u1 && !defined $u2 && return undef;
    
    # If either of the expressions is a wildcard, we're okay.
    
    return if ref $u1 && $u1->{'*'};
    return if ref $u2 && $u2->{'*'};
    
    # If both of the expressions are either null or dimensionless, we're okay
    
    if ( (!defined $u1 || $u1->{'/'}) and (!defined $u2 || $u2->{'/'}) ) {
	return;
    }
    
    # Otherwise, if one of the expressions is null or dimensionless and the
    # other isn't then we have a problem.
    
    if ( !defined $u1 || $u1->{'/'} ) {
	my $str = print_units($u2);
	$self->unit_error($node, "cannot compare a quantity of <$str> to a unitless expression");
	return;
    }
    
    if ( !defined $u2 || $u2->{'/'} ) {
	my $str = print_units($u1);
	$self->unit_error($node, "cannot compare a quantity of <$str> to a unitless expression");
	return;
    }
    
    # If the two unit expressions are the same, then we're okay.  Otherwise,
    # we have a problem.
    
    unless ( equiv_units($u1, $u2) ) {
	my $str1 = print_units($u1);
	my $str2 = print_units($u2);
	$self->unit_error($node, "cannot compare a quantity of <$str1> to a quantity of <$str2>");
    }
    
    return;
}


# check_units_assign ( $node, $param_units, $value_units, $which )
# 
# Compare the units of a function parameter to the corresponding argument
# value.  If these two sets of units are not compatible, then signal an error.
# Otherwise, return silently.  $which tells us which parameter or variable is
# at fault.

sub check_units_assign {

    my ($self, $node, $pu, $vu, $which) = @_;
    
    # If both unit expressions are null, return null
    
    !defined $pu && !defined $vu && return undef;
    
    # If either of the expressions is a wildcard, we're okay.
    
    return if ref $pu && $pu->{'*'};
    return if ref $vu && $vu->{'*'};
    
    # If the parameter is null, we're okay.  Return the value units.
    
    if ( !defined $pu ) {
	return;
    }
    
    # If both of the expressions are either null or dimensionless, we're okay
    
    if ( $pu->{'/'} && (!defined $vu || $vu->{'/'}) ) {
	return;
    }
    
    # Otherwise, we might have a problem.  So generate a string for the error
    # message.
    
    my $name = $which;

    { 
	no warnings;
	if ( $which > 0 ) { $name = "parameter $which"; }
    }
    
    # If the parameter is dimensionless and the value isn't then we
    # have a problem.
    
    if ( $pu->{'/'} ) {
	my $str = print_units($vu);
	$self->unit_error($node, "$name was declared as </> but was given a value with units of <$str>");
	return;
    }
    
    # If the value is null or dimensionless and the parameter isn't then we
    # have a problem.
    
    if ( !defined $vu || $vu->{'/'} ) {
	my $str = print_units($pu);
	$self->unit_error($node, "$name was declared as <$str> but was given a value of </>");
	return;
    }
    
    # If the two unit expressions are the same, then we're okay.  Otherwise,
    # we have a problem.
    
    unless ( equiv_units($pu, $vu) ) {
	my $str1 = print_units($pu);
	my $str2 = print_units($vu);
	$self->unit_error($node, "$name was declared as <$str1> but was given a value with units of <$str2>");
    }
    
    return;
}


# check_node_units ( $node, $units )
# 
# If the given node has units, override $units.

sub check_node_units {
    
    my ($self, $node, $units) = @_;
    
    unless ( ref $node->{units} eq 'Units' ) {
	return $units;
    }
    
    return $node->{units};
}


# merge_units ( $node, $units1, $units2, $value )
# 
# Handle the conjunction of two terms in a numerical expression.  If the two
# sets of units are compatible under the operation associated with $node, then
# return the appropriate unit expression for the result.  Otherwise, signal an
# error and return an empty set of units.  The final parameter, $value, gets
# the generated code for the second term.  This is so we can check for integer
# literals as exponents.
# 
# If, however, the node itself has a units expression associated with it, use
# this to override and issue a warning.

sub merge_units {

    my ($self, $node, $u1, $u2, $value) = @_;
    
    # First determine the merged units
    
    my $merged = $self->merge_units_internal($node, $u1, $u2, $value);
    
    # Then see if that's being overridden.
    
    if ( defined $node->{units} && !equiv_units($node->{units}, $merged) )
    {
	my $str1 = print_units($merged);
	my $str2 = print_units($node->{units});
	$self->unit_warning($node, "expression redefined from <$str1> to <$str2>");
	return $node->{units};
    }
    
    else
    {
	return $merged;
    }
}


sub merge_units_internal {
    
    my ($self, $node, $u1, $u2, $value) = @_;
    
    # If both unit expressions are null, return null
    
    !defined $u1 && !defined $u2 && return undef;
    
    # Otherwise, look at the operation being considered
    
    my $op = $node->{attr};
    
    # When terms are added or subtracted, they must either have the same units
    # or one of them must be dimensionless.
    
    if ( $op eq '+' or $op eq '-' or $op eq 'min' or $op eq 'max' ) {
	
 	# If either of the expressions is a wildcard, return the other one.
	
	ref $u1 && $u1->{'*'} && return $u2;
	ref $u2 && $u2->{'*'} && return $u1;
	
	# Otherwise, if both of the expressions are dimensionless or null, the
	# result is, too.
	
	if ( (!defined $u1 || $u1->{'/'}) && (!defined $u2 || $u2->{'/'}) ) {
	    return $u1 || $u2;
	}
	
	# Otherwise, if one term is dimensionless or null and the other isn't,
	# we have a problem.
	
	if ( !defined $u1 || $u1->{'/'} ) {
	    my $str = print_units($u2);
	    $self->unit_error($node, "unitless expression added to <$str>");
	    return $u2;
	}
	
	if ( !defined $u2 || $u2->{'/'} ) {
	    my $str = print_units($u1);
	    $self->unit_error($node, "unitless expression added to <$str>");
	    return $u1;
	}
	
	# If the two unit expressions are identical, we return the first one
	# (we could have returned either one).
	
	if ( equiv_units($u1, $u2) ) {
	    return $u1;
	}
	
	# Otherwise, we have a problem.
	
	else {
	    my $str1 = print_units($u1);
	    my $str2 = print_units($u2);
	    
	    $self->unit_error($node, "<$str1> added to <$str2>");
	    return $UNIT_WILDCARD;
	}
    }
    
    # When terms are multiplied, the units are added.
    
    elsif ( $op eq '*' ) {
	
	# If either of the expressions is null, return the other one.
	
	!defined $u1 && return $u2;
	!defined $u2 && return $u1;
	
 	# If either of the expressions is a wildcard, return the other one.
	
	ref $u1 && $u1->{'*'} && return $u2;
	ref $u2 && $u2->{'*'} && return $u1;
	
	# If either is dimensionless then return the other one.
	
	$u1->{'/'} && return $u2;
	$u2->{'/'} && return $u1;
	
	# Otherwise, we add the two.
	
	return add_units($u1, $u2);
    }
    
    # When terms are divided, the units are subtracted.
    
    elsif ( $op eq '/' ) {

 	# If either is a wildcard then return the other one (negated if it's
 	# the second.)  We check $u2 first so that if they are both wildcards
 	# then $u1 is returned.
	
	ref $u2 && $u2->{'*'} && return $u1;
	ref $u1 && $u1->{'*'} && return subtract_units(undef, $u2);
	
	# Likewise, if either is null then return the other one (negated if
	# it's the second.)
	
	!defined $u2 && return $u1;
	!defined $u1 && return subtract_units(undef, $u2);
	
	# Otherwise, if either is dimensionless then return the other one
	# (negated if it's the second.)
	
	$u2->{'/'} && return $u1;
	$u1->{'/'} && return subtract_units(undef, $u2);
	
	# Otherwise, we subtract the second.
	
	return subtract_units($u1, $u2);
    }
    
    # With exponentiation, the exponent must be dimensionless or a
    # wildcard. If the exponent is an integer literal, then it is used to
    # multiply the base units.
    
    elsif ( $op eq '^' ) {
	
	# The exponent must be either dimensionless or a wildcard, or null, or
	# there is a problem.
	
	unless ( !defined $u2 or $u2->{'/'} or $u2->{'*'} ) {
	    my $str1 = print_units($u2);
	    $self->unit_error($node, "an exponent must not have any units (has <$str1>)");
	    return $UNIT_WILDCARD;
	}
	
	# If the base is a wildcard or dimensionless or null, return that.
	
	if ( !defined $u1 or $u1->{'/'} or $u1->{'*'} ) {
	    return $u1;
	}
	
	# If the exponent is an integer literal (positive or negative), then
	# adjust the base units.
	
	if ( $value =~ /^-?[0-9]+$/ ) {
	    return scale_units($u1, 0+$value);
	}
	
	# Otherwise, return a wildcard.
	
	return $UNIT_WILDCARD;
    }
}


# add_units ( $u1, $u2 )
# 
# Add the two sets of units together (used when two expressions are
# multiplied). 

sub add_units {
    
    my ($u1, $u2) = @_;
    
    # Create a new unit expression and add in all of the units from both
    # sources.  Some of them may cancel out if one or the other has a unit
    # with a negative multiplicity.
    
    my ($new) = bless {}, 'Units';
    
    foreach my $u ( keys %{$u1} ) {
	next if $u eq '/' || $u eq '*';
	$new->{$u} = $u1->{$u} unless $u1->{$u} == 0;
    }
    
    foreach my $u ( keys %{$u2} ) {
	next if $u eq '/' || $u eq '*';
	$new->{$u} += $u2->{$u};
	delete $new->{$u} if $new->{$u} == 0;
    }
    
    # If all of the units cancel out, then we have a dimensionless quantity.
    
    $new->{'/'} = 1 unless scalar(keys %{$new}) > 0;
    
    # Return the new unit expression.
    
    return $new;
}


# subtract_units ( $u1, $u2 )
# 
# Subtract the second set of units from the first, or invert it if $u1 is not
# defined (used when two expressions are divided).

sub subtract_units {
    
    my ($u1, $u2) = @_;
    
    # Create a new unit expression and add in all of the units from the first.
    
    my ($new) = bless {}, 'Units';
    
    if ( ref $u1 ) {
	foreach my $u ( keys %{$u1} ) {
	    next if $u eq '/' || $u eq '*';
	    $new->{$u} = $u1->{$u} unless $u1->{$u} == 0;
	}
    }
    
    # Now subtract all of the units from the second.  Delete the ones that
    # cancel out.
    
    foreach my $u ( keys %{$u2} ) {
	next if $u eq '/' || $u eq '*';
	$new->{$u} -= $u2->{$u};
	delete $new->{$u} if $new->{$u} == 0;
    }
    
    # If all of the units cancel out, then we have a dimensionless quantity.
    
    $new->{'/'} = 1 unless scalar(keys %{$new}) > 0;
    
    # Return the new unit expression.
    
    return $new;
}


# scale_units ( $u1, $factor )
# 
# Scale the multiplicity all of the units in $u1 by $factor (used when an
# expression is raised to an integral power.)  Note: this routine should only
# be called with an integer value (positive or negative) for $factor.

sub scale_units {

    my ($u1, $factor) = @_;
    
    # Take care of trivial cases first
    
    return $u1 if $factor == 1;
    return $UNIT_WILDCARD if $factor == 0;
    
    # Otherwise, we need to create a new unit expression with each unit's
    # multiplicity increased.
    
    my ($new) = bless {}, 'Units';
    
    foreach my $u ( keys %{$u1} ) {
	$new->{$u} = $u1->{$u} * $factor;
    }
    
    # Return the new expression.
    
    return $new;
}


# merge_list_units ( $list_units, $elt_units )
# 
# Merge $list_units (representing the units of a growing list) with $elt_units
# (representing the units of the next element) and return the new units.

sub merge_list_units {

    my ($lu, $eu) = @_;
    
    # If either is undefined, return the other one.
    
    unless ( ref $lu eq 'Units' )
    {
	return $eu;
    }
    
    unless ( ref $eu eq 'Units' )
    {
	return $lu
    }
    
    # If either one is a wildcard, return it.
    
    if ( $lu->{'*'} )
    {
	return $lu;
    }
    
    if ( $eu->{'*'} )
    {
	return $eu;
    }
    
    # If the two are equivalent, return one of them.
    
    if ( equiv_units($lu, $eu) )
    {
	return $lu;
    }
    
    # Otherwise, return a wildcard.
    
    return $UNIT_WILDCARD;
}


1;


