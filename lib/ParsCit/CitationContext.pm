package ParsCit::CitationContext;

###
# Utility functions for finding citation contexts after citation
# parsing.  The idea is to build regular expressions that could match
# citation references in the body text and scan the body text for
# occurrences.  The size of the context returned can be configured
# in ParsCit::Config::context_radius.
#
# Isaac Councill, 7/20/07
###
use utf8;

use ParsCit::Config;

sub CountTokens 
{
	my ($text) = @_;

  	my $trim_text = $text;

  	$trim_text =~ s/^\s+//;       
	$trim_text =~ s/\s+$//;

	my @tokens = split(/\s+/, $trim_text);
  	return scalar(@tokens);
}

###
# Build a list of potential regular expressions based on the supplied
# citation marker and applies the expressions to the specified body text.
# Returns a reference to a list of strings that match the expressions,
# expanded to radius $context_radius.
###
sub GetCitationContext 
{
	my ($rbody_text, $pos_array, $marker) = @_;

	# Some global variables
	my $context_radius	= $ParsCit::Config::contextRadius;
	my $max_contexts	= $ParsCit::Config::maxContexts;

	my ($prioritize, @markers) = GuessPossibleMarkers($marker);
  
  	my @matches		= ();
	# Thang Nov 2009: store the in-text citation strings
  	my @cit_strs	= (); 	
	# Thang May 2010: store start word positions of citation markers
  	my @start_word_positions	= ();
	# Thang May 2010: store end word positions of citation markers
  	my @end_word_positions		= (); 

	###
  	# Modified by Nick Friedrich
	###
  	my @positions		= ();
  	my $position		= undef;  
	my $contexts_found	= 0;

  	foreach my $mark (@markers) 
	{
    	while (($contexts_found < $max_contexts) && $$rbody_text =~ m/(.{$context_radius}($mark).{$context_radius})/gs) 
		{
      		# Thang May 2010: check mark length
      		my $cit_str		= $2;
      		my $cit_length	= CountTokens($cit_str);
      
	  		if($cit_length == 0) { next; }

			push @positions, (pos $$rbody_text) - $context_radius;
      		push @matches, $1;

      		my $before_mark		= substr($$rbody_text, 0, (pos $$rbody_text) - $context_radius-length($cit_str));
      		my $before_length	= CountTokens($before_mark);

			if($before_mark =~ / $/ || $cit_str =~ /^ /)
			{
				push @start_word_positions, $before_length;
				push @end_word_positions, $before_length + $cit_length - 1;
			} 
			else 
			{ 
				push @start_word_positions, $before_length - 1;
				push @end_word_positions, $before_length - 1 + $cit_length - 1;
      		}

			# Thang Nov 2009
      		if($cit_str !~ /\(.+\)$/ && $cit_str =~ /\)$/)			
			{
				# Trim ending bracket
				$cit_str =~ s/\)$//; 
      		}
      		push @cit_strs, $cit_str;
      		# End Thang Nov 2009
      
      		$contexts_found++;
    	}

    	if (($prioritize > 0) && ($#matches >= 0)) { last; }
  	}
  	return ( \@matches, \@positions, \@start_word_positions, \@end_word_positions, \@cit_strs);
}

###
# Builds a list of regular expressions based on the supplied
# citation marker that may indicate a citation reference in
# body text.  The first value returned is a parameter indicating
# whether the list should be prioritized (i.e., if matches to
# one element are found, don't try to match subsquent expressions),
# with 0 indicating no prioritization and 1 indicating otherwise.
#
# HISTORY: Nick (v081201)
#
# In publications with unmarked citations the citations are not only
# referenced by markers like (Bottou, 1991). Often it is referenced like
# "Leon Bottou (1991) discussed two solutions". Getting Parscit to find
# both styles is easy. Actually ParsCit creates regular expressions like
# 'Bottou,? 1991' or 'Beel and Gipp,? 2008' . The regular expressions in
# CitationContext::guessPossibleMarkers (line 75, 78, 79 91 - 79, 82,
# 83, 95 in my modifies CitationContext.pm) need only to be modified to
# match parenthesis around the year (e.g. 'Bottou,? \(?1991\)?' ).
###
sub GuessPossibleMarkers 
{
    my $marker = shift;

    if ($marker =~ m/^([\[\(])([\p{IsUpper}\p{IsLower}\-\d]+)([\]\)])/) 
	{
		my $open	= MakeSafe($1);
		my $mark	= MakeSafe($2);
		my $close	= MakeSafe($3);

		my $ref_indicator = "$open([\\p{IsUpper}\\p{IsLower}\\-\\d]+[;,] *)*$mark([;,] *[\\p{IsUpper}\\p{IsLower}\\-\\d]+)*$close";
		return (0, $ref_indicator);
    }

    if ($marker =~ m/^(\d+)\.?/) 
	{
		my $square	= "\\[(\\d+[,;] *)*$1([;,] *\\d+)*\\]";
		my $paren	= "\\((\\d+[,;] *)*$1([,;] *\\d+)*\\)";

		return (1, $square, $paren);
    }

    if ($marker =~ m/^([\p{IsUpper}\p{IsLower}\-\.\']+(, )*)+\d{4}/) 
	{
		my @tokens	= split ", ", $marker;
		my $year	= $tokens[$#tokens];
		my @names	= @tokens[0..$#tokens-1];

		my @possible_markers = ();
	
		if ($#names == 0) 
		{
	    	push @possible_markers, $names[0].",? \\(?$year\\)?";
		}
	
		if ($#names == 1) 
		{
	    	push @possible_markers, $names[0]." and ".$names[1].",? \\(?$year\\)?";
	    	push @possible_markers, $names[0]." & ".$names[1].",? \\(?$year\\)?";
		}
		
		if ($#names > 1) 
		{
	    	map { $_ = MakeSafe($_) } $names;
	    	map { $_ = $_."," } @names;
	    	
			my $last_auth1 = "and ".$names[$#names];
	    	my $last_auth2 = "& ".$names[$#names];
	    
			push @possible_markers,
	      	join " ", @names[0..$#names-1], $last_auth1, $year;
	    	push @possible_markers,
	      	join " ", @names[0..$#names-1], $last_auth2, $year;

	    	push @possible_markers, $names[0]."? et al\\\.?,? \\(?$year\\)?";
		}

		for (my $i = 0; $i <= $#possible_markers; $i++) 
		{
	    	my $safe_marker	= $possible_markers[$i];
	    	$safe_marker	=~ s/\-/\\\-/g;
	    	$possible_markers[$i] = $safe_marker;
		}
	
		return (0, @possible_markers);
    }

    return MakeSafe($marker);
}

###
# Prepare strings for safe inclusion within a regular expression,
# escaping control characters.
###
sub MakeSafe 
{
    my $marker = shift;

	if (! defined $marker) { return ""; }

    $marker =~ s/\\/\\\\/g;
    $marker =~ s/\-/\\\-/g;
    $marker =~ s/\[/\\\[/g;
    $marker =~ s/\]/\\\]/g;
    $marker =~ s/\(/\\\(/g;
    $marker =~ s/\)/\\\)/g;
    $marker =~ s/\'/\\\'/g;
    $marker =~ s/\"/\\\"/g;
    $marker =~ s/\+//g;
    $marker =~ s/\?//g;
    $marker =~ s/\*//g;
    $marker =~ s/\^//g;
    $marker =~ s/\$//g;
    $marker =~ s/\./\\\./g;

    return $marker;
}

1;
