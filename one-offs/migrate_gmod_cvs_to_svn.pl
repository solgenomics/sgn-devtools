#!/usr/bin/perl
use strict;
use warnings;

use English;
use Carp;
use FindBin;
use Cwd 'abs_path';

use File::Basename;
use File::Spec::Functions;

use Getopt::Std;
use Pod::Usage;

use IPC::Cmd qw/ can_run /;

use Data::Dumper;

#### configuration for which projects to archive and which to skip

my %projects_to_skip = map {$_ => {}}
  qw(
     gmod
    );

my %projects_to_archive = map {$_ => {}}
  qw(
     bop
     citrina
     das2
     gds     
     gmod-home
     gmod-web
     goet
     graphbrowse
     imdb
     jalview
     javaSean
     labdoc
     org.bdgp
     pubfetch
     pubtrack
     RestGraph
    );

####


our %opt;
getopts('',\%opt) or pod2usage(1);

#$IPC::Cmd::DEBUG   = 1;
$IPC::Cmd::VERBOSE = 1;

sub run(@) {
  my $cstr =  join(' ',@_);
  #print "$cstr\n";
  #warn Dumper $cmd;
  IPC::Cmd::run( command => $cstr )
      or die "command failed: $cstr\n";
}

my $current_dir = abs_path();
my $svn_dir = 'file://'.catdir($current_dir,'gmod_svn');
my $svn_test_dir = 'file://'.catdir($current_dir,'gmod_test_svn');

run(    echo => ssh => -t => 'rbuels,gmod@shell.sourceforge.net', 'create' );
run(qw' echo adminrepo --checkout cvs ');

print "press enter when done locking CVS repo...";
my $in = <STDIN>;

# rsync gmod cvs to local disk twice
run(qw' rsync -avz --delete rsync://gmod.cvs.sourceforge.net/cvsroot/gmod/* gmod_cvs ');
run(qw' rsync -avz --delete rsync://gmod.cvs.sourceforge.net/cvsroot/gmod/* gmod_cvs ');

# tar up the gmod cvs as a backup
run(qw' tar -czf gmod_orig_cvs.tar.gz gmod_cvs ');

 # rsync gmod svn to local disk twice, for a better chance of getting a clean, consistent copy
run(qw' rsync -avz --delete gmod.svn.sourceforge.net::svn/gmod/* gmod_svn ');
run(qw' rsync -avz --delete gmod.svn.sourceforge.net::svn/gmod/* gmod_svn ');

# tar up the gmod svn as a backup
run(qw' tar -czf gmod_orig_svn.tar.gz gmod_svn/ ');

# make any necessary modifications to cvs files
run(rm => -f => 'gmod_cvs/cmap/chado_integration/chado_synchronize/Attic/cmap_syncronize_chado.pl,v');

# run cvs2svn
run('rm -rf *.svndump');
my @dump_destinations;
foreach my $project_dir (glob('gmod_cvs/*/')) {
  my $projname = basename($project_dir);
  next if $projname eq 'CVSROOT';
  my $projparent;

  #skip empty cvs dirs
  my @files = glob "$project_dir/*"; #< skip empty components
  next unless @files;

  #skip projects that are meant to be skipped
  if( my $r = $projects_to_skip{$projname} ) {
    $r->{seen} = 1;
    print "Skipping export of $projname\n";
    next;
  }

  #archive projects that are meant to be archived
  if( my $r = $projects_to_archive{$projname} ) {
    $r->{seen} = 1;
    print "Marking $projname as inactive\n";
    $projparent = "Inactive";
  }

  #die if already in svn
  my $svnls = `svn ls $svn_dir/$projname`;
  die "$projname is already in svn\n" if $svnls;

  run(qw' rm -rf cvs2svn-tmp ');
  run( cvs2svn =>
       "--dumpfile=$projname.svndump",
       "--trunk=$projname/trunk",
       "--branches=$projname/branches",
       "--tags=$projname/tags",
       '--quiet',
       '--quiet',
       $project_dir );
  push @dump_destinations, [$projname,$projparent];
}

# die if there are any projects in the archive or skip lists that
# don't actually exist in cvs
foreach my $list (\%projects_to_skip, \%projects_to_archive) { 
  foreach (keys %$list) {
    $list->{$_}->{seen}
      or die "Project '$_' is in archive or skip lists, but does not seem to be in CVS. Aborting.\n";
  }
}

# test load cvs dumps into local svn, and also build commands for loading
run(qw' rm -rf gmod_test_svn ');
run(qw' cp -r gmod_svn gmod_test_svn');
run('svn', 'mkdir', -m => '\'making directory for inactive projects\'', "$svn_test_dir/Inactive" );
my @load_commands;
foreach my $dumprec (@dump_destinations) {
  my ($projname,$projparent) = @$dumprec;
  $projparent = $projparent ? "--parent-dir $projparent" : '';
  push @load_commands, "svnadmin load -q $projparent /svnroot/gmod \< $projname.svndump";
  run( "svnadmin load -q $projparent gmod_test_svn < $projname.svndump" );
}

# ship it all over to sourceforge
run(qw' echo rsync -avz *.svndump rbuels@web.sourceforge.net: ');

# now print the commands to run over there
run(qw' echo adminrepo --checkout svn ');
run(  ' echo', 'svn', 'mkdir', -m => '\'making directory for inactive projects\'', "file:///svnroot/gmod/Inactive");
run(  " echo $_ ") foreach @load_commands;
run(qw' echo adminrepo --save ');

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

your name here

=cut
