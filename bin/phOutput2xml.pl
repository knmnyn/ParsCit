#!/usr/bin/env perl
# -*- cperl -*-
=head1 NAME

phOutput2xml.pl

=head1 SYNOPSYS

 RCS:$Id$

=head1 DESCRIPTION

=head1 HISTORY

 ORIGIN: created from templateApp.pl version 3.4 by Min-Yen Kan <kanmy@comp.nus.edu.sg>

modified from output2xml.pl for ParsCit.

 RCS:$Log$

=cut

require 5.0;
use Getopt::Std;
use strict 'vars';
# use diagnostics;

### USER customizable section
my $tmpfile .= $0; $tmpfile =~ s/[\.\/]//g;
$tmpfile .= $$ . time;
if ($tmpfile =~ /^([-\@\w.]+)$/) { $tmpfile = $1; }		      # untaint tmpfile variable
$tmpfile = "/tmp/" . $tmpfile;
$0 =~ /([^\/]+)$/; my $progname = $1;
my $outputVersion = "1.0";
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
  print STDERR "       $progname [-qEl] [-r <rankfile> -n <num>] filename(s)...\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
  print STDERR "\t-E\tTurn OFF error checking\n";
  print STDERR "\t-l\tEliminate newline tags\n";
  print STDERR "\t-r <file>\tSVM Ranking output file\n";
  print STDERR "\t-n <num>\tNumber of choices in both ranking file and input file\n";
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
  print STDERR "# Copyright 2009 \251 by Min-Yen Kan\n";
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
getopts ('Ehlqr:n:v');

our ($opt_q, $opt_v, $opt_h, $opt_r, $opt_n, $opt_E, $opt_l);
# use (!defined $opt_X) for options with arguments
if (!$opt_q) { License(); }		# call License, if asked for
if ($opt_v) { Version(); exit(0); }	# call Version, if asked for
if ($opt_h) { Help(); exit (0); }	# call help, if asked for
my $errorChecking = (defined $opt_E) ? 0 : 1;
my $ignoreNewlines = (defined $opt_l) ? 1 : 0;
my $svmRankFile = (defined $opt_r) ? $opt_r : undef;
my $rankChoices = (defined $opt_n) ? $opt_n : undef;
if ((defined $rankChoices && !defined $svmRankFile) ||
    (!defined $rankChoices && defined $svmRankFile)) {
  die "# $progname fatal\t\t-n and -r are mutually necessary switches";
}

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

# open rank file info, if applicable
my $rfh;
my @max = ();
if (defined $rankChoices && defined $svmRankFile) {
  open (*RFH, $svmRankFile) || die "# $progname crash\t\tCan't open rankfile \"$svmRankFile\"!";
  $rfh = "RFH";
  my $line = 0;
  my $curLine = 0;
  my $max = 0;
  my $maxLine = 0;
  while (<$rfh>) {
    chop;
    $line++;
    $curLine++;
    if ($_ > $max) {			   # advance max if applicable
      $max = $_;
      $maxLine = $curLine-1;
    }

    if ($line % $rankChoices == 0) {	      # save data at fencepost
      $max[int($line/$rankChoices)-1] = $maxLine;
#      print "$line $max $maxLine\n";

      $curLine = 0;					# reset values
      $max = 0;
      $maxLine = 0;
    }
  }
  close ($rfh);
}

## output XML file for display
my $line = 0;
my $buf = "";
my $buf2 = "";
my $lastTag = "";
my $variant = "";
my $confidence = "1.0";
print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
print "<?xml-stylesheet href=\"bibxml.xsl\" type=\"text/xsl\" ?>\n";
print "<file>\n";
while (<$fh>) {
  if (/^\# (\d+) ([\.\d]+)/) {
    $variant = $1;
    $confidence = $2;
    next;
  }
  elsif (/^\#/) { next; }			       # skip comments

  if (/^\s*$/) {
    $buf =~ s/&/&amp;/g;

    if ($variant eq "") {
      print "<entry no=\"$line\">\n";
      if ($ignoreNewlines) {
	$buf =~ s/\- ([a-z])/$1/g;
	$buf =~ s/>\s+/>/g;
	$buf =~ s/\s+</</g;
	$buf =~ s/\s+$//g;
	$buf =~ s/^\s+/</g;
#	$buf =~ s/PARSHED</\n      </g;	# replace with newline and spaces for formatting
	$buf =~ s/PARSHED</\n</g;	# replace with newline and spaces for formatting
      }
      print "<variant no=\"0\" confidence=\"$confidence\">" . $buf . "</$lastTag>\n</variant>\n";
      print "</entry>\n";
      $line++;
    } else {
      if ($variant eq "0" && $buf2 ne "") {
	print "<entry no=\"$line svmRank: $max[$line]\">\n" . $buf2 . "  </entry>\n";
	$buf2 = "";
	$line++;
      }
      $buf2 .= "<variant no=\"$variant\" confidence=\"$confidence\">\n" . $buf . "</$lastTag>\n</variant>\n";
    }

    $lastTag = "";
    $buf = "";
  } else {
    chop;

    my @tokens = split (/\t/);

    my $token = $tokens[0];
    my $sys = $tokens[-1];
    my $gold = $tokens[-2];
    if ($sys ne $lastTag) {
      if ($lastTag ne "") { $buf .= "</$lastTag>\n"; }
      $buf .= "PARSHED<$sys>";
#      $buf .= "<$sys>";
    }
    if ($token eq "+L+" && $ignoreNewlines) {
      next;
    }
    if ($gold ne $sys && $errorChecking) {
      $buf .= "<error correct=\"$gold\" taggedAs=\"$sys\">$token </error>";
    } else {
      $buf .= "$token ";
    }
    $lastTag = $sys;
  }
}
# print "  <entry no=\"$line\">\n" . $buf2 . "  </entry>\n";
print "</file>\n";

close ($fh);

if ($filename = shift) {
  goto NEWFILE;
}

###
### END of main program
###
