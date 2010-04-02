#!/usr/bin/perl -wT
# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Tue, 19 Jan 2010 21:59:51

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
  print STDERR "       $progname -in inDir\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
}
my $QUIET = 0;
my $HELP = 0;
my $inDir = undef;

$HELP = 1 unless GetOptions('in=s' => \$inDir,
			    'h' => \$HELP,
			    'q' => \$QUIET);

if ($HELP || !defined $inDir) {
  Help();
  exit(0);
}

if (!$QUIET) {
  License();
}

### Untaint ###
$inDir = untaintPath($inDir);
my $envPath = $ENV{'PATH'};
$envPath = untaintPath($envPath);
$ENV{'PATH'} = $envPath;
### End untaint ###


my $allOutput = "$inDir/all.out";
#execute("$path/../../../bin/sectLabel/conlleval_modified.pl -r -c -d \"\t\" < $allOutput");

my $inFile = "$inDir/evaluation.stdout";

processFile($inFile);

sub processFile{
  my ($inFile) = @_;
  
  print STDERR "# $inFile\n";
  #file I/O
  if(! (-e $inFile)){
    die "#File \"$inFile\" doesn't exist";
  }
  open(IF, "<:utf8", $inFile) || die "#Can't open file \"$inFile\"";
  
  my $isStart = 0;
  my $count = 0;
  my $totalP = 0;
  my $totalR = 0;
  my $totalFB1 = 0;
  #process input file
  
  my $output = "";
  while(<IF>){
    chomp;
    if(/accuracy:/){
      $isStart = 1;
      print STDERR "$_\n";
    } else {
      if($isStart){
	#           address: precision:  89.47%; recall:  53.12%; FB1:  66.67  38
	if(/^\s*(\w+?): precision:\s+([\d\.]+?)%; recall:\s+([\d\.]+?)%; FB1:\s+?([\d\.]+)/){
	  $count++;
	  $totalP += $2;
	  $totalR += $3;
	  $totalFB1 += $4;
	  $output .= "$1\t$4\n";
#	  print STDERR "\"$1\"\t\"$2\"\t\"$3\"\n";
	}
      }
    }
  }
  
  my $P = ($totalP/$count);
  my $R = ($totalR/$count);
#  my $F = (2*$P*$R)/($P + $R);
  my $FB1 = ($totalFB1/$count);

#  print STDERR "$P\t$R\t$F\n";
  print STDERR "avgP = ".round($P)."%\tavgR = ".round($R)."%\tavgFB1 = ".round($FB1)."\n";
  print STDERR $output;
  close IF;
}

sub round {
  my ($num) = @_;
  return int($num*100 + 0.5)/100;
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
  if ($s =~ /^([\w \-\@\(\),\.\/<>\"\s]+)$/) {
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
