package ParsCit::PreProcess;

###
# Utilities for finding and normalizing citations within
# text files, including separating citation text from
# body text and segmenting citations.
#
# Isaac Councill, 7/19/07
###

use utf8;
use strict;

use Omni::Config;
use ParsCit::Citation;

my %marker_types =	(	'SQUARE'		=> '\\[.+?\\]',
		   				'PAREN'			=> '\\(.+?\\)',
		   				'NAKEDNUM'		=> '\\d+',
			   			'NAKEDNUMDOT'	=> '\\d+\\.',
						#'NAKEDNUM' 	=> '\\d{1,3}',		# Modified by Artemy Kolchinsky (v090625)
						#'NAKEDNUMDOT'	=> '\\d{1,3}\\.'	# Modified by Artemy Kolchinsky (v090625)
					);

# Omnilib configuration: object name
my $obj_list = $Omni::Config::obj_list;

###
# Huydhn: similar to findCitationText, find the citation portion using regular expression.
# However the input is an omnipage xml document object, not the raw text
###
sub FindCitationTextXML
{
	my ($doc) = @_;

	# Positions or addresses of all lines in the reference
	my @cit_addrs	= ();

	# Start and end of a reference
	my $start_found	= 0;
	my %start_ref	= ();
	my $end_found	= 0;
	my %end_ref		= ();

	# All pages in the document
	my $pages		= $doc->get_objs_ref();	
	# Foreach line in the document, check if it is the beginning of a reference using regular expression
	for (my $x = scalar(@{ $pages }) - 1; $x >= 0; $x--)
	{
		# All columns in one page
		my $columns	= $pages->[ $x ]->get_objs_ref();

		for (my $y = scalar(@{ $columns }) - 1; $y >= 0; $y--)
		{
			# All paragraphs in one column
			my $paras = $columns->[ $y ]->get_objs_ref();

			for (my $z = scalar(@{ $paras }) - 1; $z >= 0; $z--)
			{
				# All lines in one paragraph
				my $lines = $paras->[ $z ]->get_objs_ref();

				for (my $t = scalar(@{ $lines }) - 1; $t >= 0; $t--)
				{
					my $ln_content = $lines->[ $t ]->get_content();

					# Is it the beginning of a reference
    				if ($ln_content =~ m/\b(References?|REFERENCES?|Bibliography|BIBLIOGRAPHY|References?\s+and\s+Notes?|References?\s+Cited|REFERENCES?\s+CITED|REFERENCES?\s+AND\s+NOTES?|LITERATURE?\s+CITED?):?\s*$/)
					{
						if (($t + 1) < scalar(@{ $lines }))
						{
							$start_ref{ 'L4' }	= $t + 1;
							$start_ref{ 'L3' }	= $z;
							$start_ref{ 'L2' }	= $y;
							$start_ref{ 'L1' }	= $x;
						}
						elsif (($z + 1) < scalar(@{ $paras }))
						{
							$start_ref{ 'L4' }	= 0;
							$start_ref{ 'L3' }	= $z + 1;	
							$start_ref{ 'L2' }	= $y;
							$start_ref{ 'L1' }	= $x;
						}
						elsif (($y + 1) < scalar(@{ $columns }))
						{
							$start_ref{ 'L4' }	= 0;
							$start_ref{ 'L3' }	= 0;	
							$start_ref{ 'L2' }	= $y + 1;
							$start_ref{ 'L1' }	= $x;
						}
						elsif (($x + 1) < scalar(@{ $pages }))
						{
							$start_ref{ 'L4' }	= 0;
							$start_ref{ 'L3' }	= 0;	
							$start_ref{ 'L2' }	= 0;
							$start_ref{ 'L1' }	= $x + 1;
						}
						else
						{
							# What the heck, the beginning is at the end of the document.
						}						

						$start_found = 1;
						last;
					}
				}

				if ($start_found == 1) { last; }
			}
			
			if ($start_found == 1) { last; }
		}

		if ($start_found == 1) { last; }
	}

	# Reference length
	my $reference_length = 0;
	# Citation
	my $reference_text	 = "";

	# Reference not found
	if (! exists $start_ref{ 'L1' }) { return (\%start_ref, \%end_ref, \$reference_text); }

	# Foreach line in the document after the start of the reference, check if it is the end of a reference using regular expression
	for (my $x = $start_ref{ 'L1' }; $x < scalar(@{ $pages }); $x++)
	{
		# All columns in one page
		my $columns	= $pages->[ $x ]->get_objs_ref();
	
		my $start_column = ($x == $start_ref{ 'L1' }) ? $start_ref{ 'L2' } : 0;

		for (my $y = $start_column; $y < scalar(@{ $columns }); $y++)
		{
			# All paragraphs in one column
			my $paras = $columns->[ $y ]->get_objs_ref();

			my $start_para = (($x == $start_ref{ 'L1' }) && ($y == $start_ref{ 'L2' })) ? $start_ref{ 'L3' } : 0;

			for (my $z = $start_para; $z < scalar(@{ $paras }); $z++)
			{
				# All lines in one paragraph
				my $lines = $paras->[ $z ]->get_objs_ref();

				my $start_line = (($x == $start_ref{ 'L1' }) && ($y == $start_ref{ 'L2' }) && ($z == $start_ref{ 'L3' })) ? $start_ref{ 'L4' } : 0;

				for (my $t = $start_line; $t < scalar(@{ $lines }); $t++)
				{
					my $ln_content = $lines->[ $t ]->get_content();

					# Just a temporary variable
					my $tmp = undef;
					# Is it the end?					
					if ($ln_content =~ m/^([\s\d\.]+)?(Acknowledge?ments?|Autobiographical|Tables?|Appendix|Exhibit|Annex|Fig|Notes?)(.*?)$/)
					{
						# Then save its location
						if ($t == 0)
						{
							if ($z == 0)
							{
								if ($y == 0)
								{
									if ($x == 0)
									{
										# What the heck, the end is at the beginning of the document.
									}
									else
									{
										$end_ref{ 'L1' }	 = $x - 1;
									
										$tmp = $pages->[ $x - 1 ]->get_objs_ref();
										$end_ref{ 'L2' } 	= scalar(@{ $tmp }) - 1;
									
										$tmp = $tmp->[ -1 ]->get_objs_ref();
										$end_ref{ 'L3' }	 = scalar(@{ $tmp }) - 1;
									
										$tmp = $tmp->[ -1 ]->get_objs_ref();
										$end_ref{ 'L4' }	 = scalar(@{ $tmp }) - 1;	
									}
								}
								else
								{
									$end_ref{ 'L1' }	= $x;
									$end_ref{ 'L2' }	= $y - 1;
									
									$tmp = $columns->[ $y - 1 ]->get_objs_ref();
									$end_ref{ 'L3' }	= scalar(@{ $tmp }) - 1;
									
									$tmp = $tmp->[ -1 ]->get_objs_ref();
									$end_ref{ 'L4' }	= scalar(@{ $tmp }) - 1;
								}
							}
							else
							{
								$end_ref{ 'L1' }	= $x;
								$end_ref{ 'L2' } 	= $y;
								$end_ref{ 'L3' }	= $z - 1;
							
								$tmp = $paras->[ $z - 1 ]->get_objs_ref();
								$end_ref{ 'L4' }	= scalar(@{ $tmp }) - 1;
							}
						}
						else
						{
							$end_ref{ 'L1' }	= $x;
							$end_ref{ 'L2' }	= $y;
							$end_ref{ 'L3' }	= $z;
							$end_ref{ 'L4' }	= $t - 1;
						}

						$end_found = 1;
						last;
					}
					# This is is not the end of the reference, so, logically, it belongs to the reference
					else
					{
						push @cit_addrs, { 'L1' => $x, 'L2' => $y, 'L3' => $z, 'L4' => $t };
					}
					
					$reference_length += length($ln_content);
					$reference_text	  .= $ln_content . "\n";
				}

				if ($end_found == 1) { last; }
			}

			if ($end_found == 1) { last; }
		}

		if ($end_found == 1) { last; }
	}

	# End of the reference not found, asume that it's the end of the document
	if (! exists $end_ref{ 'L1' })
	{
		# Just a temporary variable
		my $tmp = undef;

		$end_ref{ 'L1' }	= scalar(@{ $pages }) - 1;

		$tmp = $pages->[ -1 ]->get_objs_ref();
		$end_ref{ 'L2' }	= scalar(@{ $tmp }) - 1;

		$tmp = $tmp->[ -1 ]->get_objs_ref();
		$end_ref{ 'L3' }	= scalar(@{ $tmp }) - 1;

		$tmp = $tmp->[ -1 ]->get_objs_ref();
		$end_ref{ 'L4' }	= scalar(@{ $tmp }) - 1;
	}

	# Odd case: when citation is longer than the content itself, what should we do?
    if (1.8 * $reference_length >= 0.8 * length($doc->get_content())) 
	{
		print STDERR "Citation text longer than article body: ignoring\n";

		%start_ref = (); %end_ref = (); $reference_text = "";
		return (\%start_ref, \%end_ref, \$reference_text);
    }

	# Now we have the citation text
	return (\%start_ref, \%end_ref, \$reference_text, \@cit_addrs);
}

