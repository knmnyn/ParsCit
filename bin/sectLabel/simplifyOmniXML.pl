#!/usr/bin/perl -wT
# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Tue, 02 Jun 2009 01:30:42

# Modified from template by Min-Yen Kan <kanmy@comp.nus.edu.sg>

require 5.0;
use strict;
use Getopt::Long;
use HTML::Entities;

# I do not know a better solution to find a lib path in -T mode.
# So if you know a better solution, I'd be glad to hear.
# See this http://www.perlmonks.org/?node_id=585299 for why I used the below code
use FindBin;
FindBin::again(); # to get correct path in case 2 scripts in different directories use FindBin
my $path;
BEGIN {
  if ($FindBin::Bin =~ /(.*)/) {
    $path = $1;
  }
}
use lib "$path/../../lib";
use SectLabel::PreProcess;

### USER customizable section
$0 =~ /([^\/]+)$/; my $progname = $1;
my $outputVersion = "1.0";
### END user customizable section

sub License {
  print STDERR "# Copyright 2009 \251 by Luong Minh Thang\n";
}

### HELP Sub-procedure
sub Help {
  print STDERR "Process Omnipage XML output (concatenated results fromm all pages of a PDF file), and extract necessary information. Marking in the output detailed word-level info ### Page\\n## Para\\n# Line\\nword\\n### Table\\n### Figure\n";
  
  print STDERR "usage: $progname -h\t[invokes help]\n";
  print STDERR "       $progname -in xmlFile -out outFile [-decode -allowEmptyLine -log]\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
  print STDERR "\t-decode: decode HTML entities and then output, to avoid double entity encoding later\n";
}

my $QUIET = 0;
my $HELP = 0;
my $outFile = undef;
my $inFile = undef;

