#!/usr/bin/env perl

eval 'exec /usr/bin/perl -w -S $0 ${1+"$@"}'
    if 0; # not running under some shell

use strict;
use warnings;

use English;
use Carp;
use FindBin;

use Path::Class;

use Getopt::Std;
use Pod::Usage;

use File::Copy;
use File::Find;

#use Data::Dumper;

our %opt;
getopts('Mc',\%opt) or pod2usage(1);

my $accept_pat = qr/.modulebuildrc$/;

my ($from_path, $to_path) = map dir($_), @ARGV;
for my $d ($from_path, $to_path) {
    $d = dir( $ENV{PWD}, $d ) unless $d->is_absolute;
}

print "relocating $from_path -> $to_path\n";

if( $opt{c} ) {
    system( cp => -ra => $from_path => $to_path )
        and die "failed copying $from_path -> $to_path\n";
}
elsif( ! $opt{M} ) {
    system( mv => $from_path => $to_path )
        and die "failed moving $from_path -> $to_path\n";
}

find(
     sub {
         my $file = $_;
         return unless $File::Find::name =~ $accept_pat;

         inplace( $file =>
                  sub { $_ = shift;
                        s/$from_path/$to_path/g;
                        $_
                    }
                );
     },
     $to_path,
    );

sub inplace {
    my ($file, $sub) = @_;
    print "altering $file\n";
    my $slurp =
        do {
            open my $f, $file
                or die "$! reading $_\n";
            local $/;
            scalar <$f>
        };

    $slurp = $sub->($slurp);
    #warn "would write:\n$slurp";
    open my $f, '>', $file
        or die "$! writing $File::Find::name\n";
    print $f $slurp;
}

__END__

=head1 NAME

relocate_local_lib.sh - script to do something

=head1 SYNOPSIS

  relocate_local_lib.sh [options] from_path to_path

  Options:

    -M lib has already been moved, do not try to move it

    -c copy the local lib instead of moving it

=head1 MAINTAINER

Robert Buels

=head1 AUTHOR

Robert Buels, E<lt>rmb32@cornell.eduE<gt>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
