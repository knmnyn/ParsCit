#!/usr/bin/perl -wT
# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Fri, 06 Nov 2009 03:14:22

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
  print STDERR "       $progname -in fileList -dir inDir -out outFile\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
}
my $QUIET = 0;
my $HELP = 0;
my $inDir = undef;
my $fileList = undef;
my $outFile = undef;

$HELP = 1 unless GetOptions('in=s' => \$fileList,
			    'dir=s' => \$inDir,
			    'out=s' => \$outFile,
			    'h' => \$HELP,
			    'q' => \$QUIET);

if ($HELP || !defined $fileList || !defined $inDir || !defined $outFile) {
  Help();
  exit(0);
}

if (!$QUIET) {
  License();
}

### Untaint ###
$fileList = untaintPath($fileList);
$inDir = untaintPath($inDir);
$outFile = untaintPath($outFile);
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
### End untaint ###

processFile($fileList, $inDir, $outFile);

sub processFile{
  my ($fileList, $inDir, $outFile) = @_;
  
  #file I/O
  if(! (-e $fileList)){
    die "#File \"$fileList\" doesn't exist";
  }
  open(IF, "<:utf8", $fileList) || die "#Can't open file \"$fileList\"";
  open(OF, ">:utf8", $outFile) || die "#Can't open file \"$outFile\"";
  
  #process input file
  while(<IF>){
    chomp;
    
    my $inFile1 = "$inDir/$_.ahea";
    my $inFile2 = "$inDir/$_.info";

    open(IF1, "<:utf8", $inFile1) || die "#Can't open file \"$inFile1\"";
    open(IF2, "<:utf8", $inFile2) || die "#Can't open file \"$inFile2\"";
    my @lines1 = <IF1>;
    my @lines2 = <IF2>;
    if(scalar(@lines1) != scalar(@lines2)){
     die "#! Different num of lines: $inFile1\t$inFile2\n";
    }
    
    my $n = scalar(@lines1);
    for(my $i=0; $i<$n; $i++){
      my $line1 = $lines1[$i];
      chomp $line1;
      my $line2 = $lines2[$i];
      chomp $line2;

      print OF "thang\tfeature\t$line1\t$line2\n";
    }
    print OF "\n";
    close IF1;
    close IF2;
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
