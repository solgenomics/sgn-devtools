#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

BEGIN {
  use_ok(  'MYMODULE'  )
    or BAIL_OUT('could not include the module being tested');
}

# add your tests here

done_testing;
