#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;

#SL1.00sc00014   ITAG_infernal   rRNA_5S 2067200 2067318 66.44   -       .       Name=RF00001;Alias=5S_rRNA;e-value=2.709e-12

while (my $line = <>){
    chomp $line;
    if ($line =~ m/ITAG_infernal\t/) {
        my @f = split /\t/, $line;
        my $rna_type = $f[2];
        $f[2] = 'transcript';
        $f[8] .= ";rna_type=$rna_type";
        $line = join "\t", @f;
    }
    print "$line\n";
}
