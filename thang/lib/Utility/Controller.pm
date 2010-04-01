package Utility::Controller;
#
# This package is used to ...
#
# Minh-Thang Luong 03 June 09
#
require 'dumpvar.pl';
use strict;

my $root = "$ENV{SMT_HOME}";
my $B="100";
my $corpora = "acl05";

#### List methods ###
# checkDir
# getNumLines
# getFilesInDir
# loadFWHash
# loadListHash
# loadListArray
# loadLexFileTopN
# loadLexFile
# getWordFreq
# getMorphemeFreq
# getTopMorphemes
# processLexicalFile
# stringSim
# sequenceSim
# max
# getIdentityStr
# processLineFile
# normalDistributionSet
# normalDistribution
# printHashAlpha
# printHashKeyAlpha
# printHashNumeric
# printHashKeyNumeric
# outputHashNumeric
# outputHashKey
# outputHashKeySTDERR
# lowercase
# execute
# execute1
# newTmpFile
#####################

# checkDir
sub checkDir {
  my ($outDir) = @_;

  if(-d $outDir){
    print STDERR "#! Directory $outDir exists!\n";
  } else {
    print STDERR "# Directory $outDir does not exist! Creating ...\n";
    execute("mkdir -p $outDir");
  }
}

# generate a hash of $n int random value btw [$min, $max]
sub getHashRandom {
  my ($n, $min, $max, $index) = @_;

  if($max < $min){
    die "Die: max $max < min $min\n";
  }

  if($n > ($max - $min + 1)){
    die "Die: can't generate $n distinct values in range [$min, $max]\n";
  }

  my $count = 0;
  my $upper = $min - 1;
  while($count < $n){
    my $num = $min + int(rand($max-$min+1)); #generate values in [0, $max-$min]
    if(!$index->{$num}){
      $index->{$num} = 1;
      $count++;
      
      if($num > $upper){
	$upper = $num;
      }
    }
  }

  return $upper;
}

# get the number of lines in a file
sub getNumLines {
  my ($inFile) = @_;

  ### Count & verify the totalLines ###
  chomp(my $tmp = `wc -l $inFile`);
  my @tokens = split(/ /, $tmp);
  return $tokens[0];
}

### Get a list of files in the provided directory, and sort them alphabetically###
sub getFilesInDir{
  my ($inDir, $files) = @_;

  if(!-d $inDir) {
    die "Die: directory $inDir does not exist!\n";
  }
  
  opendir DIR, $inDir or die "cannot open dir $inDir: $!";
  my @files= grep { $_ ne '.' && $_ ne '..' && $_ !~ /~$/} readdir DIR;
  closedir DIR;
  
  my @sorted_files = sort { $a cmp $b } @files;
  @{$files} = @sorted_files;
}

sub loadFWHash {
  my ($inFile, $hash) = @_;

  open(IF, "<:utf8", $inFile) || die "#Can't open file \"$inFile\"";

  print STDERR "# Loading $inFile ";
  my $count = 0;
  while(<IF>){ 
    chomp;

    $hash->{$_} = 1;
    if($_ =~ /\/\w\w\w$/){
      $hash->{"$_+"} = 1; # add plus sign
    }

    $count++;
    if($count % 1000 == 0){
      print STDERR ".";
    }
  }
  print STDERR " - Done! Total lines read = $count\n";
  close IF;
}

sub loadListHash {
  my ($inFile, $hash) = @_;

  open(IF, "<:utf8", $inFile) || die "#Can't open file \"$inFile\"";

  print STDERR "# Loading $inFile ";
  my $count = 0;
  while(<IF>){ 
    chomp;

    $hash->{$_} = 1;
    $count++;
    if($count % 1000 == 0){
      print STDERR ".";
    }
  }
  print STDERR " - Done! Total lines read = $count\n";
  close IF;
}

sub loadListArray {
  my ($inFile, $array) = @_;

  open(IF, "<:utf8", $inFile) || die "#Can't open file \"$inFile\"";

  my $count = 0;
  while(<IF>){ 
    chomp;

    $array->[$count++] = $_;
  }

  close IF;
}

sub loadLexFileTopN {
  my ($inFile, $hash, $topN) = @_;

  open(IF, "<:utf8", $inFile) || die "#Can't open file \"$inFile\"";

  print STDERR "# Loading $inFile ";
  my $topNCount = 0;
  my $count = 0;
  while(<IF>){ 
    chomp;
    if(/^\#\#\#/){
      $topNCount = 0;
      next;
    }
    if($topNCount >= $topN) { next; }
    
    my ($eToken, $fToken, $value) = split(/ /, $_);
    if(!$hash->{$fToken}){
      $hash->{$fToken} = ();
    }
    $hash->{$fToken}->{$eToken} = $value;

    $topNCount++;
    $count++;
    if($count % 1000 == 0){
      print STDERR ".";
    }
  }
  print STDERR " - Done! Total lines read = $count\n";
  close IF;
}

