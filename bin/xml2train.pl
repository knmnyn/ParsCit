#!/usr/bin/perl
# Author: Do Hoang Nhat Huy <dcsdhnh@nus.edu.sg>, generated at Fri, 3 Dec 2010 14:36:00
# Modified from template by Min-Yen Kan <kanmy@comp.nus.edu.sg>
require 5.0;
use strict;

use FindBin;
use Getopt::Long;

# I do not know a better solution to find a lib path in -T mode.
# So if you know a better solution, I'd be glad to hear.
# See this http://www.perlmonks.org/?node_id=585299 for why I used the below code
my $path;	# Path to Parscit binary directory
BEGIN 
{
	if ($FindBin::Bin =~ /(.*)/) { $path  = $1; }
}

use lib "$path/../lib";

# Local libraries
use Omni::Omnidoc;
use ParsCit::Tr2crfpp;
use ParsCit::PreProcess;
# Dependencies


### USER customizable section
my $version = "1.0";
$0 =~ /([^\/]+)$/; my $progname = $1;
### END user customizable section

sub License 
{
	print STDERR "# Copyright 2011 \251 by Do Hoang Nhat Huy\n";
}

### HELP Sub-procedure
sub Help 
{
	print STDERR "Process Omnipage XML output (Reference Section Only) and extract text lines together with other XML information\n";
	print STDERR "usage: $progname -h\t[invokes help]\n";
  	print STDERR "       $progname -in xmlfile -out outfile -opt option [-codec -app]\n";
 	print STDERR "Options:\n";
  	print STDERR "\t-q		\tQuiet Mode (don't echo license)\n";
  	print STDERR "\t-in		\tXML input from Omnipage\n";
  	print STDERR "\t-out	\tOutput file\n";
  	print STDERR "\t-codec	\tCodec of the input XML: utf-16 or utf-8. Default is utf-8\n";
  	print STDERR "\t-opt	\tOptio: train (output is train file for crf++) or xml (output is xml features). Default is train\n";
}

my $help	= 0;
my $quite	= 0;
my $infile	= undef;
my $outfile	= undef;
my $option	= "train";
my $codec	= "utf-8";

$help = 1 unless GetOptions('in=s'		=> \$infile,
			 				'out=s'		=> \$outfile,
							'opt=s'		=> \$option,
							'codec=s'	=> \$codec,
			 				'h' 		=> \$help,
							'q' 		=> \$quite);

if ($help || !defined $infile || !defined $outfile) 
{
	Help();
	exit(0);
}

if (!$quite) 
{
	License();
}

# Sanity check
if (($option ne "train") && ($option ne "xml"))
{
	die "Die: -opt must equal \"train\" or \"xml\".\n";
}

if (($codec ne "utf-8") && ($codec ne "utf-16"))
{
	die "Die: -codec must equal \"utf-8\" or \"utf-16\".\n";
}

# Untaint check
$infile		= UntaintPath($infile);
$outfile 	= UntaintPath($outfile);

$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
# End untaint check

# MAIN
my $infile_utf8 = $infile . "-utf8";
if ($codec eq "utf-16") { Convert($infile, "UTF16", $infile_utf8, "UTF8"); }

if (! open(IN, "<:utf8", $infile)) { return (-1, "Could not open xml file " . $infile . ": " . $!); }
my $xml = do { local $/; <IN> };
close IN;

# Cleanup
CleanUp(\$xml);

# New document
my $doc = new Omni::Omnidoc();
$doc->set_raw($xml);

# Extract the reference portion from the XML
my ($start_ref, $end_ref, $rcite_text_from_xml) = ParsCit::PreProcess::findCitationTextXML($doc);

if ($option eq "train")
{
	# Prepare to split unmarked reference portion
	my $tmp_file = ParsCit::Tr2crfpp::prepDataUnmarked($doc, $start_ref, $end_ref);

	# Save the temporary file
	my $cmd = "mv " . $tmp_file . " " . $outfile;

	Execute($cmd);
}
else
{
	
}

# END

# Convert the input XML
sub Convert
{
	my ($from_file, $from_encode, $to_file, $to_encode, $log) = @_;
	
	# Call iconv program
	my $cmd = "iconv" . " -f " . $from_encode . " -t " . $to_encode . " " . $from_file . " -o " . $to_file;
	
	# Transformation
	Execute($cmd);
}

# Clean up the input XML
sub CleanUp
{
	my ($ref_xml) = @_;
	
	# Remove <?xml version="1.0" encoding="UTF-8"?>
	$$ref_xml =~ s/<\?xml.+?>\n//g;
	# Remove <!--XML document generated using OCR technology from ScanSoft, Inc.-->
	$$ref_xml =~ s/<\!\-\-XML.+?>\n//g; 
	# Add the root tag
	$$ref_xml = "<root>" . "\n" . $$ref_xml . "\n" . "</root>";	
}

sub UntaintPath 
{
	my ($path) = @_;

	if ($path =~ /^([-_:" \/\w\.%\p{C}\p{P}]+)$/ ) 
	{
		$path = $1;
	} 
	else 
	{
		die "Bad path \"$path\"\n";
	}

	return $path;
}

sub Untaint 
{
	my ($s) = @_;
	if ($s =~ /^([\w \-\@\(\),\.\/>\p{C}\p{P}]+)$/) 
	{
		$s = $1;               # $data now untainted
	} 
	else 
	{
		die "Bad data in $s";  # log this somewhere
	}
	return $s;
}

sub Execute 
{
	my ($cmd) = @_;
	print STDERR "Executing: $cmd\n";
	system($cmd);
}



