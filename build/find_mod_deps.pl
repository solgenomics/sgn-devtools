#!/usr/bin/perl

=head1 NAME

find_mod_deps.pl - inspect *hard-coded* dependencies of sets of perl files

=head1 USAGE

find_mod_deps.pl [options]  [ path ... ]

If given any paths, inspects only the files in those paths.  Defaults
to inspecting all perl files in the current directory.

=head2 Options

=over 4

=item -i

If set, also print dependencies on files that are in the same
distribution.

=cut

use strict;
use warnings;

use File::Find;
use List::MoreUtils 'any';
use Module::CoreList;

use Pod::Usage;
use Getopt::Std;

my %opt;
getopts('i', \%opt) or pod2usage();

-d './lib' or -d './bin' or -d './scripts' or die "run this script from the root dir of a distribution\n";

my @kinds = ( { name => 'build_requires', dir => ['t'] },
              { name => 'requires', dir => ['lib','scripts','bin','cgi-bin','Bio'] },
            );

for my $dep_kind (@kinds) {
    if( @ARGV ) {
        my @matching = grep {
            my $user_path = $_;
            scalar grep index( $user_path, $_ ) == 0, @{$dep_kind->{dir}}
        } @ARGV;

        $dep_kind->{dir} = \@matching
    }
}

#index the use and require statements as modulename => build or 
my %uses;
for my $k (@kinds) {
    my @perl_lines;
    $k->{perlfiles} ||= do {
        my @perlfiles;
        find( sub {
                  return unless -f && ( -x || /\.(pm|t|pl)$/ );
                  push @perlfiles, $File::Find::name;
                  open my $p, '<', $_ or die "$! opening $File::Find::name\n";
                  push @perl_lines, $_ while <$p>;
              },
              $_
            ) for grep -d, @{$k->{dir}};
        \@perlfiles
    };
    #warn Dumper $k->{perlfiles};

    foreach my $depline ( grep /^\s*(use|require|extends|with)\s+.+;/, @perl_lines ) {
        $depline =~ s/#.+//; #remove comments
        next unless $depline && $depline =~ /\S/;

        my @toks = $depline =~ /([\w:]{3,})/ig
            or die 'cannot parse: '.$depline;

        #warn "    adding to $k->{name}\n";
        shift @toks;
        if( @toks ) {
            if ( $toks[0] eq 'base' ) {
                shift @toks;
                shift @toks if $toks[0] eq 'qw';
            } else {
                @toks = ($toks[0]);
            }
        }

      MODNAME:
        foreach my $modname (@toks) {

            chomp $depline;
            #warn "'$depline' goes to $modname\n";

            #skip if the module is in the distribution
            my $modfile = modfile($modname);
            next if !$opt{i} && -f $modfile;

            #skip if the module is in core before 5.6
            my $rl = Module::CoreList->first_release($modname);
            next if $rl && $rl <= 5.006;

            #skip if the module is actually defined in a parent file
            my $p = $modname;
            while( $p = namespace_parent($p) ) {
                my $p_modfile = modfile($p);
                #warn  "checking $p / $p_modfile\n";

                next unless -f $p_modfile;

                open my $p, '<', $p_modfile or die "$! opening $p_modfile\n";
                while( <$p> ) {
                    next MODNAME if /^\s*package\s+$p\b/;
                }
            }

            $k->{deps}{$modname} = 1;
        }
    }
}


foreach (@kinds) {
    print "$_->{name} => {\n";
    for (sort {lc($a) cmp lc($b)} keys %{$_->{deps}}) {
        print "    '$_' => 0,\n"
    }
    print "},\n";
}

sub modfile {
    my $modname = shift;
    my $modfile = "./lib/$modname.pm";
    $modfile =~ s|::|/|g;
    return $modfile;
}

sub namespace_parent {
    my $modname = shift;
    $modname =~ s/(?:::)?[^:]+$//;
    return $modname;
}
