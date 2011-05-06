package SectLabel::AAMatching;

###
# This package provides methods to solve the matching problem
# between author and affiliation in a pdf
#
# Do Hoang Nhat Huy 21 Apr, 11
###

use strict;

# Dependencies
use IO::File;
use XML::Writer;
use XML::Writer::String;

# Local libraries
use SectLabel::Config;
use ParsCit::PostProcess;

# Dictionary
my %dict = ();

# Author
# Affiliation
sub AAMatching
{
	my ($doc, $aut_addrs, $aff_addrs) = @_;

	my $need_object	= 1;
	# Get the author objects
	my $aut_lines	= Omni::Traversal::OmniCollector($doc, $aut_addrs, $need_object);
	# Get the affiliation objects
	my $aff_lines	= Omni::Traversal::OmniCollector($doc, $aff_addrs, $need_object);
	
	# Dictionary
	ReadDict($SectLabel::Config::dictFile);

	# Authors
	my $aut_features = AuthorFeatureExtraction($aut_lines);
	# Call CRF
	# TODO: DO NOT NEED TO SPLIT AUTHOR FROM DIFFERENT SECTIONS
	my $aut_signal 	 = AuthorExtraction($aut_features);

	# Affiliations
	my $aff_features = AffiliationFeatureExtraction($aff_lines);
	# Call CRF
	# TODO: DO NOT NEED TO SPLIT AFFILIATION FROM DIFFERENT SECTIONS
	my ($aff_signal, $affs) = AffiliationExtraction($aff_features);

	# Do the matching
	# XML string
	my $sxml 	= "";
	# and XML writer
	my $writer	= new XML::Writer(OUTPUT => \$sxml, ENCODING => 'utf-8', DATA_MODE => 'true', DATA_INDENT => 2);	

	# Algorithm
	$writer->startTag("algorithm", "name" => "AAMatching", "version" => $SectLabel::Config::algorithmVersion);	

	# XML header
	my $date = `date`; chomp($date);
	my $time = `date +%s`; chomp($time);	
	# Write XML header
	$writer->startTag("results", "time" => $time, "date" => $date);

	# Write authors
	$writer->startTag("authors");

	# Write the author name and his corresponding institution
	foreach my $author (keys %{ $aut_signal })
	{
		$writer->startTag("author");

		$writer->startTag("fullname", "source" => "parscit");
		$writer->characters($author);
		$writer->endTag("fullname");

		$writer->startTag("institutions");		
		foreach my $signal (@{ $aut_signal->{ $author } })
		{
			$signal =~ s/^\s+|\s+$//g;
			# Skip blank
			if ($signal eq "") { next; }

			$writer->startTag("institution", "symbol" => $signal);
			$writer->characters($aff_signal->{ $signal });
			$writer->endTag("institution");
		}
		$writer->endTag("institutions");

		$writer->endTag("author");
	}

	# Finish authors
	$writer->endTag("authors");

	# Write institutions
	$writer->startTag("institutions");
	
	# Write the instituion name
	foreach my $institute (@{ $affs })
	{
		$writer->startTag("institution");
		$writer->characters($institute);
		$writer->endTag("institution");	
	}

	$writer->endTag("institutions");

	# Done
	$writer->endTag("results");
	# Done
	$writer->endTag("algorithm");
	# Done
	$writer->end();

	# Return the xml content back to the caller
	return $sxml;
}