my $isDecode = 0;
my $isAllowEmpty = 0;
my $isDebug = 0;
$HELP = 1 unless GetOptions('in=s' => \$inFile,
			    'out=s' => \$outFile,
			    'decode' => \$isDecode,
			    'allowEmptyLine' => \$isAllowEmpty,
			    'log' => \$isDebug,
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

if($isDebug){
  print STDERR "\n# Processing file $inFile & output to $outFile\n";
}

my $markupOutput = "";
processFile($inFile);

if($isDecode){
  $markupOutput = decode_entities($markupOutput);
}

open(OF, ">:utf8", "$outFile") || die"#Can't open file \"$outFile\"\n";
print OF "$markupOutput";
close OF;

sub processFile {
  my ($inFile) = @_;
  
  if (!(-e $inFile)) { die "# $progname crash\t\tFile \"$inFile\" doesn't exist"; }
  open (IF, "<:utf8", $inFile) || die "# $progname crash\t\tCan't open \"$inFile\"";
  
  my $isPara = 0;
  my $isTable = 0;
  my $isSpace = 0;
  my $isPic = 0;
  my $text = ""; 

  while (<IF>) { #each line contains a header
    if (/^\#/) { next; }			# skip comments
    chomp;
    s/\cM$//; # remove ^M character at the end of the file if any
    my $line = $_;


    #    if ($line =~ /<\?xml version.+>/){    } ### Xml ###
    #    if ($line =~ /^<\/column>$/){    } ### Column ###
    if ($line =~ /<theoreticalPage (.*)\/>/){    
      $markupOutput .= "||| Page $1\n";
    }

    ### pic ###
    if ($line =~ /^<dd (.*)>$/){
      $isPic = 1;
      
      $markupOutput .= "||| Figure $1\n";
    }
    elsif ($line =~ /^<\/dd>$/){
      $isPic = 0;
    }

    ### Table ###
    elsif ($line =~ /^<table (.*)>$/){
      $isTable = 1;
      $markupOutput .= "||| Table $1\n";
    }
    elsif ($line =~ /^<\/table>$/){
      $isTable = 0;
    }

    ### Paragraph ###
    # Note: table processing should have higher priority than paragraph, i.e. the priority does matter
    elsif ($line =~ /^<para (.*)>$/){
      $text .= $line."\n"; # we need the header
      $isPara = 1;
      
      if($isTable){
	$markupOutput .= "||| ParaTable $1\n";
      } else {
	$markupOutput .= "||| Para $1\n";
      }
    }
    elsif ($line =~ /^<\/para>$/){
      my $paraText;
      processPara($text);

      $isPara = 0;
      $text = "";
    }
    elsif($isPara){
      $text .= $line."\n";
      next;
    }
  }  
  close IF;
}

sub getAttrValue {
  my ($attrText, $attr) = @_;

  my $value = "none";
  if($attrText =~ /^.*$attr=\"(.+?)\".*$/){
    $value = $1;
  }
  
  return $value;
}

sub checkFontAttr {
  my ($attrText, $attr, $attrHash, $count) = @_;

  if($attrText =~ /^.*$attr=\"(.+?)\".*$/){
    my $attrValue = $1;
    
    $attrHash->{$attrValue} = $attrHash->{$attrValue} ? ($attrHash->{$attrValue}+$count) : $count;
  }
}

sub processPara {
  my ($inputText) = @_;

  my $isSpace = 0;
  my $isSpecialSpace = 0;
  my $isTab = 0;
  my $isBullet = 0;

  my $isForcedEOF = "none";  # 3 signals for end of L: forcedEOF=\"true\" in attribute of <ln> or || <nl orig=\"true\"\/> || end of </para> without encountering any of the above signal in the para plus $isSpace = 0

  my $lnAttr; my $isLn = 0; my $lnBold = "none"; my $lnItalic = "none";
  my $runAttr;  my $runText = ""; my $isRun = 0; my $runBold = "none"; my $runItalic = "none";
  my $wdAttr; my $wdText = ""; my $isWd = 0;

  my $text = ""; 
  my $tmpMarkupOutput = "";
#  binmode(STDERR, ":utf8");

  my @lines = split(/\n/, $inputText);
  for(my $i=0; $i<scalar(@lines); $i++){
    my $line = $lines[$i];

    ## new ln
    if ($line =~ /^<ln (.+)>$/){ 
      $lnAttr = $1;
      $isLn = 1;

      $tmpMarkupOutput .= "||| Line $lnAttr\n";
      $isForcedEOF = getAttrValue($lnAttr, "forcedEOF");
    }

    ## new run
    elsif ($line =~ /<run (.*)>$/){
      $runAttr = $1;

      $isSpace = 0;
      $isTab = 0;
      $isRun = 1;

      if($line =~ /^<wd (.*?)>/){  # new wd, that consists of many runs
	$isWd = 1;
	$wdAttr = $1;
      }
    }

    ## wd
    elsif ($line =~ /^<wd (.+)?>(.+)<\/wd>$/){
      $wdAttr = $1;
      my $word = $2;
      $isSpace = 0;
      $isTab = 0;

      $word =~ s/\cM$//g; # remove ^M character 
      $tmpMarkupOutput .= "$word $wdAttr\n";
	
      ## add text
      $text .= "$word";

      if($isRun) {
	$runText .= "$word ";
      }
    }

    ## end wd
    elsif ($line =~ /^<\/wd>$/){
      $isWd = 0;
      
      $tmpMarkupOutput .= "$wdText $wdAttr\n";
      $wdAttr = "";
      $wdText = "";
    }

    ## end run
    elsif ($line =~ /^(.*)<\/run>$/){ 
      my $word = $1;

      ## add text
      if($word ne ""){
	$word =~ s/\cM$//g; # remove ^M character 

	# appear in the final result
	if($isLn){ $text .= "$word"; }

	# for internal record
	if($isRun){ $runText .= "$word "; }	
	if($isWd){ $wdText .= "$word"; }	
      }

      ## reset run
      $runText = "";
      $isRun = 0;      
      $isSpecialSpace = 0;
    }

    ## end ln
    elsif ($line =~ /^<\/ln>$/){
      if((!$isAllowEmpty && $text !~ /^\s*$/)
	 || ($isAllowEmpty && $text ne "")){
	if($isForcedEOF eq "true" || # there's a forced EOL?
	   (!$isSpecialSpace) # not an emply line with space character
	  ){ 
	  $text .= "\n";
	 
	  $markupOutput .= $tmpMarkupOutput;
	  $tmpMarkupOutput = "";
	  $text = "";
	}
      } else {
	$tmpMarkupOutput = "";
      }

      ## reset ln
      $isLn = 0;      
      $isForcedEOF = "none";
      $isSpecialSpace = 0;
    } # end else </ln>

    ## nl newline signal
    elsif ($line =~ /^<nl orig=\"true\"\/>$/){
      if($isLn){
	$isSpace = 0;
      } else {
	if($isDebug){
	  print STDERR "#!!! Warning: found <nl orig=\"true\"\/> while not in tag <ln>: $line\n";
	}
      }
    }

    ## space
    elsif ($line =~ /^<space\/>$/){
      my $startTag = "";
      my $endTag = "";
      if($i>0 && $lines[$i-1] =~ /^<(.+?)\b.*/){
	$startTag = $1;
      }
	
      if($i < (scalar(@lines) -1) && $lines[$i+1] =~ /^<\/(.+)>/){
	$endTag = $1;
      }
      
      if($startTag eq $endTag && $startTag ne ""){
	$isSpecialSpace = 1;
      }

      ## addText
      $text .= " ";
      $isSpace = 1;
    }

    ## tab
    elsif ($line =~ /^<tab .*\/>$/){
      ## add Text
      $text .= "\t";

      $isTab = 1;
    }

    ## bullet
    elsif ($line =~ /^<bullet .*>$/){
      $isBullet = 1;
    }
  }
}

sub untaintPath {
  my ($path) = @_;

  if ( $path =~ /^([-_\/\w\.]*)$/ ) {
    $path = $1;
  } else {
    die "Bad path \"$path\"\n";
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
  if($isDebug){
    print STDERR "Executing: $cmd\n";
  }
  $cmd = untaint($cmd);
  system($cmd);
}

sub newTmpFile {
  my $tmpFile = `date '+%Y%m%d-%H%M%S-$$'`;
  chomp($tmpFile);
  return $tmpFile;
}
