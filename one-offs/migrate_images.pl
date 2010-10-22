
use strict;
use CXGN::DB::Connection;
use CXGN::Image;

my $dbh = CXGN::DB::Connection->new();

my $old_image_dir = '/data/prod_local/public/images/image_files';



my $sql = "SELECT image_id FROM metadata.md_image where obsolete !='t' order by image_id";
my $sth = $dbh->prepare($sql);
$sth->execute();

my %md5sums;
my $processed=0;
my @not_found = ();
while (my ($image_id) = $sth->fetchrow_array()) { 

    my $old_image = CXGN::Image->new(dbh=>$dbh, image_id=>$image_id, image_dir=> $old_image_dir);

    my $i = CXGN::Image->new(dbh=>$dbh, image_id=>$image_id, image_dir=>'/data/prod_local/public/images/new_image_files');


    if (! -d $old_image_dir."/".$image_id) { 
	push @not_found, "$image_id ".$i->get_name()."\n";
	print STDERR "\nNot found image: $image_id\n";
	next();
    }


    my $md5sum = $i -> calculate_md5sum($old_image_dir."/".$image_id."/".$old_image->get_original_filename().$old_image->get_file_ext());

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


