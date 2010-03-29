#!/usr/bin/perl -wT
# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Sat, 03 Oct 2009 01:35:52

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

my $tr2crfppLoc = "$path/tr2crfpp.pl";
my $keywordLoc = "$path/keywordGen.pl"; #new model
my $crf_learnLoc = "$path/../../crfpp/crf_learn";
my $crf_testLoc = "$path/../../crfpp/crf_test";
my $conllevalLoc = "$path/conlleval.pl";
### END user customizable section

## Thang add ##
sub Help {
  print STDERR "usage: $progname -h\t[invokes help]\n";
  print STDERR "       $progname -in labelDir -omni omniDir -t type -out outDir\n";
  print STDERR "Options:\n";
  print STDERR "\t\t-t type: e.g. ACL09-ACM-CHI08 to indicate subdirs containing label file. If not specified, the labelDir is supposed to contain all label files\n";
}

my $HELP = 0;
my $labelDir = undef;
my $omniDir = undef;
my $outDir = undef;
my $type = undef;
$HELP = 1 unless GetOptions('in=s' => \$labelDir,
			    'omni=s' => \$omniDir,
			    'out=s' => \$outDir,
			    't=s' => \$type,
			    'h' => \$HELP);

if ($HELP || !defined $labelDir || !defined $omniDir || !defined $labelDir || !defined $outDir || !defined $type) {
  Help();
  exit(0);
}
## End Thang add ##

### Untaint ###
$labelDir = untaintPath($labelDir);
$omniDir = untaintPath($omniDir);
$outDir = untaintPath($outDir);
$type = untaintPath($type);
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
### End untaint ###

### Get a list of labeled files ###
if(!-d $labelDir) {
  die "Die: directory $labelDir does not exist!\n";
}

if(!-d $omniDir) {
  die "Die: directory $omniDir does not exist!\n";
}

if($type eq ""){
  die "Die: empty type \"$type\"\n";
}
if(!-d $outDir) {
  print STDERR "Directory $outDir does not exist! Creating ...\n";
  execute("mkdir -p $outDir");
}

my $featureDir = newTmpFile();
print STDERR "Tmp feature files will be output to directory $featureDir\n";
execute("mkdir -p $featureDir");

my @subDirs = split(/\-/, $type);
foreach my $subDir (@subDirs){
  execute("mkdir -p $outDir/$subDir/");
  execute("mkdir -p $featureDir/$subDir/");

  opendir DIR, "$labelDir/$subDir" or die "cannot open dir $labelDir/$subDir: $!";

  my @files= grep { $_ ne '.' && $_ ne '..' && $_ !~ /~$/} readdir DIR;
  closedir DIR;

  foreach my $file (@files){
    # extract feature
    execute("$path/../../../bin/sectLabel/processOmniXML.pl -in $omniDir/$subDir/xml-concat/$file -out $featureDir/$subDir/$file -xmlFeature -paraFeature");

    # insert XML features to label txt files
    execute("$path/insertXMLFeatures.pl -in $labelDir/$subDir/$file -xml $featureDir/$subDir/$file -out $outDir/$subDir/$file -log $featureDir.log");
  }
} # end for subDir

execute("rm -rf $featureDir");

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
  if ($s =~ /^([\w \-\@\(\),\.\/><\"\s]+)$/) {
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

sub executeQuiet {
  my ($cmd) = @_;
  $cmd = untaint($cmd);
  system($cmd);
}

sub newTmpFile {
  my $tmpFile = `date '+%Y%m%d-%H%M%S-$$'`;
  chomp($tmpFile);
  $tmpFile = untaintPath($tmpFile);
  return $tmpFile;
}
