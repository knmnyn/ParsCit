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
# Returns references to the header text, normalized body text, and 
# original body text.
##
sub findHeaderText {
    my ($rText) = @_;
    my $text = $$rText;
    my $headerText = '0';
    my $bodyText = '0';

    if ($text =~ m/\b(Introductions?|INTRODUCTIONS?:?\s*\n+)/sg) {
      my $position = pos($text) - length($1);
      $headerText = substr $text, 0, $position;
      $bodyText = substr $text, $position unless ($position < 1);
    }
    
    if (length($headerText) >= 0.8*length($bodyText)) {
	print STDERR "Header text longer than article body: ignoring\n";
	$headerText = "";
	return \$headerText, \normalizeBodyText(\$bodyText), \$bodyText;
    }

    if ($headerText eq '0' || !defined $headerText) {
	print STDERR "warning: no header text found\n";
    }

    return (\$headerText,
	    \$bodyText);

}  # findHeaderText

##
# Looks for reference section markers in the supplied text and
# separates the citation text from the body text based on these
# indicators.  If it looks like there is a reference section marker
# too early in the document, this procedure will try to find later
# ones.  If the final reference section is still too long, an empty
# citation text string will be returned.  
# Returns references to the body text, citation text, and post-citation text.
##
sub findCitationText {
    my ($rText) = @_;
    my $text = $$rText;
    my $bodyText = '0';
    my $citeText = '0';
    my $remainText = "";

# Corrected by Cheong Chi Hong <chcheong@cse.cuhk.edu.hk> 2 Feb 2010
#    while ($text =~ m/\b(References?|REFERENCES?|Bibliography|BIBLIOGRAPHY|References?\s+and\s+Notes?|References?\s+Cited|REFERENCE?\s+CITED|REFERENCES?\s+AND\s+NOTES?):?\s*\n+/sg) {
    while ($text =~ m/\b(References?|REFERENCES?|Bibliography|BIBLIOGRAPHY|References?\s+and\s+Notes?|References?\s+Cited|REFERENCES?\s+CITED|REFERENCES?\s+AND\s+NOTES?):?\s*\n+/sg) {
	$bodyText = substr $text, 0, pos $text;
	$citeText = substr $text, pos $text unless (pos $text < 1);
    }
    if (length($citeText) >= 0.8*length($bodyText)) {
      print STDERR "Citation text longer than article body: ignoring\n";
      $citeText = "";
      return \$citeText, \normalizeBodyText(\$bodyText), \$bodyText;
    }
    
#    my $text = $citeText;
#    if($text =~ m/\b(Acknowledge?ments?|Autobiographical|Tables?|Appendix|Exhibit|Annex|Fig|Notes?):?\s*\n+/sg) { #
#      my $position = pos($text) - length($1);
#      $citeText = substr $text, 0, $position;
#      $remainText = substr $text, $position unless ($position < 1);
#    }

    if ($citeText eq '0' || !defined $citeText) {
	print STDERR "warning: no citation text found\n";
    }

    return (\$bodyText,
	    \$citeText);
#	    \$remainText);

}  # findCitationText

1;
