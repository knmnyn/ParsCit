#!/usr/bin/perl -wT
# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Thu, 08 Apr 2010 17:59:19

# Modified from template by Min-Yen Kan <kanmy@comp.nus.edu.sg>

require 5.0;
use strict;
use Getopt::Long;

# I do not know a better solution to find a lib path in -T mode.
# So if you know a better solution, I'd be glad to hear.
# See this http://www.perlmonks.org/?node_id=585299 for why I used the below code
use FindBin;
FindBin::again(); # to get correct path in case 2 scripts in different directories use FindBin
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
  print STDERR "Convert SectLabel training file (e.g. doc/sectLabel.tagged.txt) from single- to multi-line format\n";
  print STDERR "usage: $progname -h\t[invokes help]\n";
  print STDERR "       $progname -in inFile -out outFile [-p prefix]\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
  print STDERR "\t-p prefix: to indicate that the XML tag in inFile will have the format <\$prefix\$tag> .+ </\$prefix\$tag> (default prefix = \"\"\n";
}
my $QUIET = 0;
my $HELP = 0;
my $inFile = undef;
my $outFile = undef;
my $prefix = "";
$HELP = 1 unless GetOptions('in=s' => \$inFile,
			    'out=s' => \$outFile,
			    'p=s' => \$prefix,
			    'h' => \$HELP,
			    'q' => \$QUIET);

if ($HELP || !defined $inFile || !defined $outFile) {
  Help();
  exit(0);
}

if (!$QUIET) {
  License();
}

### Untaint ###
$inFile = untaintPath($inFile);
$outFile = untaintPath($outFile);
my $envPath = $ENV{'PATH'};
$envPath = untaintPath($envPath);
$ENV{'PATH'} = $envPath;
### End untaint ###

processFile($inFile, $outFile);

sub processFile{
  my ($inFile, $outFile) = @_;
  
  #file I/O
  if(! (-e $inFile)){
    die "#File \"$inFile\" doesn't exist";
  }
  open(IF, "<:utf8", $inFile) || die "#Can't open file \"$inFile\"";
  open(OF, ">:utf8", $outFile) || die "#Can't open file \"$outFile\"";
  
  binmode(STDERR, ":utf8");
  #process input file

  my $lineId = 0;
  while(<IF>){
    if (/^\#/) { next; }			# skip comments
    elsif (/^\s+$/) { next; }		# skip blank lines
    else {
      chomp;
      my $line = $_;
      while ($line =~ /<$prefix([\w\-]+?)> (.*?) \+L\+ <\/$prefix([\w\-]+?)>/g){ # match <tag> .* </tag>
	if($1 ne $3){
	  die "Die in single2multi.pl $lineId: begin tag \"$1\" ne end tag \"$3\"\n";
	} else {
	  my $tag = $1;
	  my $content = $2;
	  my @lines = split(/ \+L\+ /, $content);
	  foreach my $line (@lines){
	    if($line eq "") { next; }
	    print OF "$tag ||| $line\n";
	  }
	} 
      }
      
      my $postMatch = $';
      if($postMatch !~ /^\s*$/){
	die "Die in single2multi.pl $lineId: non-empty post match \"$postMatch\"\n";
      }
      print OF "\n"; # separate documents
      $lineId++;
    }
#    last;
  }
  
  close IF;
  close OF;
}

sub untaintPath {
  my ($path) = @_;

  if ( $path =~ /^([-_\/\w\.\d: \p{P}]+)$/ ) { #\p{C}\p{P}
    $path = $1;
  } else {
    die "Bad path $path\n";
  }

  return $path;
}

sub untaint {
  my ($s) = @_;
  if ($s =~ /^([\w \-\@\(\),\.\/<>\p{P}]+)$/) { #\p{C}\p{P}
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
