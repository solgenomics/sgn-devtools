
=head1 NAME

generate_passwords.pl - generate random passwords

=head1 DESCRIPTION

perl generate_passwords.pl <count>

Generates count random passwords, 8 letters long. Can be changed in the code. Passwords are output to STDOUT, one per line.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

use strict;

use Crypt::RandPasswd;

my $count = shift || 1;

foreach (1..$count) {
    my $password =Crypt::RandPasswd->word( 8 , 8 );
    print $password."\n";
}
