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
  my ($inFile, $isTokenLevel) = @_;

  my $status = 1;
  my $msg = "";
  my $xml = "";
  my $lastTag = "";
  my $variant = "";
  my $confidence = "1.0";

  ## output XML file for display
  $xml .= "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
# Min - removed stylesheet (Fri Jul 17 23:02:42 SGT 2009)
#  $xml .= "<?xml-stylesheet href=\"bibxml.xsl\" type=\"text/xsl\" ?>\n";

  my @fields = (); #array of hash: each element of fields correspond to a pairs of (tag, content) accessible through $fields[$i]->{"tag"} and $fields[$i]->{"content"}
  my $curContent = "";

  open(IN, "<:utf8", $inFile) or return (undef, undef, 0, "couldn't open infile: $!");
  while (<IN>) {
    if (/^\# (\d+) ([\.\d]+)/) { # variant & confidence info
      $variant = $1;
      $confidence = $2;
      next;
    }
    elsif (/^\#/) { next; }                              # skip comments

    if (/^\s*$/) { # end of a header, output (useful to handle multiple header classification
      # add the last field
      my %tmpHash = ();
      $tmpHash{"tag"} = $lastTag;
      $tmpHash{"content"} = $curContent;
      push(@fields, \%tmpHash);

      if ($variant eq "") {
	my $l_algVersion = $ParsCit::Config::algorithmVersion;
	my $l_algName = $ParsCit::Config::algorithmName;
	$xml .= "<algorithm name=\"$l_algName\" version=\"$l_algVersion\">\n<header>\n";

	my $output = "";
	foreach(@fields) {
	  my $tag = $_->{"tag"};
	  my $content = $_->{"content"};

	  if($content =~ /^\s*$/) { next; };

	  ($tag, $content) = normalizeHeaderField($tag, $content);

	  if($tag eq "authors"){ # handle multiple authors in a line
	    foreach my $author (@{$content}){
	      $output .= "PARSHED<author>$author</author>";
	    }
	  }elsif($tag eq "emails"){ # handle multiple emails at a time
	    foreach my $email (@{$content}){
	      $output .= "PARSHED<email>$email</email>";
	    }
	  } else {
	    $output .= "PARSHED<$tag>$content</$tag>";
	  }
	}
	$output =~ s/PARSHED</\n</g;

	$xml .= "<variant no=\"0\" confidence=\"$confidence\">" . $output . "\n</variant>\n";
	$xml .= "</header>\n</algorithm>\n";
      }

      @fields = (); #reset
      $lastTag = "";
    } else { # in a middle of a header
      chop;
      my @tokens = split (/\t/);

      my $token = $tokens[0];
      my $sys = $tokens[-1];
      my $gold = $tokens[-2];

      if(!defined $isTokenLevel){ 
	# train at line level, get the original line
	my @tokens = split(/\|\|\|/, $token);
	$token = join(" ", @tokens);
      }

      if ($sys ne $lastTag) { # start a new tag
	if ($lastTag ne "") { # not an initial value, output
	  my %tmpHash = ();
	  $tmpHash{"tag"} = $lastTag;
	  $tmpHash{"content"} = $curContent;
	  push(@fields, \%tmpHash);

	  $curContent = ""; #reset the value
	}
      }

      if(defined $isTokenLevel && $token eq "+L+"){ 
	next;
      }

      $curContent .= "$token ";
      $lastTag = $sys; #update lastTag
    }
  }

  close (IN);

  return $xml;
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
