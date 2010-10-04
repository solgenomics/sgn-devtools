#!/usr/bin/env perl
use strict;
use warnings;
my @filelist = split /\n/, `editfind @ARGV`
    or exit 1;


if ( $ENV{EDITOR} =~ m!/vim|^vim$! || !fork ) {
    exec $ENV{EDITOR}, @filelist;
}
