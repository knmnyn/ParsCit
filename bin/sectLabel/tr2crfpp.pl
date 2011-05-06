#!/usr/bin/perl -T

# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Tue, 02 Jun 2009 01:30:42
# Modified from template by Min-Yen Kan <kanmy@comp.nus.edu.sg>

=pod HISTORY
	MODIFIED: by Luong Minh thang <luongmin@comp.nus.edu.sg> to generate features at line level for parsHed 
	ORIGIN: created from tr2crfpp.pl by Min-Yen Kan <kanmy@comp.nus.edu.sg>
=cut

require 5.0;
use strict;
# Dependencies
use FindBin;
use Getopt::Long;

# I do not know a better solution to find a lib path in -T mode.
# So if you know a better solution, I'd be glad to hear.
# See this http://www.perlmonks.org/?node_id=585299 for why I used the below code
my $path = undef;
BEGIN 
{
	if ($FindBin::Bin =~ /(.*)/) { $path = $1; }
}
use lib "$path/../../lib";

# Local libraries
use SectLabel::Config;
use SectLabel::Tr2crfpp;

### USER customizable section
$0 =~ /([^\/]+)$/; my $progname = $1;
my $version = "1.0";
### END user customizable section

sub License 
{
	print STDERR "# Copyright 2009 \251 by Luong Minh Thang\n";
}

sub Help 
{
	print STDERR "Generate SectLabel features for CRF++\n";
  	print STDERR "usage: $progname -h\t[invokes help]\n";
  	print STDERR "       $progname -in infile -c config -out outfile [-template -single]\n";
  	print STDERR "Options:\n";
  	print STDERR "\t-q       \tQuiet Mode (don't echo license)\n";
  	print STDERR "\t-in      \tLabeled input file\n";
  	print STDERR "\t-c       \tTo specify which feature set to use.\n";
  	print STDERR "\t-out     \tOutput file for CRF++ training.\n";
  	print STDERR "\t-template\tTo output a template used by CRF++ according to the config file.\n";
  	print STDERR "\t-single  \tIndicate that each input document is in single-line format (e.g., doc/sectLabel.tagged.txt)\n";
}

my $quite		= 0;
my $help		= 0;
my $infile		= undef;
my $outfile		= undef;

my $dict_file	= undef;
$dict_file		= $SectLabel::Config::dictFile;
$dict_file 		= $FindBin::Bin . "/../../" . $dict_file;

my $func_file	= undef;
$func_file		= $SectLabel::Config::funcFile;
$func_file		= $FindBin::Bin . "/../../" . $func_file;

my $config_file	= undef;
my $is_template	= 0;
my $is_single	= 0;

$help = 1 unless GetOptions(	'in=s'		=> \$infile,
								'out=s'		=> \$outfile,
								'c=s'		=> \$config_file,
								'single'	=> \$is_single,
								'template'	=> \$is_template,
								'h'			=> \$help,
								'q'			=> \$quite	);

if ($help || ! defined $infile || ! defined $outfile || ! defined $config_file) 
{
	Help();
  	exit(0);
}

if (!$quite) 
{
	License();
}

### Untaint ###
$infile			= UntaintPath($infile);
$outfile		= UntaintPath($outfile);
$config_file	= UntaintPath($config_file);
$ENV{'PATH'}	= '/bin:/usr/bin:/usr/local/bin';
### End untaint ###

if ($is_single)
{
	# Convert to multiline format
	Execute("$FindBin::Bin/single2multi.pl -in $infile -out $infile.multi -p \"SectLabel_\"");
  	$infile .= ".multi";
}

SectLabel::Tr2crfpp::Tr2crfpp($infile, $outfile, $dict_file, $func_file, $config_file, $is_template);

if ($is_single)
{
	unlink($infile);
}

sub UntaintPath 
{
	my ($path) = @_;

  	if ($path =~ /^([-_\/\w\.]*)$/) 
	{
    	$path = $1;
  	} 
	else 
	{
    	die "Bad path $path\n";
  	}

  return $path;
}

sub Untaint 
{
	my ($s) = @_;
  	if ($s =~ /^([\w \-\@\(\),\.\/\_\"]+)$/) 
	{
    	$s = $1;               # Untainted
  	} 
	else 
	{
    	die "Bad data in $s";  # Log this somewhere
  	}
  
  	return $s;
}

sub Execute 
{
	my ($cmd) = @_;
  	print STDERR "Executing: $cmd\n";
  	$cmd = Untaint($cmd);
  	system($cmd);
}

sub NewTmpFile 
{
	my $tmp_file = `date '+%Y%m%d-%H%M%S-$$'`;

	chomp	$tmp_file;
  	return	$tmp_file;
}