sub loadLexFile {
  my ($inFile, $hash, $min) = @_;

  open(IF, "<:utf8", $inFile) || die "#Can't open file \"$inFile\"";

  print STDERR "# Loading $inFile ";
  my $isSkip = 0;
  my $count = 0;
  while(<IF>){ 
    chomp;
    if(/^\#\#\#/){
      $isSkip = 0;
      next;
    }
    if($isSkip) { next; }
    
    $count++;
    my ($eToken, $fToken, $value) = split(/ /, $_);
    if(defined $min && $value < $min){ 
      $isSkip = 1; 
    } else {
      if(!$hash->{$fToken}){
	$hash->{$fToken} = ();
      }
      $hash->{$fToken}->{$eToken} = $value;
    }
    if($count % 1000 == 0){
      print STDERR ".";
    }
  }
  print STDERR " - Done! Total lines read = $count\n";
  close IF;
}

##
# sub getWordFreq($inFile, $freqs)
#
# Process the $inFile by lowercasing, and counting the freqs.
#
##
sub getWordFreq {
  my ($inFile, $freqs) = @_;
  $inFile = lowercase($inFile);

  open(IF, "<:utf8", $inFile) || die "#Can't open file \"$inFile\"";

  my $numTokens = 0;
  my $numSents = 0;
  while(<IF>){ #process each sentence of the corpus
    chomp;
    my @tokens = split(/\s+/);

    foreach my $token (@tokens){ # count morpheme freq
      if(($token eq "") #empty token
	 || ($token =~ /\d/) #mixedNum
	 || ($token =~ /^[\p{P}\$\+=]+$/)){ #puncOnly
	next;
      }

      if(!defined $freqs->{$token}){
	$freqs->{$token} = 0;
      }
#      print STDERR "$token\n";
      $freqs->{$token}++;

      $numTokens++;
    }
    
    $numSents++;
    if($numSents % 100000 == 0) {print STDERR "$numSents\n";}
  } # end while (<IF>)
  close IF;  
} 


##
## getTopMorphemes($morphemeFreq, $topMorphemes, $topN, $filterPattern) ##
## Get top morphemes, stored in hash $topMorphemes
##
sub getTopMorphemes {
  my($morphemeInfo, $topMorphemes, $topN, $filterPattern, $contentWords) = @_;
  if(!defined $filterPattern) { $filterPattern = ""; }

  # sort based on frequency
  my @sorted_morphemes = sort {$morphemeInfo->{$b} <=> $morphemeInfo->{$a}} keys %{$morphemeInfo};
  
  my $count = 0;
  print STDERR "Filter content words:";
  foreach my $morpheme (@sorted_morphemes){
    if($count == $topN) { last; }
    $count++;

    #filter out
    if(!($morpheme =~ /$filterPattern/)){ next; }
    if(defined $contentWords){ #filtered content words
      if($morpheme =~ /^(.+)\/\w\w\w/){
	if($contentWords->{$1}){
	  print STDERR "\t$1";
	  next;
	}
      }
    }

    $topMorphemes->{"$morpheme"} = 1;
  }
  print STDERR "\n";
}

