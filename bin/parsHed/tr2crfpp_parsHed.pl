#!/usr/bin/perl -T
# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Tue, 02 Jun 2009 01:30:42

# Modified from template by Min-Yen Kan <kanmy@comp.nus.edu.sg>

=pod HISTORY
 MODIFIED: by Luong Minh thang <luongmin@comp.nus.edu.sg> to generate features at line level for parsHed 
 ORIGIN: created from tr2crfpp.pl by Min-Yen Kan <kanmy@comp.nus.edu.sg>
=cut

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

require 5.0;
use strict 'vars';
use Getopt::Long;
use ParsHed::Config;

my $parscitHome = "$path/../..";

### USER customizable section
$0 =~ /([^\/]+)$/; my $progname = $1;
my $outputVersion = "1.0";
### END user customizable section

sub License {
  print STDERR "# Copyright 2009 \251 by Luong Minh Thang\n";
}

### HELP Sub-procedure
sub Help {
  print STDERR "Generate features for crfpp, similar to tr2crfpp but works at line level with added ngram features\n";
  print STDERR "usage: $progname -h\t[invokes help]\n";
  print STDERR "       $progname -in taggedHeaderFile -out outFile [-k keywordFile -b bigramFile]\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
  print STDERR "\t-k: Default keywordFile $parscitHome/resources/parsHed/keywords\n";
  print STDERR "\t-b: Default bigramFile $parscitHome/resources/parsHed/bigram\n";
}
my $QUIET = 0;
my $HELP = 0;
my $inFile = undef;
my $outFile = undef;
my $dictFile = "$parscitHome/resources/parsCitDict.txt";
my $keywordFile = "$parscitHome/resources/parsHed/keywords";
my $bigramFile = "$parscitHome/resources/parsHed/bigram";
$HELP = 1 unless GetOptions('in=s' => \$inFile,
			    'out=s' => \$outFile,
			    'k=s' => \$keywordFile,
			    'b=s' => \$bigramFile,
			    'h' => \$HELP,
			    'q' => \$QUIET);

if ($HELP || !defined $inFile || !defined $outFile) {
  Help();
  exit(0);
}

if (!$QUIET) {
  License();
}

### Untaint ###
$inFile = untaintPath($inFile);
$outFile = untaintPath($outFile);
$dictFile = untaintPath($dictFile);
$keywordFile = untaintPath($keywordFile);
#$bigramFile = untaintPath($bigramFile);
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
### End untaint ###

my $isGenerateTemplate = 1; #generate template file to stdout
my @templates = (); # for storing templates info

my %dict = ();
readDict($dictFile);

# keyword statistics
my %keywords = (); #hash of hash $keywords{"affiliation"}->{"Institute"} = 1 indicates "Institute" is a high-frequent word for affiliation tag
readKeywordDict($keywordFile, \%keywords);

# bigram statistics
my %bigrams = (); #hash of hash $keywords{"abstract"}->{"we-present"} = 1 indicates "we-present" is a high-frequent bigram for abstract tag
readKeywordDict($bigramFile, \%bigrams);
  
# list of tags trained in parsHed
# those with value 0 do not have frequent keyword features
my $tags = $ParsHed::Config::tags;

# File IOs
if (!(-e $inFile)) { die "# $progname crash\t\tFile \"$inFile\" doesn't exist"; }
open (IF, "<:utf8", $inFile) || die "# $progname crash\t\tCan't open \"$inFile\"";
open (OF, ">:utf8", $outFile) || die "# $progname crash\t\tCan't open \"$outFile\"";

