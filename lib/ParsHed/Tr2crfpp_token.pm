package ParsHed::Tr2crfpp_token;
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

my $crf_test = $ENV{'CRFPP_HOME'} ? "$ENV{'CRFPP_HOME'}/bin/crf_test" : "$FindBin::Bin/../$ParsHed::Config::crf_test";

my $modelFile = $ParsHed::Config::oldModelFile;
$modelFile = "$FindBin::Bin/../$modelFile";

### END user customizable section

my %dict = ();

sub prepData {
    my ($rCiteText, $filename) = @_;
    my $tmpfile = buildTmpFile($filename);

    # Thang Mar 2010: move inside the method; only load when running
    readDict($dictFile);
    unless (open(TMP, ">:utf8", $tmpfile)) {
	fatal("Could not open tmp file $tmpDir/$tmpfile for writing.");
	return;
    }

    foreach (split "\n", $$rCiteText) {
	if (/^\s*$/) { next; }		# skip blank lines

	my $tag = "";
	my @tokens = split(/ +/);
	my @feats = ();
	my $hasPossibleEditor =
	    (/(ed\.|editor|editors|eds\.)/) ? "possibleEditors" : "noEditors";
	my $j = 0;
	for (my $i = 0; $i <= $#tokens; $i++) {
            #for (my $i = $#tokens; $i >= 0; $i--) {
	    if ($tokens[$i] =~ /^\s*$/) { next; }
	    if ($tokens[$i] =~ /^\<\/([\p{IsLower}]+)/) {
		#$tag = $1;
		next;
	    }
	    if ($tokens[$i] =~ /^\<([\p{IsLower}]+)/) {
		$tag = $1;
		next;
	    }

	    # prep
	    my $word = $tokens[$i];

	    my $wordNP = $tokens[$i];			      # no punctuation
	    $wordNP =~ s/[^\w]//g;
	    if ($wordNP =~ /^\s*$/) { $wordNP = "EMPTY"; }
	    my $wordLCNP = lc($wordNP);    # lowercased word, no punctuation
	    if ($wordLCNP =~ /^\s*$/) { $wordLCNP = "EMPTY"; }

	    ## feature generation
	    $feats[$j][0] = $word;			    # 0 = lexical word
	    my @chars = split(//,$word);
	    my $lastChar = $chars[-1];
	    if ($lastChar =~ /[\p{IsLower}]/) { $lastChar = 'a'; }
	    elsif ($lastChar =~ /[\p{IsUpper}]/) { $lastChar = 'A'; }
	    elsif ($lastChar =~ /[0-9]/) { $lastChar = '0'; }
	    push(@{$feats[$j]}, $lastChar);		       # 1 = last char

	    push(@{$feats[$j]}, $chars[0]);		      # 2 = first char
	    push(@{$feats[$j]}, join("",@chars[0..1]));  # 3 = first 2 chars
	    push(@{$feats[$j]}, join("",@chars[0..2]));  # 4 = first 3 chars
	    push(@{$feats[$j]}, join("",@chars[0..3]));  # 5 = first 4 chars

	    push(@{$feats[$j]}, $chars[-1]);		       # 6 = last char
	    push(@{$feats[$j]}, join("",@chars[-2..-1])); # 7 = last 2 chars
	    push(@{$feats[$j]}, join("",@chars[-3..-1])); # 8 = last 3 chars
	    push(@{$feats[$j]}, join("",@chars[-4..-1])); # 9 = last 4 chars

	    push(@{$feats[$j]}, $wordLCNP);  # 10 = lowercased word, no punct

	    # 11 - capitalization
	    my $ortho = ($wordNP =~ /^[\p{IsUpper}]$/) ? "singleCap" :
		($wordNP =~ /^[\p{IsUpper}][\p{IsLower}]+/) ? "InitCap" :
		($wordNP =~ /^[\p{IsUpper}]+$/) ? "AllCap" : "others";
	    push(@{$feats[$j]}, $ortho);

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
	    push(@{$feats[$j]}, $num);

	    # gazetteer (names)
	    my $dictStatus = (defined $dict{$wordLCNP}) ? $dict{$wordLCNP} : 0;
            #my $isInDict = ($dictStatus != 0) ? "isInDict" : "no";
	    my $isInDict = $dictStatus;

	    my ($publisherName,$placeName,$monthName,$lastName,$femaleName,$maleName);
	    if ($dictStatus >= 32) {
		$dictStatus -= 32;
		$publisherName = "publisherName";
	    } else {
		$publisherName = "no";
	    }
	    if ($dictStatus >= 16) {
		$dictStatus -= 16;
		$placeName = "placeName";
	    } else {
		$placeName = "no";
	    }
	    if ($dictStatus >= 8) {
		$dictStatus -= 8;
		$monthName = "monthName";
	    } else {
		$monthName = "no";
	    }
	    if ($dictStatus >= 4) {
		$dictStatus -= 4;
		$lastName = "lastName";
	    } else {
		$lastName = "no";
	    }
	    if ($dictStatus >= 2) {
		$dictStatus -= 2;
		$femaleName = "femaleName";
	    } else {
		$femaleName = "no";
	    }
	    if ($dictStatus >= 1) {
		$dictStatus -= 1;
		$maleName = "maleName";
	    } else {
		$maleName = "no";
	    }

	    push(@{$feats[$j]}, $isInDict);		    # 13 = name status
	    push(@{$feats[$j]}, $maleName);		      # 14 = male name
	    push(@{$feats[$j]}, $femaleName);		    # 15 = female name
	    push(@{$feats[$j]}, $lastName);		      # 16 = last name
	    push(@{$feats[$j]}, $monthName);		     # 17 = month name
	    push(@{$feats[$j]}, $placeName);		     # 18 = place name
	    push(@{$feats[$j]}, $publisherName);	 # 19 = publisher name

	    push(@{$feats[$j]}, $hasPossibleEditor);	# 20 = possible editor

	    # not accurate ($#tokens counts tags too)
	    if ($#tokens <= 0) {
		next;
	    }
	    my $location = int ($j / $#tokens * 12);
	    push(@{$feats[$j]}, $location);	      # 21 = relative location

	    # 22 - punctuation
	    my $punct = ($word =~ /^[\"\'\`]/) ? "leadQuote" :
		($word =~ /[\"\'\`][^s]?$/) ? "endQuote" :
		($word =~ /\-.*\-/) ? "multiHyphen" :
		($word =~ /[\-\,\:\;]$/) ? "contPunct" :
		($word =~ /[\!\?\.\"\']$/) ? "stopPunct" :
	        ($word =~ /^[\(\[\{\<].+[\)\]\}\>].?$/) ? "braces" :
		($word =~ /^[0-9]{2-5}\([0-9]{2-5}\).?$/) ? "possibleVol" : "others";
	    push(@{$feats[$j]}, $punct);		    # 22 = punctuation

	    # output tag
	    push(@{$feats[$j]}, $tag);

	    $j++;

	}

	# export output: print
	for (my $j = 0; $j <= $#feats; $j++) {
	    print TMP join (" ", @{$feats[$j]});
	    print TMP "\n";
	}
	print TMP "\n";
    }
    close TMP;
#    open (IN, "<:utf8", $tmpfile);
#    my $text;
#    {
#	local $/ = undef;
#	$text = <IN>;
#    }
#    close IN;
#    print "$text\n";
    return $tmpfile;

}  # prepData


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
    my ($inFile, $outFile) = @_;

    unless (open(PIPE, "$crf_test -m $modelFile $inFile |")) {
	fatal("Could not open pipe from crf call: $!");
	return;
    }
    my $output;
    {
	local $/ = undef;
	$output = <PIPE>;
    }
    close PIPE;

    unless(open(IN, $inFile)) {
	fatal("Could not open input file: $!");
	return;
    }
    my @codeLines = ();
    while(<IN>) {
	chomp();
	push @codeLines, $_;
    }
    close IN;

    my @outputLines = split "\n", $output;
    for (my $i=0; $i<=$#outputLines; $i++) {
	if ($outputLines[$i] =~ m/^\s*$/) {
	    next;
	}
#	my @outputTokens = split " +", $outputLines[$i];
	my @outputTokens = split(/\s+/, $outputLines[$i]); #Thang fix
	my $class = $outputTokens[$#outputTokens];
#	my @codeTokens = split "\t", $codeLines[$i];
	my @codeTokens = split(/\s+/, $codeLines[$i]); # Thang fix
	if ($#codeTokens < 0) {
	    next;
	}
	$codeTokens[$#codeTokens] = $class;
	$codeLines[$i] = join "\t", @codeTokens;
#	print Encode::decode_utf8(@codeLines[$i]), "\n";
    }
    
#    unless (open(OUT, ">:utf8", $outFile)) {
    unless (open(OUT, ">:utf8", $outFile)) {
	fatal("Could not open crf output file for writing: $!");
	return;
    }
    foreach my $line (@codeLines) {
	print OUT Encode::decode_utf8($line), "\n";
    }
    close OUT;

#    open (IN, "<:utf8", $outFile);
#    my $text;
#    {
#	local $/ = undef;
#	$text = <IN>;
#    }
#    close IN;
#    print "$text\n";
    
    return 1;

}  # decode


sub readDict {
  my $dictFileLoc = shift @_;
  my $mode = 0;
  open (DATA, "<:utf8", $dictFileLoc) || die "Could not open dict file $dictFileLoc: $!";
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

      # already tagged (some entries may appear in same part of lexicon more than once
      if ($dict{$key} >= $mode) { next; }
      else { $dict{$key} += $mode; }		      # not yet tagged
    }
  }
  close (DATA);

}  # readDict


1;
