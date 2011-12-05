#
# NBGC Project
# 
# Simulator::Perl - default subclass of Simulator, that compiles to pure Perl.  This can
# be used when PDL is not available.
# 
# Author: Michael McClennen
# Copyright (c) 2010 University of Wisconsin-Madison

package NBGC::Simulator::Perl;
our (@ISA) = 'NBGC::Simulator';

use strict;
use warnings;
use Carp;

# Compile the model that is currently loaded into the given Simulator object
# using the PERL method -- the initialization and each step of the model
# become pure Perl functions.  Variable values are all kept in the package
# NBGC_Run_$id where $id is a unique identifier assigned to this Simulator object.

sub compile_runprog {

    my $self = shift;
    
    # First, compile the initialization step.
    
    my $CODE = "package $self->{runspace};\nno strict 'vars';\n\n";
    
    foreach my $init (@{$self->{initlist}}) {
	my ($name, $expr) = ($init->{var}, $init->{expr});
	
	$CODE .= "\$$name = $expr;\n";
    }
    
    eval("\$self->{initprog} = sub {\n$CODE\n}");
    
    if ( $@ ) {
	croak "Error in initialization program: $@";
    }
    
    # Next, compile the run step.
    
    $CODE = "package $self->{runspace};\nno strict 'vars';\n\n";
    
    foreach my $flow (@{$self->{flowlist}}) {
	my $source = $flow->{source};
	my $sink = $flow->{sink};
	if ( defined $flow->{rate_expr} ) {
	    if ( $source eq '_' ) {
		$CODE .= "\$$sink += $flow->{rate_expr};\n";
	    }
	    elsif ( $sink eq '_' ) {
		$CODE .= "\$$source -= $flow->{rate_expr};\n";
	    }
	    else {
		$CODE .= "{\nmy \$val = $flow->{rate_expr};\n";
		$CODE .= "\$$source -= \$val; \$$sink += \$val;\n}\n";
	    }
	}
	
	elsif ( $flow->{rate2} eq '1' ) {
	    $CODE .= "\$$source -= \$$flow->{rate1};\n" if $source ne '_';
	    $CODE .= "\$$sink += \$$flow->{rate1};\n" if $sink ne '_';
	}
	
	else {
	    $CODE .= "\$$source -= \$$flow->{rate1} * \$$flow->{rate2}; " if $source ne '_';
	    $CODE .= "\$$sink += \$$flow->{rate1} * \$$flow->{rate2}; " if $sink ne '_';
	    $CODE .= "\n";
	}
    }
    
    eval("\$self->{runprog} = sub {\n$CODE\n}");
    
    if ( $@ ) {
	croak "Error in run program: $@";
    }
    
    $self->{compiled} = 'PurePerl';
}


# Create a trace function for the current model.

sub compile_traceprog {

    my $self = shift;
    
    my $CODE = "package $self->{runspace};\nno strict 'vars';\n\n";
    $CODE .= "push \@{\$_TRACE{'T'}}, \$T;\n";
    
    foreach my $expr (@{$self->{tracelist}}) {
	if ( $expr =~ /^\w/ ) { $expr = '$' . $expr; }
	$CODE .= "push \@{\$_TRACE{'$expr'}}, \$T;\n";
	$CODE .= "push \@{\$_TRACE{'$expr'}}, $expr;\n";
    }
    
    eval("\$self->{traceprog} = sub {\n$CODE\n}");
    
    if ( $@ ) {
	croak "Error in trace program: $@";
    }
    
    $self->{trace_compiled} = 1;
}


# init_runspace ( ) - Make sure that the package used as the namespace for
# running the model is clear of everything except the necessary variables.
# This should be called once before every run, so that each run is done de novo.

sub init_runspace {

    my $self = shift;
    my $pkgname = $self->{runspace} . '::';
    
    no strict 'refs';
    my @vars = keys %$pkgname;
    
    foreach my $var (@vars) {
	undef $$pkgname{$var};
    }
    
    my $CODE = "package $pkgname; no strict 'vars';\n\n";
    $CODE .= "\$T = 0; *t = \\\$T; \$_TRACE{'T'} = [];\n";
    
    foreach my $expr (@{$self->{tracelist}}) {
	if ( $expr =~ /^\w/ ) { $expr = '$' . $expr; }
	$CODE .= "\$_TRACE{'$expr'} = [];\n";
    }
    
    eval $CODE;
    
    if ( $@ ) {
	croak "Error in runspace init: $@";
    }
    
    return 1;
}


# trace_vars ( ) - return a list of variables being traced

sub trace_vars { 

    my $self = shift;
    
    return @{$self->{tracelist}};
}

# dump_trace ( ) - dump the trace data to the given file handle

sub dump_trace {

    my ($self, %args) = @_;
    
    my $vars = $args{"vars"} || "";
    my (@vars) = split(/\s*,\s*/, $vars);
    
    unless (@vars) {
	@vars = @{$self->{tracelist}};
    }
    
    my $fh = $args{file};
    
    my $dataref;
    eval "\$dataref = \\\%$self->{runspace}::_TRACE";
    my $datacount = scalar @{$dataref->{T}};
    
    foreach my $i (0..$datacount-1) {
	print $fh $dataref->{T}[$i], "\t";
	foreach my $var (@vars) {
	    print $fh $dataref->{$var}[2*$i+1], "\t";
	}
	print $fh "\n";
    }
}


# get_values ( variable ) - returns a list of the trace values of the
# given variable.  T returns time.

sub get_values {
    
    my ($self, $expr) = @_;
    
    my $dataref;
    eval "\$dataref = \\\%$self->{runspace}::_TRACE";
    my $datacount = scalar @{$dataref->{T}};
    
    if ( $expr eq 'T' ) {
	return @{$dataref->{$expr}};
    }
    
    else {
	my @vals;
	foreach my $i (0..$datacount-1) {
	    push @vals, $dataref->{$expr}[2*$i+1];
	}
	return @vals;
   }
}



1;
