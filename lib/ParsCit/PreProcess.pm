package ParsCit::PreProcess;
#
# Utilities for finding and normalizing citations within
# text files, including separating citation text from
# body text and segmenting citations.
#
# Isaac Councill, 7/19/07
#

use strict;
use utf8;
use ParsCit::Citation;

my %markerTypes = (
		   'SQUARE' => '\\[.+?\\]',
		   'PAREN' => '\\(.+?\\)',
		   'NAKEDNUM' => '\\d+',
		   'NAKEDNUMDOT' => '\\d+\\.',
#		   'NAKEDNUM' => '\\d{1,3}', # Modified by Artemy Kolchinsky (v090625)
#		   'NAKEDNUMDOT' => '\\d{1,3}\\.', # Modified by Artemy Kolchinsky (v090625)
		   );


##
# Looks for reference section markers in the supplied text and
# separates the citation text from the body text based on these
# indicators.  If it looks like there is a reference section marker
# too early in the document, this procedure will try to find later
# ones.  If the final reference section is still too long, an empty
# citation text string will be returned.  Returns references to
# the citation text, normalized body text, and original body text.
##
sub findCitationText {
    my ($rText) = @_;
    my $text = $$rText;
    my $bodyText = '0';
    my $citeText = '0';

    while ($text =~ m/\b(References?|REFERENCES?|Bibliography|BIBLIOGRAPHY|References?\s+and\s+Notes?|References?\s+Cited|REFERENCE?\s+CITED|REFERENCES?\s+AND\s+NOTES?):?\s*\n+/sg) {
	$bodyText = substr $text, 0, pos $text;
	$citeText = substr $text, pos $text unless (pos $text < 1);
    }
    if (length($citeText) >= 0.8*length($bodyText)) {
	print STDERR "Citation text longer than article body: ignoring\n";
	$citeText = "";
	return \$citeText, \normalizeBodyText(\$bodyText), \$bodyText;
    }
    my ($sciteText, $tmp) = split(/^([\s\d\.]+)?(Acknowledge?ments?|Autobiographical|Tables?|Appendix|Exhibit|Annex|Fig|Notes?)(.*?)\n+/m, $citeText);
    if (length($sciteText)>0) {
	$citeText = $sciteText;
    }

    if ($citeText eq '0' || !defined $citeText) {
	print STDERR "warning: no citation text found\n";
    }

    return (normalizeCiteText(\$citeText),
	    normalizeBodyText(\$bodyText),
	    \$bodyText);

}  # findCitationText


##
# Removes lines that appear to be junk from the citation text.
##
sub normalizeCiteText {
    my ($rCiteText) = @_;

    my @lines = split "\n", $$rCiteText;
    my @newLines = ();

########## modified by Artemy Kolchinsky (v090625)
# In some cases, I had situations like:
# Smith B, "Blah Blah." Journal1, 2000, p. 23-
# 85
#Here, the line consisting of '85' is part of the citation and shouldn't be dropped, even though it only consist of numeric characters.  The way I went about this is that I dropped those lines consisting of only spacing characters, *or* only numeric characters *if the previous line did not end on a hyphen*.
    my $oldline = "";
    foreach my $line (@lines) {
      $line =~ s/^\s*//g; #dropped leading spaces added by Thang (v090625)
      $line =~ s/\s*$//g; #dropped trailing spaces added by Thang (v090625)

      if ($line =~ m/^\s*$/ || ($oldline !~ m/\-$/ && $line =~ m/^\d*$/)) {
	$oldline = $line;
	next;
      }

      $oldline = $line;
      push @newLines, $line;
    }
########## end modified by Artemy Kolchinsky (v090625)

    my $newText = join "\n", @newLines;
    return \$newText;

}  # normalizeCiteText


##
# Removes lines that appear to be junk from the body text,
# de-hyphenates words where a hyphen occurs at the end of
# a line, and normalizes strings of blank spaces to only
# single blancks.
#
# HISTORY: Nick (v081201)
# 
# In some publications markers with a range such as [1-5] or [1-12, 16]
# are used. ParsCit cannot find these markers. I added a simple
# workaround to PreProcess::normalizeBodyText. The markers with range
# are replaced by markers containing every number of the range
# (e.g. [1-5] replaced by [1, 2, 3, 4, 5]).
#
##
sub normalizeBodyText {
    my ($rText) = @_;
    my @lines = split "\n", $$rText;
    my $text = "";
    foreach my $line (@lines) {

##################
	$line =~ s/\[(\d+[,;] *)*((\d+)-(\d+))([,;] *\d+)*\]/"[".$1.transformMarker($3,$4).$5."]"/e;
###################
	if ($line =~ m/^\s*$/) {
	    next;
	}

	### modified by Artemy Kolchinsky (v090625)
	# !!! merge without removing "-" if preceeded by numbers...
	if ($text =~ s/([A-Za-z])\-$/$1/) {
	    $text .= $line;
	} else {
	    if ($text !~ m/\-\s*$/) { $text .= " " }
	    $text .= $line;
	}
	### end modified by Artemy Kolchinsky (v090625)
    }
    $text =~ s/\s{2,}/ /g;
    return \$text;

} # normalizeBodyText

