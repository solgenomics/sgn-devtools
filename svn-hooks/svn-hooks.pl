#!/usr/bin/env perl
use strict;
use warnings;

use English;
use Carp;
use FindBin;
use File::Spec;
use Pod::Usage;

use IO::Socket;
 
use SVN::Hooks;
use SVN::Hooks::CheckLog;
use SVN::Hooks::DenyFilenames;
use SVN::Hooks::DenyChanges;
#use SVN::Hooks::CheckMimeTypes;
use SVN::Hooks::CheckProperty;
use SVN::Hooks::Notify;

use constant TRAC_ENV_BASE => '/data/local/trac/trac_environments';

# run the driveby bot to report on the commit in irc, in this process
#run_driveby_bot($0, @ARGV);

# run the trac integration hooks
run_trac_integration($0, @ARGV);

# run the hooks in the SVN::Hooks framework
run_hook($0, @ARGV);

exit;

############################

sub run_driveby_bot {
    my ($script_name, $repos, @args) = @_;

    # this is only for post-commit
    return unless $script_name =~ /post-commit$/;

    if( fork ) {
	$SIG{CHLD} = 'IGNORE';
	return;
    }

    my $server = "irc.perl.org";
    my $port = 6667;
    my $nick = "horsenettle";
    my $ident = "horsenettle";
    my $realname = "Sol Genomics Network CommitBot";
    my $chan = "#cxgn";
    my $pass = "";
 
    my ( $rev ) = @args;
    my $commit = SVN::Look->new( $repos, -r => $rev );
    my $user = $commit->author;

    my $url_base = 'http://bugs.sgn.cornell.edu/trac/cxgn';
    my @log = "[$rev] ($user) $repos : ".$commit->log_msg;
    push @log, "[$rev] View: $url_base/changeset/$rev";

    # add links to any tickets in the log message
    push @log, make_ticket_links( $url_base, $rev, $commit->log_msg );
    
    my $irc = IO::Socket::INET->new( PeerAddr => $server,
				     PeerPort => $port,
				     Proto    =>'tcp'
				   ) or die "Argh!";
    
#print $irc "USER $ident $ident $ident $ident :$realname\n";
    print $irc "NICK $nick\n";
#print $irc "PRIVMSG nickserv/@/services.dal.net :identify $pass\n";
    print $irc "USER $ident 8 * :$ident\n";
    print $irc "join $chan\n";
    
    while(defined( my $in = <$irc> )) {
	if( $in=~/^:(.+)\!.+ JOIN\b/ ) {
	    print $irc "PRIVMSG $chan :$_ \n" for @log;
	    last;
	}
    }

    exit;
}

sub run_trac_integration {
    my ($script_name, $repos, @args) = @_;
    my @repos_dirs = File::Spec->splitdir( $repos );

# NOTE: we take the Trac project dirname to be the same as the repository's dirname
    my $trac_project_name = $repos_dirs[-1];
    my $trac_project_env = File::Spec->catdir( TRAC_ENV_BASE, $trac_project_name);

    unless( -d $trac_project_env ) {
	warn "WARNING: COULD NOT FIND TRAC PROJECT ENV '$trac_project_env', NOT RUNNIING TRAC INTEGRATION\n";
	return;
    }


    # now run the Trac integration hooks
    if ( $script_name =~ /pre-commit$/ ) {

	# currently we don't run the trac pre-commit, which enforces that
	# every commit have an open ticket.  perhaps we should in the
	# future though.

#     my $txn = $args[0];
#     my $log = `/usr/bin/svnlook log -t "$txn" "$repos"`;
	
#     CXGN::Tools::Run->run( "$FindBin::RealBin/trac-pre-commit-hook",
# 			   $trac_project_env,
# 			   $log,
# 			 );
	
    } elsif ( $script_name =~ /post-commit$/ ) {
	if( fork ) {
	    $SIG{CHLD} = 'IGNORE';
	} else {
	    my $rev = $args[0];

	    my $trac_hook_path = "$FindBin::RealBin/trac-post-commit-hook";
	    system( $trac_hook_path,
		    -p => $trac_project_env,
		    -r => $rev,
		    );
	    die <<EOD if $CHILD_ERROR;
$! running Trac post-commit hook '$trac_hook_path'.  Make sure the Trac log for $trac_project_env is writable for the user running the SVN checkin.
EOD
            exit;
	}
    } else {
	warn "$script_name";
    }
}

sub make_ticket_links {
    my ($url_base,$rev, $log) = @_;
    my @tickets = 
     map "[$rev] Ticket $_: $url_base/ticket/$_", 
     $log =~ /(?:ref(?:erence)?s|closes|fix(?:es|ed)?|see|re|addresses)\s+#(\d+)/g;
    return @tickets;
}               
   

__END__

=head1 NAME

  svn_hooks.pl - unified hook script run by CXGN's subversion
  repository.  Uses SVN::Hooks for task dispatch.

=head1 SYNOPSIS

  svn_hooks.pl [args]

  Options:

    none yet

=cut
