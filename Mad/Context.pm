#
# NBGC Project
# 
# Class Mad::Context - context in which to evaluate symbols
# 
# Author: Michael McClennen
# Copyright (c) 2010 University of Wisconsin-Madison
# 


package Mad::Symtab;

use strict;
use warnings;
use Carp;


# new ( )
# 
# Create a new symbol table

sub new {

    my ($class_or_obj) = @_;
    
    my $self = {};
    return bless $self, $class_or_obj;
}


# define ( $key, $value )
# 
# Define a new entry

sub define {

    my ($self, $key, $value) = @_;
    
    if ( defined $value ) {
	$self->{$key} = $value;
	return 1;
    }
    
    else {
	return undef;
    }
}


# remove ( $key )
# 
# Remove an entry from the symbol table

sub remove {

    my ($self, $key) = @_;

    delete $self->{sym}{$key};
}


# has_sym ( $key )
# 
# Return true if the given name is defined in this table.

sub has_sym {

    my ($self, $key) = @_;
    
    return 1 if exists $self->{$key};
    return undef; # otherwise
}


package Mad::Context;

use strict;
use warnings;
use Carp;


# new ( $model, $symtab )
# 
# Create a new context object, which will look up symbols in the given symbol
# table (implemented as a regular hash).  This constructor can be called
# either on the class or on an existing Context.  If the latter, then a
# reference to the latter is included in the new context so that lookups can
# be chained.

sub new {
    
    my ($obj_or_class, $model, $symtab) = @_;
    
    # Create a new symbol table unless one was given.
    
    $symtab = Mad::Symtab->new() unless $symtab;
    
    # Create a new Context object to point to that symbol table.
    
    my $self = { sym => $symtab };
    
    # If this method was called on an existing object, bless the new one and
    # link it to the old one. 
    
    if ( ref $obj_or_class ) {
	bless $self, ref $obj_or_class;
	$self->{next} = $obj_or_class;
	$self->{model} = $model;
	$self->{target} = $obj_or_class->{target};
	$self->{phase} = $obj_or_class->{phase};
	$self->{dimlist} = [];
	my @list;
	$self->{dimlist_inherited} = \@list;
	if ( exists $obj_or_class->{dimlist} )
	{
	    push @list, @{$obj_or_class->{dimlist}}, 
		@{$obj_or_class->{dimlist_inherited}};
	}
	$self->{dim_indent} = $obj_or_class->{dim_indent};
    }
    
    # Otherwise, if it was called on the class, just create a new object.
    
    else {
	bless $self, $obj_or_class;
	$self->{model} = $model;
	$self->{dimlist} = [];
	$self->{dimlist_inherited} = [];
	$self->{dim_indent} = 0;
	$self->{phase} = 'DEFAULT';
    }
    
    # Return the new context.
    
    return $self;
}


# define ( $key, $value )
# 
# Add an entry to the current context, if $value is defined.

sub define {
    
    my ($self, $key, $value) = @_;
    
    $self->{sym}->define($key, $value);
}


# remove ( $key )
# 
# Remove an entry from the current context.

sub remove { 
    
    my ($self, $key) = @_;
    
    $self->{sym}->remove($key);
}


# has_sym ( $name )
# 
# Return true if $name is defined in the given symbol table, false
# otherwise. In the first case, the value returned is a string indicating the
# variable's kind (i.e. CONST_VAR, CALC_VAR, FUNCTION, etc.)

sub has_sym {
    
    my ($self, $name) = @_;
    
    if ( exists $self->{sym}{$name} and ref $self->{sym}{$name} eq 'HASH' ) {
	return $self->{sym}{$name}{kind};
    }
    
    else {
	return undef;
    }
}


# lookup ( $key )
# 
# Look up an entry in the current context and return the value.  If the entry
# is not found, recursively carry out the look up in the next linked
# context. If the entry cannot be found in any of the linked contexts, the
# undefined value is returned.

sub lookup {
    
    my ($self, $key, $namespace) = @_;
    
    if ( exists $self->{sym}{$key} ) {
	return $self->{sym}{$key};
    }
    elsif ( ref $self->{next} eq 'Mad::Context' ) {
	$namespace ||= $self->{namespace};
	return $self->{next}->lookup($key, $namespace);
    }
    elsif ( ref $self->{model} eq 'Mad::Model' ) {
	return $self->{model}->lookup_static($key, $namespace);
    }
    else {
	return undef;
    }
}


# syntax_error ( )
# 
# This is a convenience routine, to simplify the process of emitting error
# messages during code generation.

sub syntax_error {
    
    my ($self, $node, $msg) = @_;
    
    $self->{model}->syntax_error($node, $msg);
}


# evaluate ( )
# 
# This is also a convenience routine, to simplify the process of evaluating
# expressions during code generation.

sub evaluate {
    
    my ($self, $node, $op) = @_;
    
    my $model = $self->{model};
    my $target = $self->{target};
    return $model->{expr_fun}{$target}($model, $node, $self, $op);
}


# check_types ( )
# 
# A convenience routine, which calls check_types_assign().

sub check_types {

    my $self = shift @_;
    
    my $model = $self->{model};
    return $model->check_types_assign(@_);
}


# generate_init_expr ( )
# 
# A convenience routine, which calls generate_init_expr().

sub generate_init_expr {
    
    my $self = shift @_;
    
    my $model = $self->{model};
    return $model->generate_init_expr_perl(@_);
}


# check_units ( )
# 
# A convenience routine, which calls check_units_assign().

sub check_units {

    my $self = shift @_;
    
    my $model = $self->{model};
    return $model->check_units_assign(@_);
}


# transform_type ( )
# 
# A convenience routine, which calls the type-transformation function for the
# appropriate target language.

sub transform_type {
    
    my $self = shift @_;
    
    my $model = $self->{model};
    my $target = $self->{target};
    return $model->{trans_fun}{$target}($model, @_);
}


# dimensionalize ( )
# 
# A convenience routine, which calls the dimensionalization function for the
# appropriate target language.

sub dimensionalize {

    my $self = shift @_;
    
    my $model = $self->{model};
    my $target = $self->{target};
    return $model->{dim_fun}{$target}($model, @_);
}


# model ( )
# 
# Return the model associated with the given context.

sub model {
    
    my ($self) = @_;
    
    return $self->{model};
}


# runpkg ( )
# 
# Return the 

1;
