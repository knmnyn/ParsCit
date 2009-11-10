#!/usr/bin/env perl
# -*- cperl -*-
=head1 NAME

tr2crfpp.pl

=head1 SYNOPSYS

 CVS:$Id: tr2crfpp.pl,v 1.1 2007/03/07 07:02:24 rpnlpir Exp $

=head1 DESCRIPTION

=head1 HISTORY

 ORIGIN: created from templateApp.pl version 3.4 by Min-Yen Kan <kanmy@comp.nus.edu.sg>

 CVS:$Log: tr2crfpp.pl,v $
 CVS:Revision 1.1  2007/03/07 07:02:24  rpnlpir

=cut

require 5.0;
use Getopt::Std;
use strict 'vars';
use FindBin;
# use diagnostics;

### USER customizable section
my $tmpfile .= $0; $tmpfile =~ s/[\.\/]//g;
$tmpfile .= $$ . time;
if ($tmpfile =~ /^([-\@\w.]+)$/) { $tmpfile = $1; }		      # untaint tmpfile variable
$tmpfile = "/tmp/" . $tmpfile;
$0 =~ /([^\/]+)$/; my $progname = $1;
my $outputVersion = "1.0";
my $dictFile = "$FindBin::Bin/../resources/parsCitDict.txt";
### END user customizable section

### Ctrl-C handler
sub quitHandler {
  print STDERR "\n# $progname fatal\t\tReceived a 'SIGINT'\n# $progname - exiting cleanly\n";
  exit;
}

### HELP Sub-procedure
sub Help {
  print STDERR "usage: $progname -h\t\t\t\t[invokes help]\n";
  print STDERR "       $progname -v\t\t\t\t[invokes version]\n";
  print STDERR "       $progname [-q] filename(s)...\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
  print STDERR "\n";
  print STDERR "Will accept input on STDIN as a single file.\n";
  print STDERR "\n";
}

### VERSION Sub-procedure
sub Version {
  if (system ("perldoc $0")) {
    die "Need \"perldoc\" in PATH to print version information";
  }
  exit;
}

sub License {
  print STDERR "# Copyright 2005 \251 by Min-Yen Kan\n";
}

###
### MAIN program
###

my $cmdLine = $0 . " " . join (" ", @ARGV);
if ($#ARGV == -1) { 		        # invoked with no arguments, possible error in execution? 
  print STDERR "# $progname info\t\tNo arguments detected, waiting for input on command line.\n";  
  print STDERR "# $progname info\t\tIf you need help, stop this program and reinvoke with \"-h\".\n";
}

$SIG{'INT'} = 'quitHandler';
getopts ('hqv');

our ($opt_q, $opt_v, $opt_h);
# use (!defined $opt_X) for options with arguments
if (!$opt_q) { License(); }		# call License, if asked for
if ($opt_v) { Version(); exit(0); }	# call Version, if asked for
if ($opt_h) { Help(); exit (0); }	# call help, if asked for

my %dict = ();
readDict($dictFile);

## standardize input stream (either STDIN on first arg on command line)
my $fh;
my $filename;
if ($filename = shift) {
 NEWFILE:
  if (!(-e $filename)) { die "# $progname crash\t\tFile \"$filename\" doesn't exist"; }
  open (*IF, $filename) || die "# $progname crash\t\tCan't open \"$filename\"";
  $fh = "IF";
} else {
  $filename = "<STDIN>";
  $fh = "STDIN";
}

while (<$fh>) {
  if (/^\#/) { next; }			# skip comments
  elsif (/^\s+$/) { next; }		# skip blank lines
  else {
    my $tag = "";
    my @tokens = split(/ +/);
    my @feats = ();
    my $hasPossibleEditor = (/(ed\.|editor|editors|eds\.)/) ? "possibleEditors" : "noEditors";
    my $j = 0;
    for (my $i = 0; $i <= $#tokens; $i++) {
#    for (my $i = $#tokens; $i >= 0; $i--) {
      if ($tokens[$i] =~ /^\s*$/) { next; }
      if ($tokens[$i] =~ /^\<\/([a-z]+)/) {
#	$tag = $1;
	next;
      }
      if ($tokens[$i] =~ /^\<([a-z]+)/) {
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
      if ($lastChar =~ /[a-z]/) { $lastChar = 'a'; }
      elsif ($lastChar =~ /[A-Z]/) { $lastChar = 'A'; }
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
      my $ortho = ($wordNP =~ /^[A-Z]$/) ? "singleCap" :
	 ($wordNP =~ /^[A-Z][a-z]+/) ? "InitCap" :
	   ($wordNP =~ /^[A-Z]+$/) ? "AllCap" : "others";
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
#      my $isInDict = ($dictStatus != 0) ? "isInDict" : "no";
      my $isInDict = $dictStatus;

      my ($publisherName,$placeName,$monthName,$lastName,$femaleName,$maleName);
      if ($dictStatus >= 32) { $dictStatus -= 32; $publisherName = "publisherName" } else { $publisherName = "no"; }
      if ($dictStatus >= 16) { $dictStatus -= 16; $placeName = "placeName" } else { $placeName = "no"; }
      if ($dictStatus >= 8) { $dictStatus -= 8; $monthName = "monthName" } else { $monthName = "no"; }
      if ($dictStatus >= 4) { $dictStatus -= 4; $lastName = "lastName" } else { $lastName = "no"; }
      if ($dictStatus >= 2) { $dictStatus -= 2; $femaleName = "femaleName" } else { $femaleName = "no"; }
      if ($dictStatus >= 1) { $dictStatus -= 1; $maleName = "maleName" } else { $maleName = "no"; }

      push(@{$feats[$j]}, $isInDict);		    # 13 = name status
      push(@{$feats[$j]}, $maleName);		      # 14 = male name
      push(@{$feats[$j]}, $femaleName);		    # 15 = female name
      push(@{$feats[$j]}, $lastName);		      # 16 = last name
      push(@{$feats[$j]}, $monthName);		     # 17 = month name
      push(@{$feats[$j]}, $placeName);		     # 18 = place name
      push(@{$feats[$j]}, $publisherName);	 # 19 = publisher name

      push(@{$feats[$j]}, $hasPossibleEditor);	# 20 = possible editor

      # not accurate ($#tokens counts tags too)
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
      print join (" ", @{$feats[$j]});
      print "\n";
    }
    print "\n";
  }
}

close ($fh);

if ($filename = shift) {
  goto NEWFILE;
}

###
### END of main program
###

sub readDict {
  my $dictFileLoc = shift @_;
  my $mode = 0;
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

      # already tagged (some entries may appear in same part of lexicon more than once
      if ($dict{$key} >= $mode) { next; }
      else { $dict{$key} += $mode; }		      # not yet tagged
    }
  }
  close (DATA);
}
