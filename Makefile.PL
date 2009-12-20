
use strict;
use warnings;



use ExtUtils::MakeMaker;

WriteMakefile(
  DISTNAME  => 'Plack-App-Apache-ActionWrapper',
  NAME      => 'Plack::App::Apache::ActionWrapper',
  AUTHOR    => "Robin\ Smidsr\�\�d\ \<robin\@smidsrod\.no\>",
  ABSTRACT  => "Wrapper\ for\ Apache2\ Action\ directive\ for\ running\ PSGI\ apps\ on\ shared\ hosting\ with\ FastCGI",
  VERSION   => '0.02',
  EXE_FILES => [ qw() ],
  (eval { ExtUtils::MakeMaker->VERSION(6.31) } ? (LICENSE => 'perl') : ()),
  PREREQ_PM    => {
    "Test::More" => '0',
    "base" => '0',
    "Plack" => '0.9021',
  },
  test => {TESTS => 't/*.t'}
);
