#
# NBGC Project
# 
# Gen_cc.pm - Generate C++ code
# 
# Author: Michael McClennen
# Copyright (c) 2011
# 
# The variables and routines in this file handle generation of C++ code.


package Mad::Model;

use strict;
use warnings;

our (%INIT_TARGET) = ();

our (%PRIMITIVE_TYPE, %BASE_TYPE, %TYPE_SIGIL);



# generate_target_code ( $target, $outfile )
# 
# Generate code to express this model, and write it to the given object file.
# Return true if this was done successfully, false otherwise.  $outfile is a
# file handle to which the code will be written, while $target specifies the
# target language.  NOTE: this routine is not re-entrant, since it modifies
# $self and various globals in target-specific ways.  It can be called
# sequentially, however, for multiple targets.

sub generate_target_code {

    my ($self, $outfile, $target) = @_;
    
    # First initialize the CODE table that will hold the various blocks of
    # generated code.
    
    $self->{CODE} = {};
    
    # Then do any set-up required for the given target language.  This
    # includes defining the routines that will be called to generate the
    # actual code.
    
    $INIT_TARGET{$target}($self);
    
    # Then generate an outer context in which to define dynamic variables.
    # Blocks within the code will each be associated with their own context in
    # turn.
    
    my $context = Mad::Context->new($self);
    $context->{target} = $target;
    
    # Now we recursively traverse the parse tree and generate the necessary
    # code for the model.  This will be stored in CODE table in the Model
    # object ($self).  If any errors occur, compilation is aborted.  The
    # $target parameter is made available to all of the routines in this
    # section through $context.
    
    $self->generate_node_code($self->{parse_tree}, 'INIT', 0, $context);
    
    # When we are done, we must close any implicit loops that remain unclosed.
    
    $self->{close_dims}($context, 0);
    
    # Abort if any errors have occurred up to now.
    
    if ( $self->{error_count} > 0 )
    {
	$self->{status} = 'COMPILE_ERROR';
	return;
    }
    
    # Next, we generate the code to carry out the flows.  The information
    # necessary to do this was gathered during the traversal of the parse
    # tree.  Again, if any errors occur, abort immediately.
    
    $self->generate_flow_code($context);
    
    if ( $self->{error_count} > 0 )
    {
	$self->{status} = 'COMPILE_ERROR';
	return;
    }
    
    # Then, we add logging code to record the values of major variables.  This
    # will be used to generate the output of the simulation.
    
    $self->generate_trace_code();
    
    if ( $self->{error_count} > 0 )
    {
	$self->{status} = 'COMPILE_ERROR';
	return;
    }
    
    # Finally, we create the main loop of the simulation.
    
    $self->generate_main_code();
    
    if ( $self->{error_count} > 0 )
    {
	$self->{status} = 'COMPILE_ERROR';
	return;
    }
    
    # Now we write each of these pieces of code to the target file.
    
    foreach my $p ( 'HEAD', @{$self->{decl_list}}, @{$self->{func_list}},
		    @{$self->{phase_list}}, 'MAIN', 'TAIL' )
    {
	print $outfile $self->{CODE}{$p};
	print $outfile "\n";
    }
    
    return 1;
}


# generate_node_code ( $node, $phase, $indent, $context )
# 
# Generate code in the target language from the parse tree rooted at the given
# node, and place it by default into the given phase of the model at the given
# indentation level.  Recursively calls itself to traverse much of the parse
# tree.  This routine is responsible for parsing top-level syntactic
# constructs such as phase blocks, across blocks and flows, and calls
# generate_expr() to handle the bottom-most nodes. 

