#!/bin/bash
while [ 1 ]; do
    sudo -u postgres psql -c "select count(*) as connections from pg_stat_activity where usename <> 'postgres'"
    sleep 1;
    clear;
done
