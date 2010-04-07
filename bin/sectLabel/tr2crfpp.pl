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
use SectLabel::Config;
use SectLabel::Tr2crfpp;

### USER customizable section
$0 =~ /([^\/]+)$/; my $progname = $1;
my $outputVersion = "1.0";
### END user customizable section

sub License {
  print STDERR "# Copyright 2009 \251 by Luong Minh Thang\n";
}

### HELP Sub-procedure
sub Help {
  print STDERR "Generate SectLabel features for CRF++\n";
  print STDERR "usage: $progname -h\t[invokes help]\n";
  print STDERR "       $progname -in inFile -c configFile -out outFile [-template]\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
  print STDERR "\t-in inFile: labeled input file\n";
  print STDERR "\t-c configFile: to specify which feature set to use.\n";
  print STDERR "\t-out outFile: output file for CRF++ training.\n";
  print STDERR "\t-template: to output a template used by CRF++ according to the config file.\n";
}
my $QUIET = 0;
my $HELP = 0;
my $inFile = undef;
my $outFile = undef;
my $dictFile = $SectLabel::Config::dictFile;
$dictFile = "$FindBin::Bin/../../$dictFile";

my $funcFile = $SectLabel::Config::funcFile;
$funcFile = "$FindBin::Bin/../../$funcFile";

my $configFile = undef;
my $isTemplate = 0;
$HELP = 1 unless GetOptions('in=s' => \$inFile,
			    'out=s' => \$outFile,
			    'c=s' => \$configFile,
			    'template' => \$isTemplate,
			    'h' => \$HELP,
			    'q' => \$QUIET);

if ($HELP || !defined $inFile || !defined $outFile || !defined $configFile) {
  Help();
  exit(0);
}

if (!$QUIET) {
  License();
}

### Untaint ###
$inFile = untaintPath($inFile);
$outFile = untaintPath($outFile);
$configFile = untaintPath($configFile);
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
### End untaint ###

SectLabel::Tr2crfpp::tr2crfpp($inFile, $outFile, $dictFile, $funcFile, $configFile, $isTemplate);

sub untaintPath {
  my ($path) = @_;

  if ( $path =~ /^([-_\/\w\.]*)$/ ) {
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
