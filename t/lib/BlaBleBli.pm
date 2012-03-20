package BlaBleBli;

use Moose;

has bla => ( is => 'ro', isa => 'Num', required => 1, default => 0, documentation => "Documentation string for parameter 'bla' on Class " . __PACKAGE__ ) ;
has ble => ( is => 'ro', isa => 'Bool', default => 0, documentation => "Documentation string for parameter 'ble' on Class " . __PACKAGE__ ) ;

42
