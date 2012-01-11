#!/usr/bin/perl

=head1 NAME

test_load_dbs.pl - test load dbs on a redundant server, to be run by cron

=head1 DESCRIPTION

test_load_dbs.pl test loads the databases specified in a conf file, test_load_dbs.conf.

The conf file contains two columns of paths to database dumps to be restored and the name of the database to be given in the redundant server.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

use strict;

my $conf = shift || "/root/test_load_dbs.conf";

open(my $F, "<", $conf);

while (<$F>) { 
    chomp;
    my ($dbdump, $dbname) = split /\s+/;

    if (! -e $dbdump || -s $dbdump == 0) { 
	print "The file $dbdump does not exist of is empty. NOT TEST LOADING $dbdump!!!\n";
	next;
    }
    else { 
	backup_db($dbdump, $dbname);
    }

}


sub backup_db { 
    my $dbdump = shift;
    my $dbname = shift;

# test if database exists


    $ENV{DBDUMP} = $dbdump;
    $ENV{DBNAME} = $dbname;

    ##system('echo DBDUMP = $DBDUMP');
    ##system('echo DBNAME = $DBNAME');

    print "Checking if database $dbname exists, and removing it...\n";

    system('sudo -u postgres psql -l | grep -q $DBNAME && sudo -u postgres dropdb -U postgres $DBNAME');    

### deanx - Oct 02 2007 - originally the createdb statement was part of the DB load 
#          below.  But I found that caused login/sudo confusion and failed. now
# 	   the createdb is simply a seperate step
    print "Create new database for the daily build of $dbdump...\n";
    system('sudo -u postgres createdb -E SQL_ASCII $DBNAME');
###

    print  "Loading database from dump (this may take a while...)\n";
# reload the database from file given as parameter
    system('time { zcat -f "$DBDUMP" ; echo COMMIT ; } | sudo -u postgres psql -U postgres --echo-all --variable AUTOCOMMIT=off --variable ON_ERROR_STOP=t --dbname $DBNAME > ${2:-/tmp/build_creation_log\_$DBNAME} 2>&1 || { sudo -u postgres dropdb -U postgres $DBNAME; echo Database load failed! > /dev/stderr ; exit 1; } ');

    print "Done with db $dbname.\n";
}
