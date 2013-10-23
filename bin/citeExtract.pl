#!/usr/bin/perl
# -*- cperl -*-
#!/usr/bin/perl -CSD
=head1 NAME

 citeExtract.pl

=head1 SYNOPSYS

 RCS:$Id$

=head1 DESCRIPTION

 Simple command script for executing ParsCit in an
 offline mode (direct API call instead of going through
 the web service).

=head1 HISTORY

 ORIGIN: created from templateApp.pl version 3.4 by Min-Yen Kan <kanmy@comp.nus.edu.sg>

 Min-Yen Kan, 15 Jul 2009.
 Minh-Thang Luong, 25 May 2009.
 Isaac Councill, 08/23/07

=cut

require 5.0;

use FindBin;
use Getopt::Std;

use strict 'vars';
use lib $FindBin::Bin . "/../lib";

use lib "/home/huydhn/perl5/lib";
use lib "/home/wing.nus/tools/languages/programming/perl-5.10.0/lib/5.10.0";
use lib "/home/wing.nus/tools/languages/programming/perl-5.10.0/lib/site_perl/5.10.0";

# Dependencies
use File::Spec;
use File::Basename;

# Local libraries
use Omni::Omnidoc;
use Omni::Traversal;
use ParsCit::Controller;
use SectLabel::AAMatching;
use ParsCit::PreProcess;

# USER customizable section
my $tmpfile	.= $0; 
$tmpfile	=~ s/[\.\/]//g;
$tmpfile	.= $$ . time;

# Untaint tmpfile variable
if ($tmpfile =~ /^([-\@\w.]+)$/) { $tmpfile = $1; }

$tmpfile		= "/tmp/" . $tmpfile;
$0				=~ /([^\/]+)$/;
my $progname	= $1;

my $PARSCIT		= 1;
my $PARSHED		= 2;
my $SECTLABEL	= 4; # Thang v100401

my $default_input_type	= "raw";
my $output_version		= "110505";
my $biblio_script		= $FindBin::Bin . "/BiblioScript/biblio_script.sh";
my $default_mode		= $PARSCIT;
# END user customizable section

# Ctrl-C handler
sub quitHandler 
{
	print STDERR "\n# $progname fatal\t\tReceived a 'SIGINT'\n# $progname - exiting cleanly\n";
	exit;
}

# HELP sub-procedure
sub Help 
{
	print STDERR "usage: $progname -h\t\t\t\t[invokes help]\n";
	print STDERR "       $progname -v\t\t\t\t[invokes version]\n";
	print STDERR "       $progname [-qt] [-m <mode>] [-i <inputType>] [-e <exportType>] <filename> [outfile]\n";
	print STDERR "Options:\n";
	print STDERR "\t-q\tQuiet Mode (don't echo license)\n";

	# Thang v100401: add new mode (extract_section), and -i <inputType>
	print STDERR "\t-m <mode>	   \tMode (extract_citations, extract_header, extract_section, extract_meta, extract_all, default: extract_citations)\n";
	print STDERR "\t-i <inputType> \tType (raw, xml, default: raw)\n";
	print STDERR "\t-e <exportType>\tExport citations into multiple types (ads|bib|end|isi|ris|wordbib). Multiple types could be specified by contatenating with \"-\" e.g., bib-end-ris. Output files will be named as outfile.exportFormat, with outfile being the input argument, and exportFormat being each individual format supplied by -e option.\n";
	print STDERR "\t-t\tUse token level model instead\n";
	print STDERR "\n";
	print STDERR "Will accept input on STDIN as a single file.\n";
}

# VERSION sub-procedure
sub Version 
{
	if (system ("perldoc $0")) { die "Need \"perldoc\" in PATH to print version information"; }
	exit;
}

# MAIN program
my $cmd_line = $0 . " " . join (" ", @ARGV);

