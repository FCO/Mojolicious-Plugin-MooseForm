package BlaBleBli;

use Moose;

has bla              => ( is => 'ro', isa => 'Num', required => 1, default => 0, documentation => "Documentation string for parameter 'bla' on Class " . __PACKAGE__ ) ;
has ble              => ( is => 'ro', isa => 'Bool', default => 0, documentation => "Documentation string for parameter 'ble' on Class " . __PACKAGE__ ) ;
has three_word_attr  => ( is => 'rw', isa => 'Str', documentation => "Documentation string for parameter 'three_word_attr' on Class " . __PACKAGE__ ) ;
has attr_without_doc => ( is => 'rw', isa => 'Str', required => 1, default => "Yes, it doesnt have a doc..." ) ;
has array_of_strs    => ( is => 'rw', isa => 'ArrayRef[Str]', default => "[]") ;

42
