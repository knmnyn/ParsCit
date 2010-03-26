package ParsHed::PostProcess;
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
use ParsCit::Config; # qw(normalizeAuthorNames stripPunctuation);

##
## Main method for processing header data. Specifically, it reads CRF
## output, performs normalization to individual fields, and outputs to
## XML
##
sub wrapHeaderXml {
  my ($inFile, $confInfo, $isTokenLevel) = @_; # Thang Nov 09: $confInfo to add confidence info

  my $status = 1;
  my $msg = "";
  my $xml = "";
  my $lastTag = "";
  my $variant = "";
  my $overallConfidence = "1.0"; # Thang Nov 09: rename $confidence -> $overallConfidence

  ## output XML file for display
  $xml .= "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";

  my @fields = (); #array of hash: each element of fields correspond to a pairs of (tag, content) accessible through $fields[$i]->{"tag"} and $fields[$i]->{"content"}
  my $curContent = "";
  my $curConfidence = 0; # for lines of the same label
  my $count = 0;
  open(IN, "<:utf8", $inFile) or return (undef, undef, 0, "couldn't open infile: $!");
  while (<IN>) {
    if (/^\# ([\.\d]+)/) { # confidence info
      $overallConfidence = $1;
      next;
    }
    elsif (/^\#/) { next; }                              # skip comments

    if (/^\s*$/) { # end of a header, output (useful to handle multiple header classification
      addFieldInfo(\@fields, $lastTag, $curContent, $curConfidence, $count);      # add the last field

      if ($variant eq "") {
	### generate XML output
	my $output = generateOutput(\@fields, $confInfo);
	my $l_algName = $ParsHed::Config::algorithmName;
	my $l_algVersion = $ParsHed::Config::algorithmVersion;
	$xml .= "<algorithm name=\"$l_algName\" version=\"$l_algVersion\">\n". "<variant no=\"0\" confidence=\"$overallConfidence\">\n". $output . "</variant>\n</algorithm>\n";
      }
      
      @fields = (); #reset
      $lastTag = "";
    } else { # in a middle of a header
      chop;
      my @tokens = split (/\t/);

      my $token = $tokens[0];
      my $sys = $tokens[-1];
      my $gold = $tokens[-2];
      my $confidence = 0;

      my $confidence = 0; # for this line
      if(!defined $isTokenLevel){ 
	# train at line level, get the original line
	my @tokens = split(/\|\|\|/, $token);
	$token = join(" ", @tokens);

	### Thang Nov 09: process confidence output from CRFPP
	if($confInfo){ #$sys contains probability info of the format "tag/prob"
	  if($sys =~ /^(.+)\/([\d\.]+)$/){
	    $sys = $1;
	    $confidence += $2;
#	    print STDERR "$token\t$sys\t$2\n";
	  } else {
	    die "Die in ParsHed::PostProcess::wrapHeaderXml : incorrect format \"tag/prob\" $sys\n";
	  }
	}
	### End Thang Nov 09: process confidence output from CRFPP
      }

      if ($sys ne $lastTag && $lastTag ne "") { # start a new tag, not an initial value, output
	addFieldInfo(\@fields, $lastTag, $curContent, $curConfidence, $count);
	  
	#reset the value
	$curContent = ""; 
	$curConfidence = 0;
	$count = 0;
      } # end if ($lastTag ne "")

      if(defined $isTokenLevel && $token eq "+L+"){ 
	next;
      }

      $curContent .= "$token ";
      $curConfidence += $confidence;
      $count++;
      $lastTag = $sys; #update lastTag
    }
  }

  close (IN);

  return $xml;
}

## Thang Mar 10: refactor this part of code into a method, to add per-field info 
sub addFieldInfo {
  my ($fields, $lastTag, $curContent, $curConfidence, $count) = @_;

  my %tmpHash = ();
  $tmpHash{"tag"} = $lastTag;
  $tmpHash{"content"} = $curContent;
  
  ### Thang Nov 09: compute confidence score
  if($count > 0){
    $tmpHash{"confidence"} = $curConfidence/$count;
  }

  push(@{$fields}, \%tmpHash);
}

## Thang Mar 10: refactor this part of code into a method, wrap all field infos into XML form
sub generateOutput {
  my ($fields, $confInfo) = @_;

  my $output = "";
  
  foreach(@{$fields}) {
    my $tag = $_->{"tag"};
    my $content = $_->{"content"};
    
    ### Thang Nov 09: modify to output confidence score
    my $confStr = "";
    if($confInfo){
      $confStr = " confidence=\"".$_->{"confidence"}."\"";
    }
    if($content =~ /^\s*$/) { next; };
    
    ($tag, $content) = normalizeHeaderField($tag, $content);
    
    if($tag eq "authors"){ # handle multiple authors in a line
      foreach my $author (@{$content}){
	$output .= "<author$confStr>$author</author>\n";
      }
    }elsif($tag eq "emails"){ # handle multiple emails at a time
      foreach my $email (@{$content}){
	$output .= "<email$confStr>$email</email>\n";
      }
    } else {
      $output .= "<$tag$confStr>$content</$tag>\n";
    }
    ### End Thang Nov 09: modify to output confidence score
  } # end for each fields
  
  return $output;    
}

##
# Header normalization subroutine.  Reads in a tag and its content, perform normalization based on that tag.
##
sub normalizeHeaderField {
  my ($tag, $content) = @_;;
  $content =~ s/^\W*$tag\W+//i;	     # remove keyword at the beginning
  $content =~ s/^\s+//g;			# strip leading spaces
  $content =~ s/\s+$//g;		      # remove trailing spaces
  $content =~ s/\- ([a-z])/$1/g;			 # unhyphenate
  cleanXML(\$content);			       # escape XML characters

  # normalize author and break into multiple authors (if any)
  if ($tag eq "author") {
    $tag = "authors";
    $content =~ s/\d//g; # remove numbers
    $content = ParsCit::PostProcess::normalizeAuthorNames($content);
  } elsif ($tag eq "email") {
    if($content =~ /^\{(.+)\}(.+)$/){ # multiple emails of the form {kanmy,luongmin}@nus.edu.sg
      my $begin = $1;
      my $end = $2;
      my $separator = ",";

      # find possible separator of emails, beside ","
      my @separators = ($begin =~ /\s+(\S)\s+/g); 
      if(scalar(@separators) > 1){
	my $cand = $separators[0];
	my $flag = 1;
	foreach(@separators) {
	  if($_ ne $cand){ #should be the same
	    $flag = 0;
	    last;
	  }
	}

	if($flag == 1) { #all separator are the same, and the number of separator > 1, update separator
	  $separator = $cand;
	}
      }

      my @tokens = split(/$separator/, $begin);
      $end =~ s/\s+//g; #remove all white spaces

      if(scalar(@tokens) > 1) { #there are actually multiple emails
	my @emails = ();

	foreach my $token (@tokens){
	  $token =~ s/\s+//g; #remove all white spaces
	  push (@emails, "$token$end");
	}

	$tag = "emails";
	$content = \@emails;
      }
    } else { # only one email
      $content =~ s/\s+//g; #remove all white spaces
    }
  } else {
    $content = ParsCit::PostProcess::stripPunctuation($content);
  }

  return ($tag, $content);
}  # normalizeFields

1;
