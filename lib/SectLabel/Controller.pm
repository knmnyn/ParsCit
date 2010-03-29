package SectLabel::Controller;
#
# This package is used to pull together various citation
# processing modules in the SectLabel distribution, serving
# as a script for handling the entire citation processing
# control flow.  
# The extractSection subroutine should be
# the only needed API element to return XML output.
#
# Luong Minh Thang 25 May, 09. Adopted from Parscit Controller Isaac Councill, 07/23/07
# 

require 'dumpvar.pl';
use strict;
use SectLabel::PostProcess;
use SectLabel::Tr2crfpp;
use SectLabel::Config;
use CSXUtil::SafeText qw(cleanXML);

##
# Main API method for generating an XML document including all
# section data.  Returns a reference XML document.
#
sub extractSection {
    my ($textFile, $isXmlOutput, $modelFile, $dictFile, $funcFile, $configFile, $isXmlInput, $isDebug) = @_;

    if (!defined $modelFile || $modelFile eq "") {
      die "Die in SectLabel::Controller::extractSection - need to specify modelFile\n";
    }
    if (!defined $configFile || $configFile eq "") {
      die "Die in SectLabel::Controller::extractSection - need to specify configFile\n";
    }

    my ($status, $msg, $xml)
	= extractSectionImpl($textFile, $isXmlOutput, $modelFile, $dictFile, $funcFile, $configFile, $isXmlInput, $isDebug);
    if ($status > 0) {
	return \$xml;
    } else {
	my $error = "Error: $msg";
	return \$error;
    }

} # extractSection

##
# Main script for actually walking through the steps of
# document processing.  Returns a status code (0 for failure),
# an error message (may be blank if no error), a reference to
# an XML document.
#
# $isTokenLevel: flag to enable previous token-level model (for performance comparison).
# Todo: catch errors and return $status < 0
##

sub extractSectionImpl {
  my ($textFile, $isXmlOutput, $modelFile, $dictFile, $funcFile, $configFile, $isXmlInput, $isDebug) = @_;

  if($isDebug){
    print STDERR "modelFile = $modelFile\n";
    print STDERR "configFile = $configFile\n";
  }
  
  my ($status, $msg) = (1, "");

  if (!open (IN, "<:utf8", "$textFile")) {
    return (-1, "Could not open text file $textFile: $!");
  }
    
  my @textLines = ();
  my %blankLines = ();
  my $lineId = -1;
  while (<IN>) {
    chomp;
    s/\cM$//; # remove ^M character at the end of the file if any
    $lineId++;

#    if (/^\#s/) { next; }			# skip comments
    if (/^\s*$/) { # skip blank lines 
      if($isDebug){
	print STDERR "#! Warning blank line at line id $lineId\n";
      }
      $blankLines{$lineId} = 1;
      next; 
    } else {
      push(@textLines, $_);
    }
  }
  close IN;

  # run tr2crfpp to prepare feature files
  my $tmpFile;
  if($isDebug){ print STDERR "\n# Extracting test features ... "; }
  $tmpFile = SectLabel::Tr2crfpp::extractTestFeatures(\@textLines, $textFile, $dictFile, $funcFile, $configFile, $isDebug);
  if($isDebug){ print STDERR " Done! Output to $tmpFile\n"; }

  # run crf_test, output2xml
  my $outFile = $tmpFile."_dec";
  my $xml;
  if($isDebug){ print STDERR "\n# Decoding $tmpFile ... "; }

  if (SectLabel::Tr2crfpp::decode($tmpFile, $modelFile, $outFile)) {
    if($isDebug){ print STDERR " Done! Output to $outFile\n"; }

    my %sectionHeaders = (); 
    $sectionHeaders{"header"} = (); # array of section headers
    $sectionHeaders{"lineId"} = (); # array of corresponding line ids (0-based)
    if(!$isXmlOutput){
      $xml = SectLabel::PostProcess::wrapDocument($outFile, \%blankLines);
    } else {
      $xml = SectLabel::PostProcess::wrapDocumentXml($outFile, \%sectionHeaders);
    }
    
    my $numHeaders = scalar(@{$sectionHeaders{"header"}});
    my $headerFile = newTmpFile();
    open(OF, ">:utf8", $headerFile);
    for(my $i=0; $i<$numHeaders; $i++){
#      print STDERR $sectionHeaders{"lineId"}->[$i]."\t".$sectionHeaders{"header"}->[$i]."\n";
      print OF $sectionHeaders{"header"}->[$i]."\n";
    }
    close OF;
    print STDERR "$headerFile\n";
  }

  unlink($tmpFile);
#  print STDERR "$outFile\n";
  unlink($outFile);
  return ($status, $msg, $xml);
}

# Thang Mar 10: method to generate tmp file name
sub newTmpFile {
  my $tmpFile = `date '+%Y%m%d-%H%M%S-$$'`;
  chomp($tmpFile);
  return $tmpFile;
}

1;
