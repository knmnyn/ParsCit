package ParsHed::Tr2crfpp;
#
# Created from templateAppl.pl version 3.4 by Min-Yen Kan <kanmy@comp.nus.edu.sg>.
# Modified by Isaac Councill on 7/20/07: wrapped the code as a package for use by
# an external controller.
#
# Copyright 2005 \251 by Min-Yen Kan (not sure what this means for IGC edits, but
# what the hell -IGC)
#

use strict 'vars';
use utf8;
use FindBin;
use ParsHed::Config;
use Encode ();

### USER customizable section

my $tmpDir = $ParsHed::Config::tmpDir;
$tmpDir = "$FindBin::Bin/../$tmpDir";

my $dictFile = $ParsHed::Config::dictFile;
$dictFile = "$FindBin::Bin/../$dictFile";

my $keywordFile = $ParsHed::Config::keywordFile;
$keywordFile = "$FindBin::Bin/../$keywordFile";

my $bigramFile = $ParsHed::Config::bigramFile;
$bigramFile = "$FindBin::Bin/../$bigramFile";

my $crf_test = $ENV{'CRFPP_HOME'} ? "$ENV{'CRFPP_HOME'}/bin/crf_test" : "$FindBin::Bin/../$ParsHed::Config::crf_test";

my $modelFile = $ParsHed::Config::modelFile;
$modelFile = "$FindBin::Bin/../$modelFile";

### END user customizable section

my %dict = ();

# keyword statistics
my %keywords = (); #hash of hash $keywords{"affiliation"}->{"Institute"} = 1 indicates "Institute" is a high-frequent word for affiliation tag

# bigrap statistics
my %bigrams = (); #hash of hash $keywords{"abstract"}->{"we-present"} = 1 indicates "we-present" is a high-frequent bigram fro abstract tag

# list of tags trained in parsHed
# those with value 0 do not have frequent keyword features
my $tags = $ParsHed::Config::tags;