# Extract affiliation and their signal using crf
sub AffiliationExtraction
{
	my ($features) = @_;

	# Temporary input file for CRF
	my $infile	= BuildTmpFile("aff-input");
	# Temporary output file for CRF
	my $outfile	= BuildTmpFile("aff-output");

	my $output_handle = undef;
	# Split and write to temporary input
	open $output_handle, ">:utf8", $infile;
	# Split
	my @lines = split /\n/, $features;
	# and write
	foreach my $line (@lines) 
	{ 
		if ($line eq "")
		{
			print $output_handle, "\n";	
		}
		else
		{
			print $output_handle $line, "\t", "affiliation", "\n"; 
		}
	}
	# Done
	close $output_handle;

	# Author model
	my $aff_model = $SectLabel::Config::affFile; 

	# Split the authors
  	system("crf_test -m $aff_model $infile > $outfile");

	# Each affiliation can have only one signal
	my %asg = ();
	# List of all affiliations
	my @aff = ();

	my $input_handle = undef;
	# Read the CRF output
	open $input_handle, "<:utf8", $outfile;
	# Author and signal string
	my $prev_class	= "";
	my $aff_str		= "";
	my $signal_str	= "";
	# Next to last signal
	my $ntl_signal	= "";
	# Read each line and get its label
	# TODO: The code assumes that an affiliation will have the following format: 1 foobar institute
	while (<$input_handle>)
	{
		my $line = $_;
		# Trim
		$line =~ s/^\s+|\s+$//g;
		# Skip blank line, what the heck
		if ($line eq "") { next; }
		
		# Split the line
		my @fields	= split /\t/, $line;
		# and extract the class and the content
		my $class	= $fields[ -1 ];
		my $content	= $fields[ 0 ];

		if ($class eq $prev_class)
		{
			# An affiliation
			if ($class eq "affiliation")
			{
				$aff_str .= $content . " ";
			}
			# A signal
			elsif ($class eq "signal")
			{
				$signal_str .= $content . " ";	
			}		
		}
		else
		{
			if ($prev_class eq "affiliation")
			{
				# TODO: How to solve the case when the signal is attached to the affiliation string, e.g. *foobar institute
				my $affiliation = NormalizeAffiliationName($aff_str);
				# Save the affiliation
				push @aff, $affiliation;
				# and its signal
				if ($ntl_signal ne "") { $asg{ $ntl_signal } = $affiliation; }
			}
			elsif ($prev_class eq "signal")
			{
				# Save the next to last signal
				$ntl_signal = NormalizeAffiliationSignal($signal_str);
			}

			# Cleanup
			$aff_str 	= "";
			$signal_str = "";
			# Switch to the current class
			$prev_class = $class;

			if ($class eq "affiliation")
			{
				$aff_str .= $content . " ";
			}
			elsif ($class eq "signal")
			{
				$signal_str .= $content . " ";	
			}
		}
	}

	# Final class
	if ($prev_class eq "affiliation")
	{
		# TODO: How to solve the case when the signal is attached to the affiliation string, e.g. *foobar institute
		my $affiliation = NormalizeAffiliationName($aff_str);
		# Save the affiliation
		push @aff, $affiliation;
		# and its signal
		if ($ntl_signal ne "") { $asg{ $ntl_signal } = $affiliation; }
	}
	elsif ($prev_class eq "signal")
	{
		# Save the next to last signal
		$ntl_signal = NormalizeAffiliationSignal($signal_str);
	}

	# Done
	close $input_handle;
	
	# Clean up
	unlink $infile;
	unlink $outfile;
	# Done
	return (\%asg, \@aff);
}

sub NormalizeAffiliationSignal
{
	my ($signal_str) = @_;

	# Trim
	$signal_str =~ s/^\s+|\s+$//g;
	# Remove all space inside the signature
	$signal_str =~ s/\s+//g;
	
	# Done
	return $signal_str;
}

sub NormalizeAffiliationName
{
	my ($aff_str) = @_;

	# Trim
	$aff_str =~ s/^\s+|\s+$//g;
	
	# Done
	return $aff_str;
}