##
# sub processLexicalFile($fromMorphemes, $lexicalFile, $topLex, $transTo)
# Input
#   $lexicalFile: assumed that it has been sorted according to column 2!!!
# Output : $transTo, which maps a from-topMorpheme to a list (size $topLex)
#          of to-topMorphemes that it is likely to translate to. The probabily value is stored as well.
#         $transTo->{$from-topMorpheme}->{$to-topMorpheme} = lexical probability.
##
sub processLexicalFile {
  my ($fromMorphemes, $lexicalFile, $topLex, $transTo) = @_;

  print STDERR "Process lexical file $lexicalFile\n";
  my @sorted_fromMorphemes = sort {$a cmp $b} keys %{$fromMorphemes}; #sort alphabetically

  open(IF, "<:utf8", $lexicalFile) || die "#Can't open file \"$lexicalFile\"";
  if(eof(IF)){
    print STDERR "Empty file $lexicalFile\n";
  }

  my $line = "";
  my @tokens = ();
  my $terminate = 0;
  my $escapedFromMorpheme = "";
  foreach my $fromMorpheme (@sorted_fromMorphemes){
    $escapedFromMorpheme = $fromMorpheme;
    $escapedFromMorpheme =~ s/\+/\\\+/g; #for regex matching

    #find starting line that matches the morpheme
    do {
      $line = <IF>;
    } while (!($line =~ / $escapedFromMorpheme /) && !eof(IF));

    if(!($line =~ / $escapedFromMorpheme /)){
      print STDERR "Warning: no entry for $fromMorpheme\n";
      last;
    }
    
    # process through all the translation of the from morpheme and keep tracks of lexical probabilities
    my %probs = (); 
    while($line =~ / $escapedFromMorpheme /){
     my @tokens = split(/\s+/, $line);
     $probs{$tokens[0]} = $tokens[2];

     if(!eof(IF)){
	$line = <IF>;
      }
    }

    # sort by probability
    my @sorted_trans = sort {$probs{$b} <=> $probs{$a}} keys %probs;
    my $count = 0;
#    print STDERR "$fromMorpheme:";
    foreach my $tran (@sorted_trans){
      if($count++ < $topLex){
	if(!$transTo->{$fromMorpheme}){
	  $transTo->{$fromMorpheme} = ();
	}
	$transTo->{$fromMorpheme}->{$tran} = $probs{$tran}; #$fromMorpheme translates to $tran
	# print STDERR " $tran ($probs{$tran})";
      }
    }
#    print STDERR "\n";
  }
}

##
## stringSim($str1, $str2) ##
# Compute similarity between 2 strings
# by computing the longest common subsequence
# of their two sequence of chars/words depending on split pattern (default is chars)
##
sub stringSim {
  my ($str1, $str2, $pattern) = @_;

  if(!defined $pattern){
    $pattern = "";
  }

  my @seq1 = split(/$pattern/, $str1);
  my @seq2 = split(/$pattern/, $str2);

  my $sim = sequenceSim(\@seq1, \@seq2);
  return $sim;
}

# Longest common subsequence
# compute similarity score between two sequences
# complexiy O(mn), m and n are the lengths of the two sequences
sub sequenceSim{
  my($seq1, $seq2) = @_;
  my $l1 = @{$seq1};
  my $l2 = @{$seq2};

  my @numMatches = ();

  # initialization
  for(my $i=0; $i<=$l1; $i++){
    push(@numMatches, []);
    for(my $j=0; $j<=$l2; $j++){
      $numMatches[$i]->[$j] = 0;
    }
  }

  # dynamic programming
  for(my $i=1; $i<=$l1; $i++){
    push(@numMatches, []);
    for(my $j=1; $j<=$l2; $j++){
      if($seq1->[$i-1] eq $seq2->[$j-1]){
	$numMatches[$i]->[$j] = 1 + $numMatches[$i-1]->[$j-1];
      }
      else {
	$numMatches[$i]->[$j] = $numMatches[$i-1]->[$j] > $numMatches[$i]->[$j-1] ?
	  $numMatches[$i-1]->[$j] : $numMatches[$i]->[$j-1];
      }
    }
  }
  
  my $sim = sprintf("%.3f", $numMatches[$l1]->[$l2]/max($l1, $l2));
  return $sim;
}

#2-argument
sub max {
  my ($a, $b) = @_;
  return ($a > $b) ? $a : $b;
}

sub getIdentityStr {
  my ($dir) = @_;

  if($dir eq ""){
    $dir = `pwd`;
    chomp($dir);
  }

  my $identityStr="";
  if($ENV{HOSTNAME} =~ /^(.+?)\./){
    $identityStr .= "$1 ";
  }
  my $date=`date`;
  $identityStr .= "$date\t$dir";

  return $identityStr;
}

