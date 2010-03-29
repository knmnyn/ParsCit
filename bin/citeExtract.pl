#!/usr/bin/perl -CSD
# -*- cperl -*-
=head1 NAME

citeExtract.pl

=head1 SYNOPSYS

 RCS:$Id$

=head1 DESCRIPTION

 Simple command script for executing ParsCit in an
 offline mode (direct API call instead of going through
 the web service).

=head1 HISTORY

 ORIGIN: created from templateApp.pl version 3.4 by Min-Yen Kan <kanmy@comp.nus.edu.sg>

 Min-Yen Kan, 15 Jul 2009.
 Luong Minh Thang, 25 May 2009.
 Isaac Councill, 08/23/07

=cut
require 5.0;
use Getopt::Std;
use strict 'vars';
use FindBin;
use lib "$FindBin::Bin/../lib";
# use diagnostics;

### USER customizable section
my $tmpfile .= $0; $tmpfile =~ s/[\.\/]//g;
$tmpfile .= $$ . time;
if ($tmpfile =~ /^([-\@\w.]+)$/) { $tmpfile = $1; }		      # untaint tmpfile variable
$tmpfile = "/tmp/" . $tmpfile;
$0 =~ /([^\/]+)$/; my $progname = $1;
my $PARSCIT = 1;
my $PARSHED = 2;
my $SECTLABEL = 4; # Thang Mar 10
my $defaultMode = $PARSCIT;
my $defaultInputType = "raw"; 
my $outputVersion = "100326";
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
  print STDERR "       $progname [-qt] [-m <mode>] [-i <inputType>] <filename> [outfile]\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";

  # Thang Mar 10: add new mode (extract_section), and -i <inputType>
  print STDERR "\t-m <mode>\tMode (extract_header, extract_meta, extract_section, extract_all, default: extract_citations)\n";
  print STDERR "\t-i <inputType>\tType (raw, xml, default: raw)\n";
  print STDERR "\t-t\tUse token level model instead\n";
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

###
### MAIN program
###

my $cmdLine = $0 . " " . join (" ", @ARGV);
if ($#ARGV == -1) { 		        # invoked with no arguments, error in execution
  print STDERR "# $progname info\t\tNo arguments detected, waiting for input on command line.\n";
  print STDERR "# $progname info\t\tIf you need help, stop this program and reinvoke with \"-h\".\n";
  exit(-1);
}

$SIG{'INT'} = 'quitHandler';
getopts ('hqm:i:tv');

our ($opt_q, $opt_v, $opt_h, $opt_m, $opt_i, $opt_t);
# use (!defined $opt_X) for options with arguments
if ($opt_v) { Version(); exit(0); }	# call Version, if asked for
if ($opt_h) { Help(); exit (0); }	# call help, if asked for
my $mode = (!defined $opt_m) ? $defaultMode : parseMode($opt_m);
my $phModel = ($opt_t == 1) ? 1 : 0;
my $in = shift;						  # input file
my $out = shift;					# if available
my $rXML = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<algorithms version=\"$outputVersion\">\n";       # output buffer

my $inputType = (!defined $opt_i) ? $defaultInputType : $opt_i; # Thang Mar 10: add input type option
if($inputType ne "raw" && $inputType ne "xml"){
  print STDERR "Input type needs to be either \"raw\" or \"xml\"\n";
  Help(); exit (0);
}

if (($mode & $PARSHED) == $PARSHED) { # PARSHED
  use ParsHed::Controller;
  my $phXML = ParsHed::Controller::extractHeader($in, $phModel); 
  $rXML .= removeTopLines($$phXML, 1) . "\n"; # remove first line <?xml/> 
}

if (($mode & $PARSCIT) == $PARSCIT) { # PARSCIT
  use ParsCit::Controller;
  my $pcXML = ParsCit::Controller::extractCitations($in);
  $rXML .= removeTopLines($$pcXML, 1) . "\n";   # remove first line <?xml/> 
}

# Thang Mar 10: add sectLabel
if (($mode & $SECTLABEL) == $SECTLABEL) { # SECTLABEL
  my $slXML .= sectLabel($in, $inputType);
  $rXML .= removeTopLines($slXML, 1) . "\n"; # remove first line <?xml/> 
}


$rXML .= "</algorithms>";

if (defined $out) {
  open (OUT, ">$out") or die "$progname fatal\tCould not open \"$out\" for writing: $!";
  print OUT $rXML;
  close OUT;
} else {
  print $rXML;
}

###
### END of main program
###

sub parseMode {
  my $arg = shift;
  if ($arg eq "extract_meta") {
    return ($PARSCIT | $PARSHED);
  } elsif ($arg eq "extract_header") {
    return $PARSHED;
  } elsif ($arg eq "extract_citations") {
    return $PARSCIT;
  } elsif ($arg eq "extract_section") {
    return $SECTLABEL;
  } elsif ($arg eq "extract_all") {
    return ($PARSHED | $PARSCIT | $SECTLABEL);  
  } else {
    Help();
    exit(-1);
  }
}

# Thang Mar 10: remove top n lines
sub removeTopLines {
  my ($input, $topN) = @_;
  # remove first line <?xml/> 
  my @lines = split (/\n/,$input);
  for(my $i=0; $i<$topN; $i++){
    shift(@lines);
  }

  return join("\n",@lines);
}
  
# Thang Mar 10: generate section info
sub sectLabel {
  my ($in, $inputType) = @_;

  use SectLabel::Controller;
  use SectLabel::Config;
  my $isXmlOutput = 1;
  my $isDebug = 0;
  my $isXmlInput = ($inputType eq "xml") ?  1 : 0;
  my $modelFile = $isXmlInput? $SectLabel::Config::modelXmlFile : $SectLabel::Config::modelFile;
  $modelFile = "$FindBin::Bin/../$modelFile";

  my $dictFile = $SectLabel::Config::dictFile;
  $dictFile = "$FindBin::Bin/../$dictFile";

  my $funcFile = $SectLabel::Config::funcFile;
  $funcFile = "$FindBin::Bin/../$funcFile";

  my $configFile = $isXmlInput ? $SectLabel::Config::configXmlFile : $SectLabel::Config::configFile;
  $configFile = "$FindBin::Bin/../$configFile";

  # generate XML features if xml input
  if($isXmlInput){
    my $xmlInFile = newTmpFile();
    my $cmd = "$FindBin::Bin/sectLabel/processOmniXML.pl -in $in -out $xmlInFile -xmlFeature";
#    print STDERR "$cmd\n";
    system($cmd);
    $in = $xmlInFile;
  }

  # classify section
  my $slXML = SectLabel::Controller::extractSection($in, $isXmlOutput, $modelFile, $dictFile, $funcFile, $configFile, $isXmlInput, $isDebug);

  # remove xml feature file if any
  if($isXmlInput){
    unlink($in); 
  }

  return $$slXML;
}

# Thang Mar 10: method to generate tmp file name
sub newTmpFile {
  my $tmpFile = `date '+%Y%m%d-%H%M%S-$$'`;
  chomp($tmpFile);
  return $tmpFile;
}
