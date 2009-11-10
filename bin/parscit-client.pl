#!/usr/bin/perl -CSD
#
# Simple SOAP client for the ParsCit web service.
#
# Isaac Councill, 07/24/07
#
use strict;
use encoding 'utf8';
use utf8;
use SOAP::Lite +trace=>'debug';
use MIME::Base64;
use FindBin;

my $textFile = $ARGV[0];
my $repositoryID = $ARGV[1];

if (!defined $textFile || !defined $repositoryID) {
    print "Usage: $0 textFile repositoryID\n".
	"Specify \"LOCAL\" as repository if using local file system.\n";
    exit;
}

my $wsdl = "$FindBin::Bin/../wsdl/ParsCit.wsdl";

my $parsCitService = SOAP::Lite
    ->service("file:$wsdl")
    ->on_fault(
	       sub {
		   my($soap, $res) = @_;
		   die ref $res ? $res->faultstring :
		       $soap->transport->status;
	       });

my ($citations, $citeFile, $bodyFile) =
    $parsCitService->extractCitations($textFile, $repositoryID);

#print "$citations\n";
#print "CITEFILE: $citeFile\n";
#print "BODYFILE: $bodyFile\n";

