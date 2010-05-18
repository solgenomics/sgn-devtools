#!/usr/bin/env perl
use strict;
use warnings;
use autodie ':all';

use Pod::Usage;

use File::Temp;
use File::Spec::Functions;

pod2usage(0) unless @ARGV;

my @repos;
foreach (@ARGV) {
    unless( -d catdir($_,'.svn') ) {
        print "$_ does not appear to be an svn checkout, skipping\n";
        next;
    }
    if( -d "$_.old_svn" ) {
        print "$_ backup copy ($_.old_svn) already exists, skipping\n";
        next;
    }
    if( m|\.old_svn/?| ) {
        print "$_ is already a backup copy, skipping.\n";
        next;
    }
    s|/||g;
    push @repos, $_;
}

foreach my $repo (@repos) {
    print "converting $repo to a git checkout\n\n";

    my $tempdir = File::Temp->newdir;

    # clone the repo from github
    system git => clone => 'git@github.com:solgenomics/'.$repo.'.git' => catdir($tempdir,$repo);

    # get the svn di from the existing repo
    my $svn_wc_patch = `svn di $repo`;
    # and also the list of any additional files
    my @additional_files = `cd $repo && svn st | grep ^?`;
    for(@additional_files) {
        chomp; s/^\s*\S+\s+//;
    }

    # move the svn repo to a backup copy
    system mv => $repo => "$repo.old_svn";

    # move the git repo into place
    system mv => catdir($tempdir,$repo) => $repo;

    # apply the patch to the git repo
    { open my $patch, "| patch -p0";
      $patch->print($svn_wc_patch);
    }

    # copy additional files to the working copy
    system cp => -rav => catfile( "$repo.old_svn", $_ ) => catfile($repo, $_)
        for @additional_files;

    # and that's all!
    print "\nsuccessfully converted $repo.\n\n";
}

__END__


#!/usr/bin/perl

=head1 NAME

convert_svn_checkout_to_git.pl - SGN-specific script one-time script to convert svn working copy into a git working copy, preserving changes

=head1 SYNOPSIS

  convert_svn_checkout_to_git.pl dir another_dir ...

=head1 AUTHOR

Robert Buels

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
