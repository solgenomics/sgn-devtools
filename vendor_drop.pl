#!/usr/bin/env perl
use strict;
use warnings;
use English;
use Carp;
use FindBin;
use Getopt::Std;
use POSIX;
use URI::Escape;

use Config;

#use Data::Dumper;

use File::Temp qw/tempdir/;

########### GLOBALS ##############

our $datestr = strftime('%Y-%m-%d_%H:%M',localtime);
our $svn_repos = 'svn+ssh://svn.sgn.cornell.edu/data/svn/cxgn';

####################################
sub usage {
  my $message = shift || '';
  $message = "Error: $message\n" if $message;
  my $tempbase = File::Spec->tmpdir;
  my $droplist = join '', map "    $_\n", valid_drops();
  die <<EOU;
$message
Usage:
  $FindBin::Script [options] update <dropname> <working_copy_path>
  $FindBin::Script [options] init <dropname>
  $FindBin::Script [options] undo <dropname>

  Script to update one of the vendor drops in our SVN repository.
  The merging of the updated code is up to you.

Vendor drops:
$droplist

Options:

  -r <url>
    set repository basepath.
    Default $svn_repos

  -t <dir>
    put tempfiles in a subdirectory of here
    Default $tempbase

  -D
    Debug mode.  Equivalent to setting environment
    variable VENDORDROPDEBUG=1

Example:

  update-vendor-drop.pl moby /usr/local/lib/site_perl/MOBY

EOU
}


###DEBUGGING ROUTINES
#set environment variable VENDORDROPDEBUG=1 for a debug mode where it
#doesn't actually check anything in
our $DEBUG => $ENV{VENDORDROPDEBUG} ? 1 : 0;
sub DEBUG { $DEBUG };

sub tee(@) {
  local $| = 1;
  my @stuff = @_;
  foreach (@stuff) {
    next if ref;
    s/\n/\n     /g;
  }
  print "     ".join " ", @stuff;
  print "\n";
  @_;
}

sub run(@) {
  tee @_;
  return if DEBUG;
  system @_;
  die 'run failed (code $CHILD_ERROR):'.join(' ',@_)."\n" if $CHILD_ERROR;
}


### parse and validate command-line args
our %opt;
getopts('r:D',\%opt) or usage();
$DEBUG=1 if $opt{D};
$svn_repos = $opt{r} if $opt{r};
$svn_repos =~ m!^(svn\+ssh|file)://!
  or die "invalid svn repository, must begin with either svn+ssh:// or file://";
my ($command, $dropname, $checkout_path) = @ARGV;
$command && $dropname or usage;
grep $_ eq $dropname, valid_drops()
  or die "unknown drop name '$dropname', available drops are:\n",map {"  $_\n" } valid_drops();

#check that all dependencies are in our path
check_executables();

### now call the appropriate operation
if( $command eq 'undo' ) {
  undo_drop($dropname);
} elsif( $command eq 'init' ) {
  init_drop($dropname);
} elsif( $command eq 'update') {

  -d File::Spec->catdir($checkout_path,'.svn')
    or die "Specified checkout path does not appear to be a working copy.\n";
  -w File::Spec->catdir($checkout_path,'.svn')
    or die "Specified working copy is not writable.\n";

  update_drop($dropname,$checkout_path);
} else {
  die "invalid command '$command'\n";
}

system 'rm -rf '.my_tempdir() unless DEBUG;
exit;

############# SUBROUTINES ############

#initialize a vendor drop by getting the source, loading it, and
#making a current tag
sub init_drop {
  my ($dropname) = @_;

  print "Initializing drop $dropname...\n";
  get_new_upstream_code($dropname);
  run ( 'svn-load',
	-t => tag_name($dropname,'new'),
	$svn_repos,
	tag_name($dropname,'current'),
	my_tempdir()."/NEWDROP",
      );
  print "Done initializing drop.\n";
}

sub write_readme_file_datestamp {
  my ($dropname) = @_;
  my $readme_filename = File::Spec->catfile( my_tempdir()."/NEWDROP", "README_$dropname.txt" );
  open my $dropfile, '>>', $readme_filename
    or die "$! writing $readme_filename";
  print $dropfile "This copy of $dropname was imported on:\n";
  print $dropfile `date`;
  close $dropfile;
}

