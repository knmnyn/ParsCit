#!/usr/bin/env perl
# -*- cperl -*- 

require 5.0;
use strict;
use Getopt::Long;
use FindBin;

### USER customizable section
my $tmpfile .= $0; $tmpfile =~ s/[\.\/]//g;
$tmpfile .= $$ . time;
if ($tmpfile =~ /^([-\@\w.]+)$/) { $tmpfile = $1; }		      # untaint tmpfile variable
$tmpfile = "/tmp/" . $tmpfile;
$0 =~ /([^\/]+)$/; my $progname = $1;
my $outputVersion = "1.0";

my $parscitHome = "$FindBin::Bin/../..";
my $tr2crfppLoc = "$parscitHome/bin/parsHed/tr2crfpp_parsHed.pl";
my $convertLoc = "$parscitHome/bin/parsHed/convert2TokenLevel.pl"; #new model
my $keywordLoc = "$parscitHome/bin/parsHed/keywordGen.pl"; #new model
my $crfpp = $ENV{'CRFPP_HOME'} ? "$ENV{'CRFPP_HOME'}/bin" : "$parscitHome/crfpp";
my $crf_learnLoc = "$crfpp/crf_learn";
my $crf_testLoc = "$crfpp/crf_test";
my $conllevalLoc = "$parscitHome/bin/conlleval.pl";
### END user customizable section

## Thang add ##
sub Help {
  print STDERR "usage: $progname -h\t[invokes help]\n";
  print STDERR "       $progname -in trainFile -t templateFile -n folds [-p numCpus -oldModel]\n";
  print STDERR "Options:\n";
  print STDERR "\t\t-p: Default is 6 cpus\n";
  print STDERR "\t\t-p: Default: use the new line-level model. Specify -oldModel to run with the old one.\n";
  print STDERR "\t\t-tr2crfpp: Default $ENV{ParsCit}/bin/parsHed/tr2crfpp.pl\n";
}

my $HELP = 0;
my $trainingFile = undef;
my $crfTemplateLoc = undef;
my $folds = undef;
my $numCpus = 6;
my $isOldModel = 0;
$HELP = 1 unless GetOptions('in=s' => \$trainingFile,
			    't=s' => \$crfTemplateLoc,
			    'n=i' => \$folds,
			    'p=i' => \$numCpus,
			    'oldModel' => \$isOldModel,
			    'h' => \$HELP);

if ($HELP || !defined $trainingFile || !defined $folds || !defined $crfTemplateLoc) {
  Help();
  exit(0);
}
## End Thang add ##

if($isOldModel){
  $tr2crfppLoc = "$parscitHome/bin/tr2crfpp.pl";
}

print STDERR "### Note the number of CPU for parallel crfpp is $numCpus\n";

# construct test data
print STDERR "### Constructing $folds-fold test files $tmpfile.*.test.src...\n"; # Thang add
open (IF, $trainingFile) || die "# $progname fatal\tTraining file cannot be opened \"$trainingFile\"!";
my $i = 0;
while (<IF>) {
  open (OF, ">>$tmpfile.$i.test.src") || die "$progname fatal\tCan't append to file \"$tmpfile.$i.test.src\"!";
  print OF $_;
  $i++;
  $i = $i % $folds;
}
close (IF);

# construct crf features
if(!$isOldModel){
  for (my $i = 0; $i < $folds; $i++) {
    # construct src training data first
    for (my $j = 0; $j < $folds; $j++) {
      if ($j == $i) {next; }
      else {
	execute("cat $tmpfile.$j.test.src >> $tmpfile.$i.train.src");
      }
    }

    #construct keywordFile, using topN = 100
    my $topN = 100;
    execute("$keywordLoc -in $tmpfile.$i.train.src -out $tmpfile.$i.keywords -n $topN"); # keyword file
    execute("$keywordLoc -in $tmpfile.$i.train.src -out $tmpfile.$i.bigram -n $topN -nGram 2"); # bigram file

    # create crf features
    execute("$tr2crfppLoc -in $tmpfile.$i.test.src -out $tmpfile.$i.test -k $tmpfile.$i.keywords -b $tmpfile.$i.bigram 1>/dev/null");
  }
} else {
  for (my $i = 0; $i < $folds; $i++) {
    execute("$tr2crfppLoc $tmpfile.$i.test.src > $tmpfile.$i.test");
  }
}

# construct training data
for (my $i = 0; $i < $folds; $i++) {
  for (my $j = 0; $j < $folds; $j++) {
    if ($j == $i) {next; }
    else {
      execute("cat $tmpfile.$j.test >> $tmpfile.$i.train");
    }
  }

}

# train
print STDERR "### Training ...\n"; # Thang add
for (my $i = 0; $i < $folds; $i++) {
  execute("$crf_learnLoc -m 100 -p $numCpus -f 3 -c 3 $crfTemplateLoc $tmpfile.$i.train $tmpfile.$i.model");
}

