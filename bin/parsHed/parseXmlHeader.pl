#!/usr/bin/perl -wT
# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Tue, 02 Jun 2009 01:30:42

# Modified from template by Min-Yen Kan <kanmy@comp.nus.edu.sg>

require 5.0;
use strict;
use Getopt::Long;

### USER customizable section
$0 =~ /([^\/]+)$/; my $progname = $1;
my $outputVersion = "1.0";
### END user customizable section

sub License {
  print STDERR "# Copyright 2009 \251 by Luong Minh Thang\n";
}

### HELP Sub-procedure
sub Help {
  print STDERR "Parse tagged header file into line-level data\n";
  print STDERR "usage: $progname -h\t[invokes help]\n";
  print STDERR "       $progname -in taggedHeaderFile -out outFile\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
}
my $QUIET = 0;
my $HELP = 0;
my $outFile = undef;
my $inFile = undef;

$HELP = 1 unless GetOptions('in=s' => \$inFile,
			    'out=s' => \$outFile,
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
processFile($inFile, $outFile);

sub processFile {
  my ($inFile, $outFile) = @_;
  
  if (!(-e $inFile)) { die "# $progname crash\t\tFile \"$inFile\" doesn't exist"; }
  open (IF, $inFile) || die "# $progname crash\t\tCan't open \"$inFile\"";
  open(OF, ">:utf8", "$outFile") || die"#Can't open file \"$outFile\"\n";
  
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
	  if($line =~ /^\s*$/) { print STDERR "Skip \"$line\"\n"; next; }

	  my @sub_lines = split(/\s*\+L\+\s*/, $line);
	  for(my $i=0; $i<$#sub_lines; $i++){#go through each subline of a header field

	    if($sub_lines[$i] !~ /^\s*$/){
	      print OF "$sub_lines[$i] +L+\n";
	    }
	  }
	  
	  #check if $line end with +L+
	  if($line =~ /\+L\+\s*$/){
	    print OF "$sub_lines[$#sub_lines] +L+\n";
	  } else {
	    print OF "$sub_lines[$#sub_lines]\n";
	  }

	  $line = ""; # reset
	  next;
	} elsif (/^\<([a-z]+)/) { #beginning tag
	  $tag = $1;
	  
	  print OF "//$tag\n";
	  next;
	} else { #contents inside tag
	  $line .= "$_ ";
	}
      }
    }
    print OF "\n";
  }
  
  close OF;
  close IF;
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
