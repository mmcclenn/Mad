#
# NBGC Project
# 
# Simulator::PDL - subclass of Simulator that uses PDL internally.
# 
# Author: Michael McClennen
# Copyright (c) 2010 University of Wisconsin-Madison

package NBGC::Simulator::PDL;
our (@ISA) = 'NBGC::Simulator';

use strict;
use warnings;
use Carp;
use PDL;
use PDL::NiceSlice;
use PDL::Graphics::PLplot;

# Compile the model that is currently loaded into this Simulator object.
# The model state is kept as a piddle.  Variable values are all kept in
# the package NBGC::Run_$id where $id is a unique identifier assigned to this
# Simulator object.

sub compile_runprog {

    my $self = shift;
    
    # First, go through the symbol table to generate a vector of
    # actual variables (not constants).
    
    my $vindex = 2;		# position 0 is for the time, and position 1
                                # is for the constant 1.
    
    my @vv = (undef, undef);
    
    foreach my $sym (@{$self->{sseq}}) {
	if ( $sym->{type} eq 'var' ) {
	    $sym->{index} = $vindex;
	    $vv[$vindex++] = $sym;
	}
    }
    
    $self->{vvector} = \@vv;
    my $vlen = scalar(@vv);
    
    # First generate the state vector and linear transformation vector, and
    # add them to the simulator object.
    
    my ($tmp);
    $self->{STATE} = zeros($vlen);
    ($tmp = $self->{STATE}->slice('1')) .= $self->{t_unit};
    
    $self->{LINTRAN} = zeros($vlen, $vlen);
    ($tmp = $self->{LINTRAN}->diagonal(0,1))++;
    ($tmp = $self->{LINTRAN}->slice('0,1')) .= 1;
    
    # Our generated code goes in the 'runspace' package.
    
    my $CODE = <<ENDCODE;
package $self->{runspace};
no strict 'vars';
use PDL;

ENDCODE
    
    # First generate code to evaluate the initialization expressions, possibly
    # overridden by user-set initial values stored in the 'itable'.
    
    foreach my $init (@{$self->{initlist}}) {
	my ($name, $expr) = ($init->{sym}{name}, $init->{expr});
	$CODE .= <<ENDCODE;
\$$name = (defined \$self->{itable}{'$name'} ? \$self->{itable}{'$name'} : $expr);
ENDCODE
    }
    
    # Then generate code to initialize each of the positions in the state
    # vector (except for 0 and 1) based on the results of these initialization
    # expressions.
    
    foreach my $i (2..$#vv) {
	$CODE .= <<ENDCODE;
(\$tmp = \$self->{STATE}->slice('$i')) .= \$$vv[$i]{name};
ENDCODE
    }
    
    # Then create the linear transformation matrix and enter into it the
    # elements necessary for each of the flows.  This matrix will typically be
    # quite sparse.  Flows which are not linear will have to be taken care of
    # in the next step.

    foreach my $flow (@{$self->{flowlist}}) {
	
	my $rate = $flow->{rate};
	
	# Eventually we will be able to do this...
	
	if ( $flow->{rate}{type} eq 'expr' ) {
	    croak "Arbitrary rate expressions are not yet allowed with PDL.";
	}
	
	# Assuming it's not an arbitrary expression, find the order of the
	# rate.  For now, we only do linear flows.
	
	if ( $self->find_order($rate) > 1 ) {
	    croak "Higher order flows are not yet allowed with PDL.";
	}
	
	# So, we know that the rate is either a constant, a variable, or the
	# product of a constant and a variable.
	
	my ($rate_coeff, $rate_var_index);
	
	if ( $rate->{type} eq 'literal' ) {
	    $rate_coeff = $rate->{value};
	    $rate_var_index = 1; # index of t_unit in state vector
	}
	
	elsif ( $rate->{type} eq 'const' ) {
	    $rate_coeff = "\$$rate->{name} * $self->{t_unit}";
	    $rate_var_index = 1; # index of t_unit in state vector
	}
	
	elsif ( $rate->{type} eq 'var' ) {
	    $rate_coeff = $self->{t_unit};
	    $rate_var_index = $rate->{index};
	}
	
	elsif ( $rate->{type} eq 'prod' ) {
	    $rate_coeff = $self->{t_unit};
	    $rate_var_index = 1; # will be overridden if a child is of type 'var'
	    foreach my $child (@{$rate->{child}}) {
		if ( $child->{type} eq 'var' ) {
		    $rate_var_index = $child->{index};
		}
		
		elsif ( $child->{type} eq 'const' ) {
		    $rate_coeff .= " * \$$child->{name}";
		}
		
		elsif ( $child->{type} eq 'literal' ) {
		    $rate_coeff .= " * $child->{value}";
		}
	    }
	}
	
	# Now that we know the coefficient and variable index, add statements
	# that will put that information into the linear transformation matrix.
	
	$CODE .= <<ENDCODE unless $flow->{source}{type} eq 'flowlit';
(\$tmp = \$self->{LINTRAN}->slice('$flow->{source}{index},$rate_var_index')) -=
     $rate_coeff;
ENDCODE
	$CODE .= <<ENDCODE unless $flow->{sink}{type} eq 'flowlit';
(\$tmp = \$self->{LINTRAN}->slice('$flow->{sink}{index},$rate_var_index')) +=
     $rate_coeff;

ENDCODE
    }
    
    if ( $self->{debug_level} > 0 ) {
	print "=========== initprog ===========\n";
	print $CODE;
	print "=========== initprog ===========\n";
    }
    
    eval("\$self->{initprog} = sub {\n$CODE\n}");
    
    if ( $@ ) {
	croak "Error in initialization program: $@";
    }
    
    # Next, compile the run step.
    
    $self->{runprog} = sub {
	my ($s) = @_;
	
	$s->{STATE} = $s->{STATE} x $s->{LINTRAN};
    };
    
    if ( $@ ) {
	croak "Error in run program: $@";
    }
    
    return 1;
}


