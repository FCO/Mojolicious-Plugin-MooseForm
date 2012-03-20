use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Mojolicious::Plugin::MooseForm',
    AUTHOR              => q{Fernando Correa de Oliveira <fco@cpan.org>},
    VERSION_FROM        => 'lib/Mojolicious/Plugin/MooseForm.pm',
    ABSTRACT_FROM       => 'lib/Mojolicious/Plugin/MooseForm.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More'  => 0,
        'Mojolicious' => 2.61,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Mojolicious-Plugin-MooseForm-*' },
);
