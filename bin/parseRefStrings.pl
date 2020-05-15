#!/usr/bin/perl -CSD
#
# Simple command script for executing ParsCit in an
# offline mode (direct API call instead of going through
# the web service).
#
# Min-Yen Kan (Thu Feb 28 14:10:28 SGT 2008)
#  Derived from citeExtract.pl
#
# Matthias Bösinger (29.03.2016)
# -> all changes marked with: MB1

use strict;
use FindBin;
use Getopt::Long;
use lib "$FindBin::Bin/../lib";

use lib "/home/wing.nus/tools/languages/programming/perl-5.10.0/lib/5.10.0";
use lib "/home/wing.nus/tools/languages/programming/perl-5.10.0/lib/site_perl/5.10.0";

use ParsCit::Controller;
use CSXUtil::SafeText qw(cleanAll cleanXML);
use ParsCit::ConfigLang;

###
# set standard encoding to UTF-8 
# MB1
###
binmode STDIN, ":encoding(UTF-8)";
binmode STDOUT, ":encoding(UTF-8)";

### Get additional parameter (language parameter (english as default), split parameter, keep temp files parameter) - MB1
my $lang = "en";
my $split = '';
my $keep = '';
if (!GetOptions("lang=s" => \$lang, "split" => \$split, "keep" => \$keep)) {
	print "Usage: $0 textfile outfile [-lang=en|de] [-split] [-keep]\n";
    exit;
}
# initialize language config
if (!ParsCit::ConfigLang::Init($lang)) {
	print "Usage: $0 textfile outfile [-lang=en|de] [-split] [-keep]\n";
    exit;
}
### End (additional parameter) - MB1

my $textFile = $ARGV[0];
my $outFile = $ARGV[1];

if (!defined $textFile) {
    print "Usage: $0 textfile outfile [-lang=en|de] [-split] [-keep]\n";	# Updated - MB1
    exit;
}

# open (IF, $textFile) || die "Couldn't open text file \"textFile\"!";
open (IF, "<:utf8", $textFile) || die "Couldn't open text file \"textFile\"!"; 	# set to utf-8-encoding - MB1
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
my $tmpFile = ParsCit::Tr2crfpp::PrepData(\$normalizedCiteText, $textFile, $split); 	# Additional parameter 'split' - MB1
my $outTmpFile = $tmpFile."_dec"; 	# Changed name from '$outFile'. Otherwise name conflict with 'outFile' from $ARGV[1]; - MB1
my @validCitations = ();

my $xml = "";
$xml .= "<algorithm name=\"$ParsCit::Config::algorithmName\" version=\"$ParsCit::Config::algorithmVersion\">\n";
$xml .= "<citationList>\n";
if (ParsCit::Tr2crfpp::Decode($tmpFile, $outTmpFile)) {
    my ($rRawXML, $rCiteInfo, $tstatus, $tmsg) =
	ParsCit::PostProcess::ReadAndNormalize($outTmpFile);
    if ($tstatus <= 0) {
	return ($tstatus, $msg, undef, undef);
    }
    my @citeInfo = @{$rCiteInfo};
    for (my $i=0; $i<=$#citeInfo; $i++) {
	my %citeInfo = %{$citeInfo[$i]};
	$xml .= "<citation>\n";
	foreach my $key (keys %citeInfo) {
	    if ($key eq "authors" || $key eq "editors") 
	    {
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

###
# tmp-files are kept if parameter has been set.
# MB1
###
unless ($keep) { 
	unlink($tmpFile); 
	unlink($outTmpFile);
}

###
# If outFile has been passed as parameter the result .xml will be print to this file.
# Else the result .xml will be print to standard out.
# MB1
###
if (open(OUT, ">:utf8", $outFile)) {
	print OUT $xml;
}
else {
	print $xml;
}

