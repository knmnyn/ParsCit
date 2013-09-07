package ParsCit::Controller;

###
# This package is used to pull together various citation
# processing modules in the ParsCit distribution, serving
# as a script for handling the entire citation processing
# control flow.  The extractCitations subroutine should be
# the only needed API element if XML output is desired;
# however, the extractCitationsImpl subroutine can be used
# to get direct access to the list of citation objects.
#
# Isaac Councill, 07/23/07
###

require 'dumpvar.pl';

use strict;
# Local libraries
use ParsCit::Config;
use ParsCit::Tr2crfpp;
use ParsCit::PreProcess;
use ParsCit::PostProcess;
use ParsCit::CitationContext;
# Omnipage libraries
use Omni::Omnidoc;
# Dependencies
use CSXUtil::SafeText qw(cleanXML);

###
# Main API method for generating an XML document including
# all citation data.  Returns a reference XML document and
# a reference to the article body text.
###

# Extract citations from text
sub ExtractCitations 
{
    my ($text_file, $org_file, $is_xml) = @_;

	# Real works are in there
    my ($status, $msg, $citations, $body_text) = ExtractCitationsImpl($text_file, $org_file, $is_xml);

	# Check the result status
    if ($status > 0) 
	{
		return BuildXMLResponse($citations);
    } 
	else 
	{
		# Return error message
		my $error = "Error: " . $msg; return \$error;
    }
}

###
# Huydhn
# Extract citations from text
# The reference section will be provided by sectlabel.
# Previously, parscit find this section itself using 
# regular expression
###
sub ExtractCitations2
{
	my ($all_text, $cit_lines, $is_xml, $doc, $cit_addrs) = @_;

	# Real works are in there
    my ($status, $msg, $citations, $body_text) = ExtractCitationsImpl2($all_text, $cit_lines, $is_xml, $doc, $cit_addrs);

	# Check the result status
    if ($status > 0) 
	{
		return BuildXMLResponse($citations);
    } 
	else 
	{
		# Return error message
		my $error = "Error: " . $msg; return \$error;
    }	
}

