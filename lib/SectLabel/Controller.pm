package SectLabel::Controller;

###
# This package is used to pull together various citation processing 
# modules in the SectLabel distribution, serving as a script for 
# handling the entire citation processing control flow.
#
# The ExtractSection subroutine should be the only needed API element 
# to return XML output.
#
# Luong Minh Thang 25 May, 09. 
# Adopted from Parscit Controller Isaac Councill, 07/23/07
###

require 'dumpvar.pl';

use strict;

# Dependencies
use FindBin;

# Local libraries
use SectLabel::Config;
use SectLabel::Tr2crfpp;
use SectLabel::PostProcess;
use CSXUtil::SafeText qw(cleanXML);

my $generic_sect_path = $FindBin::Bin . "/sectLabel/genericSectExtract.rb";

###
# Main API method for generating an XML document including all
# section data.  Returns a reference XML document.
###
sub ExtractSection 
{
    my ($text_file, $is_xml_output, $model_file, $dict_file, $func_file, $config_file, $is_xml_input, $is_debug, $for_parscit) = @_;

    if (!defined $model_file || $model_file eq "") 
	{
		die "Die in SectLabel::Controller::extractSection - need to specify modelFile\n";
    }

    if (!defined $config_file || $config_file eq "") 
	{
      	die "Die in SectLabel::Controller::extractSection - need to specify configFile\n";
    }

	# Classify section
	if (! $for_parscit)
	{
	    my ($status, $msg, $xml, $aut_lines, $aff_lines) = ExtractSectionImpl(	$text_file, 
																				$is_xml_output, 
																				$model_file, 
																				$dict_file, 
																				$func_file, 
																				$config_file, 
																				$is_xml_input, 
																				$is_debug,
																				$for_parscit	);

		if ($status > 0) 
		{
			return (\$xml, $aut_lines, $aff_lines);
	    } 
		else 
		{
			my $error = "Error: " . $msg;
			return (\$error, undef, undef);
    	}
	}
	else
	{
		my ($all_text, $cit_lines) = ExtractSectionImpl(	$text_file, 
															$is_xml_output, 
															$model_file, 
															$dict_file, 
															$func_file, 
															$config_file, 
															$is_xml_input, 
															$is_debug,
															$for_parscit	);
		return ($all_text, $cit_lines);
	}
}

###
# Main script for actually walking through the steps of document processing.
# Returns a status code (0 for failure), an error message (may be blank if 
# no error), a reference to an XML document.
#
# $is_token_level: flag to enable previous token-level model (for performance 
# comparison)
#
# TODO: catch errors and return $status < 0
###
sub ExtractSectionImpl 
{
	my ($text_file, $is_xml_output, $model_file, $dict_file, $func_file, $config_file, $is_xml_input, $is_debug, $for_parscit) = @_;

  	if ($is_debug)
	{
    	print STDERR "Model File = " . $model_file . "\n";
	    print STDERR "Config File = " . $config_file . "\n";
  	}
  
  	my ($status, $msg) = (1, "");

  	if (!open (IN, "<:utf8", $text_file)) { return (-1, "Could not open text file $text_file: $!"); }
    
  	my @text_lines	 = ();
  	my %blank_lines = ();
  	my $line_id		 = -1;

  	while (<IN>) 
	{
    	chomp;
		
		# Remove ^M character at the end of the file if any
		s/\cM$//; 

		$line_id++;

		# Skip blank lines
    	if (/^\s*$/) 
		{
      		if ($is_debug) { print STDERR "#! Warning blank line at line id " . $line_id . "\n"; }
			
			$blank_lines{ $line_id } = 1;
			next; 
    	} 
		else 
		{
      		push(@text_lines, $_);
    	}
  	}
  	close IN;

  	# Run tr2crfpp to prepare feature files
	my $tmp_file = undef;

	if ($is_debug) { print STDERR "\n# Extracting test features ... "; }
  	$tmp_file = SectLabel::Tr2crfpp::ExtractTestFeatures(\@text_lines, $text_file, $dict_file, $func_file, $config_file, $is_debug);

	if ($is_debug) { print STDERR " Done! Output to " . $tmp_file . "\n"; }

  	# Run crf_test, output2xml
  	my $out_file = $tmp_file . "_dec";

	my $xml = "";
	if ($is_debug) { print STDERR "\n# Decoding " . $tmp_file . " ... "; }

  	if (SectLabel::Tr2crfpp::Decode($tmp_file, $model_file, $out_file)) 
	{
    	if ($is_debug) { print STDERR " Done! Output to " . $out_file . "\n"; }

	    my %section_headers = ();

		$section_headers{ "header" } = (); # Array of section headers
	    $section_headers{ "lineId" } = (); # Array of corresponding line ids (0-based)
    
		if (!$is_xml_output)
		{
    	  	$xml = SectLabel::PostProcess::WrapDocument($out_file, \%blank_lines);
	    } 	
		else 
		{
    		$xml = SectLabel::PostProcess::WrapDocumentXml($out_file, \%section_headers);
      	
	  		# Array of generic headers
			$section_headers{ "generic" } = ();

			GetGenericHeaders( $section_headers{ "header" }, \@{ $section_headers{ "generic" } });

      		$xml = InsertGenericHeaders($xml, $section_headers{ "header" }, $section_headers{ "generic" }, $section_headers{ "lineId" });
    	}
 	}

	###
	# Huydhn: provide input for parscit
	###
	if ($for_parscit)
	{
		my ($all_text, $cit_lines) = SectLabel::PostProcess::GenerateParscitInput($out_file);
	
		unlink($tmp_file);
	  	unlink($out_file);
		return ($all_text, $cit_lines);
	}
	else
	{
		my ($aut_lines, $aff_lines) = SectLabel::PostProcess::GenerateAuthorAffiliation($out_file);

		unlink($tmp_file);
  		unlink($out_file);
		return ($status, $msg, $xml, $aut_lines, $aff_lines);
	}
}

