#!/bin/sh

# test if database exists
echo "Checking if database exists..."
sudo -u postgres psql -l | grep -q cxgn_daily_build && sudo -u postgres dropdb -U postgres cxgn_daily_build

### deanx - Oct 02 2007 - originally the createdb statement was part of the DB load 
#          below.  But I found that caused login/sudo confusion and failed. now
# 	   the createdb is simply a seperate step
echo "Create new database for the daily build..."
sudo -u postgres createdb -E SQL_ASCII cxgn_daily_build
###

echo "Loading database from dump (this may take a while...)"
# reload the database from file given as parameter
{ zcat -f "$1" ; echo COMMIT ; } | 
  sudo -u postgres psql -U postgres --echo-all --variable AUTOCOMMIT=off --variable ON_ERROR_STOP=t \
    --dbname cxgn_daily_build > ${2:-/tmp/cxgn_daily_build_creation_log} 2>&1 || \
      { dropdb -U postgres cxgn_daily_build; echo Database load failed! > /dev/stderr ; exit 1; } 