sub transformMarker {
	my ($firstNumber, $secondNumber) = @_;
	my $newMarker = $firstNumber;
	
	for ( my $i = ($firstNumber+1) ; $i<=$secondNumber ; $i++ ) {
		$newMarker .= ", ".$i;
	}

	return $newMarker;
}

##
# Controls the process by which citations are segmented,
# based on the result of trying to guess the type of
# citation marker used in the reference section.  Returns
# a reference to a list of citation objects.
##
sub segmentCitations {
    my ($rCiteText) = @_;
    my $markerType = guessMarkerType($rCiteText);

    my $rCitations;

    if ($markerType ne 'UNKNOWN') {
	$rCitations = splitCitationsByMarker($rCiteText, $markerType);
    } else {
	$rCitations = splitUnmarkedCitations($rCiteText);
    }

    return $rCitations;

}  # segmentCitations


##
# Segments citations that have explicit markers in the
# reference section.  Whenever a new line starts with an
# expression that matches what we'd expect of a marker,
# a new citation is started.  Returns a reference to a
# list of citation objects.
##
sub splitCitationsByMarker {
    my ($rCiteText, $markerType) = @_;
    my @citations;
    my $currentCitation = new ParsCit::Citation();
    my $currentCitationString;

    # TODO: Might want to add a check that marker number is
    # increasing as we'd expect, if the marker is numeric.

    foreach my $line (split "\n", $$rCiteText) {
	if ($line =~ m/^\s*($markerTypes{$markerType})\s*(.*)$/) {
	    my ($marker, $citeString) = ($1, $2);
	    if (defined $currentCitationString) {
		$currentCitation->setString($currentCitationString);
		push @citations, $currentCitation;
		$currentCitationString = undef;
	    }
	    $currentCitation = new ParsCit::Citation();
	    $currentCitation->setMarkerType($markerType);
	    $currentCitation->setMarker($marker);
	    $currentCitationString = $citeString;
	} else {
	  ### modified by Artemy Kolchinsky (v090625)
	  # !!! merge without removing "-" if preceeded by numbers...
	  if ($currentCitationString =~ m/[A-Za-z]\-$/) { 
	    # merge words when lines are hyphenated
	    $currentCitationString =~ s/\-$//; 
	    $currentCitationString .= $line;
	  } else {
	    if ($currentCitationString !~ m/\-\s*$/) { $currentCitationString .= " " } #!!!
	    $currentCitationString .= $line;
	  }
	  ### end modified by Artemy Kolchinsky (v090625)
	}
    }
    if (defined $currentCitation && defined $currentCitationString) {
	$currentCitation->setString($currentCitationString);
	push @citations, $currentCitation;
    }
    return \@citations;

}  # splitCitationsByMarker


