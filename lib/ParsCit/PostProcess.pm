package ParsCit::PostProcess;
#
# Utilities for normalizing the output of CRF++ into standard
# representations.
#
# Isaac Councill, 07/20/07
#

use strict;
use utf8;
use CSXUtil::SafeText qw(cleanXML);

##
# Main normalization subroutine.  Reads in a CRF++ output file
# and normalizes each field of individual citations.  An intermediate
# XML representation is used to keep track of the tags discovered by
# the model.  Returns a reference to the raw XML (may not be encoded
# safely) and a reference to a list of hashes containing the normalized
# citation subfields, keyed by tag name.
##
sub readAndNormalize {
    my ($inFile) = @_;

    my $status = 1;
    my $msg = "";

    open(IN, "<:utf8", $inFile) or return (undef, undef, 0,
				    "couldn't open infile: $!");

    my $currentTag;
    my @currentTokens = ();

    my $newCitation = 1;

    my $xml = "";

    while(<IN>) {
	if (m/^\s*$/) { # blank line separates citations
	    if ($newCitation <= 0) {
		finishCitation(\$xml, \$currentTag, \@currentTokens);
		@currentTokens = ();
		$newCitation = 1;
		next;
	    }
	}
	if ($newCitation > 0) {
	    $xml .= "<citation>\n";
	    $newCitation = 0;
	}
	my @fields = split /\s+/;
	my $token = $fields[0];
	my $tag = $fields[$#fields];
	if (!defined $currentTag) {
	    $currentTag = $tag;
	}
	if ($tag eq $currentTag) {
	    push @currentTokens, $token;
	} else {
	    $xml .= makeSegment($currentTag, @currentTokens);
	    $currentTag = $tag;
	    @currentTokens = ();
	    push @currentTokens, $token;
	}
    }

    close IN;

    if ($newCitation <= 0) {
	finishCitation(\$xml, \$currentTag, \@currentTokens);
	@currentTokens = ();
	$newCitation = 1;
    }

    my $rCiteInfo = normalizeFields(\$xml);

    return \$xml, $rCiteInfo, $status, $msg;

}  # readAndNormalize

##
# Utility for adding a closing tag to a citation in the
# intermediate XML, and setting the currentTag value to undef.
##
sub finishCitation {
    my ($r_xml, $r_currentTag, $r_currentTokens) = @_;
    if (defined $$r_currentTag) {
	$$r_xml .= makeSegment($$r_currentTag, @$r_currentTokens);
    }
    $$r_xml .= "</citation>\n";
    $$r_currentTag = undef;

}  # finishCitation


##
# Makes an XML segment based on the specifed tag and token list.
##
sub makeSegment {
    my ($tag, @tokens) = @_;
    my $segment = join " ", @tokens;
    return "<$tag>$segment</$tag>\n";
}


##
# Switching utility for reading through the intermediate XMl
# and passing control to an appropriate normalization routine
# for each field encountered.  Returns a reference to a list
# of hashes containing normalized fields, keyed by tag name.
##
sub normalizeFields {
    my ($rXML) = @_;
    my @citeInfos = ();

    $_ = $$rXML;
    my @citeBlocks = m/<citation>(.*?)<\/citation>/gs;
    foreach my $block (@citeBlocks) {
	my %citeInfo;
#	print STDERR "$block\n";
	while($block =~ m/<(.*?)>(.*?)<\/\1>/gs) {
	    my ($tag, $content) = ($1, $2);
	    if ($tag eq "author") {
		$tag = "authors";
		$content = normalizeAuthorNames($content);
	    } elsif ($tag eq "date") {
		$content = normalizeDate($content);
	    } elsif ($tag eq "volume") {
		$content = normalizeNumber($content);
	    } elsif ($tag eq "number") {
		$content = normalizeNumber($content);
	    } elsif ($tag eq "pages") {
		$content = normalizePages($content);
	    } else {
		$content = stripPunctuation($content);
	    }
	    # Heuristic - only get first instance of tag.
	    # TODO: we can do better than that...
	    unless (defined $citeInfo{$tag}) {
		$citeInfo{$tag} = $content;
	    }
	}
	push @citeInfos, \%citeInfo;
    }
    return \@citeInfos;

}  # normalizeFields


sub stripPunctuation {
    my $text = shift;

    # Thang v100401c: not remove open (\p{Ps}) and close (\p{Pe}) brackets
    my $stop = 0;
    while(!$stop){
      $text =~ s/^[^\p{IsLower}\p{IsUpper}0-9\p{Ps}]+//; 
      $text =~ s/[^\p{IsLower}\p{IsUpper}0-9\p{Pe}]+$//;

      # sanity check
      $stop = 1;
      if($text =~ /\p{Pe}$/){ # check ending brackets
	if($text !~ /\p{Ps}[^\p{Ps}\p{Pe}]+\p{Pe}$/){ # not a proper bracket pair
	  $text =~ s/\p{Pe}+$//; #strip ending brackets
	  $stop = 0; # continue stripping
	}
      }

      if($text =~ /^\p{Ps}/){ # check starting brackets
	if($text !~ /^\p{Ps}[^\p{Ps}\p{Pe}]+\p{Pe}/){ # not a proper bracket pair
	  $text =~ s/^\p{Ps}+//; #strip starting brackets
	  $stop = 0; # continue stripping
	}
      }
    }
    return $text;
}


##
# Tries to split the author tokens into individual author names
# and then normalizes these names individually.  Returns a
# list of author names.
##
sub normalizeAuthorNames {
    my ($authorText) = @_;

    my @tokens = repairAndTokenizeAuthorText($authorText);

    my @authors = ();
    my @currentAuth = ();
    my $beginAuth = 1;

    foreach my $tok (@tokens) {
	if ($tok =~ m/^(&|and)$/i) {
	    if ($#currentAuth >= 0) {
		my $auth = normalizeAuthorName(@currentAuth);
		push @authors, $auth;
	    }
	    @currentAuth = ();
	    $beginAuth = 1;
	    next;
	}
	if ($beginAuth > 0) {
	    push @currentAuth, $tok;
	    $beginAuth = 0;
	    next;
	}
	if ($tok =~ m/,$/) {
	    push @currentAuth, $tok;
	    if ($#currentAuth>0) {
		my $auth = normalizeAuthorName(@currentAuth);
		push @authors, $auth;
		@currentAuth = ();
		$beginAuth = 1;
	    }
	} else {
	    push @currentAuth, $tok;
	}
    }
    if ($#currentAuth >= 0) {
	my $auth = normalizeAuthorName(@currentAuth);
	push @authors, $auth;
    }
    return \@authors;

}  # normalizeAuthorNames


##
# Strips unexpected punctuation and removes tokens that
# are obviously not name words from the token list.
##
sub repairAndTokenizeAuthorText {
    my ($authorText) = @_;

    # Repair obvious parse errors and weird notations.
    $authorText =~ s/et\.? al\.?.*$//;
    $authorText =~ s/^.*?[\p{IsUpper}\p{IsLower}][\p{IsUpper}\p{IsLower}]+\. //;
    $authorText =~ s/\(.*?\)//g;
    $authorText =~ s/^.*?\)\.?//g;
    $authorText =~ s/\(.*?$//g;

    $authorText =~ s/\[.*?\]//g;
    $authorText =~ s/^.*?\]\.?//g;
    $authorText =~ s/\[.*?$//g;

    $authorText =~ s/;/,/g;
    $authorText =~ s/,/, /g;
    $authorText =~ s/\:/ /g;
    $authorText =~ s/[\:\"\<\>\/\?\{\}\[\]\+\=\(\)\*\^\%\$\#\@\!\~\_]//g;
    $authorText = joinMultiWordNames($authorText);

    my @origTokens = split '\s+', $authorText;
    my @tokens = ();

    for (my $i=0; $i<=$#origTokens; $i++) {
	my $tok = $origTokens[$i];
	if ($tok !~ m/[\p{IsUpper}\p{IsLower}&]/) {
	    if ($i < $#origTokens/2) {
		# Probably got junk up to now.
		@tokens = ();
		next;
	    } else {
		last;
	    }
	}
	if ($tok =~ m/^(jr|sr|ph\.?d|m\.?d|esq)\.?\,?$/i) {
	    if ($tokens[$#tokens] =~ m/\,$/) {
		next;
	    }
	}
	if ($tok =~ m/^[IVX][IVX]+\.?\,?$/) {
	    next;
	}
	push @tokens, $tok;
    }
    return @tokens;

}  #repairAndTokenizeAuthorText


##
# Tries to normalize an individual author name into the form
# "First Middle Last", without punctuation.
##
sub normalizeAuthorName {
    my @authTokens = @_;
    if ($#authTokens < 0) {
	return "";
    }

#    for (my $i=0; $i<=$#authTokens; $i++) {
#	my $tok = $authTokens[$i];
#	$tok = lc($tok);
#	$tok = ucfirst($tok);
#	$authTokens[$i] = $tok;
#    }

    my $tmpStr = join " ", @authTokens;
    if ($tmpStr =~ m/(.+),\s*(.+)/) {
	$tmpStr = "$2 $1";
    }

    $tmpStr =~ s/\.\-/-/g;
   $tmpStr =~ s/[\,\.]/ /g;
    $tmpStr =~ s/  +/ /g;
    $tmpStr = trim($tmpStr);

    if ($tmpStr =~ m/^[^\s][^\s]+(\s+[^\s]|\s+[^\s]\-[^\s])+$/) {
	my @newTokens = split '\s+', $tmpStr;
	my @newOrder = @newTokens[1..$#newTokens];
	push @newOrder, $newTokens[0];
	$tmpStr = join " ", @newOrder;
    }

    return $tmpStr;

}  # normalizeAuthorName


##
# Utility for creating an intermediate representation of multi-word
# name components, e.g., transforms "van der Wald" to "van_dir_Wald".
# this helps keep things straight during normalization.  The
# underscores can be stripped out later.
##
sub joinMultiWordNames {
    my $authorText = shift;
    $authorText =~ s/\b((?:van|von|der|den|de|di|le|el))\s/$1_/sgi; # Thang 02 Mar 10: change \1 into \$1
    return $authorText;

} # joinMultiWordNames


##
# Normalizes a date field into just the year.  Looks for a string of
# four digits.
##
sub normalizeDate {
    my $dateText = shift;
    if ($dateText =~ m/(\d{4})/) {
	my $year = $1;
	# check to see whether this is a sane year setting
	my @timeData = localtime(time);
	my $currentYear = $timeData[5]+1900;
	if ($year <= $currentYear+3) {
	    return $1;
	}
    }

}  # normalizeDate


##
# If a field should be numeric only, this utility is used
# to extract the first number string only.
##
sub normalizeNumber {
    my $numText = shift;
    if ($numText =~ m/(\d+)/) {
	return $1;
    } else {
	return $numText;
    }

}  # normalizeNumber


##
# Normalizes page fields into the form "start--end".  If the page
# field does not appear to be in a standard form, does nothing.
##
sub normalizePages {
    my $pageText = shift;
    if ($pageText =~ m/(\d+)[^\d]+?(\d+)/) {
	return "$1--$2";
    } elsif ($pageText =~ m/(\d+)/) {
	return $1;
    } else {
	return $pageText;
    }

}  # normalizePages


sub trim {
    my $str = shift;
    $str =~ s/^\s+//;
    $str =~ s/\s+$//;
    return $str;
}


1;
