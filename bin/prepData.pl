#!/usr/bin/perl
#
# Script to transform reference strings to crf++ compatible data.
# By doing so, CRF++ can be used manually with the trasnformed reference data.
#
# Derived from 'parseRefStrings.pl'
#
# MB1 (March 2016)

use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";

use lib "/home/wing.nus/tools/languages/programming/perl-5.10.0/lib/5.10.0";
use lib "/home/wing.nus/tools/languages/programming/perl-5.10.0/lib/site_perl/5.10.0";

use ParsCit::Controller;
use CSXUtil::SafeText qw(cleanAll cleanXML);

my $textFile = $ARGV[0];
my $outFile = $ARGV[1];

if (!defined $textFile || !defined $outFile) {
    print "Usage: $0 textfile outfile\n";
    exit;
}

open (IF, $textFile) || die "Couldn't open text file \"textFile\"!";
my $normalizedCiteText = "";
my $line = 0;
while (<IF>) {
  chop;
  # Tr2cfpp needs an enclosing tag for initial class seed.
  $normalizedCiteText .= "<title> " . $_ . " </title>\n";
  $line++;
}
close (IF);

if ($line == 0) {
  # Stop - nothing left to do.
  exit();
}

our $msg = "";
my $tmpFile = ParsCit::Tr2crfpp::PrepData(\$normalizedCiteText, $textFile);

open (TF, $tmpFile) || die "Couldn't open tmp file!";
open (OF, ">$outFile") || die "Couldn't open out file!";
while (<TF>) {
	chop;
	print OF $_ . "\n";
}

close(TF);
close(OF);

unlink($tmpFile);