# test
print STDERR "### Testing ...\n"; # Thang add
for (my $i = 0; $i < $folds; $i++) {
  execute("$crf_testLoc -m $tmpfile.$i.model $tmpfile.$i.test > $tmpfile.$i.out");
  
  # convert from line-level format to token-level format
  if(!$isOldModel){
    print STDERR "### Convert from line-level format to token-level format...\n";
    execute("$convertLoc -in1 $tmpfile.$i.test.src -in2 $tmpfile.$i.out -out $tmpfile.$i.out.convert 2>$tmpfile.$i.out.log");
    execute("cat $tmpfile.$i.out.convert >> $tmpfile.all.out");
  } else {
    execute("cat $tmpfile.$i.out >> $tmpfile.all.out");
  }
}

  
# eval
#for (my $i = 0; $i < $folds; $i++) {
#  my $cmd = "$conllevalLoc -r -d \"	\" < $tmpfile.$i.out";
#  print "$cmd\n";
#  system ($cmd);
#}
print STDERR "### Evaluating ...\n"; # Thang add
execute("$conllevalLoc -r -d \"	\" < $tmpfile.all.out");

# clean up
#`rm -f $tmpfile*`;

## Thang add ##
sub execute {
  my ($cmd) = @_;
  print STDERR "Executing: $cmd\n";
  system($cmd);
}
## End Thang add ##

######################################################################
# 2-fold -m 100 -f 3 -c 3 on svm_headerparse.txt 
### Token-level model
# accuracy:  96.76%; precision:  96.76%; recall:  96.76%; FB1:  96.76
# abstract: precision:  99.04%; recall:  99.58%; FB1:  99.31  121194
# address: precision:  93.75%; recall:  89.43%; FB1:  91.54  5342
# affiliation: precision:  92.65%; recall:  92.06%; FB1:  92.35  9823
# author: precision:  94.11%; recall:  92.57%; FB1:  93.33  7825
# date: precision:  89.94%; recall:  92.59%; FB1:  91.25  1084
# degree: precision:  80.67%; recall:  84.30%; FB1:  82.45  2163
# email: precision:  91.54%; recall:  90.30%; FB1:  90.91  1667
# intro: precision:  97.56%; recall:  96.49%; FB1:  97.03  1354
# keyword: precision:  92.73%; recall:  81.24%; FB1:  86.60  1966
# note: precision:  86.70%; recall:  87.27%; FB1:  86.99  11220
# page: precision: 100.00%; recall: 100.00%; FB1: 100.00  288
# phone: precision:  92.17%; recall:  79.37%; FB1:  85.29  434
# pubnum: precision:  91.55%; recall:  85.83%; FB1:  88.60  556
# title: precision:  94.22%; recall:  95.10%; FB1:  94.66  9043
# web: precision:  77.32%; recall:  45.45%; FB1:  57.25  97
#
### Line-level model
#accuracy:  97.15%; precision:  97.15%; recall:  97.15%; FB1:  97.15
# abstract: precision:  98.70%; recall:  99.77%; FB1:  99.23  121842
# address: precision:  95.81%; recall:  97.01%; FB1:  96.40  5653
# affiliation: precision:  95.33%; recall:  95.94%; FB1:  95.63  9955
# author: precision:  93.31%; recall:  95.05%; FB1:  94.17  8084
# date: precision:  87.00%; recall:  94.07%; FB1:  90.40  1131
# degree: precision:  98.38%; recall:  58.55%; FB1:  73.41  1232
# email: precision:  97.37%; recall:  96.96%; FB1:  97.16  1671
# intro: precision:  90.77%; recall:  99.85%; FB1:  95.10  1506
# keyword: precision:  95.29%; recall:  80.17%; FB1:  87.08  1888
# note: precision:  89.86%; recall:  82.55%; FB1:  86.05  10236
# page: precision: 100.00%; recall: 100.00%; FB1: 100.00  288
# phone: precision:  98.02%; recall:  88.49%; FB1:  93.01  455
# pubnum: precision:  92.18%; recall:  85.93%; FB1:  88.95  550
# title: precision:  93.66%; recall:  98.05%; FB1:  95.80  9379
# web: precision:  98.40%; recall:  75.93%; FB1:  85.71  125
#
# Model                                                       Type of features   FB1   # features
# Token-level model                                                             96.76% 1091340
# Line-level  model
#  fullToken                                                  Parscit features  95.72%   60285
#  fullToken.firstToken                                       Parscit features  95.94%  128745
#  fullToken.firstSecondLastToken                             Parscit features  96.59%  259050
#  fullToken.firstSecondSecondLastToken                       Parscit features  96.68%  324255
#  fullToken.firstSecondSecondLastToken.back1                 linking           96.86%  392625
#  fullToken.firstSecondSecondLastToken.back1.forw1           linking           96.98%  458175 further linking reduces performance
#  fullToken.firstSecondSecondLastToken.back1.forw1.keyword   keyword           97.15%  461085
