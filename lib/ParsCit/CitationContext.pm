package ParsCit::CitationContext;
#
# Utility functions for finding citation contexts after citation
# parsing.  The idea is to build regular expressions that could match
# citation references in the body text and scan the body text for
# occurrences.  The size of the context returned can be configured
# in ParsCit::Config::contextRadius.
#
# Isaac Councill, 7/20/07
#
use ParsCit::Config;
use utf8;

my $contextRadius = $ParsCit::Config::contextRadius;
my $maxContexts = $ParsCit::Config::maxContexts;

sub countTokens {
  my ($text) = @_;

  my $trimText = $text;
  $trimText =~ s/^\s+//;       $trimText =~ s/\s+$//;
  my @tokens = split(/\s+/, $trimText);
  return scalar(@tokens);
}

##
# Build a list of potential regular expressions based on the supplied
# citation marker and applies the expressions to the specified body text.
# Returns a reference to a list of strings that match the expressions,
# expanded to radius $contextRadius.
##
sub getCitationContext {
  my ($rBodyText, $posArray, $marker) = @_;
  
  my ($prioritize, @markers) = guessPossibleMarkers($marker);
#  print STDERR join "::", @markers;
#  print STDERR "\n";
  my @matches = ();
  my @citStrs = (); # Thang Nov 2009: store the in-text citation strings
  my @startWordPositions = (); # Thang May 2010: store start word positions of citation markers
  my @endWordPositions = (); # Thang May 2010: store end word positions of citation markers

  ########## modified by Nick Friedrich
  my @positions = ();
  my $position;
  
  my $contextsFound = 0;
  foreach my $mark (@markers) {
    
    while (($contextsFound < $maxContexts) &&
	   $$rBodyText =~ m/(.{$contextRadius}($mark).{$contextRadius})/gs) {
      # Thang May 2010: check mark length
      my $citStr = $2;
      my $citLength = countTokens($citStr);
#      print STDERR "#Thang: $citStr\t$citLength\n";
      if($citLength == 0) {
	next;
      }

      push @positions, (pos $$rBodyText) - $contextRadius;
      push @matches, $1;

      my $beforeMark = substr($$rBodyText, 0, (pos $$rBodyText) - $contextRadius-length($citStr));
      my $beforeLength = countTokens($beforeMark);

      if($beforeMark =~ / $/ || $citStr =~ /^ /){
	push(@startWordPositions, $beforeLength);
	push(@endWordPositions, $beforeLength+$citLength-1);
      } else { # no space in btw
	push(@startWordPositions, $beforeLength-1);
	push(@endWordPositions, $beforeLength-1+$citLength-1);
      }

      # Thang Nov 2009
      if($citStr !~ /\(.+\)$/ && $citStr =~ /\)$/){
	$citStr =~ s/\)$//; # trim ending bracket
      }
      push @citStrs, $citStr;
      # End Thang Nov 2009
      
      $contextsFound++;
    }
    if (($prioritize > 0) && ($#matches >= 0)) {
      last;
    }
  }
  return ( \@matches, \@positions, \@startWordPositions, \@endWordPositions, \@citStrs);
  ##########
}  # getCitationContext


##
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
# 
##
sub guessPossibleMarkers {
    my $marker = shift;

    if ($marker =~ m/^([\[\(])([\p{IsUpper}\p{IsLower}\-\d]+)([\]\)])/) {
	my $open = makeSafe($1);
	my $mark = makeSafe($2);
	my $close = makeSafe($3);
	my $refIndicator = "$open([\p{IsUpper}\p{IsLower}\\-\\d]+[;,] *)*$mark([;,] *[\p{IsUpper}\p{IsLower}\\-\\d]+)*$close";
	return (0, $refIndicator);
    }
    if ($marker =~ m/^(\d+)\.?/) {
	my $square = "\\[(\\d+[,;] *)*$1([;,] *\\d+)*\\]";
	my $paren = "\\((\\d+[,;] *)*$1([,;] *\\d+)*\\)";
	return (1, $square, $paren);
    }
    if ($marker =~ m/^([\p{IsUpper}\p{IsLower}\-\.\']+(, )*)+\d{4}/) {
	my @tokens = split ", ", $marker;
	my $year = $tokens[$#tokens];
	my @names = @tokens[0..$#tokens-1];
	my @possibleMarkers = ();
	if ($#names == 0) {
	    push @possibleMarkers, $names[0].",? \\(?$year\\)?";
	}
	if ($#names == 1) {
	    push @possibleMarkers, $names[0]." and ".$names[1].",? \\(?$year\\)?";
	    push @possibleMarkers, $names[0]." & ".$names[1].",? \\(?$year\\)?";
	}
	if ($#names > 1) {
	    map { $_ = makeSafe($_) } $names;
	    map { $_ = $_."," } @names;
	    my $lastAuth1 = "and ".$names[$#names];
	    my $lastAuth2 = "& ".$names[$#names];
	    push @possibleMarkers,
	      join " ", @names[0..$#names-1], $lastAuth1, $year;
	    push @possibleMarkers,
	      join " ", @names[0..$#names-1], $lastAuth2, $year;

	    push @possibleMarkers, $names[0]."? et al\\\.?,? \\(?$year\\)?";
	}
	for (my $i=0; $i<=$#possibleMarkers; $i++) {
	    my $safeMarker = $possibleMarkers[$i];
	    $safeMarker =~ s/\-/\\\-/g;
	    $possibleMarkers[$i] = $safeMarker;
	}
	return (0, @possibleMarkers);
    }
    return makeSafe($marker);

}  # guessPossibleMarkers


##
# Prepare strings for safe inclusion within a regular expression,
# escaping control characters.
##
sub makeSafe {
    my $marker = shift;
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

} # makeSafe


1;
