#
# NBGC Project
# 
# Gen_cc.pm - Generate C++ code to embody a Mad model.
# 
# Author: Michael McClennen
# Copyright (c) 2010 University of Wisconsin-Madison
# 
# The variables and routines in this file handle generation of Perl code.


package Mad::Model;

use strict;
use warnings;

our (%INIT_TARGET);

$INIT_TARGET{'cc'} = \&init_gen_cc;


# Setup the model object pointed to by $self for generating C++ code.

sub init_gen_cc {

    my ($self) = @_;
    
    $self->{open_block} = \&open_block_cc;
    $self->{close_block} = \&close_block_cc;
    $self->{open_dims} = \&open_dims_cc;
    $self->{close_dims} = \&close_dims_cc;
    $self->{gen_expr_code} = \&gen_expr_cc;
    
    # etc...
}


sub open_block_cc {

}

sub close_block_cc {

}

sub open_dims_cc {

}

sub close_dims_cc {

}

sub gen_expr_cc {

}
