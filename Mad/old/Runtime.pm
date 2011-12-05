#
# NBGC Project
# 
# Class Mad::Runtime - classes and definitions needed for Mad code that has
#                      been compiled to Perl.
# 
# Author: Michael McClennen
# Copyright (c) 2010 University of Wisconsin-Madison
# 



package Mad::Set;

use strict;
use warnings;
use Carp;


sub new {

    my ($class, @initial) = @_;
    
    # Create and bless a net Set object.
    
    my $self = bless "Mad::Set", { elements => {}, order => [] };
    
    # Now initialize it.
    
    foreach my $n ( @initial )
    {
	$self->{elements}{$n} = 1;
	push @{$self->{order}}, $n;
    }
    
    return $self;
}



    
    
