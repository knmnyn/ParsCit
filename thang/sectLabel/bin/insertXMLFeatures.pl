#!/usr/bin/perl -wT
# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Thu, 24 Dec 2009 22:46:38

# Modified from template by Min-Yen Kan <kanmy@comp.nus.edu.sg>

require 5.0;
use strict;
use Getopt::Long;

# I do not know a better solution to find a lib path in -T mode.
# So if you know a better solution, I'd be glad to hear.
# See this http://www.perlmonks.org/?node_id=585299 for why I used the below code
use FindBin;
my $path;
BEGIN {
  if ($FindBin::Bin =~ /(.*)/) {
    $path = $1;
  }
}
use lib "$path/../../lib";
#use Utility::Controller;
#use Morphology::Controller;

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
  print STDERR "       $progname -in inFile -xml xmlFile -out outFile [-log logFile]\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
}
my $QUIET = 0;
my $HELP = 0;
my $inFile = undef;
my $xmlFile = undef;
my $outFile = undef;
my $logFile = "";
$HELP = 1 unless GetOptions('in=s' => \$inFile,
			    'xml=s' => \$xmlFile,
			    'out=s' => \$outFile,
			    'log=s' => \$logFile,
			    'h' => \$HELP,
			    'q' => \$QUIET);

if ($HELP || !defined $inFile || !defined $xmlFile || !defined $outFile) {
  Help();
  exit(0);
}

if (!$QUIET) {
  License();
}

### Untaint ###
$inFile = untaintPath($inFile);
$xmlFile = untaintPath($xmlFile);
$outFile = untaintPath($outFile);
$logFile = untaintPath($logFile);
my $envPath = $ENV{'PATH'};
$envPath = untaintPath($envPath);
$ENV{'PATH'} = $envPath;
### End untaint ###

processFile($inFile, $xmlFile, $outFile, $logFile);

sub processFile{
  my ($inFile, $xmlFile, $outFile, $logFile) = @_;
  
  #file I/O
  if(! (-e $inFile)){
    die "#File \"$inFile\" doesn't exist";
  }
  open(IF, "<:utf8", $inFile) || die "#Can't open file \"$inFile\"";
  if(! (-e $xmlFile)){
    die "#File \"$xmlFile\" doesn't exist";
  }
  open(XML, "<:utf8", $xmlFile) || die "#Can't open file \"$xmlFile\"";

  open(OF, ">:utf8", $outFile) || die "#Can't open file \"$outFile\"";

  if($logFile ne ""){
    open(INLOG, ">>:utf8", "$logFile.in") || die "#Can't open file \"$logFile.in\"";
    open(XMLLOG, ">>:utf8", "$logFile.xml") || die "#Can't open file \"$logFile.xml\"";
    print INLOG "\n### $inFile ###\n";
    print XMLLOG "\n### $inFile ###\n";
  }

  my $inLine;
  my $xmlLine;

  #process input file
  binmode(STDERR, ":utf8");
  my $id = -1;
  while(<IF>){
    $id++;
    chomp;
    $inLine = $_;

    if(eof(XML)){
      die "Die: lack value in XML file at line id $id\n";
    } else {
      $xmlLine = <XML>; chomp($xmlLine);
    }

    my $inContent;
    if($inLine =~ /^.+ \|\|\| (.+)$/){
      $inContent = $1;
    } else {
      $inContent = $inLine;
    }
    $inContent =~ s/^\s+//;
    $inContent =~ s/\s+$//;

    if($xmlLine =~ /^(.+) \|XML\| (.+)$/){
      my $xmlContent = $1;
      my $xmlFeature = $2;
      $xmlContent =~ s/^\s+//;
      $xmlContent =~ s/\s+$//;
      
      if($inContent ne $xmlContent && $logFile ne ""){
	print INLOG "$inContent\n";
	print XMLLOG "$xmlContent\n";
      }
      print OF "$inLine |XML| $xmlFeature\n";
    } else {
      die "Die: xml line \"$xmlLine\" doesn't match\n";
    }
  }
  
  if(!eof(XML)){
    die "Die: lack value in in file at line id $id\n";
  }
  if($logFile ne ""){
    close INLOG;
    close XMLLOG;
  }

  close IF;
  close OF;
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
