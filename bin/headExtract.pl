#!/usr/bin/perl -CSD
#
# Simple command script for executing ParsHed in an
# offline mode (direct API call instead of going through
# the web service).
#
# Luong Minh Thang 25 May, 09. Adopted from Isaac Councill, 08/23/07
#
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use ParsHed::Controller;

my $isTokenLevel = 0; # 1: enable old model which was trained at token level, while the default new model is trained at line level
my @newArgv = ();
foreach(@ARGV){
  if($_ eq "-tokenLevel"){
    $isTokenLevel = 1;
  } else {
    push(@newArgv, $_);
  }
}

my $textFile = $newArgv[0];
my $outFile = $newArgv[1];

if (!defined $textFile) {
    print "Usage: $0 textfile [outfile] [-tokenLevel]\n";
    exit;
}

my $rXML = ParsHed::Controller::extractHeader($textFile, $isTokenLevel);

if (defined $outFile) {
    open (OUT, ">$outFile") or die "Could not open $outFile for writing: $!";
    print OUT $$rXML;
    close OUT;
} else {
    print "$$rXML";
}
