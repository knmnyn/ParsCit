#!/usr/bin/perl -CSD
#
# Simple command script for executing ParsCit in an
# offline mode (direct API call instead of going through
# the web service).
#
# Min-Yen Kan (Thu Feb 28 14:10:28 SGT 2008)
#  Derived from citeExtract.pl
#
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";

use lib "/home/wing.nus/tools/languages/programming/perl-5.10.0/lib/5.10.0";
use lib "/home/wing.nus/tools/languages/programming/perl-5.10.0/lib/site_perl/5.10.0";

use ParsCit::Controller;
use CSXUtil::SafeText qw(cleanAll cleanXML);

my $textFile = $ARGV[0];
my $outFile = $ARGV[1];

if (!defined $textFile) {
    print "Usage: $0 textfile [outfile]\n";
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
my $outFile = $tmpFile."_dec";
my @validCitations = ();

my $xml = "";
$xml .= "<algorithm name=\"$ParsCit::Config::algorithmName\" version=\"$ParsCit::Config::algorithmVersion\">\n";
$xml .= "<citationList>\n";
if (ParsCit::Tr2crfpp::Decode($tmpFile, $outFile)) {
    my ($rRawXML, $rCiteInfo, $tstatus, $tmsg) =
	ParsCit::PostProcess::ReadAndNormalize($outFile);
    if ($tstatus <= 0) {
	return ($tstatus, $msg, undef, undef);
    }
    my @citeInfo = @{$rCiteInfo};
    for (my $i=0; $i<=$#citeInfo; $i++) {
	my %citeInfo = %{$citeInfo[$i]};
	$xml .= "<citation>\n";
	foreach my $key (keys %citeInfo) {
	    if ($key eq "authors" || $key eq "editors") {
		my $singular = $key;
		chop $singular;
		$xml .= "<$key>\n";
		foreach my $person (@{$citeInfo{$key}}) {
			cleanAll(\$person);
		    $xml .= "<$singular>$person</$singular>\n";
		}
		$xml .= "</$key>\n";
	    } 
		elsif ($key eq "volume") 
		{
			if (scalar(@{$citeInfo{$key}}) > 0)
			{
				# Main volume
				cleanAll(\$citeInfo{$key}[ 0 ]);
				$xml .= "<$key>" . $citeInfo{$key}[ 0 ] . "</$key>\n";

				# Sub-volume, issue
				for (my $i = 1; $i < scalar(@{$citeInfo{$key}}); $i++)
				{
					cleanAll(\$citeInfo{$key}[ $i ]);
					$xml .= "<issue>" . $citeInfo{$key}[ $i ] . "</issue>\n";
				}
    		}
		}
		else {
		cleanAll(\$citeInfo{$key});
		$xml .= "<$key>$citeInfo{$key}</$key>\n";
	    }
	}
	$xml .= "</citation>\n";
    }
    $xml .= "</citationList>\n</algorithm>\n";
}

unlink($tmpFile);
unlink($outFile);

print $xml;
