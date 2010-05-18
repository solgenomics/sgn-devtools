#!/usr/bin/env perl
use strict;
use warnings;
use English;

use Test::More tests => 2;

BEGIN {
  use_ok(  'MYMODULE'  )
    or BAIL_OUT('could not include the module being tested');
}

