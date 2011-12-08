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

###
# Main API method for generating an XML document including all
# header data.  Returns a reference XML document.
###
sub extractHeader 
{
    my ($text_file, $is_token_level) = @_; 

	# Thang 10/11/09: add confidence score option - 1: enable, 0: disable
    my $conf_level = 1; 
    my ($status, $msg, $xml) = extractHeaderImpl($text_file, $is_token_level, $conf_level);

    if ($status > 0) 
	{
		return \$xml;
    } 
	else 
	{
		my $error = "Error: $msg";
		return \$error;
    }
}


###
# Main script for actually walking through the steps of
# header processing.  Returns a status code (0 for failure),
# an error message (may be blank if no error), a reference 
# to an XML document.
#
# $is_token_level: flag to enable previous token-level model 
# (for performance comparison).
# Todo: catch errors and return $status < 0
###
sub extractHeaderImpl 
{
	# Thang 10/11/09: $confLevel to add confidence info
	my ($text_file, $is_token_level, $conf_level) = @_;

  	my ($status, $msg) = (1, "");

	# Open input text file
  	if (!open (IN, "<:utf8", "$text_file")) { return (-1, "Could not open text file $text_file: $!"); }
    
  	my $buf = "";
	while (<IN>) 
	{
    	chomp;

		# Remove ^M character at the end of the file if any
		s/\cM$//; 
	
		# Skip comments
    	if (/^\#/) 
		{ 
			next; 
		}
		# Skip blank lines
		elsif (/^\s+$/) 
		{ 
			next; 
		}
    	else 
		{
			# sample RE for header stop.
	      	if (/INTRODUCTION/i) { last; }
      
      		if($is_token_level)
			{
				$buf .= "$_";
				$buf .= " +L+ ";
      		} 
			else 
			{
				$buf .= "$_\n";
      		}
    	}
  	}
  	close IN;

	# For compatible reason
  	if($is_token_level) { $buf = "<title> $buf </title>\n"; }

  	# Run tr2crfpp to prepare feature files
	my $tmpfile;
  	if($is_token_level)
	{
    	$tmpfile = ParsHed::Tr2crfpp_token::prepData(\$buf, $text_file);
  	} 
	else 
	{
    	$tmpfile = ParsHed::Tr2crfpp::prepData(\$buf, $text_file);
  	}

  	my $xml = undef;
  	# run crf_test, output2xml
	my $outfile = $tmpfile."_dec";

  	if($is_token_level)
	{
    	if (ParsHed::Tr2crfpp_token::decode($tmpfile, $outfile)) 
		{
			$xml = ParsHed::PostProcess::wrapHeaderXml($outfile, 0, $is_token_level);
    	}
  	} 
	else 
	{
		# Thang 10/11/09: $confLevel to add confidence info
    	if (ParsHed::Tr2crfpp::decode($tmpfile, $outfile, $conf_level)) 
		{
			# Thang 10/11/09: $confLevel to add confidence info
      		$xml = ParsHed::PostProcess::wrapHeaderXml($outfile, $conf_level);  
    	}
  	}

  	unlink($tmpfile);
  	unlink($outfile);
  	return ($status, $msg, $xml);
}

1;
