#!/usr/bin/perl -wT
# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Wed, 17 Mar 2010 17:36:26

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
use lib "$path/../lib";
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
  print STDERR "       $progname -in inFile -out outFile -l labelFile\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
}
my $QUIET = 0;
my $HELP = 0;
my $inFile = undef;
my $outFile = undef;
my $labelFile = undef;
$HELP = 1 unless GetOptions('in=s' => \$inFile,
			    'out=s' => \$outFile,
			    'l=s' => \$labelFile,
			    'h' => \$HELP,
			    'q' => \$QUIET);

if ($HELP || !defined $inFile || !defined $outFile || !defined $labelFile) {
  Help();
  exit(0);
}

if (!$QUIET) {
  License();
}

### Untaint ###
$inFile = untaintPath($inFile);
$outFile = untaintPath($outFile);
$labelFile = untaintPath($labelFile);
my $envPath = $ENV{'PATH'};
$envPath = untaintPath($envPath);
$ENV{'PATH'} = $envPath;
### End untaint ###


my $labelCount = getNumLines($labelFile);

my %labelMap = ();
loadLabels($labelFile, \%labelMap);
my $count =  processParaFile($inFile, \%labelMap, $outFile);

if($count != $labelCount){
  die "Die: $count != $labelCount\n";
}

sub processParaFile{
  my ($inFile, $labelMap, $outFile) = @_;
  
  #file I/O
  if(! (-e $inFile)){
    die "#File \"$inFile\" doesn't exist";
  }
  open(IF, "<:utf8", $inFile) || die "#Can't open file \"$inFile\"";
  open(OF, ">:utf8", $outFile) || die "#Can't open file \"$outFile\"";
  
  #process input file
  my $totalLines = 0;
  my $index;
  my $numLines;
  my $label;
  my $input = "";
  while(<IF>){
    chomp;
    my $paraLine = $_;
    if($paraLine =~ /^\# Para (\d+) (\d+)$/){
      # output previous results
      if($input ne ""){
	print OF "# Para $index $numLines $label\n";
	print STDERR "# Para $index $numLines $label\n";
	print OF $input;
      }

      $index = $1;
      $numLines = $2;
      $label = $labelMap->{$index};
      $totalLines += $numLines;      
      $input = "";

      # get new content
      for(my $i=0; $i<$numLines; $i++){
	my $line = <IF>;
	$input .= $line;
      }
    } else {
      die "Die: Para line \"$paraLine\" fails to match\n";
    }
  } # end while <IF>

  if($input ne ""){
    print OF "# Para $index $numLines $label\n";
    print STDERR "# Para $index $numLines $label\n";
    print OF $input;
  }

  
  close IF;
  close OF;
  
  return $totalLines;
}


sub sentDelimit {
  my ($input) = @_;

  my $tmpFile = newTmpFile();
  
  open(OF1, ">:utf8", $tmpFile) || die "#Can't open file \"$tmpFile\"";
  print OF1 $input."\n";  
  close OF1;
  
  execute("java -cp $path/mxtag/mxpost.jar eos.TestEOS $path/mxtag/eos.project < $tmpFile 1>$tmpFile.delimit 2>/dev/null");
  
  my $output = "";
  open(IF1, "<:utf8", "$tmpFile.delimit") || die "#Can't open file \"$tmpFile.delimit\"";
  while(<IF1>){
    $output .= $_;
  }
  close IF1;
  
  unlink($tmpFile);
  unlink("$tmpFile.delimit");

  return $output;
}

sub loadLabels{
  my ($inFile, $labelMap) = @_;
  
  #file I/O
  if(! (-e $inFile)){
    die "#File \"$inFile\" doesn't exist";
  }
  open(IF, "<:utf8", $inFile) || die "#Can't open file \"$inFile\"";
  
  #process input file
  my $index = 0;
  while(<IF>){
    chomp;
    
    if(/^(\w+)\s/){
      $labelMap->{$index} = $1;
      $index++;
    } else {
      die "Die: line \"$_\" fails to match!\n";
    }
  }
  close IF;
}

# get the number of lines in a file
sub getNumLines {
  my ($inFile) = @_;

  ### Count & verify the totalLines ###
  chomp(my $tmp = `wc -l $inFile`);
  my @tokens = split(/ /, $tmp);
  return $tokens[0];
}

sub untaintPath {
  my ($path) = @_;

  if ( $path =~ /^([-_\/\w\.\d: ]*)$/ ) {
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
  $tmpFile = untaint($tmpFile);
  return $tmpFile;
}
