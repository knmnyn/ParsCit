#!/usr/bin/perl -wT
# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Wed, 24 Mar 2010 00:21:43

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
  print STDERR "       $progname -l fileList -in inDir -out outDir [-suf suffix -opt option]\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
  print STDERR "\t-suf: suffix to name output file \$outDir/\$file\$sufffix.xml\n";
  print STDERR "\t-opt: options to input to citeExtract.pl e.g, \"-m extract_all -i xml\"\n";
}
my $QUIET = 0;
my $HELP = 0;
my $fileList = undef;
my $inDir = undef;
my $outDir = undef;
my $opt = "";
my $suffix = "";
$HELP = 1 unless GetOptions('l=s' => \$fileList,
			    'in=s' => \$inDir,
			    'out=s' => \$outDir,
			    'opt=s' => \$opt,
			    'suf=s' => \$suffix,
			    'h' => \$HELP,
			    'q' => \$QUIET);

if ($HELP || !defined $fileList || !defined $inDir || !defined $outDir) {
  Help();
  exit(0);
}

if (!$QUIET) {
  License();
}

### Untaint ###
$fileList = untaintPath($fileList);
$inDir = untaintPath($inDir);
$outDir = untaintPath($outDir);
my $envPath = $ENV{'PATH'};
$envPath = untaintPath($envPath);
$ENV{'PATH'} = $envPath;
### End untaint ###

my $root = "$path/../../bin";
if(!-e "$outDir"){
  print STDERR "#! Dir $outDir not exist! Creating ... \n";
  execute("mkdir -p $outDir");
}

processFile($fileList, $inDir, $outDir, $opt);

sub processFile{
  my ($fileList, $inDir, $outDir) = @_;
  
  #file I/O
  if(! (-e $fileList)){
    die "#File \"$fileList\" doesn't exist";
  }
  open(IF, "<:utf8", $fileList) || die "#Can't open file \"$fileList\"";
  
  #process input file
  while(<IF>){
    chomp;

    print STDERR "# $_\n";
    my $inFile = "$inDir/$_.txt";
    my $outFile = "$outDir/$_$suffix.xml";
    
    execute("$root/citeExtract.pl $opt $inFile $outFile");
  }
  
  close IF;
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
