#!/usr/bin/env perl

use Modern::Perl;
use feature 'say';
use autodie qw/:all/;

unless (!-e 'sgn-site') {
    say_run("git clone git.sgn.cornell.edu:/git/deploy/sgn-site");
}
chdir 'sgn-site';

say_run("make gitupdate");

# Review what changed
say_run("git log -1 --stat -p");

# This will block on an interactive prompt for a GPG password
say_run("make deb");

# Review what changed
say_run("git log -1 --stat -p");

say <<NOTE;
You may want to save the commit you just made by doing

    git push origin master

But you might want to try again, so this part is not automated :)
NOTE

sub say_run {
    my ($cmd) = @_;
    say "Running '$cmd'";
    system $cmd;
}
