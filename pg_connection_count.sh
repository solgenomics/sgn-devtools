#!/bin/bash
while [ 1 ]; do
    sudo -u postgres psql -c "select datname,count(*) as connections from pg_stat_activity where usename <> 'postgres' group by datname"
    sleep 1;
    clear;
done
