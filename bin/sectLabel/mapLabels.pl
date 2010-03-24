#!/usr/bin/perl -wT
# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Thu, 03 Dec 2009 02:26:01

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
use Utility::Controller;
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
  print STDERR "       $progname -in inFile -l labelFile -out outFile [-noEmpty]\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
}
my $QUIET = 0;
my $HELP = 0;
my $inFile = undef;
my $labelFile = undef;
my $outFile = undef;
my $isNoEmpty = 0;
$HELP = 1 unless GetOptions('in=s' => \$inFile,
			    'l=s' => \$labelFile,
			    'out=s' => \$outFile,
			    'noEmpty' => \$isNoEmpty,
			    'h' => \$HELP,
			    'q' => \$QUIET);

if ($HELP || !defined $inFile || !defined $labelFile || !defined $outFile) {
  Help();
  exit(0);
}

if (!$QUIET) {
  License();
}

### Untaint ###
$inFile = untaintPath($inFile);
$labelFile = untaintPath($labelFile);
$outFile = untaintPath($outFile);
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
### End untaint ###

print STDERR "# $inFile\n";
processFile($inFile, $labelFile, $outFile);

sub processFile{
  my ($inFile, $labelFile, $outFile) = @_;
  
  #file I/O
  if(! (-e $inFile)){
    die "#File \"$inFile\" doesn't exist";
  }
  open(IF, "<:utf8", $inFile) || die "#Can't open file \"$inFile\"";

  if(! (-e $labelFile)){
    die "#File \"$labelFile\" doesn't exist";
  }
  open(LF, "<:utf8", $labelFile) || die "#Can't open file \"$labelFile\"";

  open(OF, ">:utf8", $outFile) || die "#Can't open file \"$outFile\"";
  my @tmpLines;

  # read inLines
  @tmpLines = <IF>;
  my @inLines = ();
  foreach my $line (@tmpLines){
    chomp($line);
#    if($line !~ /^\s*$/){
      push(@inLines, $line);
#    }
  }

  # read labelLines 
  @tmpLines = <LF>;
  my @labelLines = ();
  foreach my $line (@tmpLines){
    chomp($line);
#    if($line !~ /^\s*$/){
      push(@labelLines, $line);
#    }
  }

  my $numInLines = scalar(@inLines);
  my $numLabelLines = scalar(@labelLines);

  binmode(STDERR, ":utf8");

  #process input file
  my $inLine;
  my $labelLine;
  my $label;
  my $iIndex = 0;
  my $lIndex = 0;
  my $simThres = 0.3;
  while ($iIndex < $numInLines && $lIndex < $numLabelLines){
    $inLine = $inLines[$iIndex];     chomp($inLine);
    $labelLine = $labelLines[$lIndex];     chomp($labelLine);
    if($labelLine =~ /^(.+) \|\|\| (.*)$/){
      $label = $1;
      $labelLine = $2;
    }

    my $inLineCopy = $inLine;
    $inLineCopy =~ s/\s+/ /g;
    if($inLineCopy =~ /^\s*$/) { $inLineCopy = ""; }

    my $labelLineCopy = $labelLine;
    $labelLineCopy =~ s/\s+/ /g;
    if($labelLineCopy =~ /^\s*$/) { $labelLineCopy = ""; }

    if($inLine ne $labelLine && $inLineCopy eq $labelLineCopy){
      print STDERR "# Match ignore cases: \"$inLine\" vs \"$labelLine\"\n";
    }

    if($inLineCopy ne $labelLineCopy){
      my $sim = Utility::Controller::stringSim($inLine, $labelLine, "\\s\+");
      
      if($sim < $simThres) {
	print STDERR "\n# $label\t$sim\n\"$inLine\"\n\"$labelLine\"\n";

	if ($iIndex == ($numInLines-1) || $lIndex == ($numLabelLines-1)){
	  print STDERR "($iIndex == ($numInLines-1) || $lIndex == ($numLabelLines-1))\n";
	  last;
	}

	## find match
	# iIndex + 1 vs lIndex
	my $found = 0;
	$sim = Utility::Controller::stringSim($inLines[$iIndex+1], $labelLine, "\\s\+");
	if($sim >= $simThres) { # iIndex
	  $inLine = $inLines[++$iIndex];
	  print STDERR "# iIndex+1 $label\t$sim\n\"$inLine\"\n\"$labelLine\"\n";
	  $found = 1;
	} 
	
	# iIndex + 2 vs lIndex
	if(!$found && $iIndex < ($numInLines -2)){
	  $sim = Utility::Controller::stringSim($inLines[$iIndex+2], $labelLine, "\\s\+");
	  if($sim >= $simThres) { # iIndex
	    $iIndex += 2;
	    $inLine = $inLines[$iIndex];
	    print STDERR "# iIndex+2 $label\t$sim\n\"$inLine\"\n\"$labelLine\"\n";
	    $found = 1;
	  } 
	}

	# iIndex vs lIndex+1
	if(!$found) {
	  my $tmpLabelLine = $labelLines[$lIndex+1];     chomp($tmpLabelLine);
	  my $tmpLabel;
	  if($tmpLabelLine =~ /^(.+) \|\|\| (.*)$/){
	    $tmpLabel = $1;
	    $tmpLabelLine = $2;
	  }
	  $sim = Utility::Controller::stringSim($inLine, $tmpLabelLine, "\\s\+");
	  if($sim >= $simThres) { # match
	    $label = $tmpLabel;
	    $labelLine = $tmpLabelLine;
	    $lIndex++;

	    print STDERR "# lIndex+1 $label\t$sim\n\"$inLine\"\n\"$labelLine\"\n";
	    $found = 1;
	  }
	} # end if

	# iIndex vs lIndex+1
	if(!$found && $lIndex < ($numLabelLines -2)) {
	  my $tmpLabelLine = $labelLines[$lIndex+2];     chomp($tmpLabelLine);
	  my $tmpLabel;
	  if($tmpLabelLine =~ /^(.+) \|\|\| (.*)$/){
	    $tmpLabel = $1;
	    $tmpLabelLine = $2;
	  }
	  $sim = Utility::Controller::stringSim($inLine, $tmpLabelLine, "\\s\+");
	  if($sim >= $simThres) { # match
	    $label = $tmpLabel;
	    $labelLine = $tmpLabelLine;
	    $lIndex+=2;

	    print STDERR "# lIndex+2 $label\t$sim\n\"$inLine\"\n\"$labelLine\"\n";
	    $found = 1;
	  }
	} # end if

      } # end if sim < simThres
    } # end if inLine ne labelLine

    $iIndex++;
    $lIndex++;

    # inLine is mapped to label $label, output
    my @lines = split(/ \+L\+ /, $inLine);
    foreach my $line (@lines){
      if($isNoEmpty && $line =~ /^\s*$/){
	next;
      } else {
	print OF "$label ||| $line\n";
      }
    }
  }
  
  close IF;
  close OF;
}

sub untaintPath {
  my ($path) = @_;

  if ( $path =~ /^([-_\/\w\.]+)$/ ) {
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
