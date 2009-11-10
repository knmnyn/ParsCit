#!/usr/bin/perl -CSD
#
# Simple command script for executing ParsCit in an
# offline mode (direct API call instead of going through
# the web service).
#
# Isaac Councill, 08/23/07
#
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use ParsCit::Controller;

my $textFile = $ARGV[0];
my $outFile = $ARGV[1];

if (!defined $textFile) {
    print "Usage: $0 textfile [outfile]\n";
    exit;
}

my $rXML =
    ParsCit::Controller::extractCitationsAlreadySegmented($textFile);

if (defined $outFile) {
    open (OUT, ">$outFile") or die "Could not open $outFile for writing: $!";
    print OUT $$rXML;
    close OUT;
} else {
    print "$$rXML";
}
