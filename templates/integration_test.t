#!/usr/bin/perl
use strict;
use warnings;

use Test::More;

use lib 't/lib';
use SGN::Test::WWW::Mechanize;
use SGN::Test::Data qw/ create_test /;

my $input_page = "/tools/convert/input.pl";

my $mech = SGN::Test::WWW::Mechanize->new;

for my $id_input ('TC115712',"TC115712\n","TC115710") {
    $mech->get_ok( $input_page );

    # a few checks on the title
    $mech->title_is( "ID Converter", "Make sure we're on ID Converter input page" );

    # a few checks on the content
    $mech->content_contains( "TIGR TC", "mentions TIGR TC" );
    $mech->content_like( qr/SGN-U\d+/, "mentions unigenes" );

    $mech->submit_form_ok({ form_name => 'convform',
                            fields => {ids => $id_input},
                          },
                          'search for a single TC to convert',
                         );

    $mech->content_like( qr/SGN Unigene ID/, "mentions unigenes" );
    my ($id) = $id_input =~ /(\d+)/;
    $mech->content_contains($id, "contains TC ident (whether found or not)" );
}

done_testing;