# Extract author name and their signal using crf
sub AuthorExtraction
{
	my ($features) = @_;

	# Temporary input file for CRF
	my $infile	= BuildTmpFile("aut-input");
	# Temporary output file for CRF
	my $outfile	= BuildTmpFile("aut-output");

	my $output_handle = undef;
	# Split and write to temporary input
	open $output_handle, ">:utf8", $infile;
	# Split
	my @lines = split /\n/, $features;
	# and write
	foreach my $line (@lines) 
	{ 
		if ($line eq "")
		{
			print $output_handle, "\n";	
		}
		else
		{
			print $output_handle $line, "\t", "ns", "\n"; 
		}
	}
	# Done
	close $output_handle;

	# Author model
	my $author_model = $SectLabel::Config::autFile; 

	# Split the authors
  	system("crf_test -m $author_model $infile > $outfile");

	# Each author can have one or more signals
	my %asg = ();

	my $input_handle = undef;
	# Read the CRF output
	open $input_handle, "<:utf8", $outfile;
	# Author and signal string
	my $prev_class	= "";
	my $author_str	= "";
	my $signal_str	= "";
	# Next to last authors
	my %ntl_asg 	= ();
	# Read each line and get its label
	while (<$input_handle>)
	{
		my $line = $_;
		# Trim
		$line =~ s/^\s+|\s+$//g;
		# Skip blank line, what the heck
		if ($line eq "") { next; }
		
		# Split the line
		my @fields	= split /\t/, $line;
		# and extract the class and the content
		my $class	= $fields[ -1 ];
		my $content	= $fields[ 0 ];

		if ($class eq $prev_class)
		{
			# An author
			if ($class eq "author")
			{
				$author_str .= $content . " ";
			}
			# A signal
			elsif ($class eq "signal")
			{
				$signal_str .= $content . " ";	
			}		
		}
		else
		{
			if ($prev_class eq "author")
			{
				# TODO: How to solve the case when the signal is attached to the author string, e.g. foobar*, more foobar
				my $authors = ParsCit::PostProcess::NormalizeAuthorNames($author_str);
				# Save each author
				foreach my $author (@{ $authors })
				{
					$asg{ $author }		= ();		
					$ntl_asg{ $author }	= 0;
				}
			}
			elsif ($prev_class eq "signal")
			{
				my $signals = NormalizeAuthorSignal($signal_str);
				# Save each signal to its corresponding author
				foreach my $author (keys %ntl_asg)
				{
					foreach my $signal (@{ $signals })
					{
						push @{ $asg{ $author } }, $signal;
					}
				}
			}

			# Clean the next to last author list if this current class is author
			if ($class eq "author") { %ntl_asg = (); }					


			# Cleanup
			$author_str = "";
			$signal_str = "";
			# Switch to the current class
			$prev_class = $class;

			if ($class eq "author")
			{
				$author_str .= $content	. " ";
			}
			elsif ($class eq "signal")
			{
				$signal_str .= $content . " ";	
			}
		}
	}

	# Final class
	if ($prev_class eq "author")
	{
		# TODO: How to solve the case when the signal is attached to the author string, e.g. foobar*, more foobar
		my $authors = ParsCit::PostProcess::NormalizeAuthorNames($author_str);
		# Save each author
		foreach my $author (@{ $authors })
		{
			$asg{ $author }	= ();		
		}
	}
	elsif ($prev_class eq "signal")
	{
		my $signals = NormalizeAuthorSignal($signal_str);
		# Save each signal to its corresponding author
		foreach my $author (keys %ntl_asg)
		{
			foreach my $signal (@{ $signals })
			{
				push @{ $asg{ $author } }, $signal;
			}
		}
	}

	# Done
	close $input_handle;
	
	# Clean up
	unlink $infile;
	unlink $outfile;
	# Done
	return \%asg;
}

# 
sub NormalizeAuthorSignal
{
	my ($signal_str) = @_;

	# Trim
	$signal_str =~ s/^\s+|\s+$//g;
	# Split into individual signal
	my @signals = split / |,|:|;/, $signal_str;
	
	# Done
	return \@signals; 
}

