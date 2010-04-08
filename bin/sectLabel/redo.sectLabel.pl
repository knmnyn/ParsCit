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
