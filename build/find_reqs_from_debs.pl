#!/usr/bin/perl
use strict;
use Data::Dumper;
use File::Find;

# find all the packages in the given debian control output
my @all_packages;
while(<>) {
    if(/^\s*Depends:/) {
        chomp;
        my @p = map /^\s*(\S+)/, split /\s*,\s*/,$_;
        $p[0] =~ s/^\s*Depends:\s*//;

        push @all_packages,
            grep /perl/, @p;
    }
}

my @all_mods;
foreach my $p (@all_packages) {
    warn "searching $p\n";
    my @pkg_files = `dpkg -L $p`;
    unless( @pkg_files ) {
        @pkg_files = `apt-file show $p | cut -d : -f 2`;
    }
    @pkg_files or die "cannot list files from package $p\n";
    my @mods =
        map { s!/!::!g; $_ }
        map {
            #my (undef,$f) = split /: /,$_,2;
            chomp;
            m!/[^/]*perl[^/]*/(\S+)\.pm$!;
        }
        @pkg_files;

    warn Dumper \@mods if @mods;
    push @all_mods,@mods;
}




my @kinds = ( { name => 'build_requires', dir => ['t'] },
              { name => 'requires', dir => ['lib','scripts'] },
            );

#@all_mods = @all_mods[0..200];
foreach my $mod (@all_mods) {
    warn "searching for uses of $mod\n";
    my @needs;
    for my $k (@kinds) {
        $k->{perlfiles} ||= do {
            my @perlfiles;
            find( sub {
                      return unless -x || /\.(pm|t|pl)$/;
                      push @perlfiles, $File::Find::name;
                  },
                  $_
                ) for grep -d, @{$k->{dir}};
            \@perlfiles
        };

        next unless @{$k->{perlfiles}};
        unless(system qw/grep -qP/, qq@(use|require)\\s+["']?$mod@, @{$k->{perlfiles}}) {
            warn "    adding to $k->{name}\n";
            $k->{deps}{$mod} = 1;
        }
    }
                                    #print "$mod: ".join(' ',@needs)."\n";
}

foreach (@kinds) {
    print "$_->{name} => {\n";
    for (sort {lc($a) cmp lc($b)} keys %{$_->{deps}}) {
        print "    '$_' => 0,\n"
    }
    print "},\n";
}