# process input files
while (<IF>) {
  if (/^\#/) { next; }			# skip comments
  elsif (/^\s+$/) { next; }		# skip blank lines
  else {
    my @tokens = split(/ +/);

    my $tag = "";
    my $line = "";
    foreach(@tokens){
      if (/^\s*$/) { # spaces
	next; 
      } elsif (/^\<\/([a-z]+)/) { #end  tag
	# break field content into multi sub-lines that are separated by +L+
	my @sub_lines = split(/\s*\+L\+\s*/, $line);
	foreach my $sub_line (@sub_lines){
	  if($sub_line eq ""){
	    next;
	  }
	  
	  # generate CRF features
	  crfFeature($sub_line, $tag);
	  
	  if($isGenerateTemplate){
	    $isGenerateTemplate = 0; #done generate template file
	  }
	}

	$line = ""; # reset
	next;
      } elsif (/^\<([a-z]+)/) { #beginning tag
	$tag = $1;

	next;
      } else { #contents inside tag
	$line .= "$_ ";
      }
    }

    print OF "\n"; #blank line separate for each header entry
  }
}
close (IF);
close (OF);

###
### END of main program
###


##
# Main method to extract features
## 
sub crfFeature {
  my ($line, $tag) = @_;
  
  my @tmpTokens = split(/\s+/, $line);
  #filter out empty token
  my @tokens = ();
  foreach my $token (@tmpTokens){ 
    if($token ne ""){
      push(@tokens, $token);
    }
  }

  my @feats = ();
  my $featureCount = 0;
  my %featureCounts = (); # to perform feature linking
  my $token = "";

  # full form: does not count in crf template file, simply for outputing purpose to get the whole line data
  my $lineFull = join("|||", @tokens);
  push(@feats, "$lineFull");

  # fullForm token general features: concatenate the wholeline into one token, apply most of Parscit features
  if($ParsHed::Config::isFullFormToken == 1){
    $lineFull =~ s/\d/0/g; # normalize number
    $lineFull =~ s/\|\|\|//g; #strip of the separator we previously added

    push(@templates, "#fullForm token general features\n");
    $featureCounts{"fullFormToken"}->{"start"} = $featureCount;
    $featureCount = generateTokenFeature($lineFull, "UF", $featureCount, \@feats, \@templates);
    $featureCounts{"fullFormToken"}->{"end"} = $featureCount;
  }

  # first token general features: apply most of Parscit features
  if($ParsHed::Config::isFirstToken){
    push(@templates, "#first token general features\n");
    $featureCounts{"firstToken"}->{"start"} = $featureCount;
    $featureCount = generateTokenFeature($tokens[0], "U0", $featureCount, \@feats, \@templates);
    $featureCounts{"firstToken"}->{"end"} = $featureCount;
  }

  # first token keyword features
  if($ParsHed::Config::isKeyword){
    push(@templates, "#first token keyword features\n");
    $featureCounts{"firstKeyword"}->{"start"} = $featureCount;
    $featureCount = generateKeywordFeature($tokens[0], "U1", $featureCount, \@feats, \@templates, \%keywords);
    $featureCounts{"firstKeyword"}->{"end"} = $featureCount;
  }
  
  # second token general features: apply most of Parscit features
  if($ParsHed::Config::isSecondToken || $ParsHed::Config::isBigram){
    $token = "EMPTY";

    if($#tokens > 0){#  1 token
      $token = $tokens[1];
    }
  }
  if($ParsHed::Config::isSecondToken){
    push(@templates, "#second token general features\n");
    $featureCounts{"secondToken"}->{"start"} = $featureCount;
    $featureCount = generateTokenFeature($token, "U2", $featureCount, \@feats, \@templates);
    $featureCounts{"secondToken"}->{"end"} = $featureCount;
  }

  # bigram features
  if($ParsHed::Config::isBigram){
    my $nGram  = $tokens[0];
    $nGram =~ s/^\p{P}+//g; #strip out leading punctuations
    $nGram =~ s/\p{P}+$//g; #strip out trailing punctuations
    $nGram =~ s/\d/0/g; #canocalize number into "0"
    $nGram = lc($nGram);

    $token =~ s/^\p{P}+//g; #strip out leading punctuations
    $token =~ s/\p{P}+$//g; #strip out trailing punctuations
    $token =~ s/\d/0/g; #canocalize number into "0"
    $token = lc($token);

    $nGram .= "-$token";

    push(@templates, "#bigram features\n");
    $featureCounts{"bigram"}->{"start"} = $featureCount;
    $featureCount = generateKeywordFeature($nGram, "U4", $featureCount, \@feats, \@templates, \%bigrams);
    $featureCounts{"bigram"}->{"end"} = $featureCount;
  }

  # second last token general features: apply most of Parscit features
  if($ParsHed::Config::isSecondLastToken){
    $token = "EMPTY";
    if($#tokens > 0){# only 1 token
      $token = $tokens[$#tokens-1];
    }
  }
  if($ParsHed::Config::isSecondLastToken){
    push(@templates, "#second last token general features\n");
    $featureCounts{"secondLastToken"}->{"start"} = $featureCount;
    $featureCount = generateTokenFeature($token, "U7", $featureCount, \@feats, \@templates);
    $featureCounts{"secondLastToken"}->{"end"} = $featureCount;
  }

  # last token general features: apply most of Parscit features
  if($ParsHed::Config::isLastToken){
    push(@templates, "#last token general features\n");
    $featureCounts{"lastToken"}->{"start"} = $featureCount;
    $featureCount = generateTokenFeature($tokens[$#tokens], "U8", $featureCount, \@feats, \@templates);
    $featureCounts{"lastToken"}->{"end"} = $featureCount;
  }

  ## feature linking in terms of template file
  my $i;
  if($ParsHed::Config::isBack1){
    if($isGenerateTemplate){ 
      # to constraint on last token features at -1 relative position
      $i = 0;
      push(@templates, "#constraint on last token features at -1 relative position \n");
      for(my $j=$featureCounts{"lastToken"}->{"start"}; $j < $featureCounts{"lastToken"}->{"end"}; $j++){
	push(@templates, "UA".$i++.":%x[-1,$j]\n");
      }
      push(@templates, "\n");  
    }
  }
  push(@templates, "\n");  

  if($ParsHed::Config::isForw1){
    if($isGenerateTemplate){ 
      # to constraint on first token features at 1 relative position
      $i = 0;
      push(@templates, "#constraint on first token features at 1 relative position \n");
      for(my $j=$featureCounts{"firstToken"}->{"start"}; $j < $featureCounts{"firstToken"}->{"end"}; $j++){
	push(@templates, "UB".$i++.":%x[1,$j]\n");
      }
      push(@templates, "\n");  
    }
  }
  push(@templates, "\n");  
  ## end feature linking

  ##
  # output tag
  ##
  push(@feats, $tag);

  if($isGenerateTemplate){
    push(@templates, "# Output\nB0\n");  
    print STDOUT join ("", @templates);
  }
  print OF join (" ", @feats);
  print OF "\n";
}

sub generateKeywordFeature {
  my ($token, $label, $featureCount, $feats, $templates, $keywords) = @_;

  my $i = 0;

  $token =~ s/^\p{P}+//g; #strip out leading punctuations
  $token =~ s/\p{P}+$//g; #strip out trailing punctuations
  $token =~ s/\d/0/g; #canocalize number into "0"

  foreach(keys %{$tags}){ # 9 tags: feature 1-10
    if($tags->{$_} == 0) { next; }

    if($keywords->{$_}->{$token}){
      push(@{$feats}, "$_-$token");
    } else {
      push(@{$feats}, "none");
    }
    
    if($isGenerateTemplate){
      push(@{$templates}, "$label".$i++.":%x[0,$featureCount]\n");
      $featureCount++;
    }
  }
  push(@{$templates}, "\n");

  return $featureCount;
}

sub generateTokenFeature {
  my ($token, $label, $featureCount, $feats, $templates) = @_;

  # prep
  my $word = $token;
  my $wordNP = $token;			      # no punctuation
  $wordNP =~ s/[^\w]//g;
  if ($wordNP =~ /^\s*$/) { $wordNP = "EMPTY"; }
  my $wordLCNP = lc($wordNP);    # lowercased word, no punctuation
  if ($wordLCNP =~ /^\s*$/) { $wordLCNP = "EMPTY"; }
  
  ## feature generation
  push(@{$feats}, "TOKEN-$word");			    # 0 = lexical word

  my @chars = split(//,$word);
  my $lastChar = $chars[-1];
  if ($lastChar =~ /[a-z]/) { $lastChar = 'a'; }
  elsif ($lastChar =~ /[A-Z]/) { $lastChar = 'A'; }
  elsif ($lastChar =~ /[0-9]/) { $lastChar = '0'; }
  push(@{$feats}, $lastChar);		       # 1 = last char
  
  push(@{$feats}, $chars[0]);		      # 2 = first char
  push(@{$feats}, join("",@chars[0..1]));  # 3 = first 2 chars
  push(@{$feats}, join("",@chars[0..2]));  # 4 = first 3 chars
  push(@{$feats}, join("",@chars[0..3]));  # 5 = first 4 chars
  
  push(@{$feats}, $chars[-1]);		       # 6 = last char
  push(@{$feats}, join("",@chars[-2..-1])); # 7 = last 2 chars
  push(@{$feats}, join("",@chars[-3..-1])); # 8 = last 3 chars
  push(@{$feats}, join("",@chars[-4..-1])); # 9 = last 4 chars
  
  push(@{$feats}, $wordLCNP);  # 10 = lowercased word, no punct
  
  # 11 - capitalization
  my $ortho = ($wordNP =~ /^[A-Z]$/) ? "singleCap" :
    ($wordNP =~ /^[A-Z][a-z]+/) ? "InitCap" :
      ($wordNP =~ /^[A-Z]+$/) ? "AllCap" : "others";
  push(@{$feats}, $ortho);
  
  # 12 - numbers
  my $num = ($wordNP =~ /^(19|20)[0-9][0-9]$/) ? "year" :
    ($word =~ /[0-9]\-[0-9]/) ? "possiblePage" :
      ($word =~ /[0-9]\([0-9]+\)/) ? "possibleVol" :
	($wordNP =~ /^[0-9]$/) ? "1dig" :
	  ($wordNP =~ /^[0-9][0-9]$/) ? "2dig" :
	    ($wordNP =~ /^[0-9][0-9][0-9]$/) ? "3dig" :
	      ($wordNP =~ /^[0-9]+$/) ? "4+dig" :
		($wordNP =~ /^[0-9]+(th|st|nd|rd)$/) ? "ordinal" :
		  ($wordNP =~ /[0-9]/) ? "hasDig" : "nonNum";
  push(@{$feats}, $num);
  
  # gazetteer (names)
  my $dictStatus = (defined $dict{$wordLCNP}) ? $dict{$wordLCNP} : 0;
  #      my $isInDict = ($dictStatus != 0) ? "isInDict" : "no";
  my $isInDict = $dictStatus;
  
  my ($publisherName,$placeName,$monthName,$lastName,$femaleName,$maleName);
  if ($dictStatus >= 32) { $dictStatus -= 32; $publisherName = "publisherName" } else { $publisherName = "no"; }
  if ($dictStatus >= 16) { $dictStatus -= 16; $placeName = "placeName" } else { $placeName = "no"; }
  if ($dictStatus >= 8) { $dictStatus -= 8; $monthName = "monthName" } else { $monthName = "no"; }
  if ($dictStatus >= 4) { $dictStatus -= 4; $lastName = "lastName" } else { $lastName = "no"; }
  if ($dictStatus >= 2) { $dictStatus -= 2; $femaleName = "femaleName" } else { $femaleName = "no"; }
  if ($dictStatus >= 1) { $dictStatus -= 1; $maleName = "maleName" } else { $maleName = "no"; }
  
  push(@{$feats}, $isInDict);		    # 13 = name status
  push(@{$feats}, $maleName);		      # 14 = male name
  push(@{$feats}, $femaleName);		    # 15 = female name
  push(@{$feats}, $lastName);		      # 16 = last name
  push(@{$feats}, $monthName);		     # 17 = month name
  push(@{$feats}, $placeName);		     # 18 = place name
  push(@{$feats}, $publisherName);	 # 19 = publisher name
  
  #push(@{$feats[$j]}, $hasPossibleEditor);	# 20 = possible editor
  
  # not accurate ($#tokens counts tags too)
#  my $location = int ($i / $#tokens * 12);
#  push(@{$feats}, $location);	      # 21 = relative location
  
  # 22 - punctuation
  my $punct = ($word =~ /^[\"\'\`]/) ? "leadQuote" :
    ($word =~ /[\"\'\`][^s]?$/) ? "endQuote" :
      ($word =~ /\-.*\-/) ? "multiHyphen" :
	($word =~ /[\-\,\:\;]$/) ? "contPunct" :
	  ($word =~ /[\!\?\.\"\']$/) ? "stopPunct" :
	    ($word =~ /^[\(\[\{\<].+[\)\]\}\>].?$/) ? "braces" :
	      ($word =~ /^[0-9]{2-5}\([0-9]{2-5}\).?$/) ? "possibleVol" : "others";
  push(@{$feats}, $punct);		    # 22 = punctuation

  my $i = 0;
  my $curSize = scalar(@{$feats});
  if($isGenerateTemplate){
    for(my $j=$featureCount; $j < $curSize; $j++){
      push(@{$templates}, "$label".$i++.":%x[0,$j]\n");
    }
  }

  push(@{$templates}, "\n");  
  return $curSize;
}

sub readKeywordDict {
  my ($inFile, $keywords) = @_;

  open (IF, "<:utf8", $inFile) || die "$progname fatal\t\tCannot open \"$inFile\"!";
  print STDERR "Load keywords from file $inFile\n";
  #process input file
  while(<IF>){
    chomp;
    
    if(/^(.+?): (.+)$/){
      my $tag = $1;
      my @tokens = split(/\s+/, $2);
      $keywords->{$tag} = ();
      foreach(@tokens){
	$keywords->{$tag}->{$_} = 1;
      }
    }
  }

  close (IF);
}

sub readDict {
  my $dictFileLoc = shift @_;
  my $mode = 0;
  print STDERR "Read dict from $dictFileLoc\n";
  open (DATA, $dictFileLoc) || die "$progname fatal\t\tCannot open \"$dictFileLoc\"!";
  while (<DATA>) {
    if (/^\#\# Male/) { $mode = 1; }			  # male names
    elsif (/^\#\# Female/) { $mode = 2; }		# female names
    elsif (/^\#\# Last/) { $mode = 4; }			  # last names
    elsif (/^\#\# Chinese/) { $mode = 4; }		  # last names
    elsif (/^\#\# Months/) { $mode = 8; }		 # month names
    elsif (/^\#\# Place/) { $mode = 16; }		 # place names
    elsif (/^\#\# Publisher/) { $mode = 32; }	     # publisher names
    elsif (/^\#/) { next; }
    else {
      chop;
      my $key = $_;
      my $val = 0;

      if (/\t/) {				     # has probability
	($key,$val) = split (/\t/,$_);
      }
      #exit;

      # already tagged (some entries may appear in same part of lexicon more than once
#      if ($dict{$key} >= $mode) { next; }
      if ($dict{$key} && $dict{$key} >= $mode) { next; } # Thang fix: uninitialized problem
      else { $dict{$key} += $mode; }		      # not yet tagged
    }
  }
  close (DATA);
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