sub processLineFile {
  my ($lineFile, $lineList) = @_;

  open(IF, "<", $lineFile) || die "#Can't open file \"$lineFile\"";

  ### get a list of lines to be extracted
  my $max = 0;
  my $i = 0;
  while(<IF>){
    chomp;
    if(/^\#/) { next; };
    
    my @tokens = split(/\s+/, $_);
    if(scalar(@tokens) == 0){
      print STDERR "Skip empty line $i\n";
    } else {
      $lineList->{$tokens[0]} = 1;

      if($tokens[0] > $max){
	$max = $tokens[0];
      }
    }
    
    $i++;
  }
  close IF;

  return $max;
}

sub normalDistributionSet {
  my ($numbers) = @_;

  my $count = scalar(@{$numbers});
  my $sum = 0;
  my $squareSum = 0;
  foreach(@{$numbers}){
    $sum += $_;
    $squareSum += ($_*$_);
  }
  return normalDistribution($sum, $squareSum, $count);
}

  
##
## normalDistribution($sum, $squareSum, $count) ##
#
# sum: the total sum of all element values
# squareSum: the total sum of squares of all element values
# count: num of elements
##
sub normalDistribution {
  my ($sum, $squareSum, $count) = @_;

  my $mean = $sum / $count;
  my $stddev = 0;
  if($count < 2) {
    $stddev = sqrt(($squareSum - $count*$mean*$mean)/ $count);
  } else {
    $stddev = sqrt(($squareSum - $count*$mean*$mean)/ ($count - 1));
  }

  return ($mean, $stddev);
}

sub printHashAlpha{
  my ($hash, $topN, $name) = @_;

  if(!defined $name){
    $name = "hash";
  }
  print STDERR "Output $name\n";

  my @sorted_keys = sort {$a cmp $b} keys %{$hash};
  my $count = 0;
  foreach(@sorted_keys){
    print STDOUT "$_\t$hash->{$_}\n";

    $count++;
    if($count == $topN){
      last;
    }
  }
}

sub printHashKeyAlpha{
  my ($hash, $topN, $name) = @_;

  if(!defined $name){
    $name = "hash keys";
  }
  print STDERR "Output $name\n";

  my @sorted_keys = sort {$a cmp $b} keys %{$hash};
  my $count = 0;
  foreach(@sorted_keys){
    print STDOUT "$_\n";

    $count++;
    if($count == $topN){
      last;
    }
  }
}

sub printHashNumeric{
  my ($hash, $topN, $name) = @_;

  if(!defined $name){
    $name = "hash keys";
  }
  print STDERR "Output $name\n";

  my @sorted_keys = sort {$hash->{$b} <=> $hash->{$a}} keys %{$hash};
  my $count = 0;
  foreach(@sorted_keys){
    print STDOUT "$_ $hash->{$_}\n";

    $count++;
    if($count == $topN){
      last;
    }
  }
}

sub printHashKeyNumeric{
  my ($hash, $topN, $name) = @_;

  if(!defined $name){
    $name = "hash keys";
  }
  print STDERR "Output $name\n";

  my @sorted_keys = sort {$hash->{$b} <=> $hash->{$a}} keys %{$hash};
  my $count = 0;
  foreach(@sorted_keys){
    print STDOUT "$_\n";

    $count++;
    if($count == $topN){
      last;
    }
  }
}

sub outputHashNumeric{
  my ($outFile, $hash, $topN, $name) = @_;

  if(!defined $name){
    $name = "hash keys";
  }
  print STDERR "Output $name to $outFile\n";
  open(OF, ">:utf8", $outFile) || die "#Can't open file \"$outFile\"";

  my @sorted_keys = sort {$hash->{$b} <=> $hash->{$a}} keys %{$hash};
  my $count = 0;
  foreach(@sorted_keys){
    print OF "$_\t$hash->{$_}\n";

    $count++;
    if($count == $topN){
      last;
    }
  }
  close OF;
}

##
# sub outputHashKey($hash, $outFile, $name)
# print all keys of the hash to the outFile ($name is used for logging purpose).
##
sub outputHashKey {
  my ($hash, $outFile, $topN, $name) = @_;

  if(!defined $name){
    $name = "hash keys";
  }
  print STDERR "Output $name to $outFile\n";
  open(OF, ">:utf8", $outFile) || die "#Can't open file \"$outFile\"";

  my @sorted_keys = sort {$a cmp $b} keys %{$hash};
  my $count = 0;
  foreach(@sorted_keys){
    print OF "$_\n";

    $count++;
    if($count == $topN){
      last;
    }
  }
  close OF;
}

##
# sub outputHashKey($hash, $outFile, $name)
# print all keys of the hash to the outFile ($name is used for logging purpose).
##
sub outputHashKeySTDERR {
  my ($hash, $topN) = @_;

  my @sorted_keys = sort {$a cmp $b} keys %{$hash};
  my $count = 0;
  foreach(@sorted_keys){
    print STDERR "$_\t";

    $count++;
    if($count == $topN){
      last;
    }
  }
  print STDERR "\n";
}

sub lowercase {
  my ($inFile) = @_;

  if(!(-e "$inFile.lowercased")){
    execute1("$ENV{SMT_HOME}/scripts/lowercase.perl < $inFile > $inFile.lowercased");
  }

~  return "$inFile.lowercased";
}

sub execute {
  my ($cmd) = @_;
  print STDERR "Executing: $cmd\n";
  system($cmd);
}

sub execute1 {
  my ($cmd) = @_;
  #print STDERR "Executing: $cmd\n";
  system($cmd);
}

sub newTmpFile {
  my $tmpFile = `date '+%Y%m%d-%H%M%S-$$'`;
  chomp($tmpFile);
  return $tmpFile;
}

1;