# Invoked with no arguments, error in execution
if ($#ARGV == -1)
{ 		        
	print STDERR "# $progname info\t\tNo arguments detected, waiting for input on command line.		\n";
	print STDERR "# $progname info\t\tIf you need help, stop this program and reinvoke with \"-h\".	\n";
	exit(-1);
}

$SIG{'INT'} = 'quitHandler';
getopts ('hqm:i:e:tva');

our ($opt_q, $opt_v, $opt_h, $opt_m, $opt_i, $opt_e, $opt_t, $opt_a);

# Use (!defined $opt_X) for options with arguments
if ($opt_v) 
{ 
	# call Version, if asked for
	Version(); 
	exit(0); 
}

if ($opt_h) 
{ 
	# call help, if asked for
	Help(); 
	exit (0); 
}

my $mode		= (!defined $opt_m) ? $default_mode : ParseMode($opt_m);
my $ph_model	= (defined $opt_t) ? 1 : 0;

my $in		= shift;	# input file
my $out		= shift;	# if available

# Convert line endings from Mac style, if so
# Canocicalizes carriage return, line feed characters 
# at line ending
ParsCit::PreProcess::canolicalizeEOL($in);

# Output buffer
my $rxml	= "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<algorithms version=\"" . $output_version . "\">\n";

###
# Thang v100401: add input type option, and SectLabel
###
my $is_xml_input = 0;
if (defined $opt_i && $opt_i !~ /^(xml|raw)$/)
{
	print STDERR "#! Input type needs to be either \"raw\" or \"xml\"\n";
	Help(); 
	exit (0);
} 
elsif (defined $opt_i && $opt_i eq "xml")
{
	$is_xml_input = 1;
}

###
# Thang v100901: add export type option & incorporate BibUtils
###
my @export_types = ();
if (defined $opt_e && $opt_e ne "")
{
	# Sanity checks
	# No call to extract_citation
	if (($mode & $PARSCIT) != $PARSCIT) 
	{ 
		print STDERR "#! Export type option is only available for the following modes: extract_citations, extract_meta and extract_all\n";
		Help(); exit(0);
	}
	
	if (! defined $out)
	{
		print STDERR "#! Export type option requires output file name to be specified\n";
		Help(); exit(0);
	}

	# Get individual export types
	my %type_hash	= ();
	my @tokens		= split(/\-/, $opt_e);
	foreach my $token (@tokens) 
	{
		if($token !~ /^(ads|bib|end|isi|ris|wordbib)$/)
		{
			print STDERR "#! Invalid export type \"$token\"\n";
			Help(); 
			exit (0);
		}
		
		$type_hash{ $token } = 1;
	}

	# Get all export types sorted
	@export_types = sort { $a cmp $b } keys %type_hash;
}

my $doc			= undef;
my $text_file	= undef;
# Extracting text from Omnipage XML output
if ($is_xml_input)
{
	$text_file	= "/tmp/" . NewTmpFile();
	my $cmd		= $FindBin::Bin . "/sectLabel/processOmniXMLv2.pl -q -in $in -out $text_file -decode";
	system($cmd);

	###
	# Huydhn: input is xml from Omnipage
	###
	if (! open(IN, "<:utf8", $in)) { return (-1, "Could not open xml file " . $in . ": " . $!); }
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
	$doc = new Omni::Omnidoc();
	$doc->set_raw($xml);
} 
else 
{
	$text_file	= $in;
}

# SECTLABEL
if (($mode & $SECTLABEL) == $SECTLABEL)
{ 
	my $sect_label_input = $text_file;

	# Get XML features and append to $text_file
	if ($is_xml_input)
	{
		my $cmd	= $FindBin::Bin . "/sectLabel/processOmniXMLv3.pl -q -in $in -out $text_file.feature -decode";
		system($cmd);

		my $address_file = $text_file . ".feature" . ".address";
		if (! open(IN, "<:utf8", $address_file)) { return (-1, "Could not open address file " . $address_file . ": " . $!); }
		
		my @omni_address = ();
		# Read the address file provided by process OmniXML script
		while (<IN>)
		{
			chomp;
			# Save and split the line
			my $line	= $_;
			my @element	= split(/\s+/, $line);

			my %addr		= ();
			# Address
			$addr{ 'L1' }	= $element[ 0 ];
			$addr{ 'L2' }	= $element[ 1 ];
			$addr{ 'L3' }	= $element[ 2 ];
			$addr{ 'L4' }	= $element[ 3 ];

			# Save the address
			push @omni_address, { %addr };
		}
		close IN;
		unlink($address_file);

		$sect_label_input .= ".feature";
		my ($sl_xml, $aut_lines, $aff_lines) = SectLabel($sect_label_input, $is_xml_input, 0);

		# Remove first line <?xml/>
		$rxml .= RemoveTopLines($sl_xml, 1) . "\n";
	
		# Only run author - affiliation if "something" is provided
		if ($opt_a)
		{
			my @aut_addrs = ();
			my @aff_addrs = ();
			# Address of author section	
			for my $lindex (@{ $aut_lines }) { push @aut_addrs, $omni_address[ $lindex ]; }
			# Address of affiliation section
			for my $lindex (@{ $aff_lines }) { push @aff_addrs, $omni_address[ $lindex ]; }

			# The tarpit
			my $aa_xml = SectLabel::AAMatching::AAMatching($doc, \@aut_addrs, \@aff_addrs);
		
			# Author-Affiliation Matching result
			$rxml .= $aa_xml . "\n";
		}

		# Remove XML feature file
		unlink($sect_label_input);
	}
	else
	{
		my ($sl_xml, $aut_lines, $aff_lines) = SectLabel($sect_label_input, $is_xml_input, 0);

		# Remove first line <?xml/>
		$rxml .= RemoveTopLines($sl_xml, 1) . "\n";
	}
}

# PARSHED
if (($mode & $PARSHED) == $PARSHED) 
{
	use ParsHed::Controller;

	my $ph_xml	= ParsHed::Controller::extractHeader($text_file, $ph_model); 
	
	# Remove first line <?xml/> 
	$rxml		.= RemoveTopLines($$ph_xml, 1) . "\n";
}

# PARSCIT
if (($mode & $PARSCIT) == $PARSCIT)
{
    my ($all_text, $cit_lines);
	if ($is_xml_input)
	{
		my $cmd	= $FindBin::Bin . "/sectLabel/processOmniXMLv3.pl -q -in $in -out $text_file.feature -decode";
		system($cmd);

		my $address_file = $text_file . ".feature" . ".address";
		if (! open(IN, "<:utf8", $address_file)) { return (-1, "Could not open address file " . $address_file . ": " . $!); }
		
		my @omni_address = ();
		# Read the address file provided by process OmniXML script
		while (<IN>)
		{
			chomp;
			# Save and split the line
			my $line	= $_;
			my @element	= split(/\s+/, $line);

			my %addr		= ();
			# Address
			$addr{ 'L1' }	= $element[ 0 ];
			$addr{ 'L2' }	= $element[ 1 ];
			$addr{ 'L3' }	= $element[ 2 ];
			$addr{ 'L4' }	= $element[ 3 ];

			# Save the address
			push @omni_address, { %addr };
		}
		close IN;
		unlink($address_file);

		my $sect_label_input = $text_file . ".feature";
		# Output of sectlabel becomes input for parscit
		($all_text, $cit_lines) = SectLabel($sect_label_input, $is_xml_input, 1);	
		# Remove XML feature file
		unlink($sect_label_input);

		my @cit_addrs = ();
		# Address of reference section	
		for my $lindex (@{ $cit_lines }) { push @cit_addrs, $omni_address[ $lindex ]; }

		my $pc_xml = undef;
		# Huydhn: add xml features to parscit in case of unmarked reference
		$pc_xml = ParsCit::Controller::ExtractCitations2(\$all_text, $cit_lines, $is_xml_input, $doc, \@cit_addrs);

		# Remove first line <?xml/> 
		$rxml .= RemoveTopLines($$pc_xml, 1) . "\n";

		# Thang v100901: call to BiblioScript
		if (scalar(@export_types) != 0) { BiblioScript(\@export_types, $$pc_xml, $out); }
	}
	else
	{

        # Issue 13 resolution : Rerouting SectLabel Output to ParsCit - Ankur #

		#my $pc_xml = ParsCit::Controller::ExtractCitations($text_file, $in, $is_xml_input);

		($all_text, $cit_lines) = SectLabel($text_file, $is_xml_input, 1);
        my $cit_addrs = 0;
		my $pc_xml = ParsCit::Controller::ExtractCitations2(\$all_text, $cit_lines, $is_xml_input, $doc, $cit_addrs);

        #----------------------------

		# Remove first line <?xml/> 
		$rxml .= RemoveTopLines($$pc_xml, 1) . "\n";

		# Thang v100901: call to BiblioScript
		if (scalar(@export_types) != 0) { BiblioScript(\@export_types, $$pc_xml, $out); }
	}
}

$rxml .= "</algorithms>";

if (defined $out) 
{
	open (OUT, ">:utf8", $out) or die $progname . " fatal\tCould not open \"" . $out . "\" for writing: $!";
	print OUT $rxml;
	close OUT;
} 
else 
{
	print $rxml;
}

# Clean-up step
if ($is_xml_input)
{
	# PARSCIT
	if (($mode & $PARSCIT) == $PARSCIT) 
	{ 
		# Get the normal .body .cite files
        my $filename = $text_file . ".body";
        if(-e $filename){
            system("mv $text_file.body $in.body");
            system("mv $text_file.cite $in.cite");
        }
	}

	unlink($text_file);
}

# END of main program

sub ParseMode 
{
	my $arg = shift;

	if ($arg eq "extract_meta") 
	{
		return ($PARSCIT | $PARSHED);
	} 
	elsif ($arg eq "extract_header") 
	{
		return $PARSHED;
	} 
	elsif ($arg eq "extract_citations") 
	{
		return $PARSCIT;
	} 
	elsif ($arg eq "extract_section") 
	{
		return $SECTLABEL;
	} 
	elsif ($arg eq "extract_all") 
	{
		return ($PARSHED | $PARSCIT | $SECTLABEL);
	} 
	else 
	{
		Help();
		exit(-1);
	}
}

# Remove top n lines
sub RemoveTopLines 
{
	my ($input, $top_n) = @_;

	# Remove first line <?xml/> 
	my @lines = split (/\n/, $input);
	for(my $i = 0; $i < $top_n; $i++)
	{
		shift(@lines);
	}

	return join("\n", @lines);
}

###
# Thang v100401: generate section info
###
sub SectLabel 
{
	my ($text_file, $is_xml_input, $for_parscit) = @_;

	use SectLabel::Config;
	use SectLabel::Controller;

	my $is_xml_output	= 1;
	my $is_debug		= 0;

	my $model_file	= $is_xml_input ? $SectLabel::Config::modelXmlFile : $SectLabel::Config::modelFile;
	$model_file		= "$FindBin::Bin/../$model_file";

	my $dict_file	= $SectLabel::Config::dictFile;
	$dict_file		= "$FindBin::Bin/../$dict_file";

	my $func_file	= $SectLabel::Config::funcFile;
	$func_file		= "$FindBin::Bin/../$func_file";

	my $config_file	= $is_xml_input ? $SectLabel::Config::configXmlFile : $SectLabel::Config::configFile;
	$config_file	= "$FindBin::Bin/../$config_file";

	# Classify section
	if (! $for_parscit)
	{
		my ($sl_xml, $aut_lines, $aff_lines) = SectLabel::Controller::ExtractSection(	$text_file, 
																						$is_xml_output, 
																						$model_file, 
																						$dict_file, 
																						$func_file, 
																						$config_file, 
																						$is_xml_input, 
																						$is_debug,
																						$for_parscit	);
		return ($$sl_xml, $aut_lines, $aff_lines);
	}
	# Huydhn: sectlabel output -> parscit input
	else
	{
		my ($all_text, $cit_lines) = SectLabel::Controller::ExtractSection(	$text_file, 
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
# Thang v100901: incorporate BiblioScript
###
sub BiblioScript 
{
	my ($types, $pc_xml, $outfile) = @_;

	my @export_types	= @{ $types };
	my $tmp_dir			= "/tmp/" . NewTmpFile();
	system("mkdir -p $tmp_dir");

	# Write extract_citation output to a tmp file
	my $filename		= "$tmp_dir/input.txt";

	open(OF, ">:utf8", $filename);
	print OF $pc_xml;
	close OF;

	# Call to BiblioScript
	my $size	= scalar(@export_types);
	my $format	= $export_types[0];
	my $cmd		= $biblio_script . " -q -i parscit -o " . $format . " " . $filename . " " . $tmp_dir;

	system($cmd);
	system("mv $tmp_dir/parscit.$format $outfile.$format");

	# Reuse the MODS file generated in the first call
	for (my $i = 1; $i < $size; $i++)
	{
		$format	= $export_types[$i];
		$cmd	= $biblio_script . " -q -i mods -o " . $format . " " . $tmp_dir . "/parscit_mods.xml " . $tmp_dir;

		system($cmd);
		system("mv $tmp_dir/parscit.$format $outfile.$format");
	}

	system("rm -rf " . $tmp_dir);
}

# Method to generate tmp file name
sub NewTmpFile 
{
	my $tmpfile	= `date '+%Y%m%d-%H%M%S-$$'`;
	chomp  $tmpfile;
	return $tmpfile;
}



