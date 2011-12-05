#
# Mad Project
# 
# RunningAverage class
# 
# Author: Michael McClennen
# Copyright (c) 2010 University of Wisconsin-Madison
# 
# 
# Objects of this class are used to keep a running average of quantities
# generated in the model.
# 

package Mad::Gen::RunningAverage;
@ISA = ("Mad::Gen::ExtClass");

my $attr_hash = { length => { type => 'Mad::Gen::int',
			      default => 10,
			      can_init => 1,
			      can_get => 1,
			      can_set => 0},
		  value => { type => 'Mad::Gen::num', 
			     units => '@',
			     default => 0.0,
			     can_init => 0, 
			     can_get => 1, 
			     can_set => 0} };

my $init_list = ['length'];

sub _attrs {
    return $attr_hash, $init_list;
}

my $met_hash = { new => { type => 'Mad::Gen::RunningAverage',
			  sig => ['Mad::Gen::int'] },
		 add => { type => 'void',
			  sig => ['Mad::Gen::num', '@'] } };
			  
sub _methods {
    return $met_hash;
}


sub new {
    my ($class, $length) = @_;
    
    unless ( $length > 0 ) {
	Mad::Run::exec_error("$class: you must specify a length > 0");
    }
    
    my $newobj = $class->SUPER::new($length);
    
    $newobj->{value} = undef;
    $newobj->{run} = [];
    return $newobj;
}


sub add {
    my ($self, $new_value) = @_;
    
    push @{$self->{run}}, $new_value;
    while ( @{$self->{run}} > $self->{length} ) {
	shift @{$self->{run}};
    }
    
    my $sum = 0;
    my $count = 0;
    
    foreach $v ( @{$self->{run}} ) {
	$sum += $v;
	$count += 1;
    }
    
    $self->{value} = $sum / $count;
    return $self->{value};
}


1;
