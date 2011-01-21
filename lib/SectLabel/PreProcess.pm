package SectLabel::PreProcess;
#
# Utilities for finding header, body, and reference.
# Avoid normalization to maintain consistent number of lines in a document
# Simplified from ParsCit::PreProcess
#
# Minh-Thang Luong, v100401
#

use strict;
use utf8;

##
# Looks for header section markers in the supplied text and
# separates the header text from the body text based on these
# indicators.  If it looks like there is a header section marker
# too late, an empty header text string will be returned.  
## Input: reference to an array of lines, line id to start process, number of lines (startId < numLines)
## Output: header length, body length, body start id)
##
sub findHeaderText {
		my ($lines, $startId, $numLines) = @_;

		if($startId >= $numLines){
			die "Die in SectLabel::PreProcess::findHeaderText: start id $startId >= num lines $numLines\n";
		}

		my $bodyStartId = $startId;
		for(; $bodyStartId<$numLines; $bodyStartId++){
			if($lines->[$bodyStartId] =~ /^(.*?)\b(Abstract|ABSTRACT|Introductions?|INTRODUCTIONS?)\b(.*?):?\s*$/) {
	if(countTokens($3) > 0){ # there are trailing text after the word introduction
	 if($3 =~ /background/i){ # INTRODUCTION AND BACKGROUND
		 last;
	 }
	} else {
	 last;
	}
			}
		}
		
		my $headerLength = $bodyStartId - $startId;
		my $bodyLength = $numLines - $bodyStartId;
		if ($headerLength >= 0.8*$bodyLength) {
	print STDERR "Header text $headerLength longer than 80% article body length $bodyLength: ignoring\n";
	$bodyStartId = $startId;
	$headerLength = 0;
	$bodyLength = $numLines - $bodyStartId;
		}

		if ($headerLength == 0){
	print STDERR "warning: no header text found\n";
		}

		return ($headerLength, $bodyLength, $bodyStartId);
}  # findHeaderText


##
# Looks for reference section markers in the supplied text and
# separates the citation text from the body text based on these
# indicators.  If it looks like there is a reference section marker
# too early in the document, this procedure will try to find later
# ones.  If the final reference section is still too long, an empty
# citation text string will be returned.  
## Input: reference to an array of lines, line id to start process, number of lines (startId < numLines)
## Output: body length, citation length, body end id
##
sub findCitationText {
		my ($lines, $startId, $numLines) = @_;

		if($startId >= $numLines){
			die "Die in SectLabel::PreProcess::findCitationText: start id $startId >= num lines $numLines\n";
		}

		my $bodyEndId = ($numLines - 1);
		for(; $bodyEndId >= $startId; $bodyEndId--){
			if($lines->[$bodyEndId] =~ /(References?|REFERENCES?|Bibliography|BIBLIOGRAPHY|References?\s+and\s+Notes?|References?\s+Cited|REFERENCES?\s+CITED|REFERENCES?\s+AND\s+NOTES?):?\s*$/) {
	last;
			}
		}
		
		my $bodyLength = $bodyEndId - $startId + 1;
		my $citationLength = $numLines -1 - $bodyEndId;
		if ($citationLength >= 0.8*$bodyLength) {
	print STDERR "Citation text $citationLength longer than 80% article body length $bodyLength: ignoring\n";
	$bodyEndId = ($numLines - 1);
	$citationLength = 0;
	$bodyLength = $bodyEndId - $startId + 1;
		}

		if ($citationLength == 0){
	print STDERR "warning: no citation text found\n";
		}

		return ($bodyLength, $citationLength, $bodyEndId);
}  # findHeaderText

sub countTokens {
	my ($text) = @_;

	$text =~ s/^\s+//; # trip leading spaces
	$text =~ s/\s+$//; # trip trailing spaces
	my @tokens = split(/\s+/, $text);

	return scalar(@tokens);
}

1;
