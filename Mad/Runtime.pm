#
# NBGC Project
# 
# Class NBGC::Model - dynamic system model
# 
# Author: Michael McClennen
# Copyright (c) 2010 University of Wisconsin-Madison
# 
# Each instance of this class represents a dynamic system model.  The model
# expresses a system of differential equations by means of a set of variables
# and flows.  An approximate solution to this system of equations can then be
# generated by iteration over a series of time steps.  This is referred to as
# "running" the model.


package Mad::Runtime;

use strict;
use Graphics::PLplot;

# run ( args )
# 
# Run the model.  The arguments passed to it should be the ones provided on
# the command line.

sub run {
    
    my ($rpkg) = caller;
    
    $rpkg->dbgi_sub();
    
    no strict;
    
    eval "\$${rpkg}::START = 0";
    eval "\$${rpkg}::END = 100";
    eval "\$${rpkg}::I = 1";
    eval "\$${rpkg}::T = \$${rpkg}::START";
    
    $rpkg->init_sub(@_);
    $rpkg->trac_sub();
    
    while ( ${"${rpkg}::T"} < ${"${rpkg}::END"} )
    {
	$rpkg->calc_sub();
	$rpkg->step_sub();
	$rpkg->trac_sub();
    }
    
    $rpkg->fini_sub();
    exit;
}


# error ( runpkg, $msg, $where )
# 
# This routine is called when certain runtime errors occur.

sub error {

    my ($runpkg, $msg, $where) = @_;
    
    print STDERR "$msg, at $where\n";
    die "Fatal error.\n";
}


# initial_value ( variable, value )
# 
# Set the initial value of the given variable to the given value.

sub initial_value {
    
    my ($self, $var_name, $value ) = @_;
    
    return undef unless 
	defined $var_name &&
	    defined $value &&
		exists $self->{symtab}{$var_name};
    
    $self->{initval}{$var_name} = $value;
    return 1;
}


# initialize ( )
# 
# Run the INIT step of the model, then stop.

sub initialize {
    
    my $self = shift;
    
    return undef unless	$self->{status} eq 'READY';
    
    $self->{status} = 'INIT';
    
    &{$self->{init_sub}}();
    &{$self->{trac_sub}}();
    
    $self->{status} = 'INITIALIZED';
}


# run_until ( limit )
# 
# Run the model until the time counter reaches the given limit, or until
# something else halts the run.  Return true if we actually run at least one step.

sub run_until {
    
    my ($self, $limit) = @_;
    
    # First make sure that we're ready to go, and run the initialization step
    # if it hasn't already been done.  If we are not ready to go, return false.
    
    if ( $self->{status} eq 'READY' ) {
	$self->initialize;
    }
    elsif ( $self->{status} ne 'INITIALIZED' ) {
	print STDERR "The model is not ready to run.\n";
	return undef;
    }
    
    # Make sure that the limit we are given is greater than zero.
    
    unless ( $limit > 0 ) {
	print STDERR "The limit must be a number greater than zero.\n";
	return undef;
    }
    
    # Now, run as long as we have not reached the limit.
    
    my $time_var = $self->{time_var};
    $self->{status} = 'RUNNING';
    
    while ( $$time_var < $limit ) {
	
        &{$self->{calc_sub}}();
	&{$self->{step_sub}}();
	&{$self->{trac_sub}}();
    }
    
    &{$self->{fini_sub}}();
    
    $self->{status} = 'DONE';
}


# variables ( )
# 
# Return a list of the model's variable names.  For now, include only
# endpoint-type variables.

sub variables {

    my $self = shift;
    
    my @varlist;
    
    foreach my $ep ( @{$self->{varlist}} ) {
	
	my $name = $ep->{name};
	my $type = $ep->{type};
	next if $type eq 'PseudoVar';
	next if $type eq 'num';
	
	$name =~ s/^\$?\w+:://;
	push @varlist, $name;
    }
    
    return @varlist;
}


# dump_trace ( )
# 
# Print out a dump of the trace data saved during the most recent model run.

sub dump_trace {
    
    my $self = shift;
    
    my @varlist = $self->variables;
    unshift @varlist, 'T';
    
    my $base = eval '\\%' . $self->{runpkg} . '_TRACE';
    my $count = scalar @{$base->{'T'}};
    
    foreach my $var (@varlist) {
	printf STDOUT "%-14s ", $var;
    }
    
    print STDOUT "\n";
    
    for my $i (0..$count-1) {
	foreach my $var (@varlist) {
	    printf STDOUT "%-14g ", $base->{$var}[$i];
	}
	
	print STDOUT "\n";
    }
    
    print "\n\n";
}


# get_values ( var )
# 
# Get the traced values of the specified variable (can be 'T' for time).

sub get_values {
    
    my ($self, $var) = @_;

    my $base = eval '\\%' . $self->{runpkg} . '_TRACE';
    return @{$base->{$var}};
}


# minmax_values ( @values )
# 
# Return the minimum and maximum of the given list of values.

sub minmax_values {

    my $self = shift;
    my $min = shift;
    my $max = shift;
    
    foreach (@_) {
	$min = $_ if $_ < $min;
	$max = $_ if $_ > $max;
    }
    
    return ($min, $max);
}


# plot ( @vars )
# 
# Plot the specified variables

sub plot {
    
    my ($self, @vars) = @_;

    my (@t) = $self->get_values('T');
    my ($tmin, $tmax) = $self->minmax_values(@t);
    my (@values);
    my (@colors) = (1, 3, 9, 13, 8);
    my $textcoord = 9;

    plsdev ("aqt");
    plinit ();
    plscolbg (255, 255, 255);
    plenv ($tmin, $tmax, 0, 100, 0, 2);
    
    foreach my $var (@vars) {
	print "PLOTTING VARIABLE: $var\n" if $self->{debug_level} > 0;
	@values = $self->get_values($var);
	plcol0 (shift @colors);
	plline(\@t, \@values);
	my ($varname) = $var;
	plptex(5, ($textcoord-- * 10) + 5, 1, 0, 0, $varname);
    }

    plend ();
}


1;
