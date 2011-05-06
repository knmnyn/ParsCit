package SectLabel::PreProcess;

###
# Utilities for finding header, body, and reference.
# Avoid normalization to maintain consistent number of lines in a document
# Simplified from ParsCit::PreProcess
#
# Minh-Thang Luong, v100401
###

use utf8;
use strict;

###
# Looks for header section markers in the supplied text and
# separates the header text from the body text based on these
# indicators.  If it looks like there is a header section marker
# too late, an empty header text string will be returned.  
# Input: reference to an array of lines, line id to start process, number of lines (start_id < num_lines)
# Output: header length, body length, body start id)
###
sub FindHeaderText 
{
	my ($lines, $start_id, $num_lines) = @_;

	if($start_id >= $num_lines) { die "Die in SectLabel::PreProcess::findHeaderText: start id $start_id >= num lines $num_lines\n"; }

	my $body_start_id = $start_id;
	for(; $body_start_id < $num_lines; $body_start_id++)
	{
		if($lines->[$body_start_id] =~ /^(.*?)\b(Abstract|ABSTRACT|Introductions?|INTRODUCTIONS?)\b(.*?):?\s*$/) 
		{
			# There are trailing text after the word introduction
			if (CountTokens($3) > 0)
			{
				# INTRODUCTION AND BACKGROUND
				if($3 =~ /background/i) { last; }
			} 
			else 
			{
	 			last;
			}
		}
	}
		
	my $header_length	= $body_start_id - $start_id;
	my $body_length		= $num_lines - $body_start_id;

	if ($header_length >= 0.8*$body_length) 
	{
		print STDERR "Header text $header_length longer than 80% article body length $body_length: ignoring\n";
		
		$body_start_id	= $start_id;
		$header_length	= 0;
		$body_length	= $num_lines - $body_start_id;
	}

	if ($header_length == 0) { print STDERR "warning: no header text found\n"; }

	return ($header_length, $body_length, $body_start_id);
} 

###
# Looks for reference section markers in the supplied text and
# separates the citation text from the body text based on these
# indicators.  If it looks like there is a reference section marker
# too early in the document, this procedure will try to find later
# ones.  If the final reference section is still too long, an empty
# citation text string will be returned.  
## Input: reference to an array of lines, line id to start process, number of lines (start_id < num_lines)
## Output: body length, citation length, body end id
###
sub FindCitationText 
{
	my ($lines, $start_id, $num_lines) = @_;

	if ($start_id >= $num_lines) { die "Die in SectLabel::PreProcess::findCitationText: start id $start_id >= num lines $num_lines\n"; }

	my $body_end_id = ($num_lines - 1);
	for(; $body_end_id >= $start_id; $body_end_id--)
	{
		if ($lines->[$body_end_id] =~ /(References?|REFERENCES?|Bibliography|BIBLIOGRAPHY|References?\s+and\s+Notes?|References?\s+Cited|REFERENCES?\s+CITED|REFERENCES?\s+AND\s+NOTES?):?\s*$/) 
		{
			last;
		}
	}
		
	my $body_length		= $body_end_id - $start_id + 1;
	my $citation_length	= $num_lines -1 - $body_end_id;

	if ($citation_length >= 0.8*$body_length) 
	{
		print STDERR "Citation text $citation_length longer than 80% article body length $body_length: ignoring\n";
		
		$body_end_id		= ($num_lines - 1);
		$citation_length	= 0;
		$body_length		= $body_end_id - $start_id + 1;
	}

	if ($citation_length == 0) { print STDERR "warning: no citation text found\n"; }

	return ($body_length, $citation_length, $body_end_id);
}

sub CountTokens 
{
	my ($text) = @_;

	$text =~ s/^\s+//; # Trip leading spaces
	$text =~ s/\s+$//; # Trip trailing spaces
	my @tokens = split(/\s+/, $text);

	return scalar(@tokens);
}

1;