sub ExtractCitationsAlreadySegmented 
{
    my ($text_file) = @_;

    my ($status, $msg) = (1, "");

	# Cannot open input file, return error message
    if (! open(IN, "<:utf8", $text_file)) {	return (-1, "Could not open file " . $text_file . ": " . $!); }

	#
    my @raw_citations		= ();
    my $current_citation	= undef;

	while (<IN>) 
	{
		# Remove eol
		chomp();
	
		# Save current citation
		if (m/^\s*$/ && defined $current_citation) 
		{
	    	my $cite = new ParsCit::Citation();
	    	$cite->setString($current_citation);
	    	push @raw_citations, $cite;
	    	$current_citation = undef;
	    	next;
		}

		# Current citation eq current line
		if (! defined $current_citation) 
		{
	    	$current_citation = $_;
		}
		# Append the current line to the current citation
		else 
		{
	    	$current_citation = $current_citation . " " . $_;
		}
    }

	# Close the input after reading
    close IN;

	# Save the last citation
	if (defined $current_citation) 
	{
		my $cite = new ParsCit::Citation();
		push @raw_citations, $cite;
    }

    my @citations 				= ();
    my @valid_citations			= ();
    my $normalized_cite_text	= "";

    foreach my $citation (@raw_citations) 
	{
		# Tr2cfpp needs an enclosing tag for initial class seed.
		my $cite_string = $citation->getString();

		if (defined $cite_string && $cite_string !~ m/^\s*$/) 
		{
	    	$normalized_cite_text .= "<title> " . $citation->getString() . " </title>\n";
			push @citations, $citation;
		}
    }

	# Stop - nothing left to do.
    if ($#citations < 0) { return ($status, $msg, \@valid_citations); }

    my $tmpfile = ParsCit::Tr2crfpp::PrepData(\$normalized_cite_text, $text_file);
    my $outfile = $tmpfile . "_dec";

    if (ParsCit::Tr2crfpp::Decode($tmpfile, $outfile))
	{
		my ($raw_xml, $cite_info, $tstatus, $tmsg) = ParsCit::PostProcess::ReadAndNormalize($outfile);

		if ($tstatus <= 0) { return ($tstatus, $msg, undef, undef); }

		my @all_cite_info = @{ $cite_info };

		if ($#citations == $#all_cite_info) 
		{
	    	for (my $i = 0; $i <= $#citations; $i++) 
			{
				my $citation	= $citations[ $i ];
				my %cite_hash	= %{ $all_cite_info[ $i ] };
				
				foreach my $key (keys %cite_hash)
				{
		    		$citation->loadDataItem($key, $cite_hash{ $key });
				}
		
				my $marker = $citation->getMarker();

				if (! defined $marker) 
				{
		    		$marker = $citation->buildAuthYearMarker();
		    		$citation->setMarker($marker);
				}
				
				push @valid_citations, $citation;
	    	}
		} 
		else 
		{
	    	$status	= -1;
	    	$msg	= "Mismatch between expected citations and cite info";
		}
    }

    unlink($tmpfile);
    unlink($outfile);

    return BuildXMLResponse(\@valid_citations);
}

# Thang: tmp method for debugging purpose
sub PrintArray 
{
	my ($filename, $tokens) = @_;
  	open(OF, ">:utf8", $filename);
  	foreach (@{ $tokens }) { print OF $_, "\n"; }
	close OF;
}

###
# Main script for actually walking through the steps of citation
# processing.  Returns a status code (0 for failure), an error 
# message (may be blank if no error), a reference to an array of 
# citation objects and a reference to the body text of the article
# being processed.
###
sub ExtractCitationsImpl 
{
    my ($textfile, $orgfile, $is_xml, $bwrite_split) = @_;

    if (! defined $bwrite_split) { $bwrite_split = $ParsCit::Config::bWriteSplit; }

  	if (!open (IN, "<:utf8", $textfile)) { return (-1, "Could not open text file $textfile: $!"); }
  	while (<IN>) 
	{
		
    	chomp;
		# Remove ^M character at the end of the file if any
		s/\cM$//; 

  	}
  	close IN;

	# Status and error message initialization
    my ($status, $msg) = (1, "");
	
	# NOTE: What are their purpose?
	my ($citefile, $bodyfile) = ("", "");
	# NOTE: What is its purpose?
	my @pos_array = (); 
	# Reference text, boby text, and normalize body text
	my ($rcite_text, $rnorm_body_text, $rbody_text) = undef;
	# Reference to an array of single reference
	my $rraw_citations = undef;

	# Find and separate reference
	if ($is_xml)
	{
		###
		# Huydhn: input is xml from Omnipage
		###
		if (! open(IN, "<:utf8", $orgfile)) { return (-1, "Could not open xml file " . $orgfile . ": " . $!); }
		my $xml = do { local $/; <IN> };
		close IN;

		###
		# Huydhn
		# NOTE: the omnipage xml is not well constructed (concatenated multiple xml files).
		# This merged xml need to be fixed first before pass it to xml processing libraries, e.g. xml::twig
		###
		# Convert to Unix format
		$xml =~ s/\r//g;
		# Remove <?xml version="1.0" encoding="UTF-8"?>
		$xml =~ s/<\?xml.+?>\n//g;
		# Remove <!--XML document generated using OCR technology from ScanSoft, Inc.-->
		$xml =~ s/<\!\-\-XML.+?>\n//g;
		# Declaration and root
		$xml = "<?xml version=\"1.0\"?>" . "\n" . "<root>" . "\n" . $xml . "\n" . "</root>";

		# New document
		my $doc = new Omni::Omnidoc();
		$doc->set_raw($xml);
		
		# Extract the reference portion from the XML
		my ($start_ref, $end_ref, $rcite_text_from_xml, $rcit_addrs) = ParsCit::PreProcess::FindCitationTextXML($doc);

		# Extract the reference portion from the text. 
		# TODO: NEED TO BE REMOVED FROM HERE
		my $content = $doc->get_content();
		($rcite_text, $rnorm_body_text, $rbody_text) = ParsCit::PreProcess::FindCitationText(\$content, \@pos_array);

		my @norm_body_tokens	= split(/\s+/, $$rnorm_body_text);
    	my @body_tokens			= split(/\s+/, $$rbody_text);

		my $size	= scalar(@norm_body_tokens);
    	my $size1	= scalar(@pos_array);

	    if($size != $size1) { die "ParsCit::Controller::extractCitationsImpl: normBodyText size $size != posArray size $size1\n"; }
		# TODO: TO HERE
		
		# Filename initialization
    	if ($bwrite_split > 0) { ($citefile, $bodyfile) = WriteSplit($textfile, $rcite_text_from_xml, $rbody_text); }

		# Prepare to split unmarked reference portion
		my $tmp_file = ParsCit::Tr2crfpp::PrepDataUnmarked($doc, $rcit_addrs);

		# Extract citations from citation text
	    $rraw_citations	= ParsCit::PreProcess::SegmentCitationsXML($rcite_text_from_xml, $tmp_file);
	}
	else
	{
		if (! open(IN, "<:utf8", $textfile)) { return (-1, "Could not open text file " . $textfile . ": " . $!); }
		my $text = do { local $/; <IN> };
		close IN;

		###
    	# Thang May 2010
	    # Map each position in norm_body_text to a position in body_text, scalar(@pos_array) = number of tokens in norm_body_text
		# TODO: Switch this function to sectlabel module
    	($rcite_text, $rnorm_body_text, $rbody_text) = ParsCit::PreProcess::FindCitationText(\$text, \@pos_array);

	    my @norm_body_tokens	= split(/\s+/, $$rnorm_body_text);
    	my @body_tokens			= split(/\s+/, $$rbody_text);

		my $size	= scalar(@norm_body_tokens);
    	my $size1	= scalar(@pos_array);

	    if($size != $size1) { die "ParsCit::Controller::extractCitationsImpl: normBodyText size $size != posArray size $size1\n"; }
    	# End Thang May 2010
		###

		# Filename initialization
    	if ($bwrite_split > 0) { ($citefile, $bodyfile) = WriteSplit($textfile, $rcite_text, $rbody_text); }

		# Extract citations from citation text
	    $rraw_citations	= ParsCit::PreProcess::SegmentCitations($rcite_text);
	}

	my @citations		= ();
    my @valid_citations	= ();

	# Process each citation
    my $normalized_cite_text = "";
    foreach my $citation (@{ $rraw_citations }) 
	{
		# Tr2cfpp needs an enclosing tag for initial class seed.
		my $cite_string = $citation->getString();
		if (defined $cite_string && $cite_string !~ m/^\s*$/) 
		{
	    	$normalized_cite_text .= "<title> " . $citation->getString() . " </title>\n";
	    	push @citations, $citation;
		}
    }

	# Stop - nothing left to do.
    if ($#citations < 0) { return ($status, $msg, \@valid_citations, $rnorm_body_text); }

    my $tmpfile = ParsCit::Tr2crfpp::PrepData(\$normalized_cite_text, $textfile);
    my $outfile = $tmpfile . "_dec";

    if (ParsCit::Tr2crfpp::Decode($tmpfile, $outfile)) 
	{
		my ($rraw_xml, $rcite_info, $tstatus, $tmsg) = ParsCit::PostProcess::ReadAndNormalize($outfile);
		if ($tstatus <= 0) { return ($tstatus, $msg, undef, undef); }

		my @cite_info = @{ $rcite_info };

		if ($#citations == $#cite_info) 
		{
	    	for (my $i = 0; $i <= $#citations; $i++) 
			{
				my $citation	= $citations[ $i ];
				my %cite_info	= %{ $cite_info[ $i ] };
				
				foreach my $key (keys %cite_info) 
				{
		    		$citation->loadDataItem($key, $cite_info{ $key });
				}
		
				my $marker = $citation->getMarker();
				if (!defined $marker) 
				{
		    		$marker = $citation->buildAuthYearMarker();
		    		$citation->setMarker($marker);
				}
				
				###
				# Modified by Nick Friedrich$ref_lines->[ 0 ]
				### getCitationContext returns contexts and the position of the contexts
				###
				# Thang: Nov 2009 add $rcit_strs - in-text ciation strs
				###
				my ($rcontexts, $rpositions, $start_word_positions, $end_word_positions, $rcit_strs) = ParsCit::CitationContext::GetCitationContext($rnorm_body_text, 
																																					\@pos_array, 
																																					$marker);

				###
				# Thang May 2010: add $rWordPositions, $rBodyText to find word-based positions (0-based) according to the *.body file
				###

				foreach my $context (@{ $rcontexts }) 				
				{
					# Next citation context
		    		$citation->addContext($context);
		    		
					# Next citation position
					my $position = shift @{ $rpositions };
		    		$citation->addPosition($position);
		    
					##
		    		# Thang: Nov 2009, add $rcit_strs
					###
					# Next citation string
		    		my $cit_str = shift @{ $rcit_strs };
		    		$citation->addCitStr($cit_str);
		    		# End Thang: Nov 2009

		    		# Next start and end of citation
					my $start_pos	= shift @{ $start_word_positions };
		    		my $end_pos		= shift @{ $end_word_positions };

		    		$citation->addStartWordPosition( $pos_array[ $start_pos ] );
		    		$citation->addEndWordPosition( $pos_array[ $end_pos ] );
					# print STDERR $cit_str, " --> ", $body_tokens[ $pos_array[ $start_pos ] ], " \t ", $pos_array[ $start_pos], " ### "; 
					# print STDERR $pos_array[ $end_pos], " \t ", $body_tokens[ $pos_array[ $end_pos ] ], "\n";
				}
		
				push @valid_citations, $citation;
	    	}
		} 
		else 
		{
	    	$status	= -1;
	    	$msg	= "Mismatch between expected citations and cite info";
		}
    }

    unlink($tmpfile);
    unlink($outfile);

	# Our work here is done
    return ($status, $msg, \@valid_citations, $rbody_text, $citefile, $bodyfile);
}

###
# Huydhn
# New function for citation extraction based on the output
# of sectlabel
###
sub ExtractCitationsImpl2
{
	my ($all_text, $cit_lines, $is_xml, $doc, $cit_addrs) = @_;

	# Status and error message initialization
    my ($status, $msg) = (1, "");
	
	# NOTE: What is its purpose?
	my @pos_array = (); 
	# Reference text, boby text, and normalize body text
	my ($rcite_text, $rnorm_body_text, $rbody_text) = undef;
	# Reference to an array of single reference
	my $rraw_citations = undef;

	# Find and separate reference
	if ($is_xml)
	{
		# TODO: NEED TO BE REMOVED FROM HERE
		($rcite_text, $rnorm_body_text, $rbody_text) = ParsCit::PreProcess::FindCitationText2($all_text, $cit_lines, \@pos_array);

		my @norm_body_tokens	= split(/\s+/, $$rnorm_body_text);
    	my @body_tokens			= split(/\s+/, $$rbody_text);

		my $size	= scalar(@norm_body_tokens);
    	my $size1	= scalar(@pos_array);

	    if($size != $size1) { die "ParsCit::Controller::extractCitationsImpl: normBodyText size $size != posArray size $size1\n"; }
		# TODO: TO HERE
		
		# Prepare to split unmarked reference portion
		my $tmp_file = ParsCit::Tr2crfpp::PrepDataUnmarked($doc, $cit_addrs);
		# Extract citations from citation text
	    $rraw_citations	= ParsCit::PreProcess::SegmentCitationsXML($rcite_text, $tmp_file);
		# Remove the temporary file
		unlink $tmp_file;
	}
	else
	{
		###
    	# Thang May 2010
	    # Map each position in norm_body_text to a position in body_text, scalar(@pos_array) = number of tokens in norm_body_text
		# TODO: Switch this function to sectlabel module
		###
    	($rcite_text, $rnorm_body_text, $rbody_text) = ParsCit::PreProcess::FindCitationText2($all_text, $cit_lines, \@pos_array);

	    my @norm_body_tokens	= split(/\s+/, $$rnorm_body_text);
    	my @body_tokens			= split(/\s+/, $$rbody_text);

		my $size	= scalar(@norm_body_tokens);
    	my $size1	= scalar(@pos_array);

	    if($size != $size1) { die "ParsCit::Controller::extractCitationsImpl: normBodyText size $size != posArray size $size1\n"; }
    	# End Thang May 2010
		###

		# Extract citations from citation text
	    $rraw_citations	= ParsCit::PreProcess::SegmentCitations($rcite_text);
	}

	my @citations		= ();
    my @valid_citations	= ();

	# Process each citation
    my $normalized_cite_text = "";
    foreach my $citation (@{ $rraw_citations }) 
	{
		# Tr2cfpp needs an enclosing tag for initial class seed.
		my $cite_string = $citation->getString();
		if (defined $cite_string && $cite_string !~ m/^\s*$/) 
		{
	    	$normalized_cite_text .= "<title> " . $citation->getString() . " </title>\n";
	    	push @citations, $citation;
		}
    }

	# Stop - nothing left to do.
    if ($#citations < 0) { return ($status, $msg, \@valid_citations, $rnorm_body_text); }

    my $tmpfile = ParsCit::Tr2crfpp::PrepData(\$normalized_cite_text, "");
    my $outfile = $tmpfile . "_dec";

    if (ParsCit::Tr2crfpp::Decode($tmpfile, $outfile)) 
	{
		my ($rraw_xml, $rcite_info, $tstatus, $tmsg) = ParsCit::PostProcess::ReadAndNormalize($outfile);
		if ($tstatus <= 0) { return ($tstatus, $msg, undef, undef); }

		my @cite_info = @{ $rcite_info };

		if ($#citations == $#cite_info) 
		{
	    	for (my $i = 0; $i <= $#citations; $i++) 
			{
				my $citation	= $citations[ $i ];
				my %cite_info	= %{ $cite_info[ $i ] };
				
				foreach my $key (keys %cite_info) 
				{
		    		$citation->loadDataItem($key, $cite_info{ $key });
				}
		
				my $marker = $citation->getMarker();
				if (!defined $marker) 
				{
		    		$marker = $citation->buildAuthYearMarker();
		    		$citation->setMarker($marker);
				}

				###
				# Modified by Nick Friedrich$ref_lines->[ 0 ]
				### getCitationContext returns contexts and the position of the contexts
				###
				# Thang: Nov 2009 add $rcit_strs - in-text ciation strs
				###
				my ($rcontexts, $rpositions, $start_word_positions, $end_word_positions, $rcit_strs) = ParsCit::CitationContext::GetCitationContext($rnorm_body_text, 
																																					\@pos_array, 
																																					$marker);

				###
				# Thang May 2010: add $rWordPositions, $rBodyText to find word-based positions (0-based) according to the *.body file
				###

				foreach my $context (@{ $rcontexts }) 				
				{
					# Next citation context
		    		$citation->addContext($context);
		    		
					# Next citation position
					my $position = shift @{ $rpositions };
		    		$citation->addPosition($position);
		    
					##
		    		# Thang: Nov 2009, add $rcit_strs
					###
					# Next citation string
		    		my $cit_str = shift @{ $rcit_strs };
		    		$citation->addCitStr($cit_str);
		    		# End Thang: Nov 2009

		    		# Next start and end of citation
					my $start_pos	= shift @{ $start_word_positions };
		    		my $end_pos		= shift @{ $end_word_positions };

		    		$citation->addStartWordPosition( $pos_array[ $start_pos ] );
		    		$citation->addEndWordPosition( $pos_array[ $end_pos ] );
					# print STDERR $cit_str, " --> ", $body_tokens[ $pos_array[ $start_pos ] ], " \t ", $pos_array[ $start_pos], " ### "; 
					# print STDERR $pos_array[ $end_pos], " \t ", $body_tokens[ $pos_array[ $end_pos ] ], "\n";
				}
		
				push @valid_citations, $citation;
	    	}
		} 
		else 
		{
	    	$status	= -1;
	    	$msg	= "Mismatch between expected citations and cite info";
		}
    }

    unlink($tmpfile);
    unlink($outfile);

	# Our work here is done
    return ($status, $msg, \@valid_citations, $rbody_text);
}

# Write citation list in xml format 
sub BuildXMLResponse 
{
    my ($rcitations) = @_;

    my $l_alg_name		= $ParsCit::Config::algorithmName;
    my $l_alg_version	= $ParsCit::Config::algorithmVersion;

    cleanXML(\$l_alg_name);
    cleanXML(\$l_alg_version);

    my $xml	= "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" . "<algorithm name=\"$l_alg_name\" " . "version=\"$l_alg_version\">\n";
    $xml	= $xml . "<citationList>\n";

	# Write output
    foreach my $citation (@$rcitations) { $xml .= $citation->toXML(); }

    $xml .= "</citationList>\n";
    $xml .= "</algorithm>\n";
    return \$xml;
} 

# 
sub WriteSplit 
{
    my ($textfile, $rcite_text, $rbody_text) = @_;

    my $citefile = ChangeExtension($textfile, "cite");
    my $bodyfile = ChangeExtension($textfile, "body");

    if (open(OUT, ">$citefile")) 
	{
		binmode OUT, ":utf8";
		print 	OUT $$rcite_text;
		close 	OUT;
    } 
	else 
	{
		print STDERR "Could not open .cite file for writing: $!\n";
    }

    if (open(OUT, ">$bodyfile")) 
	{
		binmode OUT, ":utf8";
		print 	OUT $$rbody_text;
		close 	OUT;
    } 
	else 
	{
		print STDERR "Could not open .body file for writing: $!\n";
    }

	# Our work here is done
    return ($citefile, $bodyfile);
} 

# Support function: change the extension of a file
sub ChangeExtension 
{
    my ($fn, $ext) = @_;
    unless ($fn =~ s/^(.*)\..*$/$1\.$ext/) { $fn .= "." . $ext; }
    return $fn;
} 

1;
