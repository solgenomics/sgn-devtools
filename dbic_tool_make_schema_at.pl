#!/usr/bin/perl

=head1 NAME

 dbic_tool_make_schema_at.pl.
 A script to create the DBIx::Class objects using the DBIx::Class::Schema::Loader (version.1.0.).

=cut

=head1 SYPNOSIS

dbic_tool_make_schema_at.pl [-h] -p <module_path> -d <dir> -s <schema> -D <dbname> -H <dbhost>
    
=head2 I<Flags:>

=over
      
=item -p

B<module_path>              the module path used to create the different DBIx::Class objects (example: CXGN::SEDM::Schema) (mandatory)

=item -d

B<directory>                the directory where the objects will be created (example: /data/local/perllib/CXGN) (mandatory)

=item -s

B<schema>                   the schema of the database that will be used to create the DBIx::Class objects (example: sed) (mandatory)

=item -D 

B<db_name>                  the database name to access to the database (mandatory) 

=item -H

B<db_hostname>              the database hostname to access to the database (mandatory) 

=item -h 

B<help>                     show the help

=back

=cut

=head1 DESCRIPTION

 This script create the objects for the DBIx::Class
 
=cut

=head1 AUTHORS

  Aureliano Bombarely Gomez.
  (ab782@cornell.edu).

=cut

=head1 METHODS

dbic_tool_make_schema_at.pl


=cut

use strict;
use warnings;

use Getopt::Std;
use CXGN::DB::InsertDBH;
use DBIx::Class::Schema::Loader qw/ make_schema_at /;

our ($opt_p, $opt_d, $opt_s, $opt_D, $opt_H, $opt_h);
getopts("p:d:s:D:H:h");
if (!$opt_p && !$opt_d && !$opt_s && !$opt_D && !$opt_H && !$opt_h) {
    print "There are n\'t any tags. Print help\n\n";
    help();
}

my $path   = $opt_p || die("None module path was supplied as -p <module_structure_path> argument.\n");
my $dir    = $opt_d || die("None directory was supplied as -d <directory> argument.\n");
my $schema = $opt_s || die("None database schema was supplied as -s <dbschema> argument.\n");
my $db     = $opt_D || die("None database name was supplied as -D <dbname> argument.\n");
#my $user   = $opt_U || die("None database username was supplied as -U <dbuser> argument.\n");
#my $pass   = $opt_P || die("None database password was supplied as -P <dbpass> argument.\n");
my $host   = $opt_H || die("None database hostname was supplied as -H <dbhost> argument.\n");


print "\n\nParameters:\n\tPATH: $path\n\tDIR: $dir\n\tSCHEMA: $schema\n\tDB_NAME: $db\n\tDB_HOST: $host\n\n";
my $dbh =  CXGN::DB::InsertDBH->new({ dbname => $db, dbhost => $host })->get_actual_dbh();


make_schema_at(
        $path,
        { debug => 1, dump_directory => $dir, db_schema => $schema },
        [ sub {$dbh }],
    );


=head2 help

  Usage: help()
  Desc: print help of this script
  Ret: none
  Args: none
  Side_Effects: exit of the script
  Example: if (!@ARGV) {
               help();
           }

=cut

sub help {
  print STDERR <<EOF;
  $0:

    Description:
      A script to create the DBIx::Class objects using the DBIx::Class::Schema::Loader        

    Usage:
     dbic_tool_make_schema_at.pl [-h] -p <module_path> -d <dir> -s <schema> -U <username> -D <dbname> -H <dbhost> -P <dbpass>

    Flags:
      -p <module_path>          the module path used to create the different DBIx::Class objects (example: CXGN::SEDM::Schema) (mandatory)
      -d <directory>            the directory where the objects will be created (example: /data/local/perllib/CXGN) (mandatory)
      -s <schema>               the schema of the database that will be used to create the DBIx::Class objects (example: sed) (mandatory)
      -D <db_name>              the database name to access to the database (mandatory) 
      -H <db_hostname>          the database hostname to access to the database (mandatory) 
      -h <help>                 show the help


EOF
exit (1);
}
