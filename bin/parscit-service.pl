#!/opt/ActivePerl-5.8/bin/perl -CSD
#
# Starts a web service using SOAP::Lite that handles requests
# for citation parsing.  For message details, see the WSDL file
# in the wsdl/ directory of the ParsCit distribution.
#
# Input messages must include a pointer to the location of a
# text file to be parsed.  There must be local access to this
# file via a standard or networked file system.
#
# Isaac Councill, 07/24/07
#
exit(0) if fork;

use strict;
use utf8;
#use SOAP::Lite +trace=>'debug';
use SOAP::Transport::HTTP;
use FindBin;
use lib "$FindBin::Bin/../lib";
use ParsCit::Config;
use Encode;
use Log::Log4perl qw(get_logger :levels);

$SIG{'PIPE'} = $SIG{'INT'} = 'IGNORE';

open(STDERR, ">>$FindBin::Bin/../parscit.err");

my $serverURL = $ParsCit::Config::serverURL;
my $serverPort = $ParsCit::Config::serverPort;

my $daemon = SOAP::Transport::HTTP::Daemon
    ->new ('LocalAddr' => $serverURL, 'LocalPort' => $serverPort, 'Reuse' => 1)
    ->dispatch_to('Parser');

## Initialize Logging
my $logger = get_logger("ParsCit");
$logger->level($INFO);
my $appender = Log::Log4perl::Appender
    ->new("Log::Dispatch::File",
	  filename => "$FindBin::Bin/../parscit.log",
	  mode => "append",
	  );
my $layout = Log::Log4perl::Layout::PatternLayout
    ->new("%d %p> %F{1}:%L - %m%n");
$appender->layout($layout);
$logger->add_appender($appender);

$logger->info("Server started at ".$daemon->url);

$daemon->handle;


##
# Service Module
#
# Passes control to the ParsCit::Controller module and provides
# a SOAP wrapping for the response.
#
##
package Parser;
use FindBin;
use lib "$FindBin::Bin/../lib";
use ParsCit::Controller;
use ParsCit::Config;
use Time::HiRes qw(tv_interval gettimeofday);
use Log::Log4perl qw(get_logger);

sub extractCitations {
    my ($class, $textFile, $repositoryID) = @_;

#	return SOAP::Data
#	    ->name('citations')
#	    ->type('string')
#	    ->type('base64Binary')
#	    ->value("I'm a citation list"),

#	    SOAP::Data->name('citeFile')
#	    ->type('string')
#	    ->value("I'm a cite file"),

#	    SOAP::Data->name('bodyFile')
#	    ->type('string')
#	    ->value("I'm a body file");

    my $logger = get_logger("ParsCit");
    my $t0 = [gettimeofday];

    my $repositoryLocation;

    if ($repositoryID ne "LOCAL") {
	$repositoryLocation =
	    $ParsCit::Config::repositories{$repositoryID};
	if (!defined $repositoryLocation) {
	    my $msg = "Unknown repository: $repositoryID";

	    $logger->error($msg);
	    die_with_parscitfault('Sender', $msg);

	} else {
	    $textFile = "$repositoryLocation/$textFile";
	}
    }

    if (! -e $textFile) {
	my $msg = "File does not exist: $textFile";
	$logger->error($msg);
	die_with_parscitfault('Sender', $msg);
    }
    if (-d $textFile) {
	my $msg = "Specified file is a directory: $textFile";
	$logger->error($msg);
	die_with_parscitfault('Sender', $msg);
    }

    my ($status, $msg, $rCitations, $rBodyText, $citeFile, $bodyFile) =
	ParsCit::Controller::extractCitationsImpl($textFile, 1);

    if ($status > 0) {

	my $relCiteFile = makeRelative($citeFile, $repositoryLocation);
	my $relBodyFile = makeRelative($bodyFile, $repositoryLocation);

	my $rXML = ParsCit::Controller::buildXMLResponse($rCitations);
	my $elapsed = tv_interval($t0, [gettimeofday]);
	$logger->info("extractCitations: $textFile $elapsed");

#	$logger->info($$rXML);

#	$$rXML =~ tr/\0-\x{ff}//;

	return SOAP::Data
	    ->name('citations')
	    ->type('string')
#	    ->type('base64Binary')
	    ->value(Encode::encode_utf8($$rXML)),

	    SOAP::Data->name('citeFile')
	    ->type('string')
	    ->value($relCiteFile),

	    SOAP::Data->name('bodyFile')
	    ->type('string')
	    ->value($relBodyFile);

    } else {

	$logger->error($msg);

	unlink $citeFile;
	unlink $bodyFile;

	die_with_parscitfault('Receiver', $msg);
    }

} # extractCitations


sub die_with_parscitfault {
    my ($faultcode, $msg) = @_;

    my $uri = $ParsCit::Config::URI;
    my $obj = SOAP::Data
	->name('ParsCitFault' =>
	       \SOAP::Data->value(SOAP::Data->name('message' => $msg)))
	->uri($uri);

    my $serverURL = $ParsCit::Config::serverURL;

    die SOAP::Fault
	->faultcode($faultcode)
	->faultstring($msg)
	->faultdetail($obj)
	->faultactor($serverURL);

} # die_with_parscitfault


sub makeRelative {
    my ($fpath, $repLoc) = @_;
    if (!defined $repLoc || $repLoc =~ /^\s*$/) {
	return $fpath;
    }
    my $newPath = substr $fpath, length($repLoc);
    $newPath =~ s/^\/+//;
    return $newPath;

} # makeRelative


1;
