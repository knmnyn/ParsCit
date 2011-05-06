#!/usr/bin/perl -wT

# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Thu, 08 Apr 2010 17:59:19
# Modified from template by Min-Yen Kan <kanmy@comp.nus.edu.sg>

require 5.0;
use strict;
# Dependencies
use Getopt::Long;
use FindBin;

# I do not know a better solution to find a lib path in -T mode.
# So if you know a better solution, I'd be glad to hear.
# See this http://www.perlmonks.org/?node_id=585299 for why I used the below code

# To get correct path in case 2 scripts in different directories use FindBin
FindBin::again();
my $path = undef;
BEGIN 
{
	if ($FindBin::Bin =~ /(.*)/) { $path = $1; }
}
use lib "$path/../lib";

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
	print STDERR "Convert SectLabel training file (e.g. doc/sectLabel.tagged.txt) from single- to multi-line format\n";
  	print STDERR "usage: $progname -h\t[invokes help]\n";
  	print STDERR "       $progname -in infile -out outfile [-p prefix]\n";
  	print STDERR "Options:\n";
  	print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
  	print STDERR "\t-p\tIndicate that the XML tag in input file will have the format <\$prefix\$tag> .+ </\$prefix\$tag> (default prefix = \"\"\n";
}
my $quite	= 0;
my $help	= 0;
my $infile	= undef;
my $outfile	= undef;
my $prefix	= "";

$help = 1 unless GetOptions(	'in=s'	=> \$infile,
								'out=s'	=> \$outfile,
								'p=s'	=> \$prefix,
								'h'		=> \$help,
								'q'		=> \$quite	);

if ($help || ! defined $infile || ! defined $outfile) 
{
	Help();
  	exit(0);
}

if (! $quite) 
{
	License();
}

### Untaint ###
$infile			= UntaintPath($infile);
$outfile		= UntaintPath($outfile);
$ENV{'PATH'}	= '/bin:/usr/bin:/usr/local/bin';
### End untaint ###

# What the heck
ProcessFile($infile, $outfile);

sub ProcessFile
{
	my ($infile, $outfile) = @_;
  
	open(IF, "<:utf8", $infile)	 || die "#Can't open file \"$infile\"";
  	open(OF, ">:utf8", $outfile) || die "#Can't open file \"$outfile\"";
  
  	binmode(STDERR, ":utf8");

  	my $line_id = 0;
	# Read input file, line by line
  	while(<IF>)
	{
		# Skip comments
		if (/^\#/) 
		{ 
			next; 
		}
		# Skip blank lines
    	elsif (/^\s+$/) 
		{ 
			next; 
		}
    	else 
		{
			# Remove end of line
      		chomp;
			# and save the line
			my $line = $_;
			
			# Match <tag> .* </tag>
			while ($line =~ /<$prefix([\w\-]+?)> (.*?) \+L\+ <\/$prefix([\w\-]+?)>/g)
			{
				if($1 ne $3)
				{
	  				die "Die in single2multi.pl $line_id: begin tag \"$1\" ne end tag \"$3\"\n";
				} 
				else 
				{
	  				my $tag		= $1;
					my $content	= $2;
					# Split the single-line into multi-line
					my @lines	= split(/ \+L\+ /, $content);

					foreach my $line (@lines)
					{
	    				if ($line eq "") { next; }
	    				print OF "$tag ||| $line\n";
	  				}
				} 
      		}
      
      		my $post_match = $';			
			if ($post_match !~ /^\s*$/)	{ die "Die in single2multi.pl $line_id: non-empty post match \"$post_match\"\n"; }
			# Separate documents
			print OF "\n"; 
      		$line_id++;
    	}
  	}
  
  	close IF;
  	close OF;
}

sub UntaintPath 
{
	my ($path) = @_;

  	if ($path =~ /^([-_\/\w\.\d: ]+)$/)
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
  
  	if ($s =~ /^([\w \-\@\(\),\.\/<>]+)$/) 
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
  chomp	 $tmp_file;
  return $tmp_file;
}





