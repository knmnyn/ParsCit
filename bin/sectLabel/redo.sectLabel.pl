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
my $conllevalLoc = "$path/../conlleval.pl";
### END user customizable section

## Thang add ##
sub Help {
  print STDERR "Perform stratified cross-validation for SectLabel\n";
  print STDERR "usage: $progname -h\t[invokes help]\n";
  print STDERR "       $progname -in trainFile -dir outDir -n folds -c configFile [-p numCpus -iter numIter -f freqCutoff]\n";
  print STDERR "Options:\n";
  print STDERR "\t\t-in: training file in the format as in doc/sectLabel.tagged.txt\n";
  print STDERR "\t\t-dir: output directory, containing all intermediate files and outputs\n";
  print STDERR "\t\t-n: num of cross validation folds\n";
  print STDERR "\t\t-c: config file to extract features and automatically generate CRF++ template\n\n";

  print STDERR "\t\t-p: CRF++ num of CPUs (deault = 6)\n";
  print STDERR "\t\t-iter: CRF++ max iteration (default = 100)\n";
  print STDERR "\t\t-f: CRF++ frequency cut-off (default = 3)\n";

}

my $HELP = 0;
my $trainFile = undef;
my $outDir = undef;
my $folds = undef;
my $configFile = undef;
my $numCpus = 6;
my $numIter = 100;
my $f = 3;
$HELP = 1 unless GetOptions('in=s' => \$trainFile,
			    'dir=s' => \$outDir,
			    'n=i' => \$folds,
			    'c=s' => \$configFile,

			    'p=i' => \$numCpus,
			    'f=i' => \$f,
			    'iter=i' => \$numIter,
			    'h' => \$HELP);

if ($HELP || !defined $trainFile || !defined $folds || !defined $outDir || !defined $configFile) {
  Help();
  exit(0);
}
## End Thang add ##

### Untaint ###
$trainFile = untaintPath($trainFile);
$outDir = untaintPath($outDir);
$configFile = untaintPath($configFile);
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
### End untaint ###

print STDERR "### Note the number of CPU for parallel crfpp is $numCpus\n";

if(!-d $outDir) {
  print STDERR "Directory $outDir does not exist! Creating...\n";
  execute("mkdir -p $outDir");
}

### construct src test data ###
print STDERR "\n### Constructing $folds-fold test files $outDir/*.test.src...\n"; # Thang add
open (IF, $trainFile) || die "# $progname fatal\tTraining file cannot be opened \"$trainFile\"!";
my $i = 0;
while (<IF>) {
  my $testFile = "$outDir/$i.test.src";
  $testFile = untaintPath($testFile);
  open (OF, ">>$testFile") || die "Can't append to file \"$testFile\"!";
  print OF $_;
  $i++;
  $i = $i % $folds;
  close OF;
}
close IF;

my $templateFile = "$outDir/template";
for (my $i = 0; $i < $folds; $i++) {
  print STDERR "\n### Test fold $i\n";

  # create test crf features  
  my $cmd = "$tr2crfppLoc -q -in $outDir/$i.test.src -out $outDir/$i.test -c $configFile -single"; # -k $outDir/$i.keywords -b $outDir/$i.bigram -tri $outDir/$i.trigram -fourth $outDir/$i.fourthgram";
  if($i == 0){ # generate template file
    $cmd .= " -template 1>$templateFile";
  }
  execute($cmd);
}

# train
print STDERR "#\n## Training ...\n"; # Thang add
for (my $i = 0; $i < $folds; $i++) {
  # create train crf features
  for (my $j = 0; $j < $folds; $j++) {
    if ($j == $i) {next; }
    else {
      execute("cat $outDir/$j.test >> $outDir/$i.train");
    }
  }
  
  my $cmd = "$crf_learnLoc";
  if($numIter > 0){
    $cmd .= " -m $numIter";
  }
  $cmd .= " -p $numCpus -f $f -c 3 $templateFile $outDir/$i.train $outDir/$i.model 1>$outDir/crf.$i.stdout 2>$outDir/crf.$i.stderr";
  execute($cmd);
}

