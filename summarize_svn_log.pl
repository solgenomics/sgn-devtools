#!/usr/bin/perl
use strict;

# summarize the svn log, suitable for pasting into an email

#push(@ARGV, '/data/local/website/cxgn/') unless $ARGV[-1] =~ /cxgn/;

die "example usage: $0 -r 1234:5678 /data/local/website/cxgn" unless @ARGV > 0;

my $log_command = 'svn log '.join(' ', @ARGV);
print "running $log_command\n";
my @full_log = `$log_command` or die "svn command failed: $!";

my %output;

my $new_entry = 0;
my $parsed_body = 0;
my @entry_info = ();
my @all_entries;
foreach my $line (@full_log){

  if ($line =~ /^-+$/){
    # this is the separator line
    $new_entry = 1;
    $parsed_body = 0;
    printf "%-6s %-9s  %s\n", @entry_info;
    push (@all_entries, [@entry_info]);
    @entry_info = ();    
    next;
  }

  if ($new_entry == 1){
    # this is the info line at the beginning of the entry
    my ($rev, $user, undef, undef) = split ' \| ', $line;
    $rev =~ s/r(\d+)/$1/;
    push(@entry_info, $rev, $user);
    $new_entry = 0;
    next;
  }

  if ($new_entry == 0 and $parsed_body == 0 and $line =~ /\S/){
    # first line of the entry body - let's truncate and keep it
       chomp $line;
       my $shortline = substr($line, 0, 50);
       $shortline .= '...' if length($shortline) < length($line); # good enough
       push(@entry_info, $shortline);
      $parsed_body = 1;
     next;
  }

}


