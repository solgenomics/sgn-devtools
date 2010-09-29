#!/usr/bin/env perl

eval 'exec /usr/bin/perl -w -S $0 ${1+"$@"}'
    if 0; # not running under some shell

use strict;
use warnings;

use English;
use Carp;
use FindBin;

use Getopt::Std;
use Pod::Usage;

#use Data::Dumper;

my %opt;
getopts('',\%opt) or pod2usage(1);











__END__

=head1 NAME

perlscript.pl - script to do something

=head1 SYNOPSIS

  perlscript.pl [options] args

  Options:

    none yet

=head1 MAINTAINER

your name here

=head1 AUTHOR

Your Name, E<lt>you@cornell.eduE<gt>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
