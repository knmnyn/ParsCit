package ParsCit::PostProcess;

###
# Utilities for normalizing the output of CRF++ into standard
# representations.
#
# Isaac Councill, 07/20/07
###

use utf8;
use strict;
use CSXUtil::SafeText qw(cleanXML);

###
# Main normalization subroutine.  Reads in a CRF++ output file and 
# normalizes each field of individual citations.  An intermediate
# XML representation is used to keep track of the tags discovered by
# the model.  Returns a reference to the raw XML (may not be encoded
# safely) and a reference to a list of hashes containing the normalized
# citation subfields, keyed by tag name.
###
sub ReadAndNormalize 
{
    my ($infile) = @_;

    my $status	= 1;
    my $msg		= "";
    my $xml		= "";

    open(IN, "<:utf8", $infile) or return (undef, undef, 0, "couldn't open infile: $!");

    my $current_tag		= undef;
    my @current_tokens	= ();
    my $new_citation	= 1;

    while(<IN>) 
	{
		# Blank line separates citations
		if (m/^\s*$/) 
		{
	    	if ($new_citation <= 0) 
			{
				FinishCitation(\$xml, \$current_tag, \@current_tokens);
				@current_tokens	= ();
				$new_citation	= 1;
				next;
	    	}
		}

		if ($new_citation > 0) 
		{
	    	$xml .= "<citation>\n";
	    	$new_citation = 0;
		}
		
		my @fields	= split /\s+/;
		my $token	= $fields[0];
		my $tag		= $fields[ $#fields ];
	
		if (!defined $current_tag) { $current_tag = $tag; }

		if ($tag eq $current_tag) 
		{
	    	push @current_tokens, $token;
		} 
		else 
		{
	    	$xml .= MakeSegment($current_tag, @current_tokens);
	    	$current_tag	= $tag;
	    	@current_tokens	= ();
	    
			push @current_tokens, $token;
		}
    }

    close IN;

    if ($new_citation <= 0) 
	{
		FinishCitation(\$xml, \$current_tag, \@current_tokens);
		@current_tokens = ();
		$new_citation = 1;
    }

    my $rcite_info = NormalizeFields(\$xml);

    return \$xml, $rcite_info, $status, $msg;
}

###
# Utility for adding a closing tag to a citation in the
# intermediate XML, and setting the currentTag value to undef.
###
sub FinishCitation 
{
    my ($r_xml, $r_current_tag, $r_current_tokens) = @_;

	if (defined $$r_current_tag) { $$r_xml .= MakeSegment($$r_current_tag, @$r_current_tokens); }
    $$r_xml .= "</citation>\n";
    $$r_current_tag = undef;
}

###
# Makes an XML segment based on the specifed tag and token list.
###
sub MakeSegment 
{
    my ($tag, @tokens) = @_;
    my $segment = join " ", @tokens;
	return "<$tag>$segment</$tag>\n";
}

###
# Switching utility for reading through the intermediate XMl
# and passing control to an appropriate normalization routine
# for each field encountered.  Returns a reference to a list
# of hashes containing normalized fields, keyed by tag name.
###
sub NormalizeFields 
{
    my ($rxml) = @_;

    my @cite_infos = ();

    $_ = $$rxml;

    my @cite_blocks = m/<citation>(.*?)<\/citation>/gs;

	foreach my $block (@cite_blocks) 
	{
		my %cite_info = ();

		while ($block =~ m/<(.*?)>(.*?)<\/\1>/gs) 
		{
	    	my ($tag, $content) = ($1, $2);

			if ($tag eq "author") 
			{
				$tag	 = "authors";
				# Content is a reference to a list of author
				$content = NormalizeAuthorNames($content);
	    	} 
			elsif ($tag eq "date") 
			{
				$content = NormalizeDate($content);
	    	} 
			###
			# Huydhn: Volume fix, e.g now we have main-volume and sub-volume
			####
			elsif ($tag eq "volume") 
			{
				$content = NormalizeVolume($content);
	    	} 
			elsif ($tag eq "number") 
			{
				$content = NormalizeNumber($content);
	    	} 
			elsif ($tag eq "pages") 
			{
				$content = NormalizePages($content);
	    	} 
			else 
			{
				$content = StripPunctuation($content);
	    	}
	    
			# Heuristic - only get first instance of tag.
	    	# TODO: we can do better than that...
	    	unless (defined $cite_info{ $tag }) { $cite_info{ $tag } = $content; }
		}
	
		push @cite_infos, \%cite_info;
    }

    return \@cite_infos;
}

sub StripPunctuation 
{
    my $text = shift;

    # Thang v100401c: not remove open (\p{Ps}) and close (\p{Pe}) brackets
    my $stop = 0;
    while (!$stop)
	{
		# Remove punctuation at the begining of the text
		$text =~ s/^[^\p{IsLower}\p{IsUpper}0-9\p{Ps}]+//; 

		###
		# Huydhn: do not need to remove the last punctuation
		# e.g. title = smth &amp;
		###
		# Remove punctuation at the end of the text
		# $text =~ s/[^\p{IsLower}\p{IsUpper}0-9\p{Pe}]+$//;

      	# Sanity check
      	$stop = 1;
		# Check ending brackets
      	if ($text =~ /\p{Pe}$/)
		{
			# Not a proper bracket pair
			if($text !~ /\p{Ps}[^\p{Ps}\p{Pe}]+\p{Pe}$/)
			{
	  			$text =~ s/\p{Pe}+$//;	# Strip ending brackets
	  			$stop = 0; 				# Continue stripping
			}
      	}
	
		# Check starting brackets
      	if ($text =~ /^\p{Ps}/)
		{
			# Not a proper bracket pair
			if ($text !~ /^\p{Ps}[^\p{Ps}\p{Pe}]+\p{Pe}/)
			{
	  			$text =~ s/^\p{Ps}+//;	# Strip starting brackets
	  			$stop = 0;				# Continue stripping
			}
      	}
    }
    return $text;
}

###
# Normalize volume number, tries to separate volume and sub volume
# e.g 5 (1)
###
sub NormalizeVolume
{
	my ($volume_number) = @_;

	# First number is main volume, the second one is sub-volume number
	my @volumes = ();

	###
	# Huydhn: special case fo volume tag: 5 (1)
	# separate into main volume and sub-volume tag
	###
	if ($volume_number =~ m/(\d+)\s*[\(\{\[]+(\d+)[\)\}\]]?/)
	{
		push @volumes, $1;
		push @volumes, $2;
	}
	elsif ($volume_number =~ m/(\d+)/) 
	{
		push @volumes, $1;
    } 
	else 
	{
		push @volumes, $volume_number;
    }

	return \@volumes;
}

###
# Tries to split the author tokens into individual author names
# and then normalizes these names individually.  Returns a
# list of author names.
###
sub NormalizeAuthorNames 
{
    my ($author_text) = @_;

    my @tokens = RepairAndTokenizeAuthorText($author_text);

    my @authors		 = ();
    my @current_auth = ();
    my $begin_auth	 = 1;

    foreach my $tok (@tokens) 
	{
		if ($tok =~ m/^(&|and)$/i) 
		{
	    	if ($#current_auth >= 0) 
			{
				my $auth = NormalizeAuthorName(@current_auth);
				push @authors, $auth;
	    	}
	    	@current_auth = ();
	    	$begin_auth = 1;
	    	next;
		}
	
		if ($begin_auth > 0) 
		{
	    	push @current_auth, $tok;
	    	$begin_auth = 0;
	    	next;
		}
	
		if ($tok =~ m/,$/) 
		{
	    	push @current_auth, $tok;
	    	if ($#current_auth>0) 
			{
				my $auth = NormalizeAuthorName(@current_auth);
				push @authors, $auth;
				@current_auth = ();
				$begin_auth = 1;
	    	}
		} 
		else 
		{
	    	push @current_auth, $tok;
		}
    }

    if ($#current_auth >= 0) 
	{
		my $auth = NormalizeAuthorName(@current_auth);
		push @authors, $auth;
    }

    return \@authors;
}

###
# Strips unexpected punctuation and removes tokens that
# are obviously not name words from the token list.
###
sub RepairAndTokenizeAuthorText 
{
    my ($author_text) = @_;

    # Repair obvious parse errors and weird notations.
    $author_text =~ s/et\.? al\.?.*$//;
    $author_text =~ s/^.*?[\p{IsUpper}\p{IsLower}][\p{IsUpper}\p{IsLower}]+\. //;
    $author_text =~ s/\(.*?\)//g;
    $author_text =~ s/^.*?\)\.?//g;
    $author_text =~ s/\(.*?$//g;

    $author_text =~ s/\[.*?\]//g;
    $author_text =~ s/^.*?\]\.?//g;
    $author_text =~ s/\[.*?$//g;

    $author_text =~ s/;/,/g;
    $author_text =~ s/,/, /g;
    $author_text =~ s/\:/ /g;
    $author_text =~ s/[\:\"\<\>\/\?\{\}\[\]\+\=\(\)\*\^\%\$\#\@\!\~\_]//g;
    $author_text = JoinMultiWordNames($author_text);

    my @orig_tokens	= split '\s+', $author_text;
    my @tokens		= ();

    for (my $i=0; $i <= $#orig_tokens; $i++) 
	{
		my $tok = $orig_tokens[$i];
		if ($tok !~ m/[\p{IsUpper}\p{IsLower}&]/) 
		{
	    	if ($i < $#orig_tokens/2) 
			{
				# Probably got junk up to now.
				@tokens = ();
				next;
	    	} 
			else 
			{
				last;
	    	}
		}
	
		if ($tok =~ m/^(jr|sr|ph\.?d|m\.?d|esq)\.?\,?$/i) 
		{
	    	if ($tokens[$#tokens] =~ m/\,$/) 
			{
				next;
	    	}
		}
		
		if ($tok =~ m/^[IVX][IVX]+\.?\,?$/) 
		{
	    	next;
		}
		
		push @tokens, $tok;
    }
    
	return @tokens;
}

###
# Tries to normalize an individual author name into the form
# "First Middle Last", without punctuation.
###
sub NormalizeAuthorName 
{
    my @auth_tokens = @_;

    if ($#auth_tokens < 0) { return ""; }

#	for (my $i=0; $i<=$#auth_tokens; $i++) 
#	{
#		my $tok = $auth_tokens[$i];
#		$tok = lc($tok);
#		$tok = ucfirst($tok);
#		$auth_tokens[$i] = $tok;
#	}

    my $tmp_str = join " ", @auth_tokens;
    
	if ($tmp_str =~ m/(.+),\s*(.+)/) 
	{
		$tmp_str = "$2 $1";
    }

    $tmp_str =~ s/\.\-/-/g;
	$tmp_str =~ s/[\,\.]/ /g;
    $tmp_str =~ s/  +/ /g;
    $tmp_str = Trim($tmp_str);

    if ($tmp_str =~ m/^[^\s][^\s]+(\s+[^\s]|\s+[^\s]\-[^\s])+$/) 
	{
		my @new_tokens	= split '\s+', $tmp_str;
		my @new_order	= @new_tokens[1..$#new_tokens];
		
		push @new_order, $new_tokens[0];
		$tmp_str = join " ", @new_order;
    }

    return $tmp_str;
}

sub NormalizeAuthorName2
{
    my @auth_tokens = @_;

    if ($#auth_tokens < 0) { return ""; }

    my $tmp_str = join " ", @auth_tokens;
    
    $tmp_str =~ s/\.\-/-/g;
	$tmp_str =~ s/[\,\.]/ /g;
    $tmp_str =~ s/  +/ /g;
    $tmp_str = Trim($tmp_str);

    return $tmp_str;
}

###
# Utility for creating an intermediate representation of multi-word
# name components, e.g., transforms "van der Wald" to "van_dir_Wald".
# this helps keep things straight during normalization.  The
# underscores can be stripped out later.
###
sub JoinMultiWordNames 
{
    my $author_text = shift;
    $author_text =~ s/\b((?:van|von|der|den|de|di|le|el))\s/$1_/sgi; # Thang 02 Mar 10: change \1 into \$1
    return $author_text;

}

###
# Normalizes a date field into just the year.  Looks for a string of
# four digits.
###
sub NormalizeDate 
{
    my $date_text = shift;

	if ($date_text =~ m/(\d{4})/) 
	{
		my $year = $1;

		# Check to see whether this is a sane year setting
		my @time_date		= localtime(time);
		my $current_year	= $time_date[5]+1900;

		if ($year <= $current_year+3) { return $1; }
    }
}

###
# If a field should be numeric only, this utility is used
# to extract the first number string only.
###
sub NormalizeNumber 
{
    my $num_text = shift;
    
	if ($num_text =~ m/(\d+)/) 
	{
		return $1;
    } 
	else 
	{
		return $num_text;
    }
}

###
# Normalizes page fields into the form "start--end".  If the page
# field does not appear to be in a standard form, does nothing.
###
sub NormalizePages 
{
    my $pageText = shift;

	if ($pageText =~ m/(\d+)[^\d]+?(\d+)/) 
	{
		return "$1--$2";
    } 
	elsif ($pageText =~ m/(\d+)/) 
	{
		return $1;
    } 
	else 
	{
		return $pageText;
    }
}

sub Trim 
{
    my $str = shift;
    $str =~ s/^\s+//;
    $str =~ s/\s+$//;
    return $str;
}

1;