###
# Looks for reference section markers in the supplied text and
# separates the citation text from the body text based on these
# indicators.  If it looks like there is a reference section marker
# too early in the document, this procedure will try to find later
# ones.  If the final reference section is still too long, an empty
# citation text string will be returned.  Returns references to
# the citation text, normalized body text, and original body text.
###
sub FindCitationText 
{
    my ($rtext, $pos_array) = @_;

	# Save the text
	my $text		= $$rtext;
    my $bodytext	= "";
    my $citetext	= "";

	###
	# Corrected by Cheong Chi Hong <chcheong@cse.cuhk.edu.hk> 2 Feb 2010
	# while ($text =~ m/\b(References?|REFERENCES?|Bibliography|BIBLIOGRAPHY|References?\s+and\s+Notes?|References?\s+Cited|REFERENCE?\s+CITED|REFERENCES?\s+AND\s+NOTES?):?\s*\n+/sg) 
	# {
	###
	###
	# Corrected by Huy Do, 15 Jan 2011
    # while ($text =~ m/\b(References?|REFERENCES?|Bibliography|BIBLIOGRAPHY|References?\s+and\s+Notes?|References?\s+Cited|REFERENCES?\s+CITED|REFERENCES?\s+AND\s+NOTES?):?\s*\n+/sg)
	# {
	###
    while ($text =~ m/\b(References?|REFERENCES?|Bibliography|BIBLIOGRAPHY|References?\s+and\s+Notes?|References?\s+Cited|REFERENCES?\s+CITED|REFERENCES?\s+AND\s+NOTES?|LITERATURE?\s+CITED?):?\s*\n+/sg) 
	{
		$bodytext = substr $text, 0, pos $text;
		$citetext = substr $text, pos $text unless (pos $text < 1);
    }

	# No citation
	if ($citetext eq "")
	{
		print STDERR "Citation text cannot be found: ignoring", "\n";
		return \$citetext, NormalizeBodyText(\$bodytext, $pos_array), \$bodytext;
	}

	# Odd case: when citation is longer than the content itself, what should we do?
    if (length($citetext) >= 0.8 * length($bodytext)) 
	{
		print STDERR "Citation text longer than article body: ignoring\n";
		return \$citetext, NormalizeBodyText(\$bodytext, $pos_array), \$bodytext;
    }

	# Citation stops when another section starts
    my ($scitetext, $tmp) = split(/^([\s\d\.]+)?(Acknowledge?ments?|Autobiographical|Tables?|Appendix|Exhibit|Annex|Fig|Notes?)(.*?)\n+/m, $citetext);

	if (length($scitetext) > 0) { $citetext = $scitetext; }

	# No citation exists
    if ($citetext eq '0' || ! defined $citetext) { print STDERR "warning: no citation text found\n"; }

	# Now we have the citation text
	return (NormalizeCiteText(\$citetext), NormalizeBodyText(\$bodytext, $pos_array), \$bodytext);
}

