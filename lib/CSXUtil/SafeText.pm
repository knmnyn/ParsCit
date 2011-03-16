package CSXUtil::SafeText;

#######################################################
##  Methods for stripping bad (XML unsafe) characters
##  from strings and performing basic HTML entity
##  translations.  Also contains a utility (stripArtifacts)
##  for getting rid of crazy control characters and
##  other things that probably aren't proper text.
##
##  Isaac Councill, 12/06/06
##
#######################################################

use utf8;
use strict;
require Exporter;

our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

$VERSION	= 1.00;
@ISA		= qw(Exporter);
@EXPORT_OK	= qw(@badChars %htmlSpecialChars %htmlCharEntities &stripBadChars &encodeHTMLSpecialChars &decodeHTMLSpecialChars &cleanXML &cleanAll &stripArtifacts);

##
#######################################################
##
##  Sharable encoding data.
##
##  Hex codes for characters that should never be put into
##  XML - or else parsers will barf.
#######################################################
our @badChars = qw(	\x00 \x01 \x02 \x03 \x04 \x05 \x06 \x07
                  	\x08 \x0B \x0C \x0E \x0F \x10 \x11 \x12
                  	\x13 \x14 \x15 \x16 \x17 \x18 \x19 \x1A
                  	\x1B \x1C \x1D \x1E \x1F \x7F	);

###
##  Subset of HTML characters that could be problematic
##  for XML.  This is not a complete list of HTML
##  special characters, but more mappings can be added
##  as needed.
###
our %htmlSpecialCharEncodings = (	"&"  => "&amp;",
                                	">"  => "&gt;",
                                	"<"  => "&lt;",
                                	"\"" => "&quot;",
				 					"\'" => "&apos;" # Added by Thang (v090625)
								);

##  The reverse map.
our %htmlSpecialCharDecodings;

foreach my $key (keys %htmlSpecialCharEncodings) 
{
	my $val = $htmlSpecialCharEncodings{$key};
   	$htmlSpecialCharDecodings{$val} = $key;
}


##
#######################################################
##
##  Subroutines
##

##  Delete all occurences of bad characters in text,
##  returns a new string that is clean.
sub stripBadChars 
{
	my $rtext = shift;
	foreach my $char (@badChars) { $$rtext =~ s/$char//g; }
}


##  Encodes special characters into HTML equivalents
##  and returns the encoded string.
sub encodeHTMLSpecialChars 
{
	my $rtext = shift;
   	foreach my $char (keys %htmlSpecialCharEncodings) 
	{
		my $code = $htmlSpecialCharEncodings{$char};
       	$$rtext =~ s/$char/$code/g;
	}
}


##  Decodes a HTML entities in the supplied string
##  into non-HTML character equivalents and returns
##  the decoded string.
sub decodeHTMLSpecialChars 
{
	my $rtext = shift;
	foreach my $code (keys %htmlSpecialCharDecodings) 
	{
		my $char = $htmlSpecialCharDecodings{$code};
       	$$rtext =~ s/$code/$char/g;
   	}
}


##  Strip out any characters that don't look like they
##  belong in a proper, readable text string.
sub stripArtifacts 
{
   	my $rtext = shift;
	$$rtext =~ s/[^\p{IsAlnum}\p{IsPunct}\p{IsSpace}\p{IsS}]//g;
}


##  Convenience routine for executing both XML safety
##  routines in a single call.
sub cleanXML 
{
   	my $rtext = shift;
   	stripBadChars($rtext);
   	encodeHTMLSpecialChars($rtext);
}


##  Clean for XML and also strip out strange characters.
sub cleanAll 
{
   	my $rtext = shift;
   	stripBadChars($rtext);
   	stripArtifacts($rtext);
   	encodeHTMLSpecialChars($rtext);
}

1;