sub generate_node_code {
    
    my ($self, $node, $phase, $indent, $context) = @_;
    
    # Return immediately if we weren't actually given a real node.
    
    return unless ref $node;
    
    my ($nt) = ref $node;			# node type
    my ($children) = $node->{children};		# child list
    
    # This still needs to be worked out for C++:
    
#     #if ( $nt eq 'USE' )
#     #{
#     #	$self->annotate('USES', 0, $node);
#     #	$self->add_lines('USES', 0, "use $node->{attr};");
#     #}
    
#     # The 'program sequence' nodes represent blocks.  PROGSEQ puts its
#     # children into the current phase, while INIT, CALC, etc. put their
#     # children specifically into the phase corresponding to their name.  In
#     # all cases, we create a new context that is chained to the existing one.
    
#     if ( $nt eq 'INIT' or $nt eq 'CALC' or $nt eq 'STEP' or $nt eq 'FINAL' or
# 	 $nt eq 'PROGSEQ' )
#     {
# 	if ( $nt ne 'PROGSEQ' ) {
# 	    $phase = $node->{attr} ne '' ? $nt . '_' . $node->{attr} : $nt;
# 	}
# 	$self->{close_dims}($context, $indent);
# 	my $nc = $context->new($self);
# 	$nc->{phase} = $phase;
# 	$self->{open_block}($nc, $indent);
# 	foreach my $n ( @$children ) {
# 	    $self->generate_node_code($n, $phase, $indent+1, $nc);
# 	}
# 	$self->{close_dims}($nc, $indent+1);
# 	$self->{close_block}($nc, $indent);
#     }
    
#     # A node of type 'STRUCT' indicates a class or structure definition.  This
#     # may include both data members and member functions.  In C++, the
#     # keywords 'struct' and 'class' are nearly equivalent, differing only in
#     # their default privacy attribute.  In Mad, these are exactly equivalent
#     # because there is no such thing as a private member.
    
#     # elsif ( $nt eq 'STRUCT' )
#     # {
#     # 	# First, enter this class/struct in the type map, so that we can
#     # 	# call the appropriate routines to read values, write values, etc.
	
#     # 	my $cname = $node->{ns} . '::' . $node->{attr};
#     # 	$self->{typemap}{$cname} = 'Mad::Gen::MadClass';
	
#     # 	# Next, we create an entry in the CODE table for this class/struct,
#     # 	# which will hold the declaration code as it is generated.  We also
#     # 	# create an entry in the LINK table for this construct, to record
#     # 	# which member functions belong to this class/struct, and an entry in
#     # 	# the HEAD table to generate header files.
	
#     # 	my $phase = "struct_$cname";
	
#     # 	$self->{CODE}{$phase} = $self->{gen_struct_head}($node, $context);
#     # 	$self->{HEAD}{$phase} = $self->{CODE}{$phase};
#     # 	$self->{LINK}{$phase} = [];
	
#     # 	# Then create a new context which links to the symbol table for this
#     # 	# class (the symbol table was already created by the parser).  This
#     # 	# context will be used in compiling member declarations, allowing the
#     # 	# use of unqualified names for other members in method code and
#     # 	# member initialization expressions.
	
#     # 	my $class_rec = $self->{STRUCT}{$node->{ns}}{$node->{attr}};
#     # 	$nc = $context->new($self, $class_rec->{sym});
#     # 	$nc->{phase} = $phase;
	
#     # 	# Then we go through the children of this node, which represent the
#     # 	# members of the class.  We first collect up the attribute nodes and
#     # 	# method nodes, since we need to process all of the attribute nodes
#     # 	# first regardless of the order in which they appear.
	
#     # 	my (@attr_nodes, @method_nodes, @init_lines, $explicit_init);
	
#     # 	foreach my $n ( @$children ) {
	    
#     # 	    # If the node type is 'DECLARE', then it represents one or more
#     # 	    # attributes.  If the node type is 'METHOD' then it represents a
#     # 	    # (you guessed it!) method.
	    
#     # 	    if ( ref $n eq 'DECLARE' )
#     # 	    {
#     # 		push @attr_nodes, $n;
#     # 	    }
#     # 	    else
#     # 	    {
#     # 		push @method_nodes, $n;
#     # 	    }
#     # 	}
	
#     # 	# We now go through the attribute nodes and add any necessary
#     # 	# initialization code to @init_lines.
	
#     # 	foreach $n (@attr_nodes)
#     # 	{
#     # 	    my $type_node = $n->{children}[-1];
#     # 	    my $type_name = $type_node->{attr};
#     # 	    my @na = $self->node_attributes($type_node);
	    
#     # 	    foreach my $nn ( @{$n->{children}} )
#     # 	    {
#     # 		next if $nn == $type_node;
#     # 		my ($type, $subtype, $fulltype) =
#     # 		    $self->build_type($type_name, ref $nn);
#     # 		my @va = $self->node_attributes($nn);
#     # 		my ($attr_expr) = $target->attr_expr($nn, $context);
#     # 		my ($init_code) = $type->init_code($context, $nn, $subtype,
#     # 						   $attr_expr, @na, @va);
#     # 		push @init_lines, $code if defined $init_code;
#     # 	    }
#     # 	}
	
#     # 	# Then we can go through the method nodes.  Any method named 'init'
#     # 	# must be modified to include the initialization code from the
#     # 	# previous step.
	
#     # 	foreach $n (@method_nodes)
#     # 	{
#     # 	    # If the method's name is 'init' then generate the method with the
#     # 	    # additional lines from @init_lines.
	    
#     # 	    if ( $n->{attr} eq 'init' )
#     # 	    {
#     # 		$explicit_init = 1;
#     # 		$self->generate_function_code($cname, $n, $context, \@init_lines);
#     # 	    }
	    
#     # 	    else
#     # 	    {
#     # 		$self->generate_function_code($cname, $n, $context);
#     # 	    }
#     # 	}
	
#     # 	# If the user didn't specify an init function but there are
#     # 	# initialization lines that need to be executed, create an automatic
#     # 	# init function.
	
#     # 	if ( !$explicit_init and @init_lines > 0 )
#     # 	{
#     # 	    $self->generate_init_function($cname, \@init_lines);
#     # 	}
#     # }
    
#     # # A 'FUNCTION' node represents a function declaration outside of any
#     # # class.  It would be a "method of the main object" if there were such a
#     # # thing.
    
#     elsif ( $nt eq 'FUNCTION' )
#     {
# #    	$self->{open_func}($context, $node);
# #	$self->{close_func}($context, $node);
#     }
    
#     # # A 'METHOD' node represents, of course, a method in a class.  Note that,
#     # # as such, it can only occur as a sub-node of a CLASS node.  We first
#     # # insert the prototype into the appropriate class record, and then
#     # # generate the function code.
    
#     # elsif ( $nt eq 'METHOD' )
#     # {
#     # 	$self->{gen_func_proto}($context, $node);
#     # 	$self->{gen_func_code}($context, $node);
#     # }
    
#     # Nodes that declare variables may generate both a declaration and an
#     # initialization.
    
#     # Variable declarations are handled by calling the _declare_code routine
#     # from the corresponding package in the Mad::Gen:: namespace to generate
#     # the necessary code.  This allows various object types to be declared in
#     # whatever way they need to be.  Initialization is handled by calling the
#     # _init_code routine.
    
# #     elsif ( $nt eq 'DECLARE' )
# #     {
# # 	my $kind = $node->{kind};
# # 	my $type_node = $child->[-1];
# # 	my $type_name = $type_node->{attr};
	
# # 	# Analyze the TYPE node, which is the last child of the DECLARE node.
# # 	# Its children specify attributes which modify all variables declared
# # 	# as children of the DECLARE node.
	
# # 	my @attrs = $self->node_attributes($type_node);
	
# # 	# and then the other children, each of which declares one variable.
# # 	# The children of each of these nodes are attributes which modify the
# # 	# individual variable.
	
# # 	foreach my $n ( @$child ) 
# # 	{
# # 	    next if $n == $type_node;
	    
# # 	    my ($var_name) = $n->{attr};
# # 	    my ($var_type, $var_subtype, $var_fulltype) = 
# # 		$self->build_type($type_name, ref $n);
# # 	    my ($var_expr, $var_dim, $var_rec);
# # 	    my (@init_perl);
	    
# # 	    # If this variable is dynamic, we need to create a new
# # 	    # variable-record for it and register it in the current context so
# # 	    # that subsequent code can refer to it.  Otherwise, we look up the
# # 	    # variable-record that already exists.
	    
# # 	    if ( $kind eq 'DYN_VAR' )
# # 	    {
# # 		$var_expr = 'my ($' . $var_name . ')';
# # 		$var_dim = $self->declare_dims($n->{children}[0]);
# # 		$var_rec = { name => $var_name, kind => 'DYN_VAR', decl => $n,
# # 			     type => $var_fulltype, dim => $var_dim };
		
# # 		$context->define($var_name, $var_rec);
# # 	    }
	    
# # 	    else
# # 	    {
# # 		$var_expr = "\$$rpk$var_name";
# # 		$var_rec = $self->lookup_static($var_name);
# # 		$var_dim = $var_rec->{dim};
		
# # 		#my ($decl_perl) = $var_type->_declare_code($context, $n, $var_subtype, 
# # 		#					   $var_expr, $var_dim);
# # 		#
# # 		#$self->add_lines('DECL', 1, $decl_perl . ";    \# $var_type");
# # 	    }
	    
# # 	    # Now declare any named dimensions that have not yet been
# # 	    # declared, and open loops for them.
	    
# # 	    my $dim_count = 0;
# # 	    my $dim_expr = '';
# # 	    my $order_expr = '';
# # 	    my (@loop_lines, @end_lines, @final_lines);
	    
# # 	    if ( ref $var_dim eq 'ARRAY' and @$var_dim > 0 )
# # 	    {
# # 		$dim_expr = '->{dim}';
		
# # 		foreach my $dim_rec ( @$var_dim )
# # 		{
# # 		    my $idx = "\$${rpk}_DIM_" . $dim_rec->{name};
# # 		    my $di = '    ' x $dim_count;
# # 		    $dim_expr .= "{$idx}";
# # 		    $order_expr .= ', ' if $order_expr ne '';
		    
# # 		    if ( $dim_rec->{select} eq 'setv' )
# # 		    {
# # 			unless ( $dim_rec->{declared} )
# # 			{
# # 			    my $dim_decl = "$idx;    \# index variable";
# # 			    $self->add_lines('DECL', 1, $dim_decl);
# # 			    $dim_rec->{declared} = 1;
# # 			}
			
# # 			my $setv_expr = "\$$rpk$dim_rec->{name}" . "->{values}";
			
# # 			$order_expr .= $setv_expr;
# # 			push @loop_lines, ($di . "foreach $idx (" . '@{' . 
# # 					   $setv_expr . '})'), ($di . '{');
# # 		    }
		    
# # 		    elsif ( $dim_rec->{select} eq 'size' )
# # 		    {
# # 			$order_expr .= $dim_rec->{size};
# # 			push @loop_lines, ($di . 
# # 			    "foreach $idx (0.." . ($dim_rec->{size} - 1) . ")"),
# # 				($di . '{');
# # 		    }
		    
# # 		    else # $dim_rec->{select} eq 'range'
# # 		    {
# # 			$order_expr .= "'$dim_rec->{start}:$dim_rec->{end}'";
# # 			push @loop_lines, ($di .
# # 			    "foreach $idx (" . $dim_rec->{start} . '..' .
# # 				$dim_rec->{end} . ')'), ($di . '{');
# # 		    }
		    
# # 		    unshift @end_lines, $di . '}';
# # 		    push @final_lines, "$idx = undef;";
# # 		    $dim_count++;
# # 		}
# # 	    }
	    
# # 	    # Now add any attributes associated with the node, and then create
# # 	    # an initialization expression.
	    
# # 	    my @nattrs = $self->node_attributes($n);
	    
# # 	    my $init_expr = $var_type->_init_code($context, $n, $var_subtype, 
# # 					$var_expr . $dim_expr, @attrs, @nattrs);
	    
# # 	    # If the dimensionality is greater than zero, enclose the
# # 	    # initialization expression in a loop and add a base
# # 	    # initialization statement beforehand.
	    
# # 	    if ( $dim_count )
# # 	    {
# # 		my $base_stmt = "$var_expr = { order => [$order_expr], dim => {} };";
# # 		$self->annotate($phase, 0, $n);
# # 		$self->add_lines($phase, $indent, $base_stmt);
# # 		$self->add_lines($phase, $indent, @loop_lines);
# # 		$self->annotate($phase, 0, $n);
# # 		$self->add_lines($phase, $indent + $dim_count, $init_expr . ';');
# # 		$self->add_lines($phase, $indent, @end_lines, @final_lines);
# # 	    }
	    
# # 	    # Otherwise, we just add the initialization statement.
	    
# # 	    else
# # 	    {
# # 		$self->annotate($phase, 0, $n);
# # 		$self->add_lines($phase, $indent, $init_expr . ';');
# # 	    }
	    
# # 	    # If this is a variable that has a value, then we'll track it.
	    
# # 	    if ( $var_type->_has_value($context) )
# # 	    {
# # 		my ($var_units) = print_units($n->{units});
# # 		my ($value_perl) = $var_type->_value_code($context, $n, 
# # 							  $var_subtype,
# # 							  $var_expr, 'value');
		
# # 		my ($trace_perl) = "\$${rpk}_VAR{'$var_name'} = \$${rpk}_VAR{'$var_expr'} = { name => '$var_name', type => '$var_fulltype', vexpr => '$value_perl', decl_file => '$n->{filename}', decl_line => '$n->{line}', kind => '$kind', units => '$var_units' }";
		
# # 		$self->add_lines('DBGI', 1, $trace_perl . ';');
# # 	    }
# # 	}
# #     }
    
# #     # Nodes representing conditionals and conditional loops can be handled
# #     # together.
    
# #     elsif ( $nt eq 'IF' || $nt eq 'UNLESS' || $nt eq 'ELSIF' || 
# # 	    $nt eq 'WHILE' || $nt eq 'UNTIL' )
# #     {
# # 	# Start by generating the conditional, plus the opening brace.
	
# # 	my $word = lc $nt;
# # 	my ($expr, $dim, $type, $units)
# # 	    = $self->generate_expr_perl($child->[0], $context, 'root');
# # 	$self->check_dims_perl($node, $context, $dim, $indent);
# # 	$self->annotate($phase, 0, $node);
# # 	$self->add_lines($phase, $indent, "$word ( $expr ) {");
# # 	my $nc = $context->new($self);
	
# # 	# Generate the code for the body, each statement indented by four
# # 	# spaces more than the enclosing block.
	
# # 	foreach my $n ( @{$node->{children}[1]{children}} ) {
# # 	    $self->generate_perl($n, $phase, $indent+1, $nc);
# # 	}
	
# # 	# Generate the closing brace, and then the 'else' or 'elsif'
# # 	# statement if any.
	
# # 	$self->close_dims_perl($nc, $indent+1);
# # 	$self->add_lines($phase, $indent, "}");
# # 	$self->generate_perl($child->[2], $phase, $indent, $context);
# #     }
    
# #     # Nodes representing an ELSE don't have a conditional, of course, so we
# #     # just need to go through the statements in the body.
    
# #     elsif ( $nt eq 'ELSE' )
# #     {
# # 	$self->add_lines($phase, $indent, "else {");
# # 	my $nc = $context->new($self);
	
# # 	foreach my $n ( @{$node->{children}[0]{children}} ) {
# # 	    $self->generate_perl($n, $phase, $indent+1, $nc);
# # 	}
	
# # 	$self->close_dims_perl($nc, $indent+1);
# # 	$self->add_lines($phase, $indent, "}");
# #     }
    
# #     # Nodes representing a FOREACH have an index variable followed by a
# #     # parenthesized list.
    
# #     elsif ( $nt eq 'FOREACH' )
# #     {
# # 	my $index_node = $node->{children}[0];
# # 	my $list_node = $node->{children}[1];
# # 	my $body_node = $node->{children}[2];
	
# # 	my ($index_expr, $index_type, $index_dim, $index_units) =
# # 	    $self->generate_expr_perl($index_node, $context, 'root');
# # 	my ($list_expr, $list_type, $list_dim, $list_units) =
# # 	    $self->generate_expr_perl($list_node, $context, 'root');
	
# # 	$indent = $self->check_dims_perl($node, $context, $list_dim, $indent);
# # 	$self->annotate($phase, 0, $node);
# # 	$self->add_lines($phase, $indent, "foreach my \$MADTMP0 ($list_expr) {");
# # 	$self->add_lines($phase, $indent+1, "$index_expr = \$MADTMP0;");
# # 	my $nc = $context->new($self);
	
# # 	# Generate the code for the body, each statement indented by four
# # 	# spaces more than the enclosing block.  Then generate the closing brace.
	
# # 	foreach my $n ( @{$body_node->{children}} ) {
# # 	    $self->generate_perl($n, $phase, $indent+1, $nc);
# # 	}
	
# # 	$self->close_dims_perl($nc, $indent+1);
# # 	$self->add_lines($phase, $indent, "}");
# #     }
    
# #     # ACROSS nodes represent implicit loops over one or more dimensions.
    
# #     elsif ( $nt eq 'ACROSS' )
# #     {
# # 	my $dimlist_node = $node->{children}[0];
# # 	my $dimlist = $dimlist_node->{children};
# # 	my $dim_count = 0;
# # 	my (@loop_lines, @end_lines, @final_lines);
	
# # 	# Open a new context for the contents of the ACROSS block
	
# # 	my $nc = $context->new($self);
	
# # 	# Open each loop
	
# # 	foreach my $dim_node (@$dimlist)
# # 	{
# # 	    my $dim_rec;
	    
# # 	    if ( ref $dim_node eq 'SETV' )
# # 	    {
# # 		$dim_rec = $self->lookup_dimension($dim_node->{attr});
# # 	    }
	    
# # 	    else
# # 	    {
# # 		$self->syntax_error($node, "dimension in an 'across' must be a set");
# # 		return;
# # 	    }
	    
# # 	    my $rpkg = $self->{runpkg};
# # 	    my $di = '    ' x $dim_count;
# # 	    my $idx = '$' . $rpkg . '_DIM_' . $dim_rec->{name};
# # 	    my $set = '@{$' . $rpkg . $dim_rec->{name} . '->{values}}';
# # 	    my $stmt = $di . "foreach $idx ( $set )";
	    
# # 	    push @loop_lines, $stmt, ($di . '{');
# # 	    push @end_lines, ($di . '}');
# # 	    push @final_lines, "$idx = undef;";
# # 	    $dim_count++;
	    
# # 	    # add the dimension to the context's dimension list
	    
# # 	    push @{$nc->{dimlist}}, $dim_rec;
# # 	}
	
# # 	# Now emit all of the starting lines.
	
# # 	$self->annotate($phase, 0, $node);
# # 	$self->add_lines($phase, $indent, @loop_lines);
	
# # 	# Then add each of the contained lines
	
# # 	foreach my $n ( @{$node->{children}} )
# # 	{
# # 	    next if $n == $dimlist_node;
# # 	    $self->generate_perl($n, $phase, $indent + $dim_count, $nc);
# # 	}
	
# # 	$self->close_dims_perl($nc, $indent + $dim_count);

# # 	# Then close all of the open loops and undefine all index variables.
	
# # 	$self->add_lines($phase, $indent, @end_lines, @final_lines);
# #     }
    
# #     # Nodes representing flows are handled by the flow function.
    
# #     elsif ( $nt eq 'FLOW' or $nt eq 'FLOW_0' or $nt eq 'FLOW_1' ) {
	
# # 	$self->annotate($phase, 0, $node);
# # 	$self->generate_rate_expr_perl($node, $context);
# #     }
    
# #     # Any other node type is translated to one or more Perl statements.  If no
# #     # phase is specified, INIT is assumed by default.
    
# #     else {
# # 	my ($stmt, $type, $dim, $units) = 
# # 	    $self->generate_expr_perl($node, $context, 'root');
# # 	$self->check_dims_perl($node, $context, $dim, $indent);
# # 	$self->annotate($phase, 0, $node);
# # 	$self->add_lines($phase, $indent+$context->{dim_indent}, $stmt . ';');
# #     }
# # }

# 1;