#update a vendor drop by getting the upstream sources, loading them
#into a dated tag in svn, then shuffling the current and previous tags
#so that the new one is tagged current, and the old current is
#previous, and the old previous is previous_previous
sub update_drop {
  my ($dropname,$checkout_path) = @_;

  print "Updating drop $dropname...\n";
  get_new_upstream_code($dropname);

  eval {
    #don't care if the previous stuff breaks
    #remove the previous_previous tag
    run ( qw| svn rm |,
	  -m => "update-vendor-drop.pl: removing $dropname previous_previous tag",
	  repos_path($dropname,'dprev'),
	);
  };
  eval {
    #move the previous to previous_previous
    run ( qw| svn mv |,
	  -m => "update-vendor-drop.pl: tag previous $dropname as previous previous",
	  repos_path($dropname,'prev'),
	  repos_path($dropname, 'dprev'),
	);
  };
    #   #remove the 
    #   run ( qw| svn rm |,
    # 	-m => "update-vendor-drop.pl: removing $dropname previous tag",
    # 	repos_path($dropname, 'prev'),
    #       );
    # _copy_ the current to previous to preserve it
  run ( qw| svn cp |,
	-m => "update-vendor-drop.pl: tag current $dropname as previous",
	repos_path($dropname, 'current'),
	repos_path($dropname, 'prev'),
      );
  #now svn_load_dirs the upstream code into the new current.
  #svn_load_dirs will try to figure out moves and stuff to make the
  #transition to the new code a little nicer in svn
  run ( qw| svn-load |,
	-t => tag_name($dropname, 'new'),
	$svn_repos,
	tag_name($dropname, 'current'),
	my_tempdir()."/NEWDROP",
      );
  #finally, merge these changes into the working copy the user
  #specified on the command line
  run ( qw| svn merge |,
	repos_path($dropname,'prev'),
	repos_path($dropname,'current'),
	$checkout_path,
#	{ working_dir => $checkout_path },
      );

  print "Done updating drop.\n";
  if(DEBUG) {
    print "\n\nNow, since you're debugging, look in ".my_tempdir()."/NEWDROP to see that the fetching worked correctly\n";
  } else {
    my $prev_repos = repos_path($dropname, 'prev');
    my $curr_repos = repos_path($dropname, 'current');
    print <<EOH;
Now complete and test the merge that I just did in $checkout_path.

If you want to cancel this update without committing, run:

  update-vendor-drop.pl undo $dropname

If you need to run the merge again, run:

  cd $checkout_path; svn merge $prev_repos $curr_repos;

EOH
  }

}

#undo a vendor drop by deleting the current tag for that drop and
#replacing it with the previous tag
sub undo_drop {
  my ($dropname) = @_;
  print "Undoing drop $dropname...\n";
  run ( qw|  svn rm |,
	-m => "$FindBin::Script: undoing $dropname update, removing current tag",
	repos_path($dropname,'current'),
      );
  run ( qw| svn cp  |,
	-m => "$FindBin::Script: undoing $dropname update, tagging old previous as current",
	repos_path($dropname,'prev'),
	repos_path($dropname,'current'),
      );
  run ( qw| svn rm |,
	-m => "$FindBin::Script: undoing $dropname update, removing previous tag",
	repos_path($dropname,'prev'),
      );
  run ( qw| svn cp |,
	-m => "$FindBin::Script: undoing $dropname update, tagging previous previous as previous",
	repos_path($dropname,'dprev'),
	repos_path($dropname,'prev'),
      );
  print "Done undoing drop.\n";
}

#make a tempdir the first time this is called, and just return the
#same one on subsequent calls
sub my_tempdir {
  return our $__tempdir_cache
    ||= tempdir( File::Spec->catdir( $opt{t} || File::Spec->tmpdir,
				     'update-vendor-drop-XXXXXXX',
				   ),
		 CLEANUP => 0,
	       );
}

#given a dropname and the type of tag name you want, return it
sub tag_name {
  my ($dropname,$type) = @_;
  my %tags = ( new     => "vendor_drops/$dropname/$datestr",
	       current => "vendor_drops/$dropname/current",
	       prev    => "vendor_drops/$dropname/previous",
	       dprev   => "vendor_drops/$dropname/previous_previous",
	     );
  return $tags{$type} || confess "unknown tag type '$type'";
}
#same as about, but with the repository path prepended
sub repos_path {
  return $svn_repos.'/'.tag_name(@_);
}




