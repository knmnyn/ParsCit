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
  print STDERR "       $progname -in fileList -pdf pdfDir -out outDir [-opt (all|formatted|normal|png|xml)]\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
  print STDERR "\t-opt: option (default = normal)\n";
}
my $QUIET = 0;
my $HELP = 0;
my $fileList = undef;
my $outDir = undef;
my $pdfDir = undef;
my $option = "normal";
$HELP = 1 unless GetOptions('in=s' => \$fileList,
			    'out=s' => \$outDir,
			    'pdf=s' => \$pdfDir,
			    'opt=s' => \$option,
			    'h' => \$HELP,
			    'q' => \$QUIET);

if ($HELP || !defined $fileList || !defined $outDir || !defined $pdfDir) {
  Help();
  exit(0);
}

if (!$QUIET) {
  License();
}

### Untaint ###
$fileList = untaintPath($fileList);
$outDir = untaintPath($outDir);
$pdfDir = untaintPath($pdfDir);
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
### End untaint ###

if(!-d $outDir){
  print STDERR "#! Output directory $outDir does not exist. Creating ...\n";
  execute("mkdir $outDir");
}

if(!-d $pdfDir){
  die "Die: Pdf directory $pdfDir does not exist.\n";
}
processFile($fileList, $outDir, $pdfDir);

sub processFile{
  my ($inFile, $outDir, $pdfDir) = @_;
  
  #file I/O
  if(! (-e $inFile)){
    die "#File \"$inFile\" doesn't exist";
  }
  open(IF, "<:utf8", $inFile) || die "#Can't open file \"$inFile\"";
  
  #process input file
  while(<IF>){
    chomp;
    
    my $index = $_;
    my $subDir = "$outDir/$index";
    my $pdfFile = "$pdfDir/$index.pdf";
    print STDERR "\n#Run Omnipage for file $pdfFile\n";

    if(-d $subDir){
      print STDERR "#! Directory $subDir does exist.\n";
    } else {  
      print STDERR "Creating $subDir ...\n";
      execute("mkdir $subDir");
    }

    execute("/home/forecite/services/omnipage/bin/omni.rb $pdfFile $option $subDir");
    execute("cat $subDir/* > $outDir/$index.txt");
  }
  
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