# Extract features from affiliation lines
# The list of features include
# Content
# Content, lower case, no punctuation
# Content length
# First word in line
#
# XML features
# Subscript, superscript
# Bold
# Italic
# Underline
# Relative font size
# Differentiate features
sub AffiliationFeatureExtraction
{
	my ($aff_lines) = @_;

	# Features will be stored here
	my $features 		= "";
	# First word in line
	my $is_first_line	= undef;

	# Font size
	my %fonts = ();
	# Each line contains many runs
	foreach my $line (@{ $aff_lines })
	{
		my $runs = $line->get_objs_ref();
		# Iterator though all work in all lines
		foreach my $run (@{ $runs })
		{
			my $fsize = $run->get_font_size();
			my $words = $run->get_objs_ref();

			# Statistic
			if (! exists $fonts{ $fsize })
			{
				$fonts{ $fsize } = scalar(@{ $words });
			}
			else
			{
				$fonts{ $fsize } += scalar(@{ $words });
			}
		}
	}

	my $dominate_font = undef;
	# Sort all the font descend with the number of their appearance
	my @sorted = sort { $fonts{ $b } <=> $fonts{ $a } } keys %fonts;
	# Select the dominated font
	$dominate_font = @sorted[ 0 ];

	# Each line contains many runs
	foreach my $line (@{ $aff_lines })
	{
		# Set first word in line
		$is_first_line = 1;

		# Format of the previous word
		my ($prev_bold, $prev_italic, $prev_underline, $prev_suscript, $prev_fontsize) = "unknown";

		my $runs = $line->get_objs_ref();
		# Iterator though all work in all lines
		foreach my $run (@{ $runs })
		{
			# The run must be non-empty
			my $tmp = $run->get_content();
			# Trim
			$tmp	=~ s/^\s+|\s+$//g;
			# Skip blank run
			if ($tmp eq "") { next; }

			###
			# The following features are XML features
			###
			
			# Bold format	
			my $bold = ($run->get_bold() eq "true") ? "bold" : "none";
			
			# Italic format	
			my $italic = ($run->get_italic() eq "true") ? "italic" : "none";

			# Underline
			my $underline = ($run->get_underline() eq "true") ? "underline" : "none";

			# Sub-Sup-script
			my $suscript =	($run->get_suscript() eq "superscript")	? "super"	:
							($run->get_suscript() eq "subscript")	? "sub"		: "none";

			# Relative font size
			my $fontsize =	($run->get_font_size() > $dominate_font)	? "large"	:
							($run->get_font_size() < $dominate_font)	? "small"	: "normal";
			
			###
			# End of XML features
			###

			# All words in the run
			my $words = $run->get_objs_ref();

			# For each word
			foreach my $word (@{ $words })
			{
				# Extract features
				my $content = $word->get_content();
				# Trim
				$content	=~ s/^\s+|\s+$//g;

				# Skip blank run
				if ($content eq "") { next; }

				# Content
				$features .= $content . "\t";
			
				# Remove punctuation
				my $content_n	=~ s/[^\w]//g;
				# Lower case
				my $content_l	= lc($content);
				# Lower case, no punctuation
				my $content_nl	= lc($content_n);
				# Lower case
				$features .= $content_l . "\t";
				# Lower case, no punctuation
				if ($content_nl ne "")
				{
					$features .= $content_nl . "\t";
				}
				else
				{
					$features .= $content_l . "\t";
				}

				# Split into character
	      		my @chars = split(//, $content);
				# Content length
				my $length =	(scalar(@chars) == 1)	? "1-char"	:
								(scalar(@chars) == 2)	? "2-char"	:
								(scalar(@chars) == 3)	? "3-char"	: "4+char";
				$features .= $length . "\t";
							
				# First word in line
				if ($is_first_line == 1)
				{
					$features .= "begin" . "\t";
	
					# Next words are not the first in line anymore
					$is_first_line = 0;
				}
				else	
				{
					$features .= "continue" . "\t";
				}		

				###
				# The following features are XML features
				###
			
				# Bold format	
				$features .= $bold . "\t";
			
				# Italic format	
				$features .= $italic . "\t";

				# Underline
				$features .= $underline . "\t";

				# Sub-Sup-script
				$features .= $suscript . "\t";

				# Relative font size
				$features .= $fontsize . "\t";

				# First word in run
				if (($prev_bold ne $bold) || ($prev_italic ne $italic) || ($prev_underline ne $underline) || ($prev_suscript ne $suscript) || ($prev_fontsize ne $fontsize))
				{
					$features .= "fbegin" . "\t";
				}
				else	
				{
					$features .= "fcontinue" . "\t";
				}

				# New token
				$features .= "\n";

				# Save the XML format
				$prev_bold		= $bold;
				$prev_italic	= $italic;
				$prev_underline	= $underline;
				$prev_suscript	= $suscript;
				$prev_fontsize	= $fontsize;
			}			
		}
	}

	return $features;

}

# Extract features from author lines
# The list of features include
# Content
# Content, lower case, no punctuation
# Content length
# Capitalization
# Numeric property
# Last punctuation
# First 4-gram
# Last 4-gram
# Dictionary
# First word in line
#
# XML features
# Subscript, superscript
# Bold
# Italic
# Underline
# Relative font size
# Differentiate features
sub AuthorFeatureExtraction
{
	my ($aut_lines) = @_;
	
	# Features will be stored here
	my $features 		= "";
	# First word in line
	my $is_first_line	= undef;
	# First word in run
	# my $is_first_run	= undef;

	# Font size
	my %fonts = ();
	# Each line contains many runs
	foreach my $line (@{ $aut_lines })
	{
		my $runs = $line->get_objs_ref();
		# Iterator though all work in all lines
		foreach my $run (@{ $runs })
		{
			my $fsize = $run->get_font_size();
			my $words = $run->get_objs_ref();

			# Statistic
			if (! exists $fonts{ $fsize })
			{
				$fonts{ $fsize } = scalar(@{ $words });
			}
			else
			{
				$fonts{ $fsize } += scalar(@{ $words });
			}
		}
	}

	my $dominate_font = undef;
	# Sort all the font descend with the number of their appearance
	my @sorted = sort { $fonts{ $b } <=> $fonts{ $a } } keys %fonts;
	# Select the dominated font
	$dominate_font = @sorted[ 0 ];

	# Each line contains many runs
	foreach my $line (@{ $aut_lines })
	{
		# Set first word in line
		$is_first_line = 1;

		# Format of the previous word
		my ($prev_bold, $prev_italic, $prev_underline, $prev_suscript, $prev_fontsize) = "unknown";

		my $runs = $line->get_objs_ref();
		# Iterator though all work in all lines
		foreach my $run (@{ $runs })
		{
			# The run must be non-empty
			my $tmp = $run->get_content();
			# Trim
			$tmp	=~ s/^\s+|\s+$//g;
			# Skip blank run
			if ($tmp eq "") { next; }

			# Set first word in run
			# $is_first_run = 1; 

			###
			# The following features are XML features
			###
			
			# Bold format	
			my $bold = ($run->get_bold() eq "true") ? "bold" : "none";
			
			# Italic format	
			my $italic = ($run->get_italic() eq "true") ? "italic" : "none";

			# Underline
			my $underline = ($run->get_underline() eq "true") ? "underline" : "none";

			# Sub-Sup-script
			my $suscript =	($run->get_suscript() eq "superscript")	? "super"	:
							($run->get_suscript() eq "subscript")	? "sub"		: "none";

			# Relative font size
			my $fontsize =	($run->get_font_size() > $dominate_font)	? "large"	:
							($run->get_font_size() < $dominate_font)	? "small"	: "normal";
			
			###
			# End of XML features
			###

			# All words in the run
			my $words = $run->get_objs_ref();

			# For each word
			foreach my $word (@{ $words })
			{
				# Extract features
				my $content = $word->get_content();
				# Trim
				$content	=~ s/^\s+|\s+$//g;

				# Skip blank run
				if ($content eq "") { next; }

				# Content
				$features .= $content . "\t";
			
				# Remove punctuation
				my $content_n	=~ s/[^\w]//g;
				# Lower case
				my $content_l	= lc($content);
				# Lower case, no punctuation
				my $content_nl	= lc($content_n);
				# Lower case
				$features .= $content_l . "\t";
				# Lower case, no punctuation
				if ($content_nl ne "")
				{
					$features .= $content_nl . "\t";
				}
				else
				{
					$features .= $content_l . "\t";
				}

				# Capitalization
				my $ortho = ($content =~ /^[\p{IsUpper}]$/)					? "single"	:
							($content =~ /^[\p{IsUpper}][\p{IsLower}]+/)	? "init" 	:
							($content =~ /^[\p{IsUpper}]+$/) 				? "all" 	: "others";
				$features .= $ortho . "\t";

				# Numeric property
				my $num =	($content =~ /^[0-9]$/)					? "1dig" 	:
							($content =~ /^[0-9][0-9]$/) 			? "2dig" 	:
							($content =~ /^[0-9][0-9][0-9]$/) 		? "3dig" 	:
							($content =~ /^[0-9]+$/) 				? "4+dig" 	:
							($content =~ /^[0-9]+(th|st|nd|rd)$/)	? "ordinal"	:
							($content =~ /[0-9]/) 					? "hasdig" 	: "nonnum";
				$features .= $num . "\t";

				# Last punctuation
				my $punct = ($content =~ /^[\"\'\`]/) 						? "leadq" 	:
							($content =~ /[\"\'\`][^s]?$/) 					? "endq" 	:
	  						($content =~ /\-.*\-/) 							? "multi"	:
	    					($content =~ /[\-\,\:\;]$/) 					? "cont" 	:
	      					($content =~ /[\!\?\.\"\']$/) 					? "stop" 	:
	        				($content =~ /^[\(\[\{\<].+[\)\]\}\>].?$/)		? "braces" 	: "others";
				$features .= $punct . "\t";

				# Split into character
	      		my @chars = split(//, $content);
				# Content length
				my $length =	(scalar(@chars) == 1)	? "1-char"	:
								(scalar(@chars) == 2)	? "2-char"	:
								(scalar(@chars) == 3)	? "3-char"	: "4+char";
				$features .= $length . "\t";
				# First n-gram
				$features .= $chars[ 0 ] . "\t";
				$features .= join("", @chars[ 0..1 ]) . "\t";
				$features .= join("", @chars[ 0..2 ]) . "\t";
				$features .= join("", @chars[ 0..3 ]) . "\t";
      			# Last n-gram
				$features .= $chars[ -1 ] . "\t";
				$features .= join("", @chars[ -2..-1 ]) . "\t";
				$features .= join("", @chars[ -3..-1 ]) . "\t";
				$features .= join("", @chars[ -4..-1 ]) . "\t";
			
				# Dictionary
				my $dict_status = (defined $dict{ $content_nl }) ? $dict{ $content_nl } : 0;
				# Possible names
				my ($publisher_name, $place_name, $month_name, $last_name, $female_name, $male_name) = undef;
   				# Check all case 
				if ($dict_status >= 32) { $dict_status -= 32; 	$publisher_name	= "publisher"	} else { $publisher_name	= "no"; }
	    		if ($dict_status >= 16)	{ $dict_status -= 16; 	$place_name 	= "place" 		} else { $place_name 		= "no"; }
	    		if ($dict_status >= 8)	{ $dict_status -= 8; 	$month_name 	= "month" 		} else { $month_name 		= "no"; }
    			if ($dict_status >= 4)	{ $dict_status -= 4; 	$last_name 		= "last" 		} else { $last_name 		= "no"; }
	    		if ($dict_status >= 2) 	{ $dict_status -= 2; 	$female_name 	= "female" 		} else { $female_name 		= "no"; }
    			if ($dict_status >= 1) 	{ $dict_status -= 1; 	$male_name 		= "male" 		} else { $male_name 		= "no"; }
	    		# Save the feature
				$features .= $male_name 	 . "\t";
				$features .= $female_name 	 . "\t";
				$features .= $last_name 	 . "\t";
				$features .= $month_name 	 . "\t";
				$features .= $place_name 	 . "\t";
				$features .= $publisher_name . "\t";

				# First word in line
				if ($is_first_line == 1)
				{
					$features .= "begin" . "\t";
	
					# Next words are not the first in line anymore
					$is_first_line = 0;
				}
				else	
				{
					$features .= "continue" . "\t";
				}		

				###
				# The following features are XML features
				###
			
				# Bold format	
				$features .= $bold . "\t";
			
				# Italic format	
				$features .= $italic . "\t";

				# Underline
				$features .= $underline . "\t";

				# Sub-Sup-script
				$features .= $suscript . "\t";

				# Relative font size
				$features .= $fontsize . "\t";

				# First word in run
				if (($prev_bold ne $bold) || ($prev_italic ne $italic) || ($prev_underline ne $underline) || ($prev_suscript ne $suscript) || ($prev_fontsize ne $fontsize))
				{
					$features .= "fbegin" . "\t";
	
					# Next words are not the first in line anymore
					# $is_first_run = 0;
				}
				else	
				{
					$features .= "fcontinue" . "\t";
				}

				# New token
				$features .= "\n";

				# Save the XML format
				$prev_bold		= $bold;
				$prev_italic	= $italic;
				$prev_underline	= $underline;
				$prev_suscript	= $suscript;
				$prev_fontsize	= $fontsize;
			}			
		}
	}

	return $features;
}

sub ReadDict 
{
  	my ($dictfile) = @_;

	# Absolute path
	my $dictfile_abs = File::Spec->rel2abs($dictfile);
	# Dictionary handle
	my $dict_handle	 = undef;
  	open ($dict_handle, "<:utf8", $dictfile_abs) || die "Could not open dict file $dictfile_abs: $!";

	my $mode = 0;
  	while (<$dict_handle>) 
	{
    	if (/^\#\# Male/) 			{ $mode = 1; }		# male names
    	elsif (/^\#\# Female/) 		{ $mode = 2; }		# female names
    	elsif (/^\#\# Last/) 		{ $mode = 4; }		# last names
    	elsif (/^\#\# Chinese/) 	{ $mode = 4; }		# last names
    	elsif (/^\#\# Months/) 		{ $mode = 8; }		# month names
    	elsif (/^\#\# Place/) 		{ $mode = 16; }		# place names
    	elsif (/^\#\# Publisher/)	{ $mode = 32; }		# publisher names
    	elsif (/^\#/) { next; }
    	else 
		{
      		chop;
      		my $key = $_;
      		my $val = 0;
			# Has probability
      		if (/\t/) { ($key,$val) = split (/\t/,$_); }

      		# Already tagged (some entries may appear in same part of lexicon more than once
      		if (! exists $dict{ $key })
			{
				$dict{ $key } = $mode;
      		} 
			else 
			{
				if ($dict{ $key } >= $mode) 
				{ 
					next; 
				}
				# Not yet tagged
				else 
				{ 
					$dict{ $key } += $mode; 
				}
      		}
    	}
  	}
  
	close ($dict_handle);
}

sub BuildTmpFile 
{
    my ($filename) = @_;
	
	my $tmpfile = $filename;
    $tmpfile 	=~ s/[\.\/]//g;
    $tmpfile 	.= $$ . time;
    
	# Untaint tmpfile variable
    if ($tmpfile =~ /^([-\@\w.]+)$/) 
	{
		$tmpfile = $1;
    }
    
    return "/tmp/$tmpfile"; # Altered by Min (Thu Feb 28 13:08:59 SGT 2008)
}

1;

















