#!/usr/bin/env perl
use strict;
use warnings;
my @filelist = split /\n/, `editfind @ARGV`;

if ($ENV{EDITOR} =~ m!/vim!) {
    exec $ENV{EDITOR}, @filelist;
} else {
    system $ENV{EDITOR}, @filelist;
}
