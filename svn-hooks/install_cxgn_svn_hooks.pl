#!/usr/bin/perl

eval 'exec /usr/bin/perl -w -S $0 ${1+"$@"}'
    if 0; # not running under some shell

use strict;
use warnings;

use English;
use Carp;
use FindBin;

use Getopt::Std;
use Pod::Usage;

use List::MoreUtils qw/uniq/;

#use Data::Dumper;

our %opt;
getopts('',\%opt) or pod2usage(1);

my ($repos_path) = @ARGV;

#check the repos path we were given
$repos_path or pod2usage(1);
-d $repos_path or die "repo path does not exist";
-f "$repos_path/format" && -d "$repos_path/hooks" && -d "$repos_path/conf"
  or die "'$repos_path' does not appear to be a valid svn repository.\n";

my $conf_dir = "$repos_path/conf";
my $conf_file = "$FindBin::RealBin/svn-hooks.conf";
my $conf_tgt = "$conf_dir/svn-hooks.conf";
my $hook_script = "$FindBin::RealBin/svn-hooks.pl";
my $hook_dir = "$repos_path/hooks";
my @hook_tgts = uniq
  (map { s/\.tmpl$//; $_} glob "$hook_dir/*.tmpl"),
  (map {"$repos_path/hooks/$_"} qw/pre-commit post-commit pre-revprop-change/);


-f $conf_file or die "conf file '$conf_file' not found, aborting";
-f $hook_script or die "hook script '$hook_script' not found, aborting";
-w or die "could not write to '$_'" foreach $conf_dir, $hook_dir;

unlink $conf_tgt;
symlink($conf_file, $conf_tgt) or die "$! linking '$conf_file' -> '$conf_tgt'";

foreach my $t (@hook_tgts) {
  unlink $t;
  symlink( $hook_script, $t ) or die "$! linking '$hook_script' -> '$t'";
}




__END__

=head1 NAME

  install_hooks.pl - tiny script to just install the accompanying svn
  hooks and configuration into the SVN repository at the given path

=head1 SYNOPSIS

  install_hooks.pl [options] repos_path

  Options:

    none yet

=cut
