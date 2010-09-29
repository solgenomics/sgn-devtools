#!/usr/bin/env perl
use strict;
use warnings;
my @filelist = split /\n/, `editfind @ARGV`;

if ( $ENV{EDITOR} =~ m!/vim! || !fork ) {
    exec $ENV{EDITOR}, @filelist;
}
