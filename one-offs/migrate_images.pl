
=head1 NAME

migrate_images.pl - image migration script 

=head1 DESCRIPTION

migrates the images from a id-based directory structure to a 2 byte stemmed directory structure based on md5sums.

Requires the ImageAddMD5sum.pm db patch (available in cxgn/sgn/db).

Options:

=over 5

=item -D 

database name (default sandbox)

=item -H

host name (default localhost)

=item -o 

old image location directory (default /data/prod/public/images/image_files)

=item -n

new image location directory (default /data/prod/public/images/new_image_files)

=back

=head1 AUTHOR

Lukas Mueller

=cut

use strict;

use Getopt::Std;

use CXGN::DB::InsertDBH;
use CXGN::Image;

our($opt_o, $opt_n, $opt_H, $opt_D);

getopts('o:n:H:D:');

my $dbh = CXGN::DB::InsertDBH->new( {
    dbname => $opt_D || 'sandbox',
    dbhost => $opt_H || 'localhost',
				    });

my $old_image_dir = $opt_o || '/data/prod/public/images/image_files';
my $new_image_dir = $opt_n || '/data/prod/public/images/new_image_files';

my $sql = "SELECT image_id FROM metadata.md_image where obsolete !='t' order by image_id";
my $sth = $dbh->prepare($sql);
$sth->execute();

my %md5sums;
my $processed=0;
my @not_found = ();

while (my ($image_id) = $sth->fetchrow_array()) { 

    my $old_image = CXGN::Image->new(dbh=>$dbh, image_id=>$image_id, image_dir=> $old_image_dir);

    my $i = CXGN::Image->new(dbh=>$dbh, image_id=>$image_id, image_dir=>$new_image_dir);


    if (! -d $old_image_dir."/".$image_id) { 
	push @not_found, "$image_id ".$i->get_name()."\n";
	print STDERR "\nNot found image: $image_id\n";
	next();
    }

    my $filepath =  $old_image_dir."/".$image_id."/".$old_image->get_original_filename().$old_image->get_file_ext();
    if (! -e $filepath) { 
	print STDERR "WARNING! $filepath does not exist!\n";
	next();
    }
    my $md5sum = $i -> calculate_md5sum($filepath);

    $md5sums{$md5sum}++;
    
    
    $i->set_md5sum($md5sum);
    $i->store();
    $dbh->commit();
    $i->make_dirs();


    $i->copy_location($old_image_dir."/".$image_id);

    $processed++;
    print STDERR "Processing image $image_id        \r";
}

foreach my $nf (@not_found) { 
    print STDERR $nf;
}


print STDERR "\nProcessed $processed images, generating ".scalar(keys(%md5sums))." unique md5 keys.\n";


