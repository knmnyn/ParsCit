#!/usr/bin/perl -w

use strict;

# Perl version
require 5.0; 

use lib "/home/huydhn/perl5/lib";
use lib "/home/wing.nus/services/parscit/tools/doc/lib";

# Dependencies
use CGI;
use CGI::Carp;
use CGI::Upload;

use File::Temp;
use File::Slurp;
use File::Basename;

use IO::Compress::Gzip qw(gzip);

# Local libraries
use Wing::Cache;

# Maximum file size, 128MB
$CGI::POST_MAX = 1024 * 1024 * 10;
# We don't accept "anything"
my $safe_filename_characters = "a-zA-Z0-9_.-";

# Internal key
my $key = "wing";
# Load threshold
my $threshold = 2;

# Storage
my $upload_dir  = "/home/wing.nus/tmp";
# OCR toolset
my $ocr_toolset = "/home/wing.nus/local/bin/ocr";
# OCR server
my $ocr_server  = "tpe.ddns.comp.nus.edu.sg:31586";

# Get the uploaded file
my $check   = new CGI;
my $query	= new CGI::Upload;
my $content	= $query->file_handle("content");

# Check load if possible to do demo
if ($check->param('key') ne $key && IsHighLoad()) {
	print "content-type: text/xml\n\n";
	print "<?xml version=\"1.0\" encoding=\"utf-8\"?>";
	print "<algorithms>Highload</algorithms>";
	# Premature exit
	exit;
}

if ((! defined $content) || ($content eq "")) 
{
	print "Content-Type: text/xml\n\n";
	print "<?xml version=\"1.0\" encoding=\"utf-8\"?>";
	print "<algorithms>Blank</algorithms>";
	# Premature exit
	exit ;
}

my $gzip_ok = undef;
# Check the environment variable HTTP_ACCEPT_ENCODING for the value "gzip".
my $accept_encoding = $ENV{HTTP_ACCEPT_ENCODING};
if (defined $accept_encoding && $accept_encoding =~ /\bgzip\b/) {
    $gzip_ok = 0;
}

# What the heck
if ($gzip_ok) {
	print "Content-Type: text/xml\n";
    print "Content-Encoding: gzip\n\n";
} else {
	print "Content-Type: text/xml\n\n";
}

my $htmp  = File::Temp->new(DIR => $upload_dir);
# Get the temporary unique filename
my $id	  = $htmp->filename;
my $ppath = $id;
my $xpath = $id . "-omni";
	
my $buf = undef;
# Save the uploaded file
open my $output_handle, ">", $ppath or die "$!"; binmode $output_handle;
while (read($content, $buf, 1024)) { print $output_handle $buf; }
close $output_handle;

my $compressed = undef;
# OCR the file
if (defined Ocr($ppath, $xpath)) {

	if ($gzip_ok) {
		# Compress by gzip
		gzip $xpath => \$compressed or die "$!";
	} else {
		$compressed = read_file( $xpath );
	}

	# Final output
	print $compressed;
} else {
	my $tmp = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><algorithms>Blank</algorithms>";

	if ($gzip_ok) {
		# Compress by gzip
		gzip \$tmp => \$compressed or die "$!";
	} else {
		$compressed = $tmp;
	}

	# Final output
	print $compressed;
}

# Done
unlink $xpath;

# OCR the PDF using Omnipage
sub Ocr
{
	my ($pdf_path, $omni_path) = @_;

	# Validity check
	if (! Verify($pdf_path)) { return undef; }

	my $option = "xml";
	my $cmd = $ocr_toolset . " " . $pdf_path . " " . $omni_path . " " . $option . " " . $ocr_server;
	system($cmd);
	
	# Validity check
	if (! Verify($omni_path)) { return undef; }

	# Return the temporary file
	return $omni_path;
}

sub Verify
{
	my ($inFile) = @_;
	
	my $status = 1;
	if(!-e $inFile)
	{
		$status = 0;
	} 
	else
	{
		my $numLines = `wc -l < $inFile`;
		chomp($numLines);
		if($numLines == 0)
		{
			print STDERR "! File $inFile has no content\n";
			$status = 0;
		}
	}

	return $status;
}

sub IsHighLoad
{
	my $load = `uptime`;
	
	$load =~ /load average: ([\d.]+)/i;
	$load = $1;
	
	if ($load > $threshold) { return 1; } else { return 0; }
}












