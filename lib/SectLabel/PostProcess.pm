
package SectLabel::PostProcess;
#
# Utilities for normalizing the output of CRF++ into standard
# representations.
#
# Luong Minh Thang 25 May, 09. Adopted from Isaac Councill, 07/20/07
#

use strict;
use utf8;
use CSXUtil::SafeText qw(cleanXML);
use ParsCit::PostProcess; # qw(normalizeAuthorNames stripPunctuation);
use ParsCit::Config;

##
# Main method for processing header data. Specifically, it reads CRF output, performs normalization to individual fields, and outputs to XML
##
sub wrapHeaderXml {
  my ($inFile, $isTokenLevel) = @_;

  my $status = 1;
  my $msg = "";
  my $xml = "";
  my $line = 0;
  my $lastTag = "";

  my $overallConfidence = "1.0";
  my $curConfidence = 0; # for lines of the same label
  my $count = 0;

  ## output XML file for display
  $xml .= "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";

  my @fields = (); #array of hash: each element of fields correspond to a pairs of (tag, content) accessible through $fields[$i]->{"tag"} and $fields[$i]->{"content"}
  my $curContent = "";
  
  open(IN, "<:utf8", $inFile) or return (undef, undef, 0, "couldn't open infile: $!");
  while (<IN>) {
    if (/^\# ([\.\d]+)/) { # confidence info
      $overallConfidence = $1;
      next;
    }

#    elsif (/^\#/) { next; }                              # skip comments
    
    if (/^\s*$/) { # end of a sentence, output (useful to handle multiple header classification
      # add the last field
      addFieldInfo(\@fields, $lastTag, $curContent, $curConfidence, $count);      # add the last field

      ### generate XML output
      my $output = generateOutput(\@fields);      
      my $l_algVersion = $ParsCit::Config::algorithmVersion;
      $xml .= "<algorithm name=\"SectLabel\" version=\"$l_algVersion\" confidence=\"$overallConfidence\">\n".$output."</algorithm>\n";
      $line++;
      
      @fields = (); #reset
      $lastTag = "";
    } else { # in a middle of a header
      chop;
      my @tokens = split (/\t/);
      
      my $line = $tokens[0];
      my $sys = $tokens[-1];
      my $gold = $tokens[-2];

      my $confidence = 0; # for this line
      # train at line level, get the original line
      @tokens = split(/\|\|\|/, $line);
      $line = join(" ", @tokens);

      if($sys =~ /^(.+)\/([\d\.]+)$/){
	$sys = $1;
	$confidence += $2;
#	print STDERR "$line\t$sys\t$2\n";
      } else {
	die "Die in SectLabel:PostProcess::wrapHeaderXml : incorrect format \"tag/prob\" $sys\n";
      }

      if ($sys ne $lastTag && $lastTag ne "") { # start a new tag, not an initial value, output
	addFieldInfo(\@fields, $lastTag, $curContent, $curConfidence, $count);
	  
	#reset the value
	$curContent = ""; 
	$curConfidence = 0;
	$count = 0;
      } # end if ($lastTag ne "")

      $curContent .= "$line\n";
      $curConfidence += $confidence;
      $count++;
      $lastTag = $sys; #update lastTag
    }
  }

  close (IN);

  return $xml;
}

## To add per-field info 
sub addFieldInfo {
  my ($fields, $lastTag, $curContent, $curConfidence, $count) = @_;

  my %tmpHash = ();
  $tmpHash{"tag"} = $lastTag;
  $tmpHash{"content"} = $curContent;

  # confidence info
  if($count > 0){
    $tmpHash{"confidence"} = $curConfidence/$count;
  }

  push(@{$fields}, \%tmpHash);

#  print STDERR "\n###\n";
#  foreach my $key (keys %tmpHash){
#    print STDERR "$key -> $tmpHash{$key}\n";
#  }
}

## Wrap all field infos into XML form
sub generateOutput {
  my ($fields) = @_;

  my $output = "";
  foreach(@{$fields}) {
    my $tag = $_->{"tag"};
    my $content = $_->{"content"};
    my $confStr = " confidence=\"".$_->{"confidence"}."\"";
    if($content =~ /^\s*$/) { next; };
    
    ($tag, $content) = normalizeHeaderField($tag, $content);
    
    if($tag eq "authors"){ # handle multiple authors in a line
      foreach my $author (@{$content}){
	$output .= "<author$confStr>\n$author\n</author>\n";
      }
    }elsif($tag eq "emails"){ # handle multiple emails at a time
      foreach my $email (@{$content}){
	$output .= "<email$confStr>\n$email\n</email>\n";
      }
    } else {
      $output .= "<$tag$confStr>\n$content\n</$tag>\n";
    }
  }

  return $output;
}

## Wrap header into non-XML form
sub wrapHeader {
  my ($inFile, $blankLines, $isTokenLevel) = @_;

  my $status = 1;
  my $msg = "";
  my $xml = "";
  my $variant = "";
  my $confidence = "1.0";

  ## output XML file for display
  my @fields = (); #array of hash: each element of fields correspond to a pairs of (tag, content) accessible through $fields[$i]->{"tag"} and $fields[$i]->{"content"}
  my @curContent = ();
  open(IN, "<:utf8", $inFile) or return (undef, undef, 0, "couldn't open infile: $!");
  my $lineId = -1;
  while (<IN>) {
    $lineId++;
    while($blankLines->{$lineId}){
      print STDERR "#! Insert none label for line id $lineId\n";
      $xml .= "none \n";
      $lineId++;
    }

    if (/^\s*$/) { # end of a sentence, output (useful to handle multiple header classification
      # add the last field
      $lineId = -1;

      if ($variant eq "") {
      }
      $lineId = -1;
    } else { # in a middle of a header
      chop;
      my @tokens = split (/\t/);
      
      my $line = $tokens[0];
      my $sys = $tokens[-1];
      my $gold = $tokens[-2];

      # train at line level, get the original line
      @tokens = split(/\|\|\|/, $line);
      $line = join(" ", @tokens);

      ($sys, $line) = normalizeHeaderField($sys, $line);
      $xml .= "$sys $line\n";
    }
  }

  close (IN);

  return $xml;
}

sub simpleNormalize {
  my ($tag, $content) = @_;;

  # remove keyword at the beginning and strip leading spaces
  $content =~ s/^\s*$tag\s+//i;

  # remove trailing spaces
  $content =~ s/\s+$//g;

  # unhyphenation
  $content =~ s/\- ([a-z])/$1/g;

  # escape XML characters
  cleanXML(\$content);
  
#  $content = ParsCit::PostProcess::stripPunctuation($content);

  return ($tag, $content);
}
##
# Header normalization subroutine.  Reads in a tag and its content, perform normalization based on that tag.
##
sub normalizeHeaderField {
  my ($tag, $content) = @_;;

  # remove keyword at the beginning and strip leading spaces
  $content =~ s/^\s*$tag\s+//i;

  # remove trailing spaces
  $content =~ s/\s+$//g;

  # unhyphenation
  $content =~ s/\- ([a-z])/$1/g;

  # escape XML characters
  cleanXML(\$content);
  
#  $content = ParsCit::PostProcess::stripPunctuation($content);
  return ($tag, $content);
}  # normalizeFields

1;
