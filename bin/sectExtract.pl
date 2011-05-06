#!/usr/bin/perl -wT

# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Wed, 03 Mar 2010 00:36:36
# Modified from template by Min-Yen Kan <kanmy@comp.nus.edu.sg>

require 5.0;
use strict;
use Getopt::Long;

# I do not know a better solution to find a lib path in -T mode.
# So if you know a better solution, I'd be glad to hear.
# See this http://www.perlmonks.org/?node_id=585299 for why I 
# used the below code
use FindBin;

my $path;
BEGIN 
{
	if ($FindBin::Bin =~ /(.*)/) { $path = $1; }
}

use lib "$path/../lib";

use SectLabel::Config;
use SectLabel::Controller;

### USER customizable section
$0 =~ /([^\/]+)$/; my $progname = $1;
my $outputVersion = "1.0";
### END user customizable section

sub License {
  print STDERR "# Copyright 2009 \251 by Luong Minh Thang\n";
}

### HELP Sub-procedure
sub Help {
  print STDERR "usage: $progname -h\t[invokes help]\n";
  print STDERR "       $progname -in inFile [-out outFile -no-xmlInput -no-xmlOutput -log -new]\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
  print STDERR "\t-out: indicate output file (if not specified output to STDOUT)\n";
  print STDERR "\t-no-xmlInput: indicate that input is normal text file (default: assume XML file from Omnipage-multiple pages concatenated)\n";
  print STDERR "\t-no-xmlOutput: do not wrap results in XML format (default: xmlOutput)\n";
  print STDERR "\t-log: output debugging messages\n";
}
my $QUIET = 0;
my $HELP = 0;
my $inFile = undef;
my $outFile = undef;
my $isXmlInput = 1;
my $isXmlOutput = 1;
my $isDebug = 0;
my $isNew = 0; # if = 1, use processOmniXml_new.pl
$HELP = 1 unless GetOptions('in=s' => \$inFile,
			    'out=s' => \$outFile,
			    'xmlInput!' => \$isXmlInput,
			    'xmlOutput!' => \$isXmlOutput,
			    'log' => \$isDebug,
			    'new' => \$isNew,
			    'h' => \$HELP,
			    'q' => \$QUIET);

if ($HELP || !defined $inFile) {
  Help();
  exit(0);
}

if (!$QUIET) {
  License();
}

### Untaint ###
$inFile = untaintPath($inFile);
my $envPath = $ENV{'PATH'};
$envPath = untaintPath($envPath);
$ENV{'PATH'} = $envPath;
### End untaint ###

my $modelFile = $isXmlInput? $SectLabel::Config::modelXmlFile : $SectLabel::Config::modelFile;
$modelFile = "$path/../$modelFile";
my $configFile = $isXmlInput ? $SectLabel::Config::configXmlFile : $SectLabel::Config::configFile;
$configFile = "$path/../$configFile";

if($isXmlInput){
  my $xmlInFile = newTmpFile();
  $xmlInFile = untaintPath($xmlInFile);
  my $cmd = "$path/sectLabel/";
  $cmd .= ($isNew) ? "processOmniXMLv2.pl" : "processOmniXML.pl";
  $cmd .= " -in $inFile -out $xmlInFile -xmlFeature -decode";
  execute($cmd);
  $inFile = $xmlInFile;
}

my $dictFile = $SectLabel::Config::dictFile;
$dictFile = "$path/../$dictFile";

my $funcFile = $SectLabel::Config::funcFile;
$funcFile = "$path/../$funcFile";
my $rXML = SectLabel::Controller::extractSection($inFile, $isXmlOutput, $modelFile, $dictFile, $funcFile, $configFile, $isXmlInput, $isDebug);

if($isXmlInput){
  unlink($inFile);
}

if (defined $outFile) {
  $outFile = untaintPath($outFile);
  
  open (OUT, ">:utf8", $outFile) or die "Could not open $outFile for writing: $!";
  print OUT $$rXML;
  close OUT;
} else {
  print "$$rXML";
}

sub untaintPath {
  my ($path) = @_;

  if ( $path =~ /^([-_\/\w\.\d: ]+)$/ ) {
    $path = $1;
  } else {
    die "Bad path $path\n";
  }

  return $path;
}

sub untaint {
  my ($s) = @_;
  if ($s =~ /^([\w \-\@\(\),\.\/<>]+)$/) {
    $s = $1;               # $data now untainted
  } else {
    die "Bad data in $s";  # log this somewhere
  }
  return $s;
}

sub execute {
  my ($cmd) = @_;
  print STDERR "Executing: $cmd\n";
  $cmd = untaint($cmd);
  system($cmd);
}

sub newTmpFile {
  my $tmpFile = `date '+%Y%m%d-%H%M%S-$$'`;
  chomp($tmpFile);
  return $tmpFile;
}
