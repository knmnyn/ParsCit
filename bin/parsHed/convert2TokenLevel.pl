#!/usr/bin/perl -wT
# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Tue, 02 Jun 2009 01:30:42

# Modified from template by Min-Yen Kan <kanmy@comp.nus.edu.sg>

require 5.0;
use strict;
use Getopt::Long;
use FindBin;

### USER customizable section
$0 =~ /([^\/]+)$/; my $progname = $1;
my $outputVersion = "1.0";
### END user customizable section

sub License {
  print STDERR "# Copyright 2009 \251 by Luong Minh Thang\n";
}

### HELP Sub-procedure
sub Help {
  print STDERR "Convert labelled result from line level to token level (for backward performance comparison)\n";
  print STDERR "usage: $progname -h\t[invokes help]\n";
  print STDERR "       $progname -in1 taggedTestFile -in2 labeledResultFile -out outFile\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
}
my $QUIET = 0;
my $HELP = 0;
my $outFile = undef;
my $testFile = undef;
my $resultFile = undef;

$HELP = 1 unless GetOptions('in1=s' => \$testFile,
			    'in2=s' => \$resultFile,
			    'out=s' => \$outFile,
			    'h' => \$HELP,
			    'q' => \$QUIET);

if ($HELP || !defined $testFile || !defined $resultFile || !defined $outFile) {
  Help();
  exit(0);
}

if (!$QUIET) {
  License();
}

### Untaint ###
$testFile = untaintPath($testFile);
$resultFile = untaintPath($resultFile);
$outFile = untaintPath($outFile);
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
### End untaint ###

my $lineTestFile = "$testFile.line";
$lineTestFile = untaintPath($lineTestFile);
execute("$FindBin::Bin/../../bin/parsHed/parseXmlHeader.pl -in $testFile -out $lineTestFile");
processFile($lineTestFile, $resultFile, $outFile);

sub processFile{
  my ($testFile, $resultFile, $outFile) = @_;
  
  #file I/O
  if(! (-e $testFile)){
    die "#File \"$testFile\" doesn't exist";
  }
  open(IF1, "<:utf8", $testFile) || die "#Can't open file \"$testFile\"";
  open(IF2, "<:utf8", $resultFile) || die "#Can't open file \"$resultFile\"";
  open(OF, ">:utf8", $outFile) || die "#Can't open file \"$outFile\"";
  
  #process input file
  my $isFirst = 1;
  while(<IF1>){
    chomp;
    my $testLine = $_;

    if($testLine =~ /^\/\//){ #new tag
      next; # do not read IF2
    }

    my $resultLine = <IF2>;
    chomp($resultLine);
    if($testLine =~ /^\s*$/){ #blank line
      print STDERR "\n";
      print OF "\n";
      $isFirst = 1;
    } else {
      my @tokens = split(/\s+/, $resultLine);
      my $trueTag = $tokens[$#tokens-1];
      my $estimateTag = $tokens[$#tokens];

      my @testTokens = split(/\s+/, $testLine);
      foreach(@testTokens){
	print OF "$_\t$trueTag\t$estimateTag\n";
      }
    }
  }
  
  close IF1;
  close IF2;
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
