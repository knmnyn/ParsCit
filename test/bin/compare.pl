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
  print STDERR "       $progname -l fileList -in1 inDir1 -in2 inDir2 -out outFile [-suf suffix]\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
  print STDERR "\t-suf: suffix to name output file \$outDir/\$file\$sufffix.xml\n";
}
my $QUIET = 0;
my $HELP = 0;
my $fileList = undef;
my $inDir1 = undef;
my $inDir2 = undef;
my $outFile = undef;
my $suffix = "";
$HELP = 1 unless GetOptions('l=s' => \$fileList,
			    'in1=s' => \$inDir1,
			    'in2=s' => \$inDir2,
			    'out=s' => \$outFile,
			    'suf=s' => \$suffix,
			    'h' => \$HELP,
			    'q' => \$QUIET);

if ($HELP || !defined $fileList || !defined $inDir1 || !defined $inDir2|| !defined $outFile) {
  Help();
  exit(0);
}

if (!$QUIET) {
  License();
}

### Untaint ###
$fileList = untaintPath($fileList);
$inDir1 = untaintPath($inDir1);
$inDir2 = untaintPath($inDir2);
$outFile = untaintPath($outFile);
my $envPath = $ENV{'PATH'};
$envPath = untaintPath($envPath);
$ENV{'PATH'} = $envPath;
### End untaint ###

my $root = "$path/../../bin";
if(!-d "$inDir2"){
  die "#! Die: $inDir2 not exist! \n";
}
if(!-d "$inDir1"){
  die "#! Die: $inDir1 not exist! \n";
}

if(-e "$outFile"){
  print STDERR "#! Die: $outFile exists! Removing ... \n";
  execute("rm -rf $outFile");
}

print STDERR "\n# Comparing $inDir1 vs $inDir2 --> $outFile\n";
processFile($fileList, $inDir1, $inDir2, $outFile);

sub processFile{
  my ($fileList, $inDir1, $inDir2, $outFile) = @_;
  
  #file I/O
  if(! (-e $fileList)){
    die "#File \"$fileList\" doesn't exist";
  }
  open(IF, "<:utf8", $fileList) || die "#Can't open file \"$fileList\"";
  
  #process input file
  while(<IF>){
    chomp;

#    print STDERR "# $_\n";
    my $inFile1 = "$inDir1/$_$suffix.xml";
    my $inFile2 = "$inDir2/$_$suffix.xml";
    
    execute("echo \"### diff $inFile1 $inFile2\" >> $outFile");
    execute("diff $inFile1 $inFile2 >> $outFile");
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
  if ($s =~ /^([\w \-\@\(\),\.\/<>\#"]+)$/) { #\p{C}\p{P}
    $s = $1;               # $data now untainted
  } else {
    die "Bad data in $s";  # log this somewhere
  }
  return $s;
}

sub execute {
  my ($cmd) = @_;
#  print STDERR "Executing: $cmd\n";
  $cmd = untaint($cmd);
  system($cmd);
}

sub newTmpFile {
  my $tmpFile = `date '+%Y%m%d-%H%M%S-$$'`;
  chomp($tmpFile);
  return $tmpFile;
}
