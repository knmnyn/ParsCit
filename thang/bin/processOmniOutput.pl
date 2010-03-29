#!/usr/bin/perl -wT
# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Sun, 28 Mar 2010 23:13:31

# Modified from template by Min-Yen Kan <kanmy@comp.nus.edu.sg>

require 5.0;
use strict;
use Getopt::Long;

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
use lib "$path/../lib";
#use Utility::Controller;
#use Morphology::Controller;

### USER customizable section
$0 =~ /([^\/]+)$/; my $progname = $1;
my $outputVersion = "1.0";
### END user customizable section

sub License {
  print STDERR "# Copyright 2009 \251 by Luong Minh Thang\n";
}

### HELP Sub-procedure
sub Help {
  print STDERR "usage: $progname -h\t[invokes help]\n";
  print STDERR "       $progname -in inDir\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
}
my $QUIET = 0;
my $HELP = 0;
my $inDir = undef;

$HELP = 1 unless GetOptions('in=s' => \$inDir,
			    'h' => \$HELP,
			    'q' => \$QUIET);

if ($HELP || !defined $inDir) {
  Help();
  exit(0);
}

if (!$QUIET) {
  License();
}

### Untaint ###
$inDir = untaintPath($inDir);
my $envPath = $ENV{'PATH'};
$envPath = untaintPath($envPath);
$ENV{'PATH'} = $envPath;
### End untaint ###

chdir $inDir;
execute("find . -type d | grep \"./\" > fileList");

# little2bigEndian
execute("mkdir xml");
execute("mkdir tmp");
execute("cp */*.xml tmp/");
chdir "tmp";
execute("ls * | xargs -I xxx $path/little2bigEndian.pl -in xxx -out ../xml/xxx");
chdir "..";

# concate XML
execute("mkdir xml-concat");
execute("echo \"#!/bin/sh\" > script.sh"); 
execute("less fileList | xargs -I xxx echo \"cat xml/xxx* > xml-concat/xxx.txt\" >> script.sh");
execute("chmod 755 script.sh");
execute("./script.sh");

# clear
execute("rm -rf tmp");

sub untaintPath {
  my ($path) = @_;

  if ( $path =~ /^([-_\/\w\.\d: ]+)$/ ) { #\p{C}\p{P}
    $path = $1;
  } else {
    die "Bad path $path\n";
  }

  return $path;
}

sub untaint {
  my ($s) = @_;
  if ($s =~ /^([\w \-\@\(\),\.\/<>*\|\"!\#]+)$/) { #\p{C}\p{P}
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
