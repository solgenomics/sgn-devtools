=head1 NAME

t/validate/STUFF.t - validation tests for STUFF

=head1 DESCRIPTION

Tests for ...

=head1 AUTHORS

Your Name

=cut

use strict;
use Test::More;
use lib 't/lib';
use SGN::Test qw/validate_urls/;

my %urls = (
        "url name 1"   => "/foo",
        "url name 2"   => "/bar/baz?id=2",
);

validate_urls(\%urls, $ENV{ITERATIONS} || 1 );

done_testing;