############# SUBROUTINES FOR FETCHING UPSTREAM CODE ###############


## HOW TO ADD A NEW VENDOR DROP

# 1.) figure out a name for it, like 'gbrowse' or whatever
# 2.) add that name to valid_drops() below
# 3.) make a function get_<name>(), which takes a temp dir as an
#     argument, downloads a new copy of the code, and puts it in
#     $tempdir/NEWDROP, in a directory structure like you want it to
#     appear in its vendor drop in subversion.  Its directory
#     structure should probably mirror that of the rest of our
#     subversion repository.  See the existing vendor drops for
#     examples of this.
# 4.) test your drop fetching code by running
#         VENDORDROPDEBUG=1 <scriptname> update <dropname> <wcpath>
#     and see that it puts everything in NEWDROP like you want it
# 5.) you're done.

sub valid_drops {
  return qw(
	    moby
	    bioperl
	    gbrowse
	    gmod_schema
	    gmod_generic_gene_page
	    biodas
	    biofpc
	    jsan
	    mochikit
            gff3_validator
	   );
}


sub get_new_upstream_code {
  my( $dropname ) = @_;
  no strict 'refs';
  print "Fetching new upstream code for $dropname...\n";
  "get_$dropname"->(my_tempdir());
  write_readme_file_datestamp( $dropname );
  print "Done fetching $dropname code.\n";
}

########### VENDOR DROP FETCHING SUBS #####################

############ MOCHIKIT #########

sub get_mochikit {
  my $temp = shift;

  system <<EOS;
cd $temp;
svn export http://svn.mochikit.com/mochikit/trunk mochikit
mkdir -p NEWDROP/jslib;
mv mochikit/MochiKit NEWDROP/jslib;
EOS
}

############ JSAN #############
sub get_jsan {
  my $temp = shift;
  sub read_with_default {
    my ($name,$url) = @_;
    print "\nPlease enter the url to download $name.\nDefault: $url\nnew url: ";
    my $in = <STDIN>;
    chomp $in;
    $url = $in || $url;
  }
  my $ss_url = read_with_default('the JSAN::ServerSide tarball','http://search.cpan.org/CPAN/authors/id/D/DR/DROLSKY/JSAN-ServerSide-0.03.tar.gz');
  my $parser_url = read_with_default('the JSAN::Parse::FileDeps tarball','http://search.cpan.org/CPAN/authors/id/A/AD/ADAMK/JSAN-Parse-FileDeps-1.00.tar.gz');
  system <<EOS;
cd $temp;
mkdir FAKEROOT;
wget -O ss.tar.gz $ss_url
tar xzf ss.tar.gz
cd JSAN*ServerSide*;
perl Makefile.PL destdir=$temp/FAKEROOT
make;
make install;
cd ..;
wget -O p.tar.gz $parser_url
tar xzf p.tar.gz
cd JSAN*Parse*;
perl Makefile.PL destdir=$temp/FAKEROOT
make;
make install;
cd ..;
mkdir -p NEWDROP/perllib;
find FAKEROOT -type d -and -name JSAN -exec cp -rfv {} NEWDROP/perllib ';' ;
find NEWDROP/perllib -type f -and -not -name *.pm -exec rm {} ';' ;
EOS
}

