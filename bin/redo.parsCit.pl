#!/usr/bin/env perl
# -*- cperl -*- 

### USER customizable section
my $tmpfile .= $0; $tmpfile =~ s/[\.\/]//g;
$tmpfile .= $$ . time;
if ($tmpfile =~ /^([-\@\w.]+)$/) { $tmpfile = $1; }		      # untaint tmpfile variable
$tmpfile = "/tmp/" . $tmpfile;
$0 =~ /([^\/]+)$/; my $progname = $1;
my $outputVersion = "1.0";
my $parscitHome = "/home/wing.nus/services/parscit/tools/";
my $tr2crfppLoc = "$parscitHome/bin/tr2crfpp.pl";
my $crfpp = $ENV{'CRFPP_HOME'} ? "$ENV{'CRFPP_HOME'}/bin" : "$parscitHome/crfpp";
my $crf_learnLoc = "$crfpp/crf_learn";
my $crf_testLoc = "$crfpp/crf_test";
my $conllevalLoc = "$parscitHome/bin/conlleval.pl";
my $crfTemplateLoc = "$parscitHome/crfpp/traindata/parsCit.template";
### END user customizable section

my $trainingFile = $ARGV[0];
my $folds = $ARGV[1];

# construct test data
open (IF, $trainingFile) || die "# $progname fatal\tTraining file cannot be opened \"$trainingFile\"!";
my $i = 0;
while (<IF>) {
  open (OF, ">>$tmpfile.$i.test.src") || die "$progname fatal\tCan't append to file \"$tmpfile.$i.test.src\"!";
  print OF $_;
  $i++;
  $i = $i % $folds;
}
close (IF);
for (my $i = 0; $i < $folds; $i++) {
  `$tr2crfppLoc $tmpfile.$i.test.src> $tmpfile.$i.test`;
}

# construct training data
for (my $i = 0; $i < $folds; $i++) {
  for (my $j = 0; $j < $folds; $j++) {
    if ($j == $i) {next; }
    else {
      `cat $tmpfile.$j.test >> $tmpfile.$i.train`;
    }
  }
}

# train
for (my $i = 0; $i < $folds; $i++) {
  my $cmd = "$crf_learnLoc -f 2 -c 3 $crfTemplateLoc $tmpfile.$i.train $tmpfile.$i.model ";
  print "$cmd\n";
  system ($cmd);
}

# test
for (my $i = 0; $i < $folds; $i++) {
  my $cmd = "$crf_testLoc -m $tmpfile.$i.model $tmpfile.$i.test > $tmpfile.$i.out";
  print "$cmd\n";
  system ($cmd);
  my $cmd = "cat $tmpfile.$i.out >> $tmpfile.all.out ";
  print "$cmd\n";
  system ($cmd);
}

# eval
#for (my $i = 0; $i < $folds; $i++) {
#  my $cmd = "$conllevalLoc -r -d \"	\" < $tmpfile.$i.out";
#  print "$cmd\n";
#  system ($cmd);
#}
my $cmd = "$conllevalLoc -r -d \"	\" < $tmpfile.all.out";
print "$cmd\n";
system ($cmd);

# clean up
`rm -f $tmpfile*`;

######################################################################
# .51
# on head (first 500 lines of tagged.txt)
# f=2, c=3 2fold: 92.86
# f=2, c=3 2fold (more unigram): 93.23
# 93.19 (with B features)
# 93.35 without B features
#
# on tagged.txt
# f=2, c=3 2fold cv: 95.24 / 93.99 => 94.61
# f=2, c=5 2fold cv: => 94.55
# f=2, c=3 2fold cv = 94.77
#
# .48
# on tagged.txt (cat of all *tagged.txt):
# normal, 2fold cv: 95.12 / 93.33
# c=1.5, 2fold cv: 95.14 / 93.38
# f=2, 2fold cv: 95.29 / 93.93
# f=2, c=1.5 2fold cv: 95.31 / 93.82
# f=2, c=3 2fold cv: 95.31 / 93.82
# f=3, 2fold cv: 95.25 / 93.69
#
#
# a=CRF-L1, f=2 2fold cv: 88.25 / 91.29
# a=CRF-L1 2fold cv: 80.63 / -- didn't complete
# a=MIRA 2fold cv: 94.48 / 92.69
# a=MIRA, f=2 2fold cv: 94.31 / 93.60

# 100326 .51 normal, 2fold cv, over all data (including iconip)
# accuracy:  94.83%; precision:  94.83%; recall:  94.83%; FB1:  94.83
