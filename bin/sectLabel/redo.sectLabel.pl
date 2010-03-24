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
  print STDERR "       $progname -in labelDir -t type -out outDir -n folds -c configFile [-p numCpus -iter numIter -topN topN]\n";
  print STDERR "Options:\n";
  print STDERR "\t\t-p: Default is 6 cpus\n";
  print STDERR "\t\t-iter: Default is 100 iterations\n";
  print STDERR "\t\t-t type: e.g. ACL09-ACM-CHI08 to indicate subdirs containing label file. If not specified, the labelDir is supposed to contain all label files\n";
}

my $HELP = 0;
my $labelDir = undef;
my $outDir = undef;
my $folds = undef;
my $configFile = undef;
my $numCpus = 6;
my $topN = 10;
my $numIter = 100;
my $type = undef;
$HELP = 1 unless GetOptions('in=s' => \$labelDir,
			    'out=s' => \$outDir,
			    'n=i' => \$folds,
			    'c=s' => \$configFile,
			    'p=i' => \$numCpus,
			    'iter=i' => \$numIter,
			    'topN=i' => \$topN,
			    't=s' => \$type,
			    'h' => \$HELP);

if ($HELP || !defined $labelDir || !defined $folds || !defined $outDir || !defined $configFile || !defined $type) {
  Help();
  exit(0);
}
## End Thang add ##

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

my %fileHash = ();
if($type eq ""){
  die "Die: empty type \"$type\"\n";
}
if(!-d $outDir) {
  print STDERR "Directory $outDir does not exist! Creating ...\n";
  execute("mkdir -p $outDir");
}

my @subDirs = split(/\-/, $type);
foreach my $subDir (@subDirs){
  opendir DIR, "$labelDir/$subDir" or die "cannot open dir $labelDir/$subDir: $!";

  my @files= grep { $_ ne '.' && $_ ne '..' && $_ !~ /~$/} readdir DIR;
  my @sorted_files = sort { $a cmp $b } @files;
  print STDERR "# $subDir: @sorted_files\n";    
  $fileHash{$subDir} = \@sorted_files;
  closedir DIR;

  ### construct src test data ###
  print STDERR "\n### Constructing $folds-fold test files $outDir/*.test.src...\n";
  my $i = 0;
  foreach my $file (@sorted_files){
    my $testFile = "$outDir/$i.test.src";
    executeQuiet("cat $labelDir/$subDir/$file >> $testFile");
    executeQuiet("echo \"\" >> $testFile"); # add a blank line in between
    
    $i++;
    $i = $i % $folds;
  }
} # end for subDir

my $templateFile = "$outDir/template";
for (my $i = 0; $i < $folds; $i++) {
  print STDERR "\n### Test fold $i\n";
  
  #construct keywordFile, using topN = 100
#  execute("$keywordLoc -in $outDir/$i.train.src -out $outDir/$i.keywords -n $topN"); # keyword file
#  execute("$keywordLoc -in $outDir/$i.train.src -out $outDir/$i.bigram -n $topN -nGram 2"); # bigram file
#  execute("$keywordLoc -in $outDir/$i.train.src -out $outDir/$i.trigram -n $topN -nGram 3"); # trigram file
#  execute("$keywordLoc -in $outDir/$i.train.src -out $outDir/$i.fourthgram -n $topN -nGram 4"); # fourthgram file

  # create test crf features
  
  my $cmd = "$tr2crfppLoc -q -in $outDir/$i.test.src -out $outDir/$i.test -c $configFile"; # -k $outDir/$i.keywords -b $outDir/$i.bigram -tri $outDir/$i.trigram -fourth $outDir/$i.fourthgram";
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
  $cmd .= " -p $numCpus -f 3 -c 3 $templateFile $outDir/$i.train $outDir/$i.model 1>crf.$i.stdout 2>crf.$i.stderr";
  execute($cmd);
}

# test
print STDERR "### Testing ...\n"; # Thang add
for (my $i = 0; $i < $folds; $i++) {
  execute("$crf_testLoc -m $outDir/$i.model $outDir/$i.test > $outDir/$i.out");
  
  execute("cat $outDir/$i.out >> $outDir/all.out");
}

  
# eval
#for (my $i = 0; $i < $folds; $i++) {
#  my $cmd = "$conllevalLoc -r -d \"	\" < $outDir/$i.out";
#  print "$cmd\n";
#  system ($cmd);
#}
print STDERR "### Evaluating ...\n"; # Thang add
execute("$conllevalLoc -r -c -d \"	\" < $outDir/all.out 1>evaluation.stdout 2>evaluation.stderr");

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
