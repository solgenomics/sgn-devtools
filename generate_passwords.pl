
=head1 NAME

generate_passwords.pl - generate random passwords

=head1 DESCRIPTION

perl generate_passwords.pl -n <count> -l <length>

Generates count random passwords, one by default, 8 letters long by default. Can be changed in the code. Passwords are output to STDOUT, one per line.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

use strict;
use Getopt::Std;
use Crypt::RandPasswd;

our($opt_n, $opt_l);

getopts('n:l:');

my $count = $opt_n || 1;
my $len = $opt_l || 8;

foreach (1..$count) {
    my $password =Crypt::RandPasswd->word($len, $len);
    print $password."\n";
}
