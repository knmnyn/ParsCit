#!/usr/bin/perl -wT
# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Tue, 02 Jun 2009 01:30:42

# Modified from template by Min-Yen Kan <kanmy@comp.nus.edu.sg>

require 5.0;
use strict;

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

use Getopt::Long;
use ParsHed::Config;

### USER customizable section
$0 =~ /([^\/]+)$/; my $progname = $1;
my $outputVersion = "1.0";
### END user customizable section

sub License {
  print STDERR "# Copyright 2009 \251 by Luong Minh Thang\n";
}

### HELP Sub-procedure
sub Help {
  print STDERR "Create keyword info from a tagged header file\n";
  print STDERR "usage: $progname -h\t[invokes help]\n";
  print STDERR "       $progname -in taggedHeaderFile -out outFile [-n topN -nGram numNGram -lowercase]\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
  print STDERR "\t-n: Default topN = 100.\n";
  print STDERR "\t-nGram: Default numNGram = 1.\n";
  print STDERR "\t-lowercase: enable lowercasing (default no lowercasign).\n";
}
my $QUIET = 0;
my $HELP = 0;
my $outFile = undef;
my $inFile = undef;
my $topN = 100;
my $numNGram = 1;
my $isLowercase = 0;
$HELP = 1 unless GetOptions('in=s' => \$inFile,
			    'out=s' => \$outFile,
			    'n=i' => \$topN,
			    'nGram=i' => \$numNGram,
			    'lowercase' => \$isLowercase,
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
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
### End untaint ###

# keyword statistics
my %keywords = (); #hash of hash $keywords{"affiliation"}->{"Institute"} = freq of "Institute" for affiliation tag

processFile($inFile, $outFile, $numNGram);

## 
# main routine to count frequent keywords/bigrams in $inFile and output to $outFile
##
sub processFile {
  my ($inFile, $outFile, $numNGram) = @_;
  
  if (!(-e $inFile)) { die "# $progname crash\t\tFile \"$inFile\" doesn't exist"; }
  open (IF, "<:utf8", $inFile) || die "# $progname crash\t\tCan't open \"$inFile\"";
  
  while (<IF>) { #each line contains a header
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
	  my @sub_lines = split(/\s*\+L\+\s*/, $line);

	  foreach my $sub_line (@sub_lines){ #go through each subline of a header field
	    countKeywords($sub_line, $tag, $numNGram);
	  }
	  $line = ""; # reset
	  next;
	} elsif (/^\<([a-z]+)/) { #beginning tag
	  $tag = $1;
	  
	  if(!$keywords{$tag}){
	    $keywords{$tag} = ();
	    $keywords{$tag}->{""} = 0;
	  }
	  
	  next;
	} else { #contents inside tag
	  $line .= "$_ ";
	}
      }
      
      next;
    }
  } # end while IF
  close IF;

  ## obtain top keyWords
  my %topKeywords = ();
  foreach my $tag (keys %keywords){
    $topKeywords{$tag} = ();

    my %freqs = %{$keywords{$tag}};
    my @sorted_keys = sort { $freqs{$b} <=> $freqs{$a} } keys %freqs;
    
    my $count = 0;    
    foreach my $keyWord (@sorted_keys){
      $topKeywords{$tag}->{$keyWord} = 1;

      $count++;
      if($count == $topN){
	last;
      }      
    }
  }

  ## filter duplicate keywords
  my %filteredKeywords = ();
  filterDuplicate(\%topKeywords, \%filteredKeywords);

  ## output results
  outputKeywords(\%filteredKeywords, $outFile);
}

##
# Output keyword hash to file
##
sub outputKeywords {
  my ($hash, $outFile) = @_;

  open(OF, ">:utf8", "$outFile") || die"#Can't open file \"$outFile\"\n";
  
  # list of tags trained in parsHed
  # those with value 0 do not have frequent keyword features
  my $tags = $ParsHed::Config::tags; # hash

  foreach my $tag (keys %{$tags}){
    if($tags->{$tag} == 0){
      next;
    }

    print OF "$tag:";

    my @keywords = sort{$a cmp $b} keys %{$hash->{$tag}};    
    foreach my $keyword (@keywords){
      print OF " $keyword";
    }

    print OF "\n";
  }
  close OF;
}

##
# Remove keywords that appear in more than one field
##
sub filterDuplicate {
  my ($hash, $filteredHash) = @_;

  my @tags = keys %{$hash};
  foreach my $tag (@tags){
    $filteredHash->{$tag} = ();
    my @keywords = keys %{$hash->{$tag}};
    
    foreach my $keyword (@keywords){
      my $isDuplicated = 0;

      # check for duplication
      foreach(@tags){
	if($_ ne $tag){ # a different tag
	  if($hash->{$_}->{$keyword}){ # duplicated
	    $isDuplicated = 1;
	    last;
	  }
	}
      } # end for @tags

      if(!$isDuplicated){
	$filteredHash->{$tag}->{$keyword} = 1;
      }
    }
  }
}

##
# Count keyword or nGrams
##
sub countKeywords {
  my ($line, $tag, $numNGram) = @_;

  if($isLowercase){
    $line = lc($line);
  }

  my @tmpTokens = split(/\s+/, $line);

  #filter out empty token
  my @tokens = ();
  foreach my $token (@tmpTokens){ 
    if($token ne ""){
      $token =~ s/^\s+//g; # strip off leading spaces
      $token =~ s/\s+$//g; # strip off trailing spaces
      push(@tokens, $token);
    }
  }

  my $funcWordCount = 0;
  my $count = 0;  
  for(my $i=0; $i<=$#tokens; $i++){
    if(($#tokens-$i + 1) < $numNGram) { last; }; # not enough ngrams
    my $nGram = "";
    for(my $j=$i; $j <= ($i+$numNGram-1); $j++){
      my $token = $tokens[$j];
      $token =~ s/^\p{P}+//g; #strip out leading punctuations
      $token =~ s/\p{P}+$//g; #strip out trailing punctuations
      $token =~ s/^\s+//g; #strip out leading spaces
      $token =~ s/\s+$//g; #strip out trailing spaces
      $token =~ s/\d/0/g; #canocalize number into "0"

      if($numNGram > 1){ # lowercase to reduce data sparseness
	$token = lc($token);
      }

      if($j < ($i+$numNGram-1)){
	$nGram .= "$token-";
      } else {
	$nGram .= "$token";
      }
    }

    if($nGram =~ /^\s*$/){ next; } #skip those with white spaces
    if($nGram =~ /^\d*$/){ next; } #skip those with only digits
    
    #print STDERR "$nGram
    if(!$keywords{$tag}->{$nGram}){
      $keywords{$tag}->{$nGram} = 0;
    }
    $keywords{$tag}->{$nGram}++;

    $count++;
    if($count == 2){
      last;
    }
  } # end while true
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
