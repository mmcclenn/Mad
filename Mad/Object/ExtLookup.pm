#
# Mad Project
# 
# ExtLookup class
# 
# Author: Michael McClennen
# Copyright (c) 2010 University of Wisconsin-Madison
# 
# 
# Objects of this class are used to lookup values in external files.
# 

package Mad::Gen::ExtLookup;
@ISA = ("Mad::Gen::ExtClass");

my $attr_hash = { filename => { type => 'Mad::Gen::string',
				default => '*',
				can_init => 1,
				can_get => 1,
				can_set => 0 },
		  format => { type => 'Mad::Gen::string', 
			      values => ['tab-text', 'comma-text', 'ws-text'],
			      default => 'tab-text',
			      can_init => 1, 
			      can_get => 1, 
			      can_set => 0 },
		  index => { type => 'Mad::Gen::string',
			     default => '1-2',
			     can_init => 1,
			     can_get => 1,
			     can_set => 0 },
		  head_lines => { type => 'Mad::Gen::int',
				 default => 1,
				 can_init => 1,
				 can_get => 1,
				 can_set => 0 },
		  value_col => { type => 'Mad::Gen::int',
			         default => 0,
				 can_init => 1,
				 can_get => 1,
				 can_set => 0 },
		};

my $init_list = ['filename', 'format', 'index', 'head_lines', 'value_col'];

sub _attrs {
    return ($attr_hash, $init_list);
}

my $met_hash = { new => { type => 'Mad::Gen::ExtLookup',
			  sig => ['Mad::Gen::string', undef,
				  'Mad::Gen::string', undef,
				  'Mad::Gen::string', undef,
				  'Mad::Gen::int', undef,
				  'Mad::Gen::int', undef] },
		 lookup_row => { type => 'Mad::Gen::int',
				 sig => ['Mad::Gen::string', undef,
					 'Mad::Gen::string', undef] },
		 get_value => { type => 'Mad::Gen::string', 
				sig => ['Mad::Gen::int', undef,
					'Mad::Gen::int', undef] },
		 lookup => { type => 'Mad::Gen::string',
			     sig => ['Mad::Gen::string', '@'] },
	         lookup_exact => { type => 'Mad::Gen::string',
				   sig => ['Mad::Gen::string', undef,
				           'Mad::Gen::int', undef,
				           'Mad::Gen::string', undef] } };
			  
sub _methods {
    return $met_hash;
}


sub new {
    my ($class, $filename, $format, $index_col, $head_lines, $value_col) = @_;
    
    my $newobj = $class->SUPER::new($filename, $format, $lookup_col, $value_col);
    
    my $lc = 0 + $index_col;
    my $vc = 0 + $value_col;
    
    unless ( $lc > 0 ) {
	Mad::Run::exec_error("$class: index column must be a positive integer");
    }
    
    unless ( $vc > 0 ) {
	Mad::Run::exec_error("$class: value column must be a positive integer");
    }
    
    unless ( $lc != $vc ) {
	Mad::Run::exec_error("$class: index column and value column must be \
distinct");
    }
    
    my ($ifh, $line, @items);
    $newobj->{lookup_str} = {};
    $newobj->{lookup_num} = {};
    $newobj->{sequence} = [];
    
    unless ( open $ifh, "<", $filename ) {
	Mad::Run::exec_error("$class: cannot open file '$filename': $!");
    }
    
    while ( $line = <$ifh> ) {
	
	chomp $line;
	
	if ( $format eq 'tab-text' ) {
	    @items = split /\t/, $line;
	} else {
	    @items = split /,\s*/, $line;
	}
	
	$newobj->{lookup_str}{$items[$lc]} = $items[$vc];
	if ( $items[$lc] =~ /^\s*-?(\d+|\d+.\d*|\d*.\d+)(?:[eE]-?\d+)?\s*$/ ) {
	    $newobj->{lookup_num}{0.0+$items[$lc]} = $items[$vc];
	    push @{$newobj->{sequence}}, $items[$lc];
	}
    }
    
    close $ifh;
    
    delete $newobj->{lookup_num} unless @{$newobj->{sequence}} > 0;
    
    return $newobj;
}


sub lookup {

}


sub lookup_row {

}


sub get_value {

}

# Look up the value of $param and return the result as a number.  If the value
# is not found in the lookup table, return $badvalue instead.

sub lookup_exact {
    my ($self, $param, $column, $badvalue) = @_;
    
    # First check to see if the parameter is a number
    # (WE NEED TYPE CHECING $$$$)
    
    if ( $param =~ /^\s*-?(\d+|\d+.\d*|\d*.\d+)(?:[eE]-?\d+)?\s*$/ and
	 exists $self->{lookup_num} ) {
	if ( exists $self->{lookup_num}{0.0+$param}[$column-1] ) {
	    return $self->{lookup_num}{0.0+$param}[$column-1];
	}
	else {
	    return $badvalue;
	}
    }
    
    # If not, look up the parameter as a string.
    
    else {
	if ( exists $self->{lookup_str}{$param}[$column-1] ) {
	    return $self->{lookup_str}{$param}[$column-1];
	}
	else {
	    return $badvalue;
	}
    }
};


# The same as lookup_exact, but return the result as a string instead of a
# number.  This is a useless distinction in Perl, but very important in C++.

sub lookup_exact_str {
    goto lookup_exact;
}


# We need sequential lookup routines also.

1;
