#!/bin/sh

# test if database exists
sudo -u postgres psql -l | grep -q cxgn_tmp && sudo -u postgres dropdb cxgn_tmp

### deanx - Oct 02 2007 - originally the createdb statement was part of the DB load 
#          below.  But I found that caused login/sudo confusion and failed. now
# 	   the createdb is simply a seperate step
sudo -u postgres createdb cxgn_tmp
###

# reload the database from file given as parameter
{ zcat -f "$1" ; echo COMMIT ; } | 
  sudo -u postgres psql --echo-all --variable AUTOCOMMIT=off --variable ON_ERROR_STOP=t \
    --dbname cxgn_tmp > ${2:-/tmp/cxgn_tmp_creation_log} 2>&1 || \
      { dropdb cxgn_tmp; echo Database load failed! > /dev/stderr ; exit 1; } 
