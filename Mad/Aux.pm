#
# This file goes along with Parser.pm.  It completes the package Mad::Parser,
# keeping the latter file from being too large.
# 

package Mad::Parser;
use strict;

use Mad::Model;


# declare_func ( $node )
# 
# Declare a method (i.e. one declared outside of a class declaration) using
# information from the parse subtree based at $node.  Also used for functions.

sub declare_func {
    my ($self, $node) = @_;
    
    my ($name) = $node->{attr};
    my ($prefix) = $self->{cf}{package};
    my ($class);
    
    if ($prefix eq 'main')
    {
	$prefix = '';
    }
    
    else
    {
	$prefix .= '::';
    }
    
    # If $name has a '::' in it, then it may be a method for a class/struct.  The
    # first (.*) is greedy by default, which is what we want.  If so, we need
    # to check that it corresponds with the declaration in the class/struct.
    
    if ( $name =~ /(.*)::(.*)/ )
    {
	$prefix .= $1;
	$name = $2;
	
	# If the prefix represents a class, we need to check against the class
	# declaration.
	
	if ( $self->{model}->has_class($class) )
	{
	    return $self->{model}->check_member_fun($node, $prefix, $name);
	}
    }
    
    # Otherwise, the prefix (if any) represents a package.
    
    return $self->{model}->declare_function($node, $prefix, $name);
}


# new_dimension ( @dimensions )
# 
# Create a new dimension-list object, adding the ones given by the arguments
# to the dimension-list in the current frame. 

sub new_dimension {

    my $self = shift @_;
    my $olddim = $self->{frame}[0]{dimension};
    
    my @dimension = @{$olddim} if ref $olddim eq 'ARRAY';
    
    foreach my $dimspec (@_) {
	if ( ref $dimspec eq 'SETV' ) {
	    push @dimension, ['SETV', $dimspec->{attr}];
	}
	elsif ( ref $dimspec eq 'ARRAYV' ) {
	    push @dimension, ['ARRAYV', $dimspec->{attr}];
	}
    }

    return \@dimension;
}


# markup_var_node ( $node, $kind )
# 
# Mark up a node representing a variable reference or declaration.  The
# parameter $kind marks whether the variable is constant (CONST_VAR), dynamic
# (DYN_VAR) or just a regular variable (CALC_VAR).

sub markup_var_node {

    my ($self, $node, $kind) = @_;
    
    my $name = $node->{attr};
    
    # If this is a dynamic variable, its name gets stored in the current
    # frame, and the node is marked so that dynamic resolution will be used
    # for subsequent references in the same context.  In this case, $pkg is
    # ignored.
    
    if ( $kind eq 'DYN_VAR' ) {
	$self->{cf}{dynamic}{$name} = 1;
	$node->{kind} = 'DYN_VAR';
	$node->{dyn_first} = 1;
	$name =~ /::/ && 
	    $self->syntax_error("dynamic variable names must not include '::'.");
    }
    
    # Otherwise, we check to see if a dynamic variable with this name was
    # already declared in the current frame.  If so, mark the current node
    # as dynamic and we're done.
    
    elsif ( $self->{cf}{dynamic}{$name} ) {
	$node->{kind} = 'DYN_VAR';
    }
    
    # Otherwise, this is a global variable.  So we need determine the its
    # package.  Was that specified explicitly?
    
    elsif ( $name !~ /::/ && $self->{cf}{package} ne '' ) {
	$node->{attr} = $self->{cf}{package} . '::' . $node->{attr};
	$node->{kind} = $kind;
    }
    
    # If an explicit package was given, we don't need to do anything
    # except set the "kind" attribute.
    
    else {
	$node->{kind} = $kind;
    }
    
    return $node;
}


# dimension_var_node ( $node )
# 
# Add some additional markup to a variable node if the current context has a
# nonzero dimension.

sub dimension_var_node {
    
    my ($self, $node) = @_;
    
    $node->{im_dim} = $self->{cf}{dimcount};
}


# Functions for reporting results
# -------------------------------

our ($STRING_OFFSET) = "  ";

sub printout {

    my ($self, $node, $indent) = @_;
    
    if ( $indent > 9 ) {
	print "$indent> ";
	print $STRING_OFFSET x ($indent-2) . ref($node);
    }
    elsif ( $indent > 4 ) {
	print "$indent > ";
	print $STRING_OFFSET x ($indent-2) . ref($node);
    }
    else {
	print $STRING_OFFSET x $indent . ref($node);
    }
    
    eval {
	if ( $node->{attr} ne '' ) {
	    print ": $node->{attr}";
	}
	
	if ( $node->{kind} ne '' ) {
	    print " (" . $node->{kind} . ")";
	}
	
	if ( $node->{ref} )
	{
	    print " [REF]";
	}
	
	if ( ref $node->{units} eq 'Units' ) {
	    print " <";
	    print Mad::Model::print_units($node->{units});
	    # my $punc = 0;
	    # foreach my $u ( keys %{$node->{units}} ) {
	    # 	print ',' if $punc; $punc = 1;
	    # 	if ( $u eq '/' or $u eq '*' or $node->{units}{$u} == 1 ) {
	    # 	    print $u;
	    # 	} else {
	    # 	    print $u . $node->{units}{$u};
	    # 	}
	    # }
	    print ">";
	}
	
	print "\n";
	
	foreach my $child ( @{$node->{children}} ) {
	    $self->printout($child, $indent+1);
	}
    };
    
    if ( $@ ) {
	$DB::single = 1;
	print "*ERROR*\n";
    }
    
    #return $result;
}

1;
