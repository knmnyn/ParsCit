#!/usr/bin/perl -wT
# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Fri, 09 Oct 2009 12:24:47

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
  print STDERR "       $progname -in inFile -out outFile\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
}
my $QUIET = 0;
my $HELP = 0;
my $outFile = undef;
my $inFile = undef;

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
$outFile = untaintPath($outFile);
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
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
  
  #process input file
  my $tag;
  my %stats = (); #$stats{$tag}: array
  while(<IF>){
    chomp;
    $_ =~ s/\s+$//;

    if(/^(.+) \|\|\| ?(.*)$/){
      $tag = $1;
      if(!$stats{$tag}){
	$stats{$tag} = ();
      }
      push(@{$stats{$tag}}, $2);
    } else {
      die "Die: no tag line $_\n";
    }
  }

  my @sorted_keys = sort {$a cmp $b} keys %stats;
  foreach(@sorted_keys){
    my @lines = @{$stats{$_}};
    print STDERR "$_\t".scalar(@lines)."\n";
    print OF "### $_\n";
    my $count = 1;
    foreach(@lines){
      print OF "$count\t$_\n";
      $count++;
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
