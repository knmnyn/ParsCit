#!/usr/bin/perl -wT
# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Thu, 01 Apr 2010 01:15:34

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
use lib "$path/../../lib";
use SectLabel::PreProcess;

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
  print STDERR "       $progname -in inFile -out outFile [-print]\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
}
my $QUIET = 0;
my $HELP = 0;
my $inFile = undef;
my $outFile = undef;
my $isPrint = 0;
$HELP = 1 unless GetOptions('in=s' => \$inFile,
			    'out=s' => \$outFile,
			    'print' => \$isPrint,
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


open (IN, "<:utf8", "$inFile") || die "#Can't open file \"$inFile\"";
my $text = "";
while(<IN>){
  $text .= $_;
}
close IN;

my @lines = split(/\n/, $text);
my $numLines = scalar(@lines);
my ($bodyLength, $citationLength, $bodyEndId) =
	    SectLabel::PreProcess::findCitationText(\@lines, 0, $numLines);

my ($headerLength, $bodyStartId);
($headerLength, $bodyLength, $bodyStartId) =
	    SectLabel::PreProcess::findHeaderText(\@lines, 0, $bodyLength);

if($isPrint){
  open(OF, ">:utf8", "$outFile.header");
  my @headers = @lines[0..$headerLength];
  foreach(@headers){
    print OF "$_\n";
  }
  close OF;
  
  open(OF, ">:utf8", "$outFile.body");
  my @bodys = @lines[($headerLength+1)..($bodyEndId-1)];
  foreach(@bodys){
    print OF "$_\n";
  }
  close OF;
  
  open(OF, ">:utf8", "$outFile.citation");
  my @citations = @lines[$bodyEndId..($numLines-1)];
  foreach(@citations){
    print OF "$_\n";
  }
  close OF;
}
#my $header = join(/\n/, @headers);
#print STDERR 

open(OF, ">:utf8", "$outFile.info");
print OF "header\t".$headerLength."\n";
print OF "body\t".$bodyLength."\n";
print OF "reference\t".$citationLength."\n";
close OF;

# sanity check
my $totalLength = $headerLength + $bodyLength + $citationLength;
if($numLines != $totalLength){
  print STDOUT "Die in getStructureInfo(): different num lines $numLines != $totalLength\n"; # to display in Web
  die "Die in getStructureInfo(): different num lines $numLines != $totalLength\n";
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