###
# Huydhn: find citation section in raw text
# This function is used exclusively when the citation
# section is provided by sectlabel
sub FindCitationText2 
{
    my ($rtext, $rcit_lines, $pos_array) = @_;

	# Citation and body text
    my $citetext	= "";
    my $bodytext	= "";

	# All line in the document
	my @lines		= split(/\n/, $$rtext);

	# Append all lines that belong to the citation
	foreach my $line_index (@{ $rcit_lines })
	{
		$citetext = $citetext . $lines[ $line_index ] . "\n";
	}

	# If a line is not in @cit_lines, it belongs to the body text
	for (my $i = 0; $i < $rcit_lines->[ 0 ]; $i++)
	{
		$bodytext = $bodytext . $lines[ $i ] . "\n";
    }

	# Odd case: when citation is longer than the content itself, what should we do?
    if (length($citetext) >= 0.8 * length($bodytext)) 
	{
		print STDERR "Citation text longer than article body: ignoring\n";
		return \$citetext, NormalizeBodyText(\$bodytext, $pos_array), \$bodytext;
    }

	# Now we have the citation text
	return (NormalizeCiteText(\$citetext), NormalizeBodyText(\$bodytext, $pos_array), \$bodytext);
}

##
# Removes lines that appear to be junk from the citation text.
##
sub NormalizeCiteText 
{
    my ($rcitetext) = @_;

    my @newlines	= ();
    my @lines		= split "\n", $$rcitetext;

	###
	# Modified by Artemy Kolchinsky (v090625)
	# In some cases, I had situations like:
	# Smith B, "Blah Blah." Journal1, 2000, p. 23-
	# 85
	# Here, the line consisting of '85' is part of the citation and shouldn't be dropped, 
	# even though it only consist of numeric characters.  The way I went about this is 
	# that I dropped those lines consisting of only spacing characters, *or* only numeric 
	# characters *if the previous line did not end on a hyphen*.
	###
    my $oldline = "";

	foreach my $line (@lines) 
	{
		$line =~ s/^\s*//g; # Dropped leading spaces added by Thang (v090625)
      	$line =~ s/\s*$//g; # Dropped trailing spaces added by Thang (v090625)
		
		if ($line =~ m/^\s*$/ || ($oldline !~ m/\-$/ && $line =~ m/^\d*$/)) 
		{
			$oldline = $line;
			next;
      	}

      	$oldline = $line;
      	push @newlines, $line;
    }
	###
	# End modified by Artemy Kolchinsky (v090625)
	###

    my $newtext = join "\n", @newlines;
    return \$newtext;
}

