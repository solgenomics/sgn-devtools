#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::WWW::Selenium;

my $server = $ENV{SELENIUM_TEST_SERVER};
$server || die "need SELENIUM_TEST_SERVER environment variable set";

my $host   = $ENV{SELENIUM_HOST} || die "need SELENIUM_HOST environment variable";

my $browser = $ENV{SELENIUM_BROWSER} || die "need SELENIUM_BROWSER environment variable";

my $s = Test::WWW::Selenium->new(
    host        => $host,
    port        => 4444,
    browser     => $browser,
    browser_url => $server."/image/index.pl?image_id=1",
    );

$s->open_ok($server."/image/index.pl?image_id=1");

my $source    = $s->get_html_source();
my $body_text = $s->get_body_text(); # this contains the interpreted javascript

like($body_text, qr/SGN Image/, "String match on page");
like($source, qr/<img src=/, "Image tag string present");
like($body_text, qr/Image Description/, "Input field match");

done_testing;

