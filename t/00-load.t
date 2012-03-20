#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Mojolicious::Plugin::MooseForm' ) || print "Bail out!\n";
}

diag( "Testing Mojolicious::Plugin::MooseForm $Mojolicious::Plugin::MooseForm::VERSION, Perl $], $^X" );