sub prepData {
  my ($rCiteText, $filename) = @_;
  my $tmpfile = buildTmpFile($filename);

  # Thang Mar 2010: move these lines inside the method, only load when running
  readDict($dictFile);
  readKeywordDict($keywordFile, \%keywords);
  readKeywordDict($bigramFile, \%bigrams);
  
  # File IOs
  open (OF, ">:utf8", $tmpfile) || die "# crash\t\tCan't open \"$tmpfile\"";
  
  # process input files
  foreach (split "\n", $$rCiteText) {
    if (/^\#/) { next; }			# skip comments
    elsif (/^\s*$/) { next; }		# skip blank lines
    else {
      my $tag = "header";
      my @feats = ();

      # generate CRF features
      crfFeature($_, $tag, \@feats);
      print OF join (" ", @feats);
      print OF "\n";
    }
  }
  close (IF);
  close (OF);

  return $tmpfile;
}  # prepData

##
# Main method to extract features
## 
sub crfFeature {
  my ($line, $tag, $feats) = @_;
  my $token = "";

  my @tmpTokens = split(/\s+/, $line);
  #filter out empty token
  my @tokens = ();
  foreach my $token (@tmpTokens){ 
    if($token ne ""){
      push(@tokens, $token);
    }
  }

  # full form: does not count in crf template file, simply for outputing purpose to get the whole line data
  my $lineFull = join("|||", @tokens);
  push(@{$feats}, "$lineFull");

  # fullForm token general features: concatenate the wholeline into one token, apply most of Parscit features
  if($ParsHed::Config::isFullFormToken){
    $lineFull =~ s/\d/0/g; # normalize number
    $lineFull =~ s/\|\|\|//g; #strip of the separator we previously added

    generateTokenFeature($lineFull, $feats);
  }

  # first token general features: apply most of Parscit features
  if($ParsHed::Config::isFirstToken){
    generateTokenFeature($tokens[0], $feats);
  }

  # first token keyword features
  if($ParsHed::Config::isKeyword){
    generateKeywordFeature($tokens[0], $feats, \%keywords);
  }
  
  # second token general features: apply most of Parscit features
  if($ParsHed::Config::isSecondToken || $ParsHed::Config::isBigram){
    $token = "EMPTY";

    if($#tokens > 0){#  1 token
      $token = $tokens[1];
    }
  }
  if($ParsHed::Config::isSecondToken){
    generateTokenFeature($token, $feats);
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
    generateKeywordFeature($nGram, $feats, \%bigrams);
  }

  # second last token general features: apply most of Parscit features
  if($ParsHed::Config::isSecondLastToken){
    $token = "EMPTY";
    if($#tokens > 0){# only 1 token
      $token = $tokens[$#tokens-1];
    }
  }
  if($ParsHed::Config::isSecondLastToken){
    generateTokenFeature($token, $feats);
  }

  # last token general features: apply most of Parscit features
  if($ParsHed::Config::isLastToken){
    generateTokenFeature($tokens[$#tokens], $feats);
  }

  ##
  # output tag
  ##
  push(@{$feats}, $tag);
}

sub generateKeywordFeature {
  my ($token, $feats, $keywords) = @_;

  my $i = 0;

  $token =~ s/^\p{P}+//g; #strip out leading punctuations
  $token =~ s/\p{P}+$//g; #strip out trailing punctuations
  $token =~ s/\d/0/g; #canocalize number into "0"

  foreach(keys %{$tags}){ # 9 tags: feature 1-10
    if($tags->{$_} == 0) { next; };

    if($keywords->{$_}->{$token}){
      push(@{$feats}, "$_-$token");
    } else {
      push(@{$feats}, "none");
    }
  }
}

sub generateTokenFeature {
	my ($token, $feats) = @_;
	
	# prep
	my $word	= $token;
	my $wordNP	= $token;			# No punctuation

	$wordNP		=~ s/[^\w]//g;
	if ($wordNP =~ /^\s*$/) { $wordNP = "EMPTY"; }

	my $wordLCNP  = lc($wordNP);	# Lowercased word, no punctuation
	if ($wordLCNP =~ /^\s*$/) { $wordLCNP = "EMPTY"; }
  
	## Feature generation
  	push(@{$feats}, "TOKEN-$word");			    # 0 = lexical word

	my @chars = split(//,$word);
	my $lastChar = $chars[-1];
	if ($lastChar =~ /[a-z]/) { $lastChar = 'a'; }
	elsif ($lastChar =~ /[A-Z]/) { $lastChar = 'A'; }
	elsif ($lastChar =~ /[0-9]/) { $lastChar = '0'; }
	push(@{$feats}, $lastChar);		       # 1 = last char
 
	my $chars_len = scalar @chars;

	push(@{$feats}, $chars[0]);		      		# 2 = first char
	if ($chars_len >= 2) {	
	  	push(@{$feats}, join("",@chars[0..1]));	# 3 = first 2 chars
	} else {
		push(@{$feats}, $chars[0]);		      	# 3 = first 2 chars
	}
	if ($chars_len >= 3) {
		push(@{$feats}, join("",@chars[0..2]));	# 4 = first 3 chars
	} elsif ($chars_len >= 2) {
	  	push(@{$feats}, join("",@chars[0..1]));	# 4 = first 3 chars
	} else {
		push(@{$feats}, $chars[0]);		      	# 4 = first 3 chars
	}
	if ($chars_len >= 4) {
		push(@{$feats}, join("",@chars[0..3]));	# 5 = first 4 chars
	} elsif ($chars_len >= 3) {
		push(@{$feats}, join("",@chars[0..2]));	# 5 = first 4 chars
	} elsif ($chars_len >= 2) {
	  	push(@{$feats}, join("",@chars[0..1]));	# 5 = first 4 chars
	} else {
		push(@{$feats}, $chars[0]);		      	# 5 = first 4 chars
	}
  
	push(@{$feats}, $chars[-1]);					# 6 = last char
	if ($chars_len >= 2) {
		push(@{$feats}, join("",@chars[-2..-1]));	# 7 = last 2 chars
	} else {
		push(@{$feats}, $chars[-1]);				# 7 = last 2 chars
	}
	if ($chars_len >= 3) {
		push(@{$feats}, join("",@chars[-3..-1]));	# 8 = last 3 chars
	} elsif ($chars_len >= 2) {
		push(@{$feats}, join("",@chars[-2..-1]));	# 8 = last 3 chars
	} else {
		push(@{$feats}, $chars[-1]);				# 8 = last 3 chars
	}
	if ($chars_len >= 4) {
		push(@{$feats}, join("",@chars[-4..-1]));	# 9 = last 4 chars
	} elsif ($chars_len >= 3) {
		push(@{$feats}, join("",@chars[-3..-1]));	# 9 = last 4 chars
	} elsif ($chars_len >= 2) {
		push(@{$feats}, join("",@chars[-2..-1]));	# 9 = last 4 chars
	} else {
		push(@{$feats}, $chars[-1]);				# 9 = last 4 chars
	}
  
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
}

sub buildTmpFile {
    my ($filename) = @_;
    my $tmpfile = $filename;
    $tmpfile =~ s/[\.\/]//g;
    $tmpfile .= $$ . time;
    # untaint tmpfile variable
    if ($tmpfile =~ /^([-\@\w.]+)$/) {
	$tmpfile = $1;
    }
    
    # return $tmpfile;
    return "/tmp/$tmpfile"; # Altered by Min (Thu Feb 28 13:08:59 SGT 2008)

}  # buildTmpFile


sub fatal {
    my $msg = shift;
    print STDERR "Fatal Exception: $msg\n";
}


sub decode {
  my ($inFile, $outFile, $confLevel) = @_;
  
  my $labeledFile = buildTmpFile($inFile);
  if($confLevel){
    execute("$crf_test -v1 -m $modelFile $inFile > $labeledFile");
  } else {
    execute("$crf_test -m $modelFile $inFile > $labeledFile");
  }
  unless (open(PIPE, $labeledFile)) {
    fatal("Could not open pipe from crf call: $!");
    return;
  }
#  print STDERR "Output to file $outFile\n";
  unless (open(OUT, ">:utf8", $outFile)) {
    fatal("Could not open crf output file for writing: $!");
    return;
  }  
  while(<PIPE>){
    chomp;
    print OUT Encode::decode_utf8($_), "\n";
  }
  close PIPE;
  close OUT;

  unlink($labeledFile);

  return 1;

}  # decode

sub readKeywordDict {
  my ($inFile, $keywords) = @_;

  open (IF, "<:utf8", $inFile) || die "fatal\t\tCannot open \"$inFile\"!";
#  print STDERR "Load keywords from file $inFile\n";
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
	open (DATA, "<:utf8", $dictFileLoc) || die "Could not open dict file $dictFileLoc: $!";
	
	while (<DATA>) {
		if (/^\#\# Male/) { 
			$mode = 1; 
		} elsif (/^\#\# Female/) { 
			$mode = 2; 
		} elsif (/^\#\# Last/) { 
			$mode = 4; 
		} elsif (/^\#\# Chinese/) { 
			$mode = 4; 
		} elsif (/^\#\# Months/) { 
			$mode = 8; 
		} elsif (/^\#\# Place/) { 
			$mode = 16; 
		} elsif (/^\#\# Publisher/) { 
			$mode = 32; 
		} elsif (/^\#/) { 
			next; 
		} else {
			chop;
			
			my $key = $_;
			my $val = 0;

			# Has probability
			if (/\t/) {
				($key,$val) = split (/\t/,$_);
			}

			# Already tagged (some entries may appear in same part of lexicon more than once
			if ((defined $dict{ $key }) && ($dict{ $key } >= $mode)) { 
				next; 
			} else { 
				# Not yet tagged
				$dict{ $key } += $mode; 
			}
		}
	}
	
	close (DATA);
}  # readDict

sub execute {
  my ($cmd) = @_;
#  print STDERR "Executing: $cmd\n";
   system($cmd);
}

1;
