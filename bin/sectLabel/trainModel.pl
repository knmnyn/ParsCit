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

my $tr2crfppLoc = "$FindBin::Bin/../bin/tr2crfpp.pl";
my $keywordLoc = "$FindBin::Bin/../bin/keywordGen.pl"; #new model
my $crf_learnLoc = "$FindBin::Bin/../crfpp/crf_learn";
my $crf_testLoc = "$FindBin::Bin/../crfpp/crf_test";
my $conllevalLoc = "$FindBin::Bin/../bin/conlleval.pl";
### END user customizable section

## Thang add ##
sub Help {
  print STDERR "usage: $progname -h\t[invokes help]\n";
  print STDERR "       $progname -in labelDir -t type -out outDir -c configFile [-xml -n topN -p numCpus -iter numIter -m modelFile]\n";
  print STDERR "Options:\n";
  print STDERR "\t\t-p: Default is 6 cpus\n";
  print STDERR "\t\t-n: Default topN is 10\n";
  print STDERR "\t\t-t type: e.g. ACL09-ACM-CHI08 to indicate subdirs containing label file. If not specified, the labelDir is supposed to contain all label files\n";
  print STDERR "\t\t-xml: Add xml feature\n";
}

my $HELP = 0;
my $labelDir = undef;
my $outDir = undef;
my $configFile = undef;
my $numCpus = 6;
my $isXml = 0;
my $topN = 10;
my $numIter = undef;
my $type = undef;
my $modelFile = "";
$HELP = 1 unless GetOptions('in=s' => \$labelDir,
			    'out=s' => \$outDir,
			    'c=s' => \$configFile,
			    'm=s' => \$modelFile,
			    'xml' => \$isXml,
			    'p=i' => \$numCpus,
			    'iter=i' => \$numIter,
			    't=s' => \$type,
			    'h' => \$HELP);

if ($HELP || !defined $labelDir || !defined $outDir || !defined $configFile || !defined $type) {
  Help();
  exit(0);
}
## End Thang add ##

if($modelFile eq ""){
  $modelFile = "$outDir/sectLabel.model";
}
### Untaint ###
$labelDir = untaintPath($labelDir);
$outDir = untaintPath($outDir);
$configFile = untaintPath($configFile);
$type = untaintPath($type);
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
### End untaint ###

print STDERR "### Note the number of CPU for parallel crfpp is $numCpus\n";

### Get a list of labeled files ###
if(!-d $labelDir) {
  die "Die: directory $labelDir does not exist!\n";
}

if(!-d $outDir) {
  print STDERR "Directory $outDir does not exist! Creating ...\n";
  execute("mkdir -p $outDir");
}


### Obtaining training file list ###
if($type eq ""){
  die "Die: empty type \"$type\"\n";
}
my @subDirs = split(/\-/, $type);
my @files = ();

foreach my $subDir (@subDirs){
  opendir DIR, "$labelDir/$subDir" or die "cannot open dir $labelDir/$subDir: $!";

  my @subFiles= grep { $_ ne '.' && $_ ne '..' && $_ !~ /~$/} readdir DIR;
  foreach my $subFile (@subFiles){
    push(@files, "$subDir/$subFile");
  }
  closedir DIR;
}
my @sorted_files = sort { $a cmp $b } @files;
print STDERR "### Number of training files = ".scalar(@sorted_files)."\n@sorted_files\n";

### construct src train data ###
my $trainSrcFile = "$outDir/train.src";
print STDERR "\n### Constructing src train data $trainSrcFile...";
foreach my $file (@sorted_files){
  executeQuiet("cat $labelDir/$file >> $trainSrcFile");
  executeQuiet("echo \"\" >> $trainSrcFile"); # add a blank line in between
}
print STDERR " Done!\n";

#construct keywordFile, using topN = 100
my $keywordFile = "$outDir/keywords";
my $bigramFile = "$outDir/bigram";
my $trigramFile = "$outDir/trigram";
my $fourthgramFile = "$outDir/fourthgram";
#execute("$keywordLoc -in $trainSrcFile -out $keywordFile -n $topN"); # keyword file
#execute("$keywordLoc -in $trainSrcFile -out $bigramFile -n $topN -nGram 2"); # bigram file
#execute("$keywordLoc -in $trainSrcFile -out $trigramFile -n $topN -nGram 3"); # bigram file
#execute("$keywordLoc -in $trainSrcFile -out $fourthgramFile -n $topN -nGram 4"); # bigram file

# create train crf features
my $trainFeatureFile = "$outDir/train.feature";
my $templateFile = "$outDir/template";
my $cmd = "$tr2crfppLoc -q -in $trainSrcFile -out $trainFeatureFile -c $configFile"; # -k $keywordFile -b $bigramFile -tri $trigramFile -fourth $fourthgramFile
if($isXml){
  $cmd .= " -xml";
}
execute("$cmd -template 1>$templateFile");

# train
print STDERR "#\n## Training ...\n"; # Thang add
$cmd = "$crf_learnLoc -p $numCpus -f 3 -c 3";
if(defined $numIter){
  $numIter = untaintPath($numIter);
  $cmd .= " -m $numIter";
}
$cmd .= " $templateFile $trainFeatureFile $modelFile";
execute($cmd);


# clean up
#`rm -f $tmpfile*`;


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
  return $tmpFile;
}
