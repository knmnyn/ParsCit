#!/usr/bin/perl -wT
# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Fri, 09 Oct 2009 02:10:37

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
  print STDERR "This program obtains labels from labelFile texts from txtFile, then merge and output to outFile\n";
  print STDERR "usage: $progname -h\t[invokes help]\n";
  print STDERR "       $progname -t txtFile -l labelFile -out outFile\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
}
my $QUIET = 0;
my $HELP = 0;
my $txtFile = undef;
my $labelFile = undef;
my $outFile = undef;
$HELP = 1 unless GetOptions('t=s' => \$txtFile,
			    'l=s' => \$labelFile,
			    'out=s' => \$outFile,
			    'h' => \$HELP,
			    'q' => \$QUIET);

if ($HELP || !defined $txtFile || !defined $labelFile || !defined $outFile) {
  Help();
  exit(0);
}

if (!$QUIET) {
  License();
}

### Untaint ###
$txtFile = untaintPath($txtFile);
$labelFile = untaintPath($labelFile);
$outFile = untaintPath($outFile);
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
### End untaint ###

processFile($txtFile, $labelFile, $outFile);

sub processFile{
  my ($txtFile, $labelFile, $outFile) = @_;
  
  #file I/O
  if(! (-e $txtFile)){
    die "#File \"$txtFile\" doesn't exist";
  }
  open(IF, "<", $txtFile) || die "#Can't open file \"$txtFile\"";

  if(! (-e $labelFile)){
    die "#File \"$labelFile\" doesn't exist";
  }
  open(LABEL, "<", $labelFile) || die "#Can't open file \"$labelFile\"";

  open(OF, ">:utf8", $outFile) || die "#Can't open file \"$outFile\"";
  
  my @inLines = <IF>;
  my @labelLines = <LABEL>;

  if(scalar(@inLines) != scalar(@labelLines)){
    die "Die: different lines $txtFile ".scalar(@inLines)." != ".scalar(@labelLines)."\n";
  }

  my $tag = "";
  for(my $i=0; $i<scalar(@inLines); $i++){
    my $line = $inLines[$i];
    my $label = $labelLines[$i];
    chomp($line);
    chomp($label);

    $line =~ s/\s+$//;
    if($label =~ /(\w+) \|\|\| ?(.*)$/){
      $tag = $1;
      print OF "$tag ||| $line\n";
    } else {
      if($tag eq ""){
	die "Die: no tag before for $_\n";
      }

      print OF "$tag ||| $line\n";
    }
  }

  close IF;
  close LABEL;
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
  if ($s =~ /^([\w \-\@\(\),\.\/]+)$/) {
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
