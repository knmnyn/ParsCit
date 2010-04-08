#!/usr/bin/perl -wT
# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Wed, 04 Nov 2009 16:27:01

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
  print STDERR "       $progname -in inFile [-out outFile]\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
}
my $QUIET = 0;
my $HELP = 0;
my $inFile = undef;
my $outFile = "";
my $version = "1.0";
$HELP = 1 unless GetOptions('in=s' => \$inFile,
			    'out=s' => \$outFile,
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
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
my $tmpFile = newTmpFile();


my $tmpOutFile = "$tmpFile.out";
if($outFile ne ""){
  $tmpOutFile = $outFile;
}
$tmpFile = untaintPath($tmpFile);
$tmpOutFile = untaintPath($tmpOutFile);
### End untaint ###

my @ids = ();
removeIds($inFile, $tmpFile, \@ids);

$inFile = $tmpFile;
execute("$path/sectExtract.pl -in $inFile -out $tmpOutFile -no-xmlInput -no-xmlOutput -log");

print STDOUT "# 1.0\n";
putIds($tmpOutFile, \@ids);

unlink($tmpFile);
if($outFile eq ""){
  unlink($tmpOutFile);
}

sub removeIds{
  my ($inFile, $outFile, $ids) = @_;
  
  #file I/O
  if(! (-e $inFile)){
    die "#File \"$inFile\" doesn't exist";
  }
  open(IF, "<:utf8", $inFile) || die "#Can't open file \"$inFile\"";
  open(OF, ">:utf8", $outFile) || die "#Can't open file \"$outFile\"";
  
  #process input file
  while(<IF>){
    chomp;
    
    if(/^([\d_]+) (.*)$/){
      push(@{$ids}, $1);
      print OF "$2\n";
    } else {
      print STDERR "#! Warning: line doesn't follow the format \"id text\" - \"$_\"\n";
    }
  }
  
  close IF;
  close OF;
}

sub putIds{
  my ($inFile, $ids) = @_;
  
  #file I/O
  if(! (-e $inFile)){
    die "#File \"$inFile\" doesn't exist";
  }
  open(IF, "<:utf8", $inFile) || die "#Can't open file \"$inFile\"";
  
  #process input file
  my $output = "";
  my $count = 0;
  while(<IF>){
    chomp;

    if(/^(\w+) .*$/){
      if(scalar(@{$ids}) == 0){
	die "Die: lack of ids that correspond to section labels @ lineId $count\n";
      }
      $output .= shift(@{$ids})." $1\n";
      $count++;
    } else {
      print STDERR "#! Warning: line doesn't follow the format \"label text\" - \"$_\"\n";
    }
  }
  
  print STDOUT "$output";
  close IF;
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