# Create a trace function for the current model.

sub compile_traceprog {

    my $self = shift;
    
    $self->{TRACECOUNT} = 0;
    
    $self->{traceprog} = sub {
	my $tmp = $self->{TRACE}->slice(",$self->{TRACECOUNT}");
	$tmp .= $self->{STATE}->copy();
	$self->{TRACECOUNT}++;
    };
    
    $self->{trace_compiled} = 1;
}


# init_runspace ( ) - Make sure that the package used as the namespace for
# running the model is clear of everything except the necessary variables.
# This should be called once before every run, so that each run is done de novo.

sub init_trace {
    
    my ($self, $tracesize) = @_;
    my $vlen = scalar(@{$self->{vvector}});
    
    $self->{TRACE} = zeros($vlen, $tracesize);
    return 1;
}


# init_run_time ( time ) - set initial run time

sub init_run_time {
    
    my ($self, $start_time) = @_;
    my ($tmp);
    
    $start_time += 0;
    
    $self->{T} = $self->{run_start} = $start_time;
    ($tmp = $self->{STATE}->slice(0)) .= $start_time;
    
    if ( $self->{debug_level} > 0 ) {
	print "========== state vector ============\n";
	print $self->{STATE}, "\n";
	print "========== state vector ============\n";
	
	print "========== lin tran matrix ============\n";
	print $self->{LINTRAN}, "\n";
	print "========== lin tran matrix ============\n";
    }
    
    return $start_time;
}


# Increment the time by one step, and return the new time as the value of this
# function.

sub increment_run_time {
    
    my ($self) = @_;
    
    $self->{T} = $self->{STATE}->at(0,0);
}


# Find the order of the expression rooted at the given node.

sub find_order {
    
    my ($self, $node) = @_;
    
    return 0 if $node->{type} eq 'const' or $node->{type} eq 'literal';
    return 1 if $node->{type} eq 'var';
    
    if ( $node->{type} eq 'prod' ) {
	my $order = 0;
	foreach my $child (@{$node->{child}}) {
	    $order += $self->find_order($child);
	}
	return $order;
    }
    
    if ( $node->{type} eq 'sum' ) {
	my $order = 0;
	foreach my $child (@{$node->{child}}) {
	    my $neworder = $self->find_order($child);
	    $order = $neworder if $neworder > $order;
	}
	return $order;
    }
    
    else {
	die "Unknown node type: $node->{type}";
    }
}


# dump_trace ( ) - dump the trace data to the given file handle

sub dump_trace {

    my ($self, %args) = @_;
    
    my $fh = $args{file};
    print $fh $self->{TRACE};
}


sub get_values {

    my ($self, $var) = @_;
    
    if ( $var eq 'T' ) {
	return $self->{TRACE}->slice(0,)->list();
    }
    
    else {
	my $idx = $self->{stable}{$var}{index};
	return $self->{TRACE}->slice($idx,)->list();
    }
}


#sub plot {
#
#    my ($self, @vars) = @_;
#    
#    
#}

1;
