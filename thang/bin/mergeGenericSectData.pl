#!/usr/bin/perl -wT
# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Wed, 07 Apr 2010 15:39:11

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
  print STDERR "usage: $progname -h\t[invokes help]\n";
  print STDERR "       $progname -header headerFile -label labelFile -out outFile\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
}
my $QUIET = 0;
my $HELP = 0;
my $headerFile = undef;
my $labelFile = undef;
my $outFile = undef;

$HELP = 1 unless GetOptions('header=s' => \$headerFile,
			    'label=s' => \$labelFile,
			    'out=s' => \$outFile,
			    'h' => \$HELP,
			    'q' => \$QUIET);

if ($HELP || !defined $headerFile || !defined $labelFile || !defined $outFile) {
  Help();
  exit(0);
}

if (!$QUIET) {
  License();
}

### Untaint ###
$headerFile = untaintPath($headerFile);
$labelFile = untaintPath($labelFile);
$outFile = untaintPath($outFile);
my $envPath = $ENV{'PATH'};
$envPath = untaintPath($envPath);
$ENV{'PATH'} = $envPath;
### End untaint ###

processFile($headerFile, $labelFile, $outFile);

sub processFile{
  my ($headerFile, $labelFile, $outFile) = @_;
  
  #file I/O
  if(! (-e $headerFile)){
    die "#File \"$headerFile\" doesn't exist";
  }
  open(HEADER, "<:utf8", $headerFile) || die "#Can't open file \"$headerFile\"";
  open(LABEL, "<:utf8", $labelFile) || die "#Can't open file \"$labelFile\"";
  open(OF, ">:utf8", $outFile) || die "#Can't open file \"$outFile\"";
  
  #process input file
  while(<HEADER>){
    chomp;
    my $header = $_;

    if(!eof(LABEL)){
      my $label = <LABEL>; chomp($label);
      $label =~ s/\s+$//;
      my @tokens = split(/\s+/, $label);
      $label = join("-", @tokens);
      print OF "$label ||| $header\n";
    } else {
      die "Die: eof label $labelFile\n";
    }
  }
  
  if(!eof(HEADER)){
    die "Die: not eof header $headerFile\n";
  }

  close HEADER;
  close OF;
}

sub untaintPath {
  my ($path) = @_;

  if ( $path =~ /^([-_\/\w\.\d: ]+)$/ ) { #\p{C}\p{P}
    $path = $1;
  } else {
    die "Bad path $path\n";
  }

  return $path;
}

sub untaint {
  my ($s) = @_;
  if ($s =~ /^([\w \-\@\(\),\.\/<>]+)$/) { #\p{C}\p{P}
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
