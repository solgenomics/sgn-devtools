#!/usr/bin/env perl

use Cwd;
use strict;
use warnings;

my $cwd = getcwd;
my @repos;

for my $dir (<*/>) {
    push @repos, $dir if -e "$dir/.svn";
}

for my $repo (@repos) {
    chdir $repo;
    print "git rebasing:  $repo\n";
    system("git pull --rebase origin");
    system("perl Build.PL");
    system("./Build installdeps");
    chdir $cwd;
}

print "No svn repos found\n" unless @repos;

=head1 NAME

update_and_build.pl - update all subversion repos in the current directory and run installdeps

=head1 SYNOPSIS

    update_and_build.pl

  Options:

    none yet

=head1 MAINTAINER

Jonathan "Duke" Leto

=head1 AUTHOR(S)

Jonathan "Duke" Leto <jonathan@leto.net>

=head1 COPYRIGHT & LICENSE

Copyright 2009 The Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
