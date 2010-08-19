#!/usr/bin/env perl

eval 'exec /usr/bin/perl -w -S $0 ${1+"$@"}'
    if 0; # not running under some shell

use strict;
use warnings;

use DBI;

use Carp;
use FindBin;

use Getopt::Std;
use Pod::Usage;

use File::Basename;

use File::Spec::Functions qw/catfile/;

use Data::Dumper;

use File::Slurp qw/ slurp /;

our %opt;
getopts('',\%opt) or pod2usage(1);

my %page_files =
    map {
        my $dir_name = $_;
	
        # the page name is just the directory name, so use basename()
        # to take the beginning part of the path off to get the page
        # name
        my $page_name = basename($dir_name);

        #### the file 'current' in the page's directory holds the revision number of the current revision of that page.

        # first, assemble the full path to that file, then get the contents of that file
        my $current_revision_file = catfile( $dir_name, 'current' );
	if( -f $current_revision_file ) {
	    my $current_revision = slurp( $current_revision_file );
	    $current_revision =~ s/\s//g; #remove all whitespace from what we got from that file
  
	    if( $current_revision ) { #< if there was a current revision

		#now finally we know where the contents of the page is
		my $current_page_file = catfile( $dir_name, 'revisions', $current_revision );
		$page_name => $current_page_file
		}
	    else {
		() #< if no current revision, return an empty list from
		    #the map to skip this one
		}
	}else{
	    () #< if no current revision file, skip
	    }
    } glob("/data/shared/wiki/data/pages/*/");

print Dumper \%page_files;


my $dbh = DBI->connect('DBI:Pg:dbname=trac_cxgn;host=localhost', 'trac', 'chaije9S', {AutoCommit => 0}); 

while ( my ($name,$file) = each %page_files ){

    #skip page if it already exists in the trac wiki
    next if $dbh->selectrow_arrayref( <<EOQ, undef, $name );
        SELECT name
	FROM public.wiki
	WHERE name = ?
EOQ

    #extract version number and remove leading zeros
    my ($version) = $file =~ /(\d+)$/;
    $version += 0;

    #get time, author, and IP number
    my $time = time();
    my $author = "internalsite_migration";
    my $ipnr = "127.0.0.1";

    #read in text of page
    local $/;
    open my $fh,'<',"$file" or next; #skip if the page is no longer in use (no current version #)
    my $text = <$fh>;
    close $fh;

    #leave comment and readonly as undef
    my $comment = "page automatically migrated from old moinmoin internal site";
    my $readonly = undef;

    #insert page into trac wiki
    $dbh->do( <<EOQ , undef, $name, $version, $time, $author, $ipnr, $text, $comment, $readonly );
        INSERT INTO public.wiki (name, version, time, author, ipnr, text, comment, readonly) 
	VALUES (?,?,?,?,?,?,?,?)
EOQ
}

$dbh->commit();
$dbh->disconnect();

__END__

=head1 NAME

moinmoin_2_trac.pl - script to migrate internal wiki pages to trac wiki

=head1 SYNOPSIS

  moinmoin_2_trac.pl 

  Options:

    none 

=head1 MAINTAINER

Rob Buels

=head1 AUTHOR

Hannah De Jong, summer intern

=head1 COPYRIGHT & LICENSE

Copyright 2009 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