##
# Uses several heuristics to decide where individual citations
# begin and end based on the length of previous lines, strings
# that look like author lists, and punctuation.  Returns a
# reference to a list of citation objects.
#
# HISTORY: Modified in 081201 by Nick and J\"{o}ran.
# 
# There was an error with unmarkedCitations. ParsCit ignored the last
# citation in the reference section due to a simple error in a for loop.
# In PreProcess::splitUnmarkedCitations (line 241; line 258 in my
# modified file) "$k<$#citeStarts" is used as exit condition. It should
# be "<=" and not "<" beause $#citeStarts provides the last index and
# not the length of the array.
#
# HISTORY: Modified in 081201 by Min to remove superfluous print statements
#
##
sub splitUnmarkedCitations {
    my ($rCiteText) = @_;
    my @content = split "\n", $$rCiteText;
    my @citeStarts = ();
    my $citeStart = 0;
    my @citations = ();

    for (my $i=0; $i<=$#content; $i++) {
	if ($content[$i] =~ m/\b\(?[1-2][0-9]{3}[\p{IsLower}]?[\)?\s,\.]*(\s|\b)/s) {
	    for (my $k=$i; $k > $citeStart; $k--) {
		if ($content[$k] =~ m/\s*[\p{IsUpper}]/g) {
		    # If length of previous line is extremely small,
		    # start a new citation here.
		    if (length($content[$k-1]) < 2) {
			$citeStart = $k;
			last;
		    }

		    # Start looking backwards for lines that could
		    # be author lists - these usually start the
		    # citation, have several separation characters (,;),
		    # and shouldn't contain any numbers.
		    my $beginningAuthorLine = -1;
		    for (my $j=$k-1; $j>$citeStart; $j--) {
			if ($content[$j] =~ m/\d/) {
			    last;
			}
			$_ = $content[$j];
			my $nSep = s/([,;])/\1/g;
			if ($nSep >= 3) {
			    if (($content[$j-1] =~ m/\.\s*$/) || $j==0) {
				$beginningAuthorLine = $j;
			    }
			} else {
			    last;
			}
		    }
		    if ($beginningAuthorLine >= 0) {
			$citeStart = $beginningAuthorLine;
			last;
		    }

		    # Now that the backwards author search failed
		    # to find any extra lines, start a new citation
		    # here if the previous line ends with a ".".

		    ########## modified by Artemy Kolchinsky (v090625)
		    #A new citation is started if the previous line ended with a period, but not if it ended with a period, something else, and then a period.  This is to avoid assuming that abbrevations, like U.S.A. , indicate the end of a cite.  Also, a new cite is started only if the current line does not begin with a series of 4 digits.  This helped avoid some mis-parsed citations for me.  The new if-statement read like:
		    
		    if ($content[$k-1] =~ m/[^\.].\.\s*$/ && $content[$k] !~ m/^\d\d\d\d/) {
		      $citeStart = $k;
		      last;
		    }
		}
	    }
	    push @citeStarts, $citeStart
		unless (($citeStart <= $citeStarts[$#citeStarts]) &&
			($citeStart != 0));
	}
    }
    for (my $k=0; $k<=$#citeStarts; $k++) {
	my $firstLine = $citeStarts[$k];
	my $lastLine = ($k==$#citeStarts) ? $#content : ($citeStarts[$k+1]-1);
	my $citeString =
	    mergeLines(join "\n", @content[$firstLine .. $lastLine]);
	my $citation = new ParsCit::Citation();
	$citation->setString($citeString);
	push @citations, $citation;
    }
    return \@citations;

}  # splitUnmarkedCitations


##
# Merges lines of text by dehyphenating where appropriate,
# with normal spacing.
##
sub mergeLines {
    my ($text) = shift;
    my @lines = split "\n", $text;
    my $mergedText = "";
    foreach my $line (@lines) {
	$line = trim($line);

	### modified by Artemy Kolchinsky (v090625)
	# !!! merge without removing "-" if preceeded by numbers...
	if ($mergedText =~ m/[A-Za-z]\-$/) { 
	  # merge words when lines are hyphenated
	  $mergedText =~ s/\-$//; 
	  $mergedText .= $line;
	} else {
	  if ($mergedText !~ m/\-\s*$/) { $mergedText .= " " } #!!!
	  $mergedText .= $line;
	}
	### end modified by Artemy Kolchinsky (v090625)

    }
    return trim($mergedText);

}  # mergeLines


##
# Uses a list of regular expressions that match common citation
# markers to count the number of matches for each type in the
# text.  If a sufficient number of matches to a particular type
# are found, we can be reasonably sure of the type.
##
sub guessMarkerType {
    my ($rCiteText) = @_;
    my $markerType = 'UNKNOWN';
    my %markerObservations;
    foreach my $type (keys %markerTypes) {
	$markerObservations{$type} = 0;
    }

    my $citeText = "\n".$$rCiteText;
    $_ = $citeText;
    my $nLines = s/\n/\n/gs - 1;

    while ($citeText =~ m/\n\s*($markerTypes{'SQUARE'}([^\n]){10})/sg) {
	$markerObservations{'SQUARE'}++;
    }

    while ($citeText =~ m/\n\s*($markerTypes{'PAREN'}([^\n]){10})/sg) {
	$markerObservations{'PAREN'}++;
    }

    while ($citeText =~ m/\n\s*($markerTypes{'NAKEDNUM'} [^\n]{10})/sg) { # modified by Artemy Kolchinsky (v090625): remove space after {10})
	$markerObservations{'NAKEDNUM'}++;
    }

    while ($citeText =~ m/\n\s*$markerTypes{'NAKEDNUMDOT'}([^\n]){10}/sg) {
	$markerObservations{'NAKEDNUMDOT'}++;
    }

    my @sortedObservations =
	sort {$markerObservations{$b} <=> $markerObservations{$a}}
    keys %markerObservations;

    my $minMarkers = $nLines / 6;
    if ($markerObservations{$sortedObservations[0]} >= $minMarkers) {
	$markerType = $sortedObservations[0];
    }
    return $markerType;

}  # guessMarkerType


sub trim {
    my $text = shift;
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    return $text;

}  # trim


1;
