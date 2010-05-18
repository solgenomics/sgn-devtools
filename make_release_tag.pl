#!/usr/bin/env perl
use strict;
use warnings;
use English;
use Carp;
use FindBin;
use File::Spec;
use Getopt::Std;

use Data::Dumper;

use Pod::Usage;

use CXGN::Tools::Run;

# parse and validate command line args
my %opt;

sub vprint(@) {
  print @_ if $opt{v};
  @_;
}
sub fsystem(@) {
    my $cmd_string = join(' ', map {$_ =~ /\s/ ? "'$_'" : $_} @_);

    print "DO: $cmd_string\n" if $opt{v} || $opt{x};
    unless($opt{x}) {
        system(@_);
        $? and die "command failed: $cmd_string\nAborting.\n";
    }
}

getopts('r:V:vxmMRS:',\%opt) or pod2usage(1);

my $svn_root = $opt{S} || 'svn+ssh://svn.sgn.cornell.edu/cxgn';
$svn_root =~ s!/$!!; #< remove any trailing slash from the svn root
$opt{M} || $opt{m} || $opt{V}
    or pod2usage('must specify either -M, -m, or -V');
@ARGV == 1
    or pod2usage('must provide component name');

my $component_name = shift @ARGV;

#get a list of previous releases
my @previous_releases = previous_releases($svn_root,$component_name);

#figure out the next major version number
my $major_version =
  defined( $opt{V} ) ? $opt{V} :
  @previous_releases ? $opt{M} ? $previous_releases[0][0]+1 :
                       $opt{m} ? $previous_releases[0][0]   :
                       usage('must specify either -M, -m, or -V')
                     : 1
  ;

#figure out the next minor version number
my $minor_version = do {
  if(my @other_rels = grep {$major_version == $_->[0]} @previous_releases) {
    $other_rels[0][1] + 1
  } else {
    0
  }
};

#figure out the SVN revision of stable we'll be taking as the release
my $release_revision = $opt{r} || 'HEAD';

#now make the new release tag in the repository
my $new_release_name     = "$component_name-$major_version.$minor_version";
my $new_release_url      = "$svn_root/$component_name/tags/$new_release_name";

if($opt{R} || $opt{m}) {
    @previous_releases
        or die "no previous releases, cannot do -m or -R\n";
    my $current_release_name = "$component_name-$previous_releases[0][0].$previous_releases[0][1]";
    my $current_release_url  = "$svn_root/$component_name/tags/$current_release_name";
    fsystem( 'svn', 'cp',
             -r => $release_revision,
             -m => "make_release_tag.pl making new $component_name release $major_version.$minor_version as a copy of current release, revision '$release_revision'",
             $current_release_url,
             $new_release_url,
           );
} else {
  fsystem( 'svn', 'cp',
	   -r => $release_revision,
	   -m => "make_release_tag.pl making new $component_name release $major_version.$minor_version from trunk, revision '$release_revision'",
	   "$svn_root/$component_name/trunk",
	   $new_release_url,
	 );
}

print <<EOF;
Made release '$new_release_name'.
EOF

#### SUBROUTINES

#args: none
#returns: a list as ([major,minor],[major,minor]) of
#previous revisions that are present in the repos,
#in descending order by major and minor revision number
sub previous_releases {
    my ( $svn_root, $component_name ) = @_;

    #do an svn ls and parse the output
    my @releases;
    my $tags_path = $svn_root."/$component_name/tags";
    my @tags = `svn ls $tags_path`;
    if ( @tags ) {
	foreach my $line (@tags) {
	    if (my ($major,$minor) = $line =~ /^$component_name-(\d+)\.(\d+)\/$/) {
		push @releases,[$major,$minor];
	    }
	}
	return sort {$b->[0] <=> $a->[0] || $b->[1] <=> $a->[1]} @releases;
    }
    else {
	system
	    'svn', 'mkdir',
	    -m => "make_release_tag.pl initializing tags for $component_name",
	    $tags_path;
	return;
    }
}



__END__

=head1 NAME

make_release_tag.pl -  make a new release tag for the given software component name.

Must specify one of -M, -m, or -V.

=head1 SYNOPSIS

  make_release_tag.pl [options] component_name

  Options:

  -M
     make this a major release.  equivalent to '-V <num+1>', where
     num is the current major release.

  -m
     make this a minor release.  equivalent to '-V <num>', where
     num is the current major release.
     Implies -R, meaning it makes the minor release as a copy of
     the most recent release tag.

  -r <num>
     main branch revision to take as this release,
     defaults to HEAD

  -R make this release tag as a copy of the current (highest-numbered)
     release, not a copy of the main branch

  -V <num>
     major version number of this release, like '4'
     defaults to the next major number in the sequence
     of releases

  -S <svn path>
     path to the root of the SVN repository.  Defaults to
     svn+ssh://svn.sgn.cornell.edu/cxgn

  -v be verbose about what you're doing

  -x just do a dry run, printing what you _would_ do

=head1 MAINTAINER

Robert Buels

=head1 AUTHOR

Robert Buels, E<lt>rmb32@cornell.eduE<gt>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
