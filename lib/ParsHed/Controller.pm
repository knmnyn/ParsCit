package ParsHed::Controller;
#
# This package is used to pull together various citation
# processing modules in the ParsCit distribution, serving
# as a script for handling the entire citation processing
# control flow.  
# The extractHeader subroutine should be
# the only needed API element to return XML output.
#
# Luong Minh Thang 25 May, 09. Adopted from Parscit Controller Isaac Councill, 07/23/07
# 

require 'dumpvar.pl';
use strict;
use ParsCit::PreProcess;
use ParsHed::PostProcess;
use ParsHed::Tr2crfpp;
use ParsHed::Tr2crfpp_token; # for token-level model
use ParsCit::CitationContext;
use ParsHed::Config;
use CSXUtil::SafeText qw(cleanXML);

##
# Main API method for generating an XML document including all
# header data.  Returns a reference XML document.
#
sub extractHeader {
    my ($textFile, $isTokenLevel, $confLevel) = @_; # Thang 10/11/09: $confLevel to add confidence info
    my ($status, $msg, $xml)
	= extractHeaderImpl($textFile, $isTokenLevel, $confLevel);
    if ($status > 0) {
	return \$xml;
    } else {
	my $error = "Error: $msg";
	return \$error;
    }

} # extractHeader


##
# Main script for actually walking through the steps of
# header processing.  Returns a status code (0 for failure),
# an error message (may be blank if no error), a reference to
# an XML document.
#
# $isTokenLevel: flag to enable previous token-level model (for performance comparison).
# Todo: catch errors and return $status < 0
##

sub extractHeaderImpl {
  my ($textFile, $isTokenLevel, $confLevel, $modelFile) = @_;  # Thang 10/11/09: $confLevel to add confidence info

  if (!defined $modelFile) {
    $modelFile = $ParsCit::Config::modelFile;
  }
  
  my ($status, $msg) = (1, "");

  if (!open (IN, "<:utf8", "$textFile")) {
    return (-1, "Could not open text file $textFile: $!");
  }
    
  my $buf = "";
  while (<IN>) {
    chomp;
    s/\cM$//; # remove ^M character at the end of the file if any

    if (/^\#/) { next; }			# skip comments
    elsif (/^\s+$/) { next; }		# skip blank lines
    else {
      if (/INTRODUCTION/i) {					    # sample RE for header stop.
	last;
      }
      
      if($isTokenLevel){
	$buf .= "$_";
	$buf .= " +L+ ";
      } else {
	$buf .= "$_\n";
      }
    }
  }
  close IN;

  if($isTokenLevel){ # for compatible reason
    $buf = "<title> $buf </title>\n";
  }

  # run tr2crfpp to prepare feature files
  my $tmpFile;
  if($isTokenLevel){
    $tmpFile = ParsHed::Tr2crfpp_token::prepData(\$buf, $textFile);
  } else {
    $tmpFile = ParsHed::Tr2crfpp::prepData(\$buf, $textFile);
  }

  # run crf_test, output2xml
  my $outFile = $tmpFile."_dec";
  my $xml;

  if($isTokenLevel){
    if (ParsHed::Tr2crfpp_token::decode($tmpFile, $outFile)) {
      $xml = ParsHed::PostProcess::wrapHeaderXml($outFile, 0, $isTokenLevel);
    }
  } else {
    if (ParsHed::Tr2crfpp::decode($tmpFile, $outFile, $confLevel)) {  # Thang 10/11/09: $confLevel to add confidence info
      $xml = ParsHed::PostProcess::wrapHeaderXml($outFile, $confLevel);  # Thang 10/11/09: $confLevel to add confidence info
    }
  }

  unlink($tmpFile);
  unlink($outFile);
  return ($status, $msg, $xml);
}

1;