# test
print STDERR "### Testing ...\n"; # Thang add
for (my $i = 0; $i < $folds; $i++) {
  execute("$crf_testLoc -m $outDir/$i.model $outDir/$i.test > $outDir/$i.out");
  
  execute("cat $outDir/$i.out >> $outDir/all.out");
}

  
# eval
print STDERR "### Evaluating ...\n"; # Thang add
execute("$conllevalLoc -r -d \"	\" < $outDir/all.out 1>$outDir/evaluation.stdout 2>$outDir/evaluation.stderr");

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
  if ($s =~ /^([\w \-\@\(\),\.\/><\"\s\_]+)$/) {
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

### v100401, micro F1 = 93.38, macro F1 (avg of individual F1s) = 84.72 ###
#processed 37802 tokens with 37802 phrases; found: 37802 phrases; correct: 35299.
#  accuracy:  93.38%; precision:  93.38%; recall:  93.38%; FB1:  93.38
#  address: precision:  88.33%; recall:  82.81%; FB1:  85.48; TP=53 FN=11 FP=7
#  affiliation: precision:  96.04%; recall:  89.81%; FB1:  92.82; TP=97 FN=11 FP=4
#  author: precision:  97.01%; recall:  98.48%; FB1:  97.74; TP=65 FN=1 FP=2
#  bodyText: precision:  95.72%; recall:  98.26%; FB1:  96.97; TP=24636 FN=435 FP=1102
#  category: precision:  89.55%; recall:  82.19%; FB1:  85.71; TP=60 FN=13 FP=7
#  construct: precision:  66.67%; recall:  22.03%; FB1:  33.11; TP=50 FN=177 FP=25
#  copyright: precision:  97.22%; recall:  93.09%; FB1:  95.11; TP=175 FN=13 FP=5
#  email: precision:  98.41%; recall:  96.88%; FB1:  97.64; TP=62 FN=2 FP=1
#  equation: precision:  70.88%; recall:  73.17%; FB1:  72.01; TP=611 FN=224 FP=251
#  figure: precision:  80.89%; recall:  78.99%; FB1:  79.93; TP=1718 FN=457 FP=406
#  figureCaption: precision:  83.05%; recall:  71.61%; FB1:  76.91; TP=338 FN=134 FP=69
#  footnote: precision:  89.61%; recall:  56.87%; FB1:  69.58; TP=207 FN=157 FP=24
#  keyword: precision:  79.66%; recall:  69.12%; FB1:  74.02; TP=47 FN=21 FP=12
#  listItem: precision:  77.98%; recall:  65.52%; FB1:  71.21; TP=857 FN=451 FP=242
#  note: precision:  97.90%; recall:  94.59%; FB1:  96.22; TP=140 FN=8 FP=3
#  page: precision:  97.98%; recall:  97.69%; FB1:  97.84; TP=339 FN=8 FP=7
#  reference: precision:  99.52%; recall:  99.47%; FB1:  99.50; TP=3945 FN=21 FP=19
#  sectionHeader: precision:  95.29%; recall:  91.79%; FB1:  93.51; TP=425 FN=38 FP=21
#  subsectionHeader: precision:  92.41%; recall:  90.40%; FB1:  91.39; TP=292 FN=31 FP=24
#  subsubsectionHeader: precision:  90.62%; recall:  74.36%; FB1:  81.69; TP=58 FN=20 FP=6
#  table: precision:  77.92%; recall:  81.33%; FB1:  79.59; TP=893 FN=205 FP=253
#  tableCaption: precision:  92.61%; recall:  71.49%; FB1:  80.69; TP=163 FN=65 FP=13
#  title: precision: 100.00%; recall: 100.00%; FB1: 100.00; TP=68 FN=0 FP=0
