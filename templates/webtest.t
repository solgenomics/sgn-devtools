#!/usr/bin/perl
use strict;
use warnings;
use English;

use CXGN::VHost::Test;

use Test::More tests => 1;

my $url = '/my/dir/myscript.pl';

my $result = get( "$url?somethign=1" );
like( $result, qr/something expected/, 'result looks OK');