###
# Thang May 2010
# Address the problem Nick mentioned in method normalizeBodyText()
# This method handle multiple bracket references in a line, e.g "abc [1, 2-5, 11] def [1-3, 5] ghi jkl"
# + this method maps the position of tokens in normalized body text --> positions of tokens in body text (for later retrieve context positions)
###
sub ExpandBracketMarker 
{
	my ($line, $pos_array, $token_count) = @_;
  	#  $line = "abc [1, 2-5, 11] def [1-3, 5] ghi jkl";
  	#  $line = "abc[1, 2-5, 11]def[1-3, 5]ghi jkl";
  	#  $line = "abc def ghi jkl";

  	my $count		= 0;
  	my $front		= "";
  	my $match		= "";
  	my $remain		= $line;
  	my $newline		= "";
  	my $space_flag	= 0;

  	while($line =~ m/\[(\d+[,;] *)*((\d+)-(\d+))([,;] *\d+)*\]/g)
	{
    	$front	= $`;
    	$match	= $&;
    	$line	= $';
    
	    # Handle front part
    	if($space_flag == 1) { $newline .= " "; }
		$newline .= $front;

    	my @tokens	= split(/\s+/, $front);
    	my $length	= scalar(@tokens);
		
    	for(my $i=0; $i < $length; $i++)
		{
      		if($i < ($length -1) || $front =~ / $/) 
			{
				#print STDERR "$tokens[$i] --> ".$token_count."\n";
				push(@{ $pos_array }, $token_count++);
      		}
    	}
    
    	# Handle match part
    	my $num_new_tokens = 0;
    	if ($match =~ /^\[(\d+[,;] *)*((\d+)-(\d+))([,;] *\d+)*\]$/)
		{
      		$num_new_tokens = $4 - $3;
			if ($num_new_tokens > 0)
			{
				$match = "[" . $1 . TransformMarker($3, $4) . $5 . "]";
      		} 
			else 
			{
				$num_new_tokens = 0;
      		}
    	}
    	$newline .= $match;
    
		@tokens	= split(/\s+/, $match);
		$length	= scalar(@tokens);
		
		for(my $i=0; $i < $length; $i++)
		{
      		if($i < ($length -1) || $line =~ /^ /) 
			{
				#print STDERR "$tokens[$i] --> ".$token_count."\n";
				if ($i >= ($length - $num_new_tokens-1) && $i < ($length -1))
				{
	  				push(@{ $pos_array }, $token_count);
				} 
				else 
				{
	  				push(@{ $pos_array }, $token_count++);
				}
      		}
    	}
    
    	if ($line =~ /^ /)
		{
      		$space_flag	= 1;
      		$line		=~ s/^\s+//;
    	} 
		else 
		{
      		$space_flag = 0;
    	}
    	
		$count++;
  	}
  
  	if($space_flag == 1) { $newline .= " "; }
	$newline .= $line;

  	my @tokens	= split(/\s+/, $line);
  	my $length	= scalar(@tokens);

  	for(my $i=0; $i < $length; $i++)
	{
		#print STDERR "$tokens[$i] --> ".$token_count."\n";
		push(@{ $pos_array }, $token_count++);
  	}

	return ($newline, $token_count);
}

###
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
###
sub NormalizeBodyText 
{
	my ($rtext, $pos_array) = @_;

  	my @lines		= split "\n", $$rtext;
  	my $text		= "";
  	my $token_count	= 0;
	
	foreach my $line (@lines) 
	{
    	$line =~ s/^\s+//; # Thang May 2010: trip leading spaces

    	my @tmp_pos_array		= ();
		($line, $token_count)	= ExpandBracketMarker($line, \@tmp_pos_array, $token_count); # Thang May 2010
		my @tokens				= split(/\s+/, $line);

		if(scalar(@tokens) != scalar(@tmp_pos_array))
		{
      		die "scalar(@tokens) != scalar(@tmp_pos_array)\n$line\n";
    	}
		#$line =~ s/\[(\d+[,;] *)*((\d+)-(\d+))([,;] *\d+)*\]/"[".$1.transformMarker($3,$4).$5."]"/e;
    
		if ($line =~ m/^\s*$/) { next; }
  
		###
    	# Modified by Artemy Kolchinsky (v090625)
    	# !!! merge without removing "-" if preceeded by numbers...
		###
    	if ($text =~ s/([A-Za-z])\-$/$1/) 
		{
      		$text .= $line;
      		shift(@tmp_pos_array); 
    	} 
		else 
		{
      		if ($text !~ m/\-\s+$/ && $text ne "") { $text .= " " } # Thang May 2010: change m/\-\s*$/ -> m/\-\s+$/
      		$text .= $line;
    	}

    	push(@{$pos_array}, @tmp_pos_array);
		###
    	# End modified by Artemy Kolchinsky (v090625)
		###
  	}

  	$text =~ s/\s{2,}/ /g;
	return \$text;  
}

# 
sub TransformMarker 
{
	my ($first_number, $second_number) = @_;

	my $new_marker = $first_number;	
	for (my $i = ($first_number + 1) ; $i <= $second_number ; $i++) { $new_marker .= ", " . $i; }
	return $new_marker;
}

###
# Controls the process by which citations are segmented, based 
# on the result of trying to guess the type of citation marker 
# used in the reference section.  Returns a reference to a list 
# of citation objects.
###
sub SegmentCitations 
{
    my ($rcite_text) = @_;

    my $marker_type = GuessMarkerType($rcite_text);

    my $rcitations = undef;
    if ($marker_type ne 'UNKNOWN') 
	{
		$rcitations = SplitCitationsByMarker($rcite_text, $marker_type);
    } 
	else 
	{
		$rcitations = SplitUnmarkedCitations($rcite_text);
    }

    return $rcitations;
}

###
# Segments citations that have explicit markers in the
# reference section.  Whenever a new line starts with an
# expression that matches what we'd expect of a marker,
# a new citation is started.  Returns a reference to a
# list of citation objects.
###
sub SplitCitationsByMarker 
{
    my ($rcite_text, $marker_type) = @_;

    my @citations 				= ();
    my $current_citation		= new ParsCit::Citation();
    my $current_citation_string	= undef;

    # TODO: Might want to add a check that marker number is
    # increasing as we'd expect, if the marker is numeric.

    foreach my $line (split "\n", $$rcite_text) 
	{
		if ($line =~ m/^\s*($marker_types{ $marker_type })\s*(.*)$/) 
		{
	    	my ($marker, $cite_string) = ($1, $2);
			
			if (defined $current_citation_string) 
			{
				$current_citation->setString($current_citation_string);
				push @citations, $current_citation;
				$current_citation_string = undef;
	    	}

	    	$current_citation			= new ParsCit::Citation();
			$current_citation->setMarkerType($marker_type);
	    	$current_citation->setMarker($marker);
			$current_citation_string	= $cite_string;
		} 
		else 
		{
			###
	  		# Modified by Artemy Kolchinsky (v090625)
	  		# !!! merge without removing "-" if preceeded by numbers...
			###
	  		if ((defined $current_citation_string) && ($current_citation_string =~ m/[A-Za-z]\-$/))
			{
		    	# Merge words when lines are hyphenated
	    		$current_citation_string	=~ s/\-$//; 
	    		$current_citation_string	.= $line;
	  		} 
			else 
			{
	    		if ((! defined $current_citation_string) || ($current_citation_string !~ m/\-\s*$/)) { $current_citation_string .= " "; } #!!!
	    		$current_citation_string .= $line;
			}
			###
	  		# End modified by Artemy Kolchinsky (v090625)
			###
		}
    }
    
	# Last citation
	if (defined $current_citation && defined $current_citation_string) 
	{
		$current_citation->setString($current_citation_string);
		push @citations, $current_citation;
    }

	# Now, we have an array of separated citations
    return \@citations;
}


###
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
###
sub SplitUnmarkedCitations 
{
    my ($rcite_text) = @_;

    my @content		= split "\n", $$rcite_text;
    
	my $cite_start	= 0;
    my @cite_starts	= ();
    my @citations	= ();

	###
	# Huydhn: when a line is an author line (the line at the start of 
	# a citation with a long list of author), the next line cannot be
	# the start of another (consequence) citation. This next line should
	# be the next part of the current citation after the author line.
	###
	my $last_author_line = undef;

	for (my $i = 0; $i <= $#content; $i++) 
	{
		if ($content[ $i ] =~ m/\b\(?[1-2][0-9]{3}[\p{IsLower}]?[\)?\s,\.]*(\s|\b)/s) 
		{
	    	for (my $k = $i; $k > $cite_start; $k--) 
			{
				if ($content[ $k ] =~ m/\s*[\p{IsUpper}]/g) 
				{
					###
					# Huydhn: The previous line is an author line, so this line
					# cannot be the start of another citation
					if ($last_author_line == $k - 1) { next; }

		    		# If length of previous line is extremely
		    		# small, then start a new citation here.
		    		if (length($content[ $k - 1 ]) < 2) 
					{
						$cite_start = $k;
						last;
		    		}

		    		# Start looking backwards for lines that could
		    		# be author lists - these usually start the
		    		# citation, have several separation characters (,;),
		    		# and shouldn't contain any numbers.
		    		my $beginning_author_line = -1;

		    		for (my $j = $k - 1; $j > $cite_start; $j--) 
					{
						if ($content[ $j ] =~ m/\d/) { last; }
			
						$_			= $content[ $j ];
						my $n_sep	= s/([,;])/$1/g;

						if ($n_sep >= 3) 
						{
			    			if (($content[ $j - 1 ] =~ m/\.\s*$/) || $j == 0) 
							{
								$beginning_author_line = $j;
							}
						} 
						else 
						{
			    			last;
						}
		    		}
		    
					if ($beginning_author_line >= 0) 
					{
						$cite_start			= $beginning_author_line;

						###
						# Huydhn: see $last_author_line
						###
						$last_author_line	= $beginning_author_line;

						last;
		    		}

		    		# Now that the backwards author search failed
		    		# to find any extra lines, start a new citation
		    		# here if the previous line ends with a ".".

					###
		    		# Modified by Artemy Kolchinsky (v090625)
					# A new citation is started if the previous line ended with 
					# a period, but not if it ended with a period, something else, 
					# and then a period.  This is to avoid assuming that abbrevations, 
					# like U.S.A. , indicate the end of a cite.  Also, a new cite is 
					# started only if the current line does not begin with a series of 
					# 4 digits.  This helped avoid some mis-parsed citations for me.  
					# The new if-statement read like:
					###		   
		    		if ($content[ $k - 1 ] =~ m/[^\.].\.\s*$/ && $content[ $k ] !~ m/^\d\d\d\d/) 
					{
		      			$cite_start = $k;
		      			last;
		    		}
				}
	    	}   
	   		# End of for 
			
			push @cite_starts, $cite_start unless (($cite_start <= $cite_starts[ $#cite_starts ]) && ($cite_start != 0));
		}
    }

    for (my $k = 0; $k <= $#cite_starts; $k++) 
	{
		my $first_line	= $cite_starts[ $k ];
		my $last_line	= ($k == $#cite_starts) ? $#content : ($cite_starts[ $k + 1 ] - 1);

		my $cite_string	= MergeLines(join "\n", @content[ $first_line .. $last_line ]);
		
		my $citation	= new ParsCit::Citation();
		$citation->setString($cite_string);
		push @citations, $citation;
    }

	# And then from nothing came everything
    return \@citations;
}

###
# Controls the process by which citations are segmented.
# Input includes XML information.
# Returns a reference to a list of citation objects.
#
# Added by Huydhn, 13 Jan 2011
###
sub SegmentCitationsXML
{
    my ($rcite_text_from_xml, $tmp_file) = @_;

	# TODO: Need to be removed
    my $marker_type = GuessMarkerType($rcite_text_from_xml);

    my $rcitations = undef;
    if ($marker_type ne 'UNKNOWN') 
	{
		# TODO: Need to be removed
		$rcitations = SplitCitationsByMarker($rcite_text_from_xml, $marker_type);
    } 
	else 	
	{
		# Huydhn: split reference using crf++ model
		$rcitations = SplitUnmarkedCitations2($tmp_file);
    }

    return $rcitations;
}

###
# Replace heuristics rules with crf++ model based on both textual
# and XML features from Omnipage.
#
# HISTORY: Added in 100111 by Huy Do
###
sub SplitUnmarkedCitations2
{
	my ($infile) = @_;	

	# Citation list
	my @citations = ();

	# Run the crf++
	my $outfile = $infile . "_split.dec";
    if (ParsCit::Tr2crfpp::SplitReference($infile, $outfile))
	{
		my $file_handle = undef;
		unless(open($file_handle, "<:utf8", $outfile))
		{
			fatal("Could not open file: $!");
			return;
    	}
    
		# Read all lines
		my @lines = ();
		while(<$file_handle>) 
		{
			chomp();
			push @lines, $_;
	    }
    	close $file_handle;
		
		my $cit_str = "";
    	for (my $i = 0; $i < scalar(@lines); $i++) 
		{
			# Get the class of the file: "parsCit_begin", "parsCit_continue", or "parsCit_end"
			my @tokens	= split(/\s+/, $lines[$i]);
			my $class	= $tokens[ $#tokens ];

			# Line content
			my $ln_con	= undef;
			$ln_con		= $tokens[ 0 ];
			# Replace the ||| sequence with \s
			$ln_con		=~ s/\|\|\|/ /g; 

			# Beginning of a citation
			if ($class eq "parsCit_begin")
			{
				# Save the previous citation
				if ($cit_str ne "") 
				{
					my $citation = new ParsCit::Citation();

					# Clean up the citation text first
					my $one_cit_str = MergeLines($cit_str);

					# Save the citation
					$citation->setString($one_cit_str);
					push @citations, $citation; 
				} 

				# Create new citation
				$cit_str = $ln_con;
			}
			# Inside a citation
			elsif ($class ne "parsCit_unknown")
			{
				$cit_str = $cit_str . "\n" . $ln_con;
			}
		}

		# Last citation
		if ($cit_str ne "")
		{
			my $citation = new ParsCit::Citation();

			# Clean up the citation text first
			my $one_cit_str = MergeLines($cit_str);

			# Save the citation
			$citation->setString($one_cit_str);
			push @citations, $citation; 			
		}
	}

	unlink($infile);
	unlink($outfile);

	# Our work here is done
	return \@citations;
}

###
# Merges lines of text by dehyphenating where appropriate,
# with normal spacing.
###
sub MergeLines 
{
    my ($text) = shift;

    my @lines		= split "\n", $text;
    my $merged_text	= "";

    foreach my $line (@lines) 
	{
		$line = Trim($line);

		###
		# Modified by Artemy Kolchinsky (v090625)
		# # !!! merge without removing "-" if preceeded by numbers...
		###
		if ($merged_text =~ m/[A-Za-z]\-$/) 
		{
	  		# Merge words when lines are hyphenated
	  		$merged_text	=~ s/\-$//; 
	  		$merged_text	.= $line;
		} 
		else 
		{
	  		if ($merged_text !~ m/\-\s*$/) { $merged_text .= " " } #!!!
	  		$merged_text .= $line;
		}
		###
		# End modified by Artemy Kolchinsky (v090625)
		###
    }

    return Trim($merged_text);
}

###
# Uses a list of regular expressions that match common citation
# markers to count the number of matches for each type in the
# text.  If a sufficient number of matches to a particular type
# are found, we can be reasonably sure of the type.
###
sub GuessMarkerType 
{
    my ($rcite_text) = @_;

    my $marker_type			= 'UNKNOWN';
    my %marker_observations	= ();

    foreach my $type (keys %marker_types) 
	{
		$marker_observations{$type} = 0;
    }

    my $cite_text	= "\n" . $$rcite_text;
    $_ 				= $cite_text;
    my $n_lines		= s/\n/\n/gs - 1;

    while ($cite_text =~ m/\n\s*($marker_types{'SQUARE'}([^\n]){10})/sg) 
	{
		$marker_observations{'SQUARE'}++;
    }

    while ($cite_text =~ m/\n\s*($marker_types{'PAREN'}([^\n]){10})/sg) 
	{
		$marker_observations{'PAREN'}++;
    }
	
	###
	# Modified by Artemy Kolchinsky (v090625): remove space after {10})
	###
    while ($cite_text =~ m/\n\s*($marker_types{'NAKEDNUM'} [^\n]{10})/sg) 
	{ 
		$marker_observations{'NAKEDNUM'}++;
    }

    while ($cite_text =~ m/\n\s*$marker_types{'NAKEDNUMDOT'}([^\n]){10}/sg) 
	{
		$marker_observations{'NAKEDNUMDOT'}++;
    }

    my @sorted_observations = sort { $marker_observations{ $b } <=> $marker_observations{ $a } } keys %marker_observations;

    my $min_markers = $n_lines / 6;
    if ($marker_observations{ $sorted_observations[0] } >= $min_markers) 
	{
		$marker_type = $sorted_observations[0];
    }

    return $marker_type;
}

sub Trim 
{
    my $text = shift;
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    return $text;
}

# Ankur : Handle Mac style CR LF encoding of input file
# Canocicalizes carriage return, line feed characters 
# at line ending
sub canolicalizeEOL {
    my ($infile) = @_;
    
	my $oneline = 0;
    if (! open(IN, "<:utf8", $infile)) { return (-1, "Could not open file " . $infile . ": " . $!); }
	
    open(IN, "<:utf8", $infile);
    my @lines;
    @lines = <IN>;
    close(IN); 
	
    foreach (@lines){
        $_ =~ s/\cM/\n/g;
    }
        
	# Create a new temp file
	my $new_file_name = $infile . "-conv-tmp";
        
	if (! open(OUT, ">:utf8", $new_file_name)) { return (-1, "Could not open file " . $new_file_name . ": " . $!); }
	print OUT @lines;
	close(OUT);
	
	# Delete the old file
	unlink( $infile );
	
	# Rename newly created file to the old file name
	my $cmd = "mv $new_file_name $infile";
	system($cmd);
}

1;