###
# Thang v100401: method to get generic headers give a list of headers
###
sub GetGenericHeaders 
{
	my ($headers, $generic_headers) = @_;

	# Huydhn
	# Found no header
	if (! defined $headers) { return; };

	my $num_headers = scalar(@{ $headers });

	# Put the list of headers to file
  	my $header_file = "/tmp/" . NewTmpFile();

  	$generic_sect_path = UntaintPath($generic_sect_path);
	
	open(OF, ">:utf8", $header_file);
	for (my $i = 0; $i < $num_headers; $i++) { print OF $headers->[$i] . "\n"; }
	close OF;
  
	# Get a list of generic headers
  	my $cmd = $generic_sect_path . " " . $header_file . " " . $header_file . ".out";
  	system($cmd);

	open(IF, "<:utf8", $header_file . ".out");
	my $generic_count = 0;

	while(<IF>)
	{
    	chomp;
	    my $generic_header = $_;

		# Temporarily add in, to be removed once Emma's code updated
	    if($generic_header eq "related_works") { $generic_header = "related_work"; }

    	push @{ $generic_headers }, $generic_header;
    	$generic_count++;
  	}
  	close IF;
  
  	if ($num_headers != $generic_count) { die "Die: SectLabel::Controller::getGenericHeaders different in number of headers $num_headers vs. the number of generic headers $generic_count\n"; }

  	unlink($header_file);
  	unlink($header_file . ".out");
}

###
# Thang v100401: method to insert generic headers into previous label XML output (ids given for checking purpose)
###
sub InsertGenericHeaders 
{
	my ($xml, $headers, $generics, $line_ids) = @_;

	my @lines		= split(/\n/, $xml);
  	my $num_lines	= scalar( @lines );

	my $text_id			= -1;
	my $header_count	= 0;

  	for (my $i = 0; $i < $num_lines; $i++)
	{
    	my $line = $lines[$i];

		# Header line
		if ($line =~ /^<sectionHeader confidence=\"([\.\d]+)\">$/)
		{
			my $confidence = $1;

			# Header line
      		$line = $lines[ ++$i ]; 

			# Sanity check
			# After increase, $text_id is the current line id (base 0)
			$text_id++; 
			if ($line_ids->[ $header_count ] != $text_id) { die "Die in SectLabel::Controller::insertGenericHeaders - different text ids " . $line_ids->[ $header_count ] . " != " . $text_id . "\n"; }

      		my $generic_header	= $generics->[ $header_count ];
    		$lines[ $i - 1 ]	= "<sectionHeader confidence=\"" . $confidence . "\" genericHeader=\"" . $generic_header . "\">";
			# After increase, $headerCount is the number of header lines read
			$header_count++; 
      
      		# Finish reading all header lines (incase of multiple line header
      		# A text line
			while ($lines[$i+1] !~ /^<[\/\?]?[a-zA-Z]+/)
			{ 
				$i++;
				$header_count++;
				$text_id++;
			}
    	} 
		# A text line
		elsif ($line !~ /^<[\/\?]?[a-zA-Z]+/)
		{
      		$text_id++;
    	}
  	}
  
  	return join("\n", @lines);
}

###
# Thang v100401
###
sub UntaintPath 
{
	my ($path) = @_;

  	if ( $path =~ /^([-_\/\w\.\d: ]+)$/ ) 
	{
    	$path = $1;
  	} 
	else 
	{
    	die "Bad path " . $path . "\n";
  	}

	return $path;
}

###
# Thang v100401 method to generate tmp file name
###
sub NewTmpFile 
{
	my $tmpfile = `date '+%Y%m%d-%H%M%S-$$'`;

	chomp($tmpfile);
	$tmpfile = UntaintPath($tmpfile);
	return $tmpfile;
}

1;
