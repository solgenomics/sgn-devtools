#!/usr/bin/env perl
use POSIX;
use File::Temp qw/tempfile/;

my $u=shift;

my (undef,$weblint_temp) = tempfile();
my (undef,$wget_temp) = tempfile();
warn "$weblint_temp, $wget_temp\n";
unless(my $wlpid = fork) {
    open \*STDOUT, '>', $weblint_temp;
    system qw|weblint --context 3 |, $u
        and die 'error running weblint';
    print "*** weblint done ***\n";
    POSIX::_exit(0);
} else {
    system 'wget', -O => $wget_temp, $u
        and die "error running wget ($!)";
    waitpid $wlpid, 0;
}

system "$ENV{EDITOR} $weblint_temp $wget_temp"
    and die "$! executing \$ENV{EDITOR} '$ENV{EDITOR}'";

for ($weblint_temp, $wget_temp) {
    unlink $_
        or warn "$! unlinking $_\n";
}
