#!/usr/bin/env perl
use strict;
use warnings;
my @filelist = split /\n/, `editfind @ARGV`
    or exit 1;

my $should_background = defined $ENV{DISPLAY} && $ENV{EDITOR} !~ m!/vim|^vim$!;

if ( !$should_background || !fork ) {
    exec $ENV{EDITOR}, @filelist;
}