############ BIOFPC ###########
sub get_biofpc {
  my $temp = shift;
  sub dl_url { #make download URLs for the AGI site, cause they want info about who downloads
    my $filename = shift;
    my $base_url = "http://www.agcol.arizona.edu/cgi-bin/software/biofpc/bioperl_dl.cgi";
    my %params = ( filename => 'bioperl_fpc.tar.gz',
		   name     => 'Robert Buels',
		   email    => 'rmb32@cornell.edu',
		   organization => 'sol genomics network',
		   address1 => 'New York, USA',
		   url      => 'http://www.sgn.cornell.edu',
		   wants_email_updates => '',
		 );
    $params{filename} = $filename;
    my @enc_params;
    while(my ($p,$v) = each %params) {
      push @enc_params, "$p=".uri_escape($v);
    }
    return $base_url . '?'. join('&',@enc_params);
  }

  my $dl_bp = dl_url('bioperl_fpc.tar.gz');
  my $dl_conf = dl_url('gbrowse_conf.tar.gz');

  #fake out the referer URL and user agent, because AGCol doesn't want use scripting this
  my $refer_url = 'http://www.agcol.arizona.edu/software/biofpc/download/';
  my $user_agent = 'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.10) Gecko/20050716 Firefox/1.0.6';
  system tee <<EOS;
cd $temp;
wget -O bioperl_fpc.tar.gz -U '$user_agent' --referer=$refer_url '$dl_bp';
wget -O gbrowse_conf.tar.gz -U '$user_agent' --referer=$refer_url '$dl_conf';
tar xzf bioperl_fpc.tar.gz;
tar xzf gbrowse_conf.tar.gz;
mkdir -p NEWDROP/perllib/Bio/Map NEWDROP/sgn-tools/biofpc;
mv bioperl_fpc/Bio/Map/* NEWDROP/perllib/Bio/Map;
mv gbrowse_conf/script/test.pl NEWDROP/sgn-tools/biofpc/fpc_to_gff.pl
find NEWDROP/perllib -type f -exec chmod a-x {} ';'
chmod ug+x NEWDROP/sgn-tools/biofpc/fpc_to_gff.pl
EOS
}

############ MOBY ###########
sub get_moby {
  my $temp = shift;
  system tee <<EOS,
cd $temp;
cvs -z9 -d :pserver:cvs:cvs\@cvs.open-bio.org:/home/repository/moby export -r HEAD moby-live/Perl/MOBY;
mkdir -p NEWDROP/perllib;
mv moby-live/Perl/MOBY NEWDROP/perllib/MOBY;
EOS
}

############# BIOPERL ##############
sub get_bioperl {
  my $temp = shift;
# old installation-based way
#   system tee <<EOS,
# cd $temp;
# cvs -d :pserver:cvs:cvs\@cvs.bioperl.org:/home/repository/bioperl login;
# cvs -z9 -d :pserver:cvs:cvs\@cvs.bioperl.org:/home/repository/bioperl export -r HEAD bioperl-live;
# mkdir -p FAKEROOT NEWDROP/perllib NEWDROP/sgn-tools;
# cd bioperl-live;
# perl Build.PL --install_base $temp/FAKEROOT
# ./Build
# ./Build install
# cd ..;
# mv `find FAKEROOT -type d -and -name Bio | grep -v auto` NEWDROP/perllib;
# mv FAKEROOT/bin NEWDROP/sgn-tools/bioperl;
# mv bioperl-live/t NEWDROP/perllib/Bio;
# cd NEWDROP/sgn-tools/bioperl;
# ln -sf bp_bulk_load_gff.pl bp_pg_bulk_load_gff.pl;
# EOS

#new way - just copy files
  my $cmds = <<EOS;
cd $temp;
svn export svn://code.open-bio.org/bioperl/bioperl-live/trunk bioperl-live
svn export svn://code.open-bio.org/bioperl/bioperl-live/trunk bioperl-run
mkdir -p FAKEROOT NEWDROP/perllib/Bio/t NEWDROP/sgn-tools/bioperl;
cp -r bioperl-*/Bio/* NEWDROP/perllib/Bio
cp -r bioperl-*/scripts/* NEWDROP/sgn-tools/bioperl
cp -r bioperl-*/t/* NEWDROP/perllib/Bio/t
find NEWDROP/sgn-tools/bioperl -name '*.PLS' -exec rename s/\.PLS/\.pl/ {} ';'
EOS
  system tee $cmds;
  open my $readme, '>', "$temp/NEWDROP/README_bioperl.txt" or die "$! writing bioperl readme file";
  print $readme "Fetch commands were:\n$cmds\n";
  close $readme;

#even newer (older) way - install the latest development release, not the cvs head
#   system tee <<EOS,
# cd $temp;
# wget -q -O - http://bioperl.org/DIST/current_core_unstable.tar.gz | tar xzf -
# wget -q -O - http://bioperl.org/DIST/current_run_unstable.tar.gz | tar xzf -
# chmod -R ug+w bioperl-*/;
# mkdir -p FAKEROOT NEWDROP/perllib/Bio/t NEWDROP/sgn-tools/bioperl;
# cp -r bioperl-*/Bio NEWDROP/perllib/
# cp -r bioperl-*/scripts/* NEWDROP/sgn-tools/bioperl
# cp -r bioperl-*/t/* NEWDROP/perllib/Bio/t
# echo This copy of bioperl was downloaded by the CXGN vendor_drop.pl script, its upstream version is bioperl-* > NEWDROP/perllib/Bio/README_vendor_drop.txt
# echo This copy of bioperl was downloaded by the CXGN vendor_drop.pl script, its upstream version is bioperl-* > NEWDROP/sgn-tools/bioperl/README_vendor_drop.txt
# find NEWDROP/sgn-tools/bioperl -name '*.PLS' -exec rename s/\.PLS/\.pl/ {} ';'
# EOS


}
############ GBROWSE ##############
sub get_gbrowse {
  my $temp = shift;
  system tee <<EOS,
cd $temp
yes '' | cvs -d :pserver:anonymous\@gmod.cvs.sourceforge.net:/cvsroot/gmod login
cvs -z9 -d :pserver:anonymous\@gmod.cvs.sourceforge.net:/cvsroot/gmod export -rHEAD Generic-Genome-Browser
cvs -z9 -d :pserver:anonymous\@gmod.cvs.sourceforge.net:/cvsroot/gmod export -rHEAD Bio-Graphics

# make and install bio-graphics in a chroot

# make and install gbrowse in a chroot
cd Generic-Genome-Browser;
perl Makefile.PL PREFIX=$temp/FAKEROOT CONF=$temp/FAKEROOT/conf HTDOCS=$temp/FAKEROOT/htdocs CGIBIN=$temp/FAKEROOT/cgi-bin/ LIB=$temp/FAKEROOT/lib/ BIN=$temp/FAKEROOT/bin/ NONROOT=1
make
make install
cd ..;


rm -rf FAKEROOT/lib/$Config{archname}/auto/;
mkdir -p NEWDROP/perllib NEWDROP/sgn/cgi-bin/gbrowse NEWDROP/sgn/documents/gbrowse NEWDROP/sgn-tools/gbrowse NEWDROP/sgn/conf/gbrowse.conf;
mv FAKEROOT/cgi-bin/* NEWDROP/sgn/cgi-bin/gbrowse;
mv FAKEROOT/htdocs/gbrowse/* NEWDROP/sgn/documents/gbrowse;
mv FAKEROOT/lib/$Config{archname}/*/ NEWDROP/perllib;
mv FAKEROOT/bin/* NEWDROP/sgn-tools/gbrowse;
mv FAKEROOT/conf/gbrowse.conf/* NEWDROP/sgn/conf/gbrowse.conf;
EOS
  #download latest gbrowse release instead of cvs head

#   print "Please type in the path to a locally downloaded GBrowse release tarball (wildcards OK):\n";
#   my $tarball = <STDIN>;
#   chomp $tarball;
#   my @tarballs = glob($tarball);
#   @tarballs == 1 or die "multiple tarballs match, must give me just one.\n";
#   $tarball = shift @tarballs;
#   -r $tarball or die "Cannot open '$tarball' for reading.\n";

#   system tee <<EOS,
# cd $temp
# tar xzf $tarball
# cd Generic-Genome-Browser*/;
# perl Makefile.PL PREFIX=$temp/FAKEROOT CONF=$temp/FAKEROOT/conf HTDOCS=$temp/FAKEROOT/htdocs CGIBIN=$temp/FAKEROOT/cgi-bin/ LIB=$temp/FAKEROOT/lib/ BIN=$temp/FAKEROOT/bin/ NONROOT=1
# make
# make install
# cd ..;
# #rm -rf FAKEROOT/lib/$Config{archname}/auto/;
# mkdir -p NEWDROP/perllib NEWDROP/sgn/cgi-bin/gbrowse NEWDROP/sgn/documents/gbrowse NEWDROP/sgn-tools/gbrowse NEWDROP/sgn/conf/gbrowse.conf;
# mv FAKEROOT/cgi-bin/* NEWDROP/sgn/cgi-bin/gbrowse;
# mv FAKEROOT/htdocs/gbrowse/* NEWDROP/sgn/documents/gbrowse;
# mv FAKEROOT/lib/$Config{archname}/*/ NEWDROP/perllib;
# mv FAKEROOT/bin/* NEWDROP/sgn-tools/gbrowse;
# mv FAKEROOT/conf/gbrowse.conf/* NEWDROP/sgn/conf/gbrowse.conf;
# EOS
}

