package SectLabel::PostProcess;

###
# Utilities for normalizing the output of CRF++ into standard
# representations.
#
# Luong Minh Thang 25 May, 09. Adopted from Isaac Councill, 07/20/07
###

use strict;
use utf8;

use CSXUtil::SafeText qw(cleanXML);
use ParsCit::Config;
use ParsCit::PostProcess; # qw(normalizeAuthorNames stripPunctuation);

###
# Main method for processing document data. Specifically, it reads CRF output, performs normalization to individual fields, and outputs to XML
###
sub WrapDocumentXml 
{
	my ($in_file, $section_headers) = @_;

	my $status		= 1;
  	my $doc_count	= 0;
  	my $msg			= "";
  	my $xml			= "";
  	my $variant		= "";
  	my $last_tag	= "";

  	my $overall_confidence	= "1.0";
	# For lines of the same label
  	my $cur_confidence		= 0; 
	# Count the number of lines in the current same label
  	my $count = 0; 

	# Output XML file for display
  	$xml .= "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";

	# Array of hash: each element of fields correspond to a pairs of (tag, content) 
	# accessible through $fields[$i]->{"tag"} and $fields[$i]->{"content"}
  	my @fields		= (); 
 	my $cur_content	= "";
  
	open(IN, "<:utf8", $in_file) or return (undef, undef, 0, "couldn't open in_file: $!");

  	my $line_id = -1;
  	while (<IN>) 
	{
    	if (/^\# ([\.\d]+)/) 
		{
			# Overall confidence info
      		$overall_confidence = $1;
      		next;
    	}

		# End of a sentence, output (useful to handle multiple document classification
    	if (/^\s*$/) 
		{
      		# Add the last field
      		AddFieldInfo(\@fields, $last_tag, $cur_content, $cur_confidence, $count);

			if ($variant eq "") 
			{
				# Benerate XML output
				my $output		 = GenerateOutput(\@fields);      
				my $l_algName	 = $SectLabel::Config::algorithmName;
				my $l_algVersion = $SectLabel::Config::algorithmVersion;
				$xml .= "<algorithm name=\"$l_algName\" version=\"$l_algVersion\">\n". "<variant no=\"0\" confidence=\"$overall_confidence\">\n". $output . "</variant>\n</algorithm>\n";
			}

      		$doc_count++;    

			# Reset
      		@fields		= (); 
      		$last_tag	= "";
      		$line_id	= -1;
    	}
		# In a middle of a document
		else 
		{ 
      		chop;
      		my @tokens = split (/\t/);
      		$line_id++;
      
      		my $line	= $tokens[0];
      		my $sys		= $tokens[-1];
      		my $gold	= $tokens[-2];

			# For this line
      		my $confidence = 0; 

			# Train at line level, get the original line
      		@tokens	= split(/\|\|\|/, $line);
      		$line	= join(" ", @tokens);
			
			# Process confidence info in the format e.g, sectionHeader/0.989046
			if ($sys =~ /^(.+)\/([\d\.]+)$/)
			{
				$sys = $1;
				$confidence += $2;
				# print STDERR "$line\t$sys\t$2\n";
      		} 
			else 
			{
				die "Die in SectLabel:PostProcess::wrapDocumentXml : incorrect format \"tag/prob\" $sys\n";
      		}

			# Start a new tag, not an initial value, output
      		if ($sys ne $last_tag && $last_tag ne "") 
			{
				AddFieldInfo(\@fields, $last_tag, $cur_content, $cur_confidence, $count);
	  
				# Reset the value
				$cur_content	= ""; 
				$cur_confidence	= 0;
				$count			= 0;
      		}

      		# Store section headers to classify generic sections later
      		if ($sys eq "sectionHeader")
			{
				push(@{$section_headers->{"header"}}, $line);
				push(@{$section_headers->{"lineId"}}, $line_id);
      		}

      		$cur_content	.= "$line\n";
      		$cur_confidence += $confidence;
      
	  		$count++;
			# Update last_tag
      		$last_tag = $sys; 
    	}
  	}

  	close (IN);
  	return $xml;
}

# To add per-field info 
sub AddFieldInfo 
{
	my ($fields, $last_tag, $cur_content, $cur_confidence, $count) = @_;

  	my %tmp_hash		 = ();
  	$tmp_hash{"tag"}	 = $last_tag;
  	$tmp_hash{"content"} = $cur_content;

	# Confidence info
  	if ($count > 0)
	{
    	$tmp_hash{"confidence"} = $cur_confidence/$count;
  	}

  	push(@{$fields}, \%tmp_hash);

	# print STDERR "\n###\n";
	# foreach my $key (keys %tmp_hash)
	# {
	# 	print STDERR "$key -> $tmp_hash{$key}\n";
	# }
}

# Wrap all field infos into XML form
sub GenerateOutput 
{
	my ($fields) = @_;

  	my $output = "";
	foreach (@{$fields}) 
	{
    	my $tag		 = $_->{"tag"};
    	my $content	 = $_->{"content"};
    	my $conf_str = " confidence=\"".$_->{"confidence"}."\"";

		if ($content =~ /^\s*$/) { next; };
    
		($tag, $content) = NormalizeDocumentField($tag, $content, 1);
    	$output .= "<$tag$conf_str>\n$content\n</$tag>\n";
  	}

	return $output;
}

# Wrap document into non-XML form
sub WrapDocument 
{
	my ($in_file, $blank_lines, $is_token_level) = @_;

  	my $msg			= "";
  	my $xml			= "";
	my $status		= 1;
  	my $variant		= "";
  	my $confidence	= "1.0";

	# Output XML file for display
	# Array of hash: each element of fields correspond to a pairs of (tag, content) 
	# accessible through $fields[$i]->{"tag"} and $fields[$i]->{"content"}
  	my @fields		= ();
  	my @cur_content	= ();

	open(IN, "<:utf8", $in_file) or return (undef, undef, 0, "couldn't open in_file: $!");
	my $line_id = -1;
  	
	while (<IN>) 
	{
		# Overall confidence info
    	if (/^\# ([\.\d]+)/) { next; }

		$line_id++;
    	while ($blank_lines->{$line_id})
		{
      		print STDERR "#! Insert none label for line id $line_id\n";
      		$xml .= "none \n";
      		$line_id++;
    	}

		# End of a sentence, output (useful to handle multiple document classification
    	if (/^\s*$/) 
		{ 
      		# Add the last field
      		$line_id = -1;
    	}
		# In a middle of a document
		else 
		{
      		chop;
      	
			my @tokens	= split (/\t/);      
      		my $line	= $tokens[0];
      		my $sys		= $tokens[-1];
      		my $gold	= $tokens[-2];

			# Train at line level, get the original line
			@tokens	= split(/\|\|\|/, $line);
			$line	= join(" ", @tokens);

			# Process confidence info in the format e.g, sectionHeader/0.989046
			if ($sys =~ /^(.+)\/[\d\.]+$/)
			{ 
				$sys = $1;
      		} 
			else 
			{
				die "Die in SectLabel:PostProcess::wrapDocument : incorrect format \"tag/prob\" $sys\n";
      		}

      		($sys, $line) = NormalizeDocumentField($sys, $line, 0);
      		$xml .= "$sys $line\n";
    	}
  	}

	close (IN);
	return $xml;
}

# Make the output "prettier"
sub SimpleNormalize 
{
	my ($tag, $content) = @_;

	# Remove keyword at the beginning and strip leading spaces
  	$content =~ s/^\s*$tag\s+//i;

  	# Remove trailing spaces
  	$content =~ s/\s+$//g;

  	# Unhyphenation
  	$content =~ s/\- ([a-z])/$1/g;

  	# Escape XML characters
  	cleanXML(\$content);
  
	# $content = ParsCit::PostProcess::stripPunctuation($content);
	return ($tag, $content);
}

###
# Document normalization subroutine. Reads in a tag and its content, perform normalization based on that tag.
###
sub NormalizeDocumentField 
{
	my ($tag, $content, $isEscape) = @_;

	# Remove keyword at the beginning and strip leading spaces
	# $content =~ s/^\s*$tag\s+//i;

	# Remove trailing spaces
  	$content =~ s/\s+$//g;

	# Unhyphenation
	# $content =~ s/\- ([a-z])/$1/g;

	# Escape XML characters
	if ($isEscape)
	{
    	cleanXML(\$content);
  	}
  
	# $content = ParsCit::PostProcess::stripPunctuation($content);
	return ($tag, $content);
}

###
# Huydhn: provide input for parscit
###
sub GenerateParscitInput
{
	my ($in_file) = @_;

	my @cit_lines	= ();
  	my $line_index	= 0;
	my $all_text	= "";

	# This file is the output from CRF++ for sectlabel
	open(IN, "<:utf8", $in_file) or return (undef, undef, 0, "couldn't open in_file: $!");

  	while (<IN>) 
	{
		# Overall condidence line, do not care about this
    	if (/^\# ([\.\d]+)/) { next; }
		# Remove end of line		
      	chop;
		# Remove blank line
		my $line =	$_;
		$line	 =~	s/^\s+|\s+$//g;
		if ($line eq "") { next; }

		# Split the line, the last token is the category provide by sectlabel
		my @tokens = split (/\t/, $line);
	 	# A line's category
   		my $sys = $tokens[-1];

		# Process confidence info in the format e.g, sectionHeader/0.989046
		if ($sys =~ /^(.+)\/([\d\.]+)$/)
		{
			$sys = $1;
      	} 
		else 
		{
			die "Die in SectLabel:PostProcess::wrapDocumentXml : incorrect format \"tag/prob\" $sys\n";
      	}

		# Only keep lines in the reference for parscit
		if ($sys eq "reference") { push @cit_lines, $line_index; }

		my $content	= $tokens[0];
		# Train at line level, get the original line
      	@tokens		= split(/\|\|\|/, $content);
      	$content	= join(" ", @tokens);

		# Save the line
		$all_text = $all_text . $content . "\n";

		# Point to the next line
		$line_index++;
  	}

  	close (IN);

	# Done
	return ($all_text, \@cit_lines);
}

###
# Huydhn: provide author and affiliation for the new matching model
###
sub GenerateAuthorAffiliation
{
	my ($in_file) = @_;

	my @aut_lines	= ();
	my @aff_lines	= ();
  	my $line_index	= 0;

	# This file is the output from CRF++ for sectlabel
	open(IN, "<:utf8", $in_file) or return (undef, undef, 0, "couldn't open in_file: $!");

	# Label of the previous line
	my $prev_sys = "";

  	while (<IN>) 
	{
		# Overall condidence line, do not care about this
    	if (/^\# ([\.\d]+)/) { next; }
		# Remove end of line		
      	chop;
		# Remove blank line
		my $line =	$_;
		$line	 =~	s/^\s+|\s+$//g;
		if ($line eq "") { next; }

		# Split the line, the last token is the category provide by sectlabel
		my @tokens = split (/\t/, $line);
	 	# A line's category
   		my $sys = $tokens[-1];

		# Process confidence info in the format e.g, sectionHeader/0.989046
		if ($sys =~ /^(.+)\/([\d\.]+)$/)
		{
			$sys = $1;
      	} 
		else 
		{
			die "Die in SectLabel:PostProcess::wrapDocumentXml : incorrect format \"tag/prob\" $sys\n";
      	}

		# Only keep lines in the reference for parscit
		if ($sys eq "author") 
		{ 
			push @aut_lines, $line_index; 
		
			# Save the old label
			$prev_sys = $sys;
			# Point to the next line
			$line_index++;
		}
		elsif ($sys eq "affiliation")
		{
			push @aff_lines, $line_index;

			# Save the old label
			$prev_sys = $sys;
			# Point to the next line
			$line_index++;
		}
		elsif (($sys eq "address") && ($prev_sys eq "affiliation"))
		{
			push @aff_lines, $line_index;
			
			# Point to the next line
			$line_index++;
		}
		else
		{
			# Save the old label
			$prev_sys = $sys;
			# Point to the next line
			$line_index++;
		}
  	}

  	close (IN);

	# Done
	return (\@aut_lines, \@aff_lines);
}

1;
