#!/usr/bin/perl -wT
# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Tue, 20 Oct 2009 15:04:47

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
  print STDERR "\t-opt: option (default = normal)\n";
}
my $QUIET = 0;
my $HELP = 0;
my $fileList = undef;
my $inDir = undef;
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

if(!-d $inDir){
  die "Die: Pdf directory $inDir does not exist.\n";
}

processFile($fileList, $inDir, $outFile);

sub processFile{
  my ($fileList, $inDir, $outFile) = @_;
  
  #file I/O
  if(! (-e $fileList)){
    die "#File \"$fileList\" doesn't exist";
  }
  open(LIST, "<:utf8", $fileList) || die "#Can't open file \"$fileList\"";
  open(OF, ">:utf8", $outFile) || die "#Can't open file \"$outFile\"";
  
  #process input file
  while(<LIST>){
    chomp;
    
    my $name = $_;
    my $inFile = "$inDir/$name";
    print STDERR "\n# $inFile\n";

    #file I/O
    if(! (-e $inFile)){
      die "#File \"$inFile\" doesn't exist";
    }
    open(IF, "<:utf8", $inFile) || die "#Can't open file \"$inFile\"";
    
    my $prevTag = "";
    my $content = "";
    while(<IF>){
      chomp;
      my $line = $_;

      if($line =~ /^(.+) \|\|\| (.*)$/){
	my $tag = $1;
	$line = $2;

	if($tag ne $prevTag && $prevTag ne ""){ # new tag
	  # print old result
	  print OF "<$prevTag> $content</$prevTag> ";
	  
	  # reset
	  $prevTag = $tag;
	  $content = "";
	} else {
	  
	}
	$prevTag = $tag;
	$content .= "$line +L+ ";
      } else {
	die "Die: fail to match \"$line\"\n";
      }
    }
    close IF;
    if($content ne ""){
      print OF "<$prevTag> $content</$prevTag>";
    }
    print OF "\n";
  }
  
  close LIST;
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
  if ($s =~ /^([\w \-\@\(\),\.\/<>\*]+)$/) {
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
