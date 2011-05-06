package ParsHed::PostProcess;

###
# Utilities for normalizing the output of CRF++ into standard
# representations.
#
# Luong Minh Thang 25 May, 09. Adopted from Isaac Councill, 07/20/07
###

use utf8;
use strict;

use CSXUtil::SafeText qw(cleanXML);
use ParsCit::Config;
use ParsCit::PostProcess;

###
# Main method for processing header data. Specifically, it reads CRF
# output, performs normalization to individual fields, and outputs to
# XML
###
sub wrapHeaderXml 
{
	# Thang Nov 09: $confInfo to add confidence info
	my ($infile, $conf_info, $is_token_level) = @_; 

  	my $status		= 1;
  	my $msg			= "";
  	my $xml			= "";
  	my $last_tag	= "";
  	my $variant		= "";

	# Thang Nov 09: rename $confidence -> $overallConfidence
  	my $overall_confidence = "1.0"; 

  	# Output XML file for display
  	$xml .= "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";

	# Array of hash: each element of fields correspond to a pairs of (tag, content) 
	# accessible through $fields[$i]->{"tag"} and $fields[$i]->{"content"}
  	my @fields	= ();
  	my $count	= 0;

	my $cur_content		= "";
	# For lines of the same label
	my $cur_confidence	= 0; 

	# Input file is the result output of crf++ test
	open(IN, "<:utf8", $infile) or return (undef, undef, 0, "couldn't open infile: $!");

  	while (<IN>) 
	{	
		# Confidence info
    	if (/^\# ([\.\d]+)/) 
		{
      		$overall_confidence = $1;
      		next;
    	}
		# Skip comments
    	elsif (/^\#/) 
		{ 
			next; 
		}                              

		# End of a header, output (useful to handle multiple header classification
    	if (/^\s*$/) 
		{
			# Add the last field
      		addFieldInfo(\@fields, $last_tag, $cur_content, $cur_confidence, $count);      

      		if ($variant eq "") 
			{
				# Generate XML output
				my $output = generateOutput(\@fields, $conf_info);

				my $l_alg_name = $ParsHed::Config::algorithmName;
				my $l_alg_version = $ParsHed::Config::algorithmVersion;
				$xml .= "<algorithm name=\"$l_alg_name\" version=\"$l_alg_version\">\n". "<variant no=\"0\" confidence=\"$overall_confidence\">\n". $output . "</variant>\n</algorithm>\n";
      		}
      
      		@fields		= (); #reset
      		$last_tag	= "";
    	} 
		# In a middle of a header
		else 
		{
      		chop;
      		my @tokens		= split (/\t/);

      		my $token		= $tokens[0];
			
      		my $sys			= $tokens[-1];
      		my $gold		= $tokens[-2];
      		my $confidence	= 0;

      		if (!defined $is_token_level)
			{
				# Train at line level, get the original line
				my @tokens	= split(/\|\|\|/, $token);
				$token		= join(" ", @tokens);
				
				###
				# Thang Nov 09: process confidence output from crf++
				###
				if($conf_info)
				{
					# $sys contains probability info of the format "tag/prob"
	  				if ($sys =~ /^(.+)\/([\d\.]+)$/)
					{
	    				$sys		= $1;
	    				$confidence	+= $2;
	  				} 
					else 
					{
	    				die "Die in ParsHed::PostProcess::wrapHeaderXml : incorrect format \"tag/prob\" $sys\n";
	  				}
				}
				###
				# End Thang Nov 09: process confidence output from crf++
				###
      		}
	
			# Start a new tag, not an initial value, output
      		if ($sys ne $last_tag && $last_tag ne "") 
			{ 
				addFieldInfo(\@fields, $last_tag, $cur_content, $cur_confidence, $count);
	  
				# Reset the value
				$cur_content	= ""; 
				$cur_confidence	= 0;
				$count			= 0;
      		}

	      	if (defined $is_token_level && $token eq "+L+") { next; }

    	 	$cur_content	.= $token . " ";
      		$cur_confidence	+= $confidence;
	      	$count++;
	
			# Update last tag
      		$last_tag = $sys;
		}
  	}

  	close (IN);
  	return $xml;
}

###
# Thang Mar 10: refactor this part of code into a method, to add per-field info
###
sub addFieldInfo 
{
  	my ($fields, $last_tag, $cur_content, $cur_confidence, $count) = @_;

  	my %tmp_hash		 = ();
  	$tmp_hash{"tag"}	 = $last_tag;
  	$tmp_hash{"content"} = $cur_content;
  
  	### Thang Nov 09: compute confidence score
  	if ($count > 0) { $tmp_hash{"confidence"} = $cur_confidence / $count; }

	# Save
  	push(@{ $fields }, \%tmp_hash);
}

###
# Thang Mar 10: refactor this part of code into a method, wrap all field infos into XML form
###
sub generateOutput 
{
  	my ($fields, $conf_info) = @_;

  	my $output = "";
  
  	foreach (@{ $fields }) 
	{
    	my $tag		= $_->{"tag"};
    	my $content	= $_->{"content"};

		###
    	# Thang Nov 09: modify to output confidence score
		###
    	my $conf_str = "";
    	if ($conf_info) { $conf_str = " confidence=\"".$_->{"confidence"}."\""; }

		# Blank content
    	if ($content =~ /^\s*$/) { next; };

    	($tag, $content) = normalizeHeaderField($tag, $content);

		# Handle multiple authors in a line
    	if ($tag eq "authors")
		{
      		foreach my $author (@{ $content })
			{
				cleanXML(\$author);
				$output .= "<author$conf_str>$author</author>\n";
      		}
    	}
		# Handle multiple emails at a time
		elsif ($tag eq "emails")
		{
      		foreach my $email (@{ $content })
			{
				$output .= "<email$conf_str>$email</email>\n";
      		}
    	} 
		else 
		{
      		$output .= "<$tag$conf_str>$content</$tag>\n";
    	}
		###
    	# End Thang Nov 09: modify to output confidence score
		###
  	} # end for each fields
  
  	return $output;    
}

###
# Header normalization subroutine.  Reads in a tag and its content, 
# perform normalization based on that tag.
###
sub normalizeHeaderField 
{
  	my ($tag, $content) = @_;;

	# Remove keyword at the beginning
	$content =~ s/^\W*$tag\W+//i;
	# Strip leading spaces
  	$content =~ s/^\s+//g;
	# Remove trailing spaces
  	$content =~ s/\s+$//g;		      
	# Unhyphenate
  	$content =~ s/\- ([a-z])/$1/g;

  	# Normalize author and break into multiple authors (if any)
  	if ($tag eq "author") 
	{
    	$tag	 = "authors";
    	$content =~ s/\d//g; # remove numbers
    	$content = ParsCit::PostProcess::NormalizeAuthorNames($content);
  	} 
	elsif ($tag eq "email") 
	{
		# Multiple emails of the form {kanmy,luongmin}@nus.edu.sg
    	if($content =~ /^\{(.+)\}(.+)$/)
		{
      		my $begin	  = $1;
      		my $end		  = $2;
      		my $separator = ",";

	      	# Find possible separator of emails, beside ","
    	  	my @separators = ($begin =~ /\s+(\S)\s+/g); 
      		if (scalar(@separators) > 1)
			{	
				my $cand = $separators[0];
				my $flag = 1;
				foreach (@separators) 
				{
					# Should be the same
	  				if($_ ne $cand)
					{
		    			$flag = 0;
	    				last;
	  				}
				}

				# All separator are the same, and the number of separator > 1, update separator
				if($flag == 1) 
				{
	  				$separator = $cand;
				}	
    	  	}

	      	my @tokens = split(/$separator/, $begin);

			# Remove all white spaces
      		$end =~ s/\s+//g; 

			# There are actually multiple emails
    	  	if (scalar(@tokens) > 1) 
			{
				my @emails = ();

				foreach my $token (@tokens)
				{
					# Remove all white spaces
	  				$token =~ s/\s+//g; 
	  				push (@emails, "$token$end");
				}

				$tag	 = "emails";
				$content = \@emails;
	      	}
    	} 
		# Only one email
		else 
		{
			# Remove all white spaces
      		$content =~ s/\s+//g; 
    	}
  	} 
	else 
	{
		# Escape XML characters
    	cleanXML(\$content);

		###
		# Huydhn: don't understand why need to remove punctuation here
		# just for the sake of appearance
		#
		# 17 jan 2011
		###
    	$content = ParsCit::PostProcess::StripPunctuation($content);
	}

  	return ($tag, $content);
}

1;