######### GMOD_SCHEMA ###########
sub get_gmod_schema {
  my $temp = shift;
  local %ENV = ( GMOD_ROOT => "$temp/FAKEROOT",
		 CHADO_DB_NAME => 'fake_chado_db_name',
		 CHADO_DB_USERNAME => 'fake_chado_db_username',
		 CHADO_DB_PASSWORD => 'fake_chado_db_password',
		 CHADO_DB_HOST     => 'fake_chado_db_host',
		 CHADO_DB_PORT     => 'fake_chado_db_port',
	       );
  system tee <<EOS
cd $temp;
yes '' | cvs -d:pserver:anonymous\@gmod.cvs.sourceforge.net:/cvsroot/gmod login
cvs -z9 -d:pserver:anonymous\@gmod.cvs.sourceforge.net:/cvsroot/gmod co schema/chado
cd schema/chado;
yes '' | perl Makefile.PL PREFIX=$temp/FAKEROOT
make
make -k install
cd $temp;
mkdir -p NEWDROP/sgn-tools/chado
mv FAKEROOT/share/perl/5.*/ NEWDROP/perllib
mv FAKEROOT/{bin,conf}/* NEWDROP/sgn-tools/chado
#remove erroneous default.conf symlink
rm NEWDROP/sgn-tools/chado/default.conf
mv FAKEROOT/src/chado NEWDROP/sgn-tools/chado/src

#NOTE: CVS PASSWORD IS BLANK, JUST HIT ENTER
EOS
}


########### BIODAS #############
sub get_biodas {
  my $temp = shift;
  my $listing_file = File::Spec->catfile($temp,'listing');
  system 'wget',
         '-q',
         -O => $listing_file,
	 'http://www.biodas.org/download/Bio::Das/?C=M;O=A',
         ;
	      ;
  open(my $listing,$listing_file) or die "no das listing file\n";
  my $mostrecent;
  while (my $line = <$listing>) {
    my ($mr) = $line =~ /href="([^"]+\.tar\.gz)"/;
    $mostrecent = $mr if $mr;
  }
  system tee <<EOS
cd $temp;
wget http://www.biodas.org/download/Bio::Das/$mostrecent;
tar xzf $mostrecent
mkdir -p FAKEROOT NEWDROP/perllib
cd Bio-Das*/;
perl Makefile.PL PREFIX=$temp/FAKEROOT
make
make install
cd ..;
mv FAKEROOT/share/perl/*/* NEWDROP/perllib
EOS
}



########### GFF3 VALIDATOR #############
sub get_gff3_validator {
  my $temp = shift;
system tee <<EOS
cd $temp;
mkdir -p NEWDROP/sgn-tools/util/
wget -r -A .tar.gz 'http://dev.wormbase.org/db/validate_gff3/validate_gff3_online'
find dev.wormbase.org -name '*.tar.gz' -exec tar xzf {} ';'
mv Validator*/ NEWDROP/sgn-tools/util/validate_gff3
EOS
}


########## GMOD GENERIC GENE PAGE ########
sub get_gmod_generic_gene_page {
  my $temp = shift;
system tee <<EOS
cd $temp;
yes '' | cvs -d:pserver:anonymous\@gmod.cvs.sourceforge.net:/cvsroot/gmod login
cvs -d:pserver:anonymous\@gmod.cvs.sourceforge.net:/cvsroot/gmod export -r HEAD GenericGenePage
mkdir -p NEWDROP/perllib/;
mv GenericGenePage/lib/Bio NEWDROP/perllib
EOS
}

####### utility methods  ####

sub check_executables {
  my $errors;
  foreach my $needed (qw( perl make tar wget svn-load cvs svn ) ) {
    unless(`which $needed`) {
      warn "$needed not found in path\n";
      $errors = 1;
    }
  }
  $errors
    and die "Please make sure the programs listed above are installed and in your path and try again.  Aborting.\n";
}
