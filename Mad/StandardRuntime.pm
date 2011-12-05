#
# Mad Project
# 
# Standard object runtime methods
# 
# Author: Michael McClennen
# Copyright (c) 2010 University of Wisconsin-Madison
# 
# This file defines the available methods for a series of object classes that
# form a base set available to Mad programmers.
# 


use strict;

# Runtime methods for objects of class 'Scalar'
# =============================================

package Mad::Gen::Scalar;

sub new {

    my ($class, $subtype, $name, $value) = @_;
    
    my ($rpkg) = caller;
    my $value = defined $main::_INIT{$rpkg}{$name} ? 
	$main::_INIT{$rpkg}{$name} : $value;
    
    if ( defined $value )
    {
	if ( $subtype =~ /num$/ )
	{
	    $value = 0.0 + $value;
	}
	
	elsif ( $subtype =~ /int$/ )
	{
	    $value = 0 + $value;
	}
	
	elsif ( $subtype =~ /flag$/ )
	{
	    $value = ($value ? 1 : 0);
	}
	
	elsif ( $subtype =~ /string$/ )
	{
	    $value = '' + $value;
	}
    }
    
    return bless { value => $value }, $class;
}


# Runtime methods for objects of class 'List'
# ===========================================

package Mad::Gen::List;

sub new {
    
    my ($class, $subtype, $name, @values) = @_;
    
    my ($rpkg) = caller;
    my $init_value = $main::_INIT{$rpkg}{$name};
    my $value_list;
    
    # First see if we've got an initial value
    
    if ( defined $init_value )
    {
	if ( ref $init_value eq 'ARRAY' )
	{
	    $value_list = $init_value;
	}
	
	elsif ( ref $init_value eq 'HASH' )
	{
	    my @value_list = keys %{$init_value};
	    $value_list = \@value_list;
	}
    
	else
	{
	    my @value_list = split /,\s*/, $init_value;
	    $value_list = \@value_list;
	}
    }
    
    else
    {
	$value_list = \@values;
    }
    
    # Now, convert the values and add them to the set one at a time.
    
    if ( $subtype eq 'num' )
    {
	foreach my $i ( @{$value_list} )
	{
	    $i = 0.0 + $i;
	}
    }
    
    elsif ( $subtype eq 'int' )
    {
	foreach my $i ( @{$value_list} )
	{
	    $i = 0 + $i;
	}
    }
    
    elsif ( $subtype eq 'flag' )
    {
	foreach my $i ( @{$value_list} )
	{
	    $i = ( $i ? 1 : 0 );
	}
    }
    
    elsif ( $subtype eq 'string' )
    {
	foreach my $i ( @{$value_list} )
	{
	    $i = '' + $i;
	}
    }
    
    # Finally, create the new object.
    
    return bless { values => $value_list }, $class;
}


# Runtime methods for objects of class 'Set'
# ==========================================

package Mad::Gen::Set;

sub new {
    
    my ($class, $subtype, $name, @values) = @_;
    
    # First create a new object
    
    my ($rpkg) = caller;
    my $init_value = $main::_INIT{$rpkg}{$name};
    my $value_list;
    
    my $obj = bless { values => [], hash => {} }, $class;
    
    # Then see if we've got an initial value
    
    if ( defined $init_value )
    {
	if ( ref $init_value eq 'ARRAY' )
	{
	    $value_list = $init_value;
	}
	
	elsif ( ref $init_value eq 'HASH' )
	{
	    my @value_list = keys %{$init_value};
	    $value_list = \@value_list;
	}
    
	else
	{
	    my @value_list = split /,\s*/, $init_value;
	    $value_list = \@value_list;
	}
    }
    
    else
    {
	$value_list = \@values;
    }
    
    # Now, convert the values and add them to the set one at a time.
    
    if ( $subtype eq 'num' )
    {
	foreach my $i ( @{$value_list} )
	{
	    $i = 0.0 + $i;
	    unless ( exists $obj->{hash}{$i} )
	    {
		push @{$obj->{values}}, $i;
		$obj->{hash}{$i} = 1;
	    }
	}
    }
    
    elsif ( $subtype eq 'int' )
    {
	foreach my $i ( @{$value_list} )
	{
	    $i = 0 + $i;
	    unless ( exists $obj->{hash}{$i} )
	    {
		push @{$obj->{values}}, $i;
		$obj->{hash}{$i} = 1;
	    }
	}
    }
    
    elsif ( $subtype eq 'flag' )
    {
	foreach my $i ( @{$value_list} )
	{
	    $i = ( $i ? 1 : 0 );
	    unless ( exists $obj->{hash}{$i} )
	    {
		push @{$obj->{values}}, $i;
		$obj->{hash}{$i} = 1;
	    }
	}
    }
    
    elsif ( $subtype eq 'string' )
    {
	foreach my $i ( @{$value_list} )
	{
	    $i = '' + $i;
	    unless ( exists $obj->{hash}{$i} )
	    {
		push @{$obj->{values}}, $i;
		$obj->{hash}{$i} = 1;
	    }
	}
    }
    
    else
    {
	foreach my $i ( @{$value_list} )
	{
	    unless ( exists $obj->{hash}{$i} )
	    {
		push @{$obj->{values}}, $i;
		$obj->{hash}{$i} = 1;
	    }
	}
    }
    
    return $obj;
}


sub assign_list {

    my ($self) = shift @_;
    
    $self->{hash} = {};
    $self->{order} = [];
    
    foreach my $elt ( @_ )
    {
	next if exists $self->{hash}{$elt};
	push @{$self->{order}}, $elt;
	$self->{hash}{$elt} = 1;
    }
}


sub contains {

    my ($self, $elt) = @_;
    
    return exists $self->{hash}{$elt};
}


package Mad::Gen::ExtClass;

sub new {
    my ($class, @args) = @_;
    my ($ah, $init_list) = $class->_attrs();
    
    my $newobj = bless {}, $class;
    
    foreach my $i (0..$#$init_list) {
	my $attr = $init_list->[$i];
	my $value = $args[$i];
	$newobj->{$attr} = $value if defined $value;
	
	if ( ref $ah->{$attr}{values} eq 'ARRAY' ) {
	    my $found = 0;
	    foreach my $j (0..$#{$ah->{$attr}{values}}) {
		$found = $j+1, last if $ah->{$attr}{values}[$j] eq $value;
	    }
	    Mad::Runtime::error("$class: '$value' is not valid for '$attr'")
		  unless $found;
	}
    }
    
    return bless $newobj, $class;
}


1;
