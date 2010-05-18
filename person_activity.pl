#!/usr/bin/perl

eval 'exec /usr/bin/perl -w -S $0 ${1+"$@"}'
    if 0; # not running under some shell

use strict;
use warnings;

use English;
use Carp;
use FindBin;

use Getopt::Std;
use Pod::Usage;

use List::MoreUtils qw/ uniq /;

#use Data::Dumper;

our %opt;
getopts('',\%opt) or pod2usage(1);

my @servers = sort uniq map "$_.sgn.cornell.edu",
  qw(
     rubisco
     pipelines
     db
     tomatine
     sgn-vm
     solanine
     eggplant
    );

for my $server (@servers) {
  if( open my $w, "ssh $server w |" ) {
    my $uptime = scalar <$w>;
    my $header = scalar <$w>;

    my @recs = map {
      my ($user, $tty, $from, $logintime, $idle, $jcpu, $pcpu, $what ) = split;
      unless( $idle =~ /days/ ) {
	chomp $what;
	$_
      } else {
	()
      }
    } <$w>;

    next unless @recs;
    print "==========  $server ==========\n";
    print $uptime,$header,@recs;

  } else {
    warn "could not connect to $server\n";
  }
}


__END__

=head1 NAME

person_activity.pl - ssh to a bunch of sgn servers and see what everybody is doing

=head1 SYNOPSIS

  person_activity.pl

  Options:

    none yet

=head1 MAINTAINER

Robert Buels

=head1 AUTHOR(S)

Robert Buels, E<lt>rmb32@cornell.eduE<gt>

=head1 COPYRIGHT & LICENSE

Copyright 2009 The Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
