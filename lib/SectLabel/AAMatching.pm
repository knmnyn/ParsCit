package SectLabel::AAMatching;

###
# This package provides methods to solve the matching problem
# between author and affiliation in a pdf
#
# Do Hoang Nhat Huy 21 Apr, 11
###

use strict;

# Dependencies
use POSIX;
use IO::File;
use XML::Writer;
use XML::Writer::String;

use	Class::Struct;

# Local libraries
use SectLabel::Config;
use ParsCit::PostProcess;

# Dictionary
my %dict = ();
# CRF++
my $crft = $ENV{'CRFPP_HOME'} ? "$ENV{'CRFPP_HOME'}/bin/crf_test" : "$FindBin::Bin/../$SectLabel::Config::crf_test";

# Matching features of each author, including
# Signals
# Coordinations: top, bottom, left, right
# Position: page, sections, paragraph, line
struct aut_rcfeatures =>
{
	signals	=> '@',	

	top		=> '$',
	bottom	=> '$',
	left	=> '$',
	right	=> '$',

	page 	=> '$',
	section	=> '$',
	para	=> '$',
	line	=> '$'
};

# Matching features of each affiliation, including
# Signals
# Coordinations: top, bottom, left, right
# Position: page, sections, paragraph, line
struct aff_rcfeatures =>
{
	signals	=> '@',	

	top		=> '$',
	bottom	=> '$',
	left	=> '$',
	right	=> '$',

	page 	=> '$',
	section	=> '$',
	para	=> '$',
	line	=> '$'
};

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
	ReadDict($FindBin::Bin . "/../" . $SectLabel::Config::dictFile);

	# Authors
	my ($aut_features, $aut_rc_features) = AuthorFeatureExtraction($aut_lines, $aut_addrs);
	# Call CRF
	my ($aut_signal, $aut_rc) = AuthorExtraction($aut_features, $aut_rc_features);

	# Affiliations
	my ($aff_features, $aff_rc_features) = AffiliationFeatureExtraction($aff_lines, $aff_addrs);
	# Call CRF
	my ($aff_signal, $aff_rc, $affs) = AffiliationExtraction($aff_features, $aff_rc_features);

	# Matching features
	my $aa_features = AAFeatureExtraction($aut_rc, $aff_rc);
	# Matching
	my $aa			= AAMatchingImp($aa_features);

=pod
	# DEBUG
	my $aut_handle	= undef;
	my $aff_handle	= undef;
	my $aau_handle	= undef;
	my $aaf_handle	= undef;
	my $aut_debug	= undef;
	my $aff_debug	= undef;
	my $aa_handle	= undef;

	open $aut_handle, ">:utf8", "aut.features"; 
	open $aff_handle, ">:utf8", "aff.features"; 
	open $aau_handle, ">:utf8", "aau.features"; 
	open $aaf_handle, ">:utf8", "aaf.features"; 
	open $aut_debug, ">:utf8", "aut.debug.features"; 
	open $aff_debug, ">:utf8", "aff.debug.features"; 
	open $aa_handle, ">:utf8", "aa.features"; 

	print $aut_handle $aut_features;
	print $aff_handle $aff_features;
	print $aau_handle $aut_rc_features;
	print $aaf_handle $aff_rc_features;
	print $aa_handle $aa_features, "\n";

	foreach my $author (keys %{ $aut_rc } )
	{
		print $aut_debug $author, ": ", "\n";

		foreach my $signal (@{ $aut_rc->{ $author }->signals })
		{
			print $aut_debug "\t", $signal, "\n";
		}

		print $aut_debug "\t", $aut_rc->{ $author }->top, "\n";
		print $aut_debug "\t", $aut_rc->{ $author }->bottom, "\n";
		print $aut_debug "\t", $aut_rc->{ $author }->left, "\n";
		print $aut_debug "\t", $aut_rc->{ $author }->right, "\n";

		print $aut_debug "\t", $aut_rc->{ $author }->page, "\n";
		print $aut_debug "\t", $aut_rc->{ $author }->section, "\n";
		print $aut_debug "\t", $aut_rc->{ $author }->para, "\n";
		print $aut_debug "\t", $aut_rc->{ $author }->line, "\n";
	}

	foreach my $affiliation (keys %{ $aff_rc } )
	{
		print $aff_debug $affiliation, ": ", "\n";
		
		foreach my $signal (@{ $aff_rc->{ $affiliation }->signals })
		{
			print $aff_debug "\t", $signal, "\n";
		}

		print $aff_debug "\t", $aff_rc->{ $affiliation }->top, "\n";
		print $aff_debug "\t", $aff_rc->{ $affiliation }->bottom, "\n";
		print $aff_debug "\t", $aff_rc->{ $affiliation }->left, "\n";
		print $aff_debug "\t", $aff_rc->{ $affiliation }->right, "\n";

		print $aff_debug "\t", $aff_rc->{ $affiliation }->page, "\n";
		print $aff_debug "\t", $aff_rc->{ $affiliation }->section, "\n";
		print $aff_debug "\t", $aff_rc->{ $affiliation }->para, "\n";
		print $aff_debug "\t", $aff_rc->{ $affiliation }->line, "\n";
	}

	close $aut_handle;
	close $aff_handle;
	close $aau_handle;
	close $aaf_handle;
	close $aut_debug;
	close $aff_debug;
	close $aa_handle;
	# END
=cut

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
=pod
		foreach my $signal (@{ $aut_signal->{ $author } })
		{
			$signal =~ s/^\s+|\s+$//g;
			# Skip blank
			if ($signal eq "") { next; }

			$writer->startTag("institution", "symbol" => $signal);
			$writer->characters($aff_signal->{ $signal });
			$writer->endTag("institution");
		}
=cut

		foreach my $affiliation (@{ $aa->{ $author } })
		{
			$writer->startTag("institution");
			$writer->characters($affiliation);
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

# Features of the relational classifier between author and affiliation
sub AAFeatureExtraction
{
	my ($aut_rc, $aff_rc) = @_;	

	# Relational features
	my $features = "";

	# Features between x authors
	foreach my $author (keys %{ $aut_rc })
	{
		my @aut_tokens	= split /\s/, $author;
		my $author_nb	= join '|||', @aut_tokens;

		my $min_aff_x	= undef;
		my $min_dist_x	= LONG_MAX;
		my $min_aff_y	= undef;
		my $min_dist_y	= LONG_MAX;
		# Find the nearest affiliation
		foreach my $aff (keys %{ $aff_rc })
		{
			my $aut_x = ($aut_rc->{ $author }->left + $aut_rc->{ $author }->right) / 2;
			my $aut_y = ($aut_rc->{ $author }->top + $aut_rc->{ $author }->bottom) / 2;

			my $aff_x = ($aff_rc->{ $aff }->left + $aff_rc->{ $aff }->right) / 2;
			my $aff_y = ($aff_rc->{ $aff }->top + $aff_rc->{ $aff }->bottom) / 2;

			my $dis_x = abs( $aut_x - $aff_x );
			my $dis_y = abs( $aut_y - $aff_y );
			# Distance between an author and an affiliation
			# my $distance = sqrt( $dis_x * $dis_x + $dis_y * $dis_y );

			# Check if it it the minimum distance in x axis
			if ($dis_x < $min_dist_x)
			{
				$min_dist_x	= $dis_x;
				$min_aff_x	= $aff;
			}

			# Check if it it the minimum distance in y axis
			if ($dis_y < $min_dist_y)
			{
				$min_dist_y	= $dis_y;
				$min_aff_y	= $aff;
			}
		}

		# and y affiliation
		foreach my $aff (keys %{ $aff_rc })
		{
			my @aff_tokens	= split /\s/, $aff;
			my $aff_nb		= join '|||', @aff_tokens;
		
			# Content
			$features .= $author_nb . "#" . $aff_nb . "\t";

			my $signal = undef;
			# Signal
			if ((scalar(@{ $aut_rc->{ $author }->signals }) == 0) || (scalar(@{ $aff_rc->{ $aff }->signals }) == 0))
			{
				$signal = "diff";
			}
			else
			{
				my $matched = undef;
				# Check each author signal
				foreach my $aut_sig (@{ $aut_rc->{ $author }->signals })
				{
					# if it match with affiliation signal
					if ($aut_sig eq ${ $aff_rc->{ $aff }->signals }[ 0 ]) { $matched = 1; last; }
				}

				$signal = (! defined $matched) ? "diff" : "same";
			}
			
			# Signal
			$features .= $signal . "\t";

			# Same page
			my $page = ($aut_rc->{ $author }->page == $aff_rc->{ $aff }->page) ? "yes" : "no";
			$features .= $page . "\t";

			my $section = undef;
			# Same section
			if ($page eq "yes")
			{
				$section = ($aut_rc->{ $author }->section == $aff_rc->{ $aff }->section) ? "yes" : "no";
				$features .= $section . "\t";
			}
			else
			{
				$section = "no";
				$features .= $section . "\t";
			}

			my $para = undef;
			# Same paragraph
			if (($page eq "yes") && ($section eq "yes"))
			{
				$para = ($aut_rc->{ $author }->para == $aff_rc->{ $aff }->para) ? "yes" : "no";
				$features .= $para . "\t";
			}
			else
			{
				$para = "no";
				$features .= $para . "\t";
			}

			my $line = undef;
			# Same line
			if (($page eq "yes") && ($section eq "yes") && ($para eq "yes"))
			{
				$line = ($aut_rc->{ $author }->line == $aff_rc->{ $aff }->line) ? "yes" : "no";
				$features .= $line . "\t";
			}
			else
			{
				$line = "no";
				$features .= $line . "\t";
			}

			# Is neartest affiliation in x axis ?
			my $nearest_x = ($aff eq $min_aff_x) ? "yes" : "no";
			$features 	 .= $nearest_x . "\t";

			# Is neartest affiliation in y axis ?
			my $nearest_y = ($aff eq $min_aff_y) ? "yes" : "no";
			$features 	 .= $nearest_y . "\n";
		}
	}

	return $features; 
}

# Actually do the matching between author and affiliation
sub AAMatchingImp
{
	my ($features) = @_;	

	# Temporary input file for CRF
	my $infile	= BuildTmpFile("aa-input");
	# Temporary output file for CRF
	my $outfile	= BuildTmpFile("aa-output");

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
			print $output_handle "\n";	
		}
		else
		{
			print $output_handle $line, "\t", "no", "\n"; 
		}
	}
	# Done
	close $output_handle;

	# AA matching model
	my $match_model = $SectLabel::Config::matFile; 

	# Matching
  	system("$crft -m $match_model $infile > $outfile");

	# List of authors and their affiliation (if exists)
	my %aa = ();

	my $input_handle = undef;
	# Read the CRF output
	open $input_handle, "<:utf8", $outfile;
	# Read each line and get its label
	while (<$input_handle>)
	{
		my $line = $_;
		# Trim
		$line =~ s/^\s+|\s+$//g;
		# Blank linem, what the heck ?
		if ($line eq "") { next; }

		# Split the line
		my @fields	= split /\t/, $line;
		# and extract the class and the content
		my $class	= $fields[ -1 ];
		my $content	= $fields[ 0 ];

		# You miss 
		if ($class ne "yes") { next; }

		# Split the content into author name and affiliation name
		my @tmp		= split /#/, $content;
		# Author name
		my $author	= $tmp[ 0 ];
		$author		=~ s/\|\|\|/ /g;
		# Affiliation name
		my $aff		= $tmp[ 1 ];
		$aff		=~ s/\|\|\|/ /g;

		# Save
		if (! exists $aa{ $author }) { $aa{ $author } = (); }
		# Save
		push @{ $aa{ $author } }, $aff;
	}
	
	# Done
	close $input_handle;
	
	# Clean up
	unlink $infile;
	unlink $outfile;
	# Done
	return (\%aa);
}

# Extract affiliation and their signal using crf
sub AffiliationExtraction
{
	my ($features, $rc_features) = @_;

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
			print $output_handle "\n";	
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
  	system("$crft -m $aff_model $infile > $outfile");

	# Each affiliation can have only one signal
	my %asg = ();
	# Each affilitiaon can have only one struct
	my %aaf	= ();
	# List of all affiliations
	my @aff = ();

	# Each line in the relational features string
	my @rc_lines = split /\n/, $rc_features;

	my $input_handle = undef;
	# Read the CRF output
	open $input_handle, "<:utf8", $outfile;
	# Author and signal string
	my $prev_class	= "";
	my @aff_str		= (); 
	my $signal_str	= "";
	# Relational classifier
	my @aaf_rc		= ();
	# Line counter
	my $counter		= 0;
	# Next to last signal
	my $ntl_signal	= "";
	# Read each line and get its label
	# TODO: The code assumes that an affiliation will have the following format: 1 foobar institute
	while (<$input_handle>)
	{
		my $line = $_;
		# Trim
		$line =~ s/^\s+|\s+$//g;
		# Blank line mark the end of an affiliation section
		if ($line eq "")
		{
			if ($prev_class eq "affiliation")
			{
				my ($affiliation, $rcs) = NormalizeAffiliationName(\@aff_str, \@aaf_rc);
				# Save the affiliation
				push @aff, $affiliation;
				# and its signal
				if ($ntl_signal ne "") { $asg{ $ntl_signal } = $affiliation; }

				# Save the signal
				push @{ $rcs->signals }, $ntl_signal;
				# Save the record
				$aaf{ $affiliation } = $rcs;
			}
			elsif ($prev_class eq "signal")
			{
				# Save the next to last signal
				$ntl_signal = NormalizeAffiliationSignal($signal_str);
			}

			# Cleanup
			$ntl_signal = "";
			# Cleanup
			@aff_str 	= ();
			$signal_str = "";
			$prev_class = "";
			# Cleanup
			@aaf_rc		= ();

			# Update the counter
			$counter++;

			next ;
		}

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
				push @aff_str, $content;
				push @aaf_rc, $rc_lines[ $counter ];
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
				my ($affiliation, $rcs) = NormalizeAffiliationName(\@aff_str, \@aaf_rc);
				# Save the affiliation
				push @aff, $affiliation;
				# and its signal
				if ($ntl_signal ne "") { $asg{ $ntl_signal } = $affiliation; }

				# Save the signal
				push @{ $rcs->signals }, $ntl_signal;
				# Save the record
				$aaf{ $affiliation } = $rcs;

			}
			elsif ($prev_class eq "signal")
			{
				# Save the next to last signal
				$ntl_signal = NormalizeAffiliationSignal($signal_str);
			}

			# Cleanup
			@aff_str 	= ();
			$signal_str = "";
			@aaf_rc		= ();
			# Switch to the current class
			$prev_class = $class;

			if ($class eq "affiliation")
			{
				push @aff_str, $content;
				push @aaf_rc, $rc_lines[ $counter ];
			}
			elsif ($class eq "signal")
			{
				$signal_str .= $content . " ";	
			}
		}

		# Update the counter
		$counter++;
	}

	# Final class
	if ($prev_class eq "affiliation")
	{
		my ($affiliation, $rcs) = NormalizeAffiliationName(\@aff_str, \@aaf_rc);
		# Save the affiliation
		push @aff, $affiliation;
		# and its signal
		if ($ntl_signal ne "") { $asg{ $ntl_signal } = $affiliation; }

		# Save the signal
		push @{ $rcs->signals }, $ntl_signal;
		# Save the record
		$aaf{ $affiliation } = $rcs;
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
	return (\%asg, \%aaf, \@aff);
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
	my ($aff_str, $aaf_rc) = @_;

	# Constraint
	if (scalar(@{ $aff_str }) != scalar(@{ $aaf_rc })) { print STDERR "# It cannot happen, if you encounter it, please consider report it as a bug", "\n"; die; }

	# Affiliation string
	my $affiliation = join ' ', @{ $aff_str };

	# First word
	my @fields = split /\s/, $aaf_rc->[ 0 ];
	# Save the relational features of an affiliation (its first word)
	my $rcs	= aff_rcfeatures->new(	signals => [],
									top => $fields[ 1 ], bottom => $fields[ 2 ], left => $fields[ 3 ], right => $fields[ 4 ],
									page => $fields[ 5 ], section => $fields[ 6 ], para => $fields[ 7 ], line => $fields[ 8 ]	);
	# Done
	return ($affiliation, $rcs);
}

# Extract author name and their signal using crf
sub AuthorExtraction
{
	my ($features, $rc_features) = @_;

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
			print $output_handle "\n";	
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
  	system("$crft -m $author_model $infile > $outfile");

	# Each author can have one or more signals
	my %asg = ();
	# Each author can have only one struct	
	my %aas = ();

	# Each line in the relational features string
	my @rc_lines = split /\n/, $rc_features;

	my $input_handle = undef;
	# Read the CRF output
	open $input_handle, "<:utf8", $outfile;
	# Author and signal string
	my $prev_class	= "";
	my @author_str	= ();
	my $signal_str	= "";
	# Relational classifier
	my @author_rc	= ();
	# Line counter
	my $counter		= 0;
	# Next to last authors
	my %ntl_asg 	= ();
	#
	my $is_authors	= 0;
	# Read each line and get its label
	while (<$input_handle>)
	{
		my $line = $_;
		# Trim
		$line =~ s/^\s+|\s+$//g;
		# Blank line mark the end of an author section
		if ($line eq "") 
		{ 
			if ($prev_class eq "author")
			{
				my ($authors, $rcs) = NormalizeAuthorNames(\@author_str, \@author_rc);
				# Save each author
				for (my $i = 0; $i < scalar(@{ $authors }); $i++)
				{
					$asg{ $authors->[ $i ] } 		= ();
					$aas{ $authors->[ $i ] }		= $rcs->[ $i ];
					$ntl_asg{ $authors->[ $i ] }	= 0;
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
						push @{ $aas{ $author }->signals }, $signal;
					}
				}
			}

			# Cleanup 
			%ntl_asg = ();
			# Cleanup
			@author_str = ();
			$signal_str = "";
			@author_rc	= ();
			# Cleanup
			$prev_class = "";

			# Update the counter
			$counter++;

			#
			$is_authors = 0;

			next; 
		}
		
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
				push @author_str, $content;
				push @author_rc, $rc_lines[ $counter ];
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
				my ($authors, $rcs) = NormalizeAuthorNames(\@author_str, \@author_rc);
				# Save each author
				for (my $i = 0; $i < scalar(@{ $authors }); $i++)
				{
					$asg{ $authors->[ $i ] } 		= ();
					$aas{ $authors->[ $i ] }		= $rcs->[ $i ];
					$ntl_asg{ $authors->[ $i ] }	= 0;
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
						push @{ $aas{ $author }->signals }, $signal;
					}
				}
			}

			# Clean the next to last author list if this current class is author
			if (($is_authors == 0) && ($class eq "author")) { %ntl_asg = (); $is_authors = 1; }
			#
			if ($class eq "signal") { $is_authors = 0; }

			# Cleanup
			@author_str = ();
			$signal_str = "";
			@author_rc	= ();
			# Switch to the current class
			$prev_class = $class;

			if ($class eq "author")
			{
				push @author_str, $content;
				push @author_rc, $rc_lines[ $counter ];
			}
			elsif ($class eq "signal")
			{
				$signal_str .= $content . " ";	
			}
		}

		# Update the counter
		$counter++;
	}

	# Final class
	if ($prev_class eq "author")
	{
		my ($authors, $rcs) = NormalizeAuthorNames(\@author_str, \@author_rc);
		# Save each author
		for (my $i = 0; $i < scalar(@{ $authors }); $i++)
		{
			$asg{ $authors->[ $i ] } 		= ();
			$aas{ $authors->[ $i ] }		= $rcs->[ $i ];
			$ntl_asg{ $authors->[ $i ] }	= 0;
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
				push @{ $aas{ $author }->signals }, $signal;
			}
		}
	}

	# Done
	close $input_handle;
	
	# Clean up
	unlink $infile;
	unlink $outfile;
	# Done
	return (\%asg, \%aas);
}

sub NormalizeAuthorNames
{
	my ($author_str, $author_rc) = @_;

	# Constraint
	if (scalar(@{ $author_str }) != scalar(@{ $author_rc })) { print STDERR "# It cannot happen, if you encounter it, please consider report it as a bug", "\n"; die; }

	# Mark the beginning of an author name
	my $begin	= 1;
	# and its corresponding relational features
	my $rcbegin	= 0;

	my @current	= ();
	my @authors	= ();
	my @rcs		= ();
	# Check all tokens in the author string
	for (my $i = 0; $i < scalar(@{ $author_str }); $i++)
	{
		my $token = $author_str->[ $i ];
	
		# Mark the end of an author name
		if ($token =~ m/^(&|and|,|;)$/i) 
		{
	    	if (scalar(@current) != 0) 
			{ 
				push @authors, ParsCit::PostProcess::NormalizeAuthorName(@current);

				# Save the relational features of an author (its first word)
				my @fields = split /\s/, $author_rc->[ $rcbegin ];
				# Create new record
				my $tmp	= aut_rcfeatures->new(	signals => [], 
												top => $fields[ 1 ], bottom => $fields[ 2 ], left => $fields[ 3 ], right => $fields[ 4 ],
												page => $fields[ 5 ], section => $fields[ 6 ], para => $fields[ 7 ], line => $fields[ 8 ]	);
				# Save the record
				push @rcs, $tmp;
			}

			# Cleanup
	    	@current	= ();
	    	$begin		= 1;

	    	next;
		}

		# Mark the begin of an author name
		if ($begin == 1) 
		{
	    	push @current, $token;

	    	$begin 	 = 0;
			$rcbegin = $i;

	    	next;
		}

		# Author name ending with a comma
		if ($token =~ m/,$/) 
		{
	    	push @current, $token;

			if (scalar(@current) != 0) 
			{ 
				push @authors, ParsCit::PostProcess::NormalizeAuthorName(@current);

				# Save the relational features of an author (its first word)
				my @fields = split /\s/, $author_rc->[ $rcbegin ];
				# Create new record
				my $tmp	= aut_rcfeatures->new(	signals => [], 
												top => $fields[ 1 ], bottom => $fields[ 2 ], left => $fields[ 3 ], right => $fields[ 4 ],
												page => $fields[ 5 ], section => $fields[ 6 ], para => $fields[ 7 ], line => $fields[ 8 ]	);
				# Save the record
				push @rcs, $tmp;
			}
			
			# Cleanup
	    	@current	= ();
	    	$begin		= 1;
		}
		# or it's just parts of the name
		else 
		{
	    	push @current, $token;
		}
	}

	# Last author name
	if (scalar(@current) != 0) 
	{
		push @authors, ParsCit::PostProcess::NormalizeAuthorName(@current);

		# Save the relational features of an author (its first word)
		my @fields = split /\s/, $author_rc->[ $rcbegin ];
		# Create new record
		my $tmp	= aut_rcfeatures->new(	signals => [], 
										top => $fields[ 1 ], bottom => $fields[ 2 ], left => $fields[ 3 ], right => $fields[ 4 ],
										page => $fields[ 5 ], section => $fields[ 6 ], para => $fields[ 7 ], line => $fields[ 8 ]	);
		# Save the record
		push @rcs, $tmp;
    }

	# Done
	return (\@authors, \@rcs); 
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
	my ($aff_lines, $aff_addrs) = @_;

	# NOTE: Relational classifier features
	my $rc_features		= "";

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
	$dominate_font = $sorted[ 0 ];

	my $size_mismatch = undef;
	# TODO: serious error if the size of aff_lines and the size of aff_addrs mismatch
	if (scalar(@{ $aff_lines }) != scalar(@{ $aff_addrs })) 
	{ 	
		$size_mismatch = 1;
		# Print the error but still try to continue
		print STDERR "# Total number of affiliation lines (" . scalar(@{ $aff_lines }) . ") != Total number of affiliation addresses (" . scalar(@{ $aff_addrs }) . ")." . "\n";
	}

	my $prev_page = undef;
	my $prev_sect = undef;
	my $prev_para = undef;
	# Each line contains many runs
	for (my $counter = 0; $counter < scalar(@{ $aff_lines }); $counter++)
	{
		# Get the line object
		my $line = $aff_lines->[ $counter ];

		# Check the size of aff_lines and aff_addrs
		if (! defined $size_mismatch)
		{
			# Check if two consecutive lines are from two different sections 
			if (! defined $prev_page)
			{
				# Init
				$prev_page = $aff_addrs->[ $counter ]->{ 'L1' };
				$prev_sect = $aff_addrs->[ $counter ]->{ 'L2' };
				$prev_para = $aff_addrs->[ $counter ]->{ 'L3' };
			}
			else
			{
				# Affiliations from different sections will be separated immediately
				if (($prev_page != $aff_addrs->[ $counter ]->{ 'L1' }) ||
					($prev_sect != $aff_addrs->[ $counter ]->{ 'L2' }) ||
					($prev_para != $aff_addrs->[ $counter ]->{ 'L3' })) 
				{ 
					$features .= "\n"; 
				
					# NOTE: Relational classifier features
					$rc_features .= "\n";
				}

				# Save the paragraph index
				$prev_page = $aff_addrs->[ $counter ]->{ 'L1' };
				$prev_sect = $aff_addrs->[ $counter ]->{ 'L2' };
				$prev_para = $aff_addrs->[ $counter ]->{ 'L3' };
			}
		}

		# Set first word in line
		$is_first_line = 1;

		# Two previous words
		my $prev_word		= undef;
		my $prev_prev_word	= undef;

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
				# Get word location
				my $top 	= $word->get_top_pos();
				my $bottom 	= $word->get_bottom_pos();
				my $left	= $word->get_left_pos();
				my $right	= $word->get_right_pos();

				# NOTE: heuristic rule, for words in the same line
				# If the x-axis distance between this word and the previous word is
				# three times larger than the distance between the previous word and
				# the word before it, then it marks the separator.
				# The better way to do this is to introduce it as a new feature in the
				# author and affiliation model but this step requires re-training these
				# two models, so ...
				#
				# NOTE: Assuming left to right writing
				if (! defined $prev_word)
				{
					$prev_word = $word;	
				}
				elsif (! defined $prev_prev_word)
				{
					# NOTE: Words have the power to both destroy and heal, when words are both
					# true and kind, they can change our world
					if (($prev_word->get_left_pos() != $word->get_left_pos()) && ($prev_word->get_right_pos() != $word->get_right_pos()))
					{
						$prev_prev_word = $prev_word;
						$prev_word		= $word;
					}
				}
				else
				{
					# NOTE: Words have the power to both destroy and heal, when words are both
					# true and kind, they can change our world
					if (($prev_word->get_left_pos() != $word->get_left_pos()) && ($prev_word->get_right_pos() != $word->get_right_pos()))
					{
						my $prev_dist = abs ($prev_word->get_left_pos() - $prev_prev_word->get_right_pos());
						my $curr_dist = abs ($word->get_left_pos() - $prev_word->get_right_pos());

						if ($prev_dist * 5 < $curr_dist)
						{
							$features .= "\n"; 
				
							# NOTE: Relational classifier features
							$rc_features .= "\n";
						}

						$prev_prev_word = $prev_word;
						$prev_word		= $word;
					}
				}

				# Extract features
				my $full_content = $word->get_content();
				# Trim
				$full_content	 =~ s/^\s+|\s+$//g;

				# Skip blank run
				if ($full_content eq "") { next; }

				my @sub_content = ();
				# This is the tricky part, one word e.g. **affiliation will be 
				# splitted into two parts: the signal, and the affiliation if 
				# possible using regular expression
				while ($full_content =~ m/([\w|-]*)(\W*)/g)
				{
					my $first	= $1;
					my $second	= $2;
						
					# Trim
					$first	=~ s/^\s+|\s+$//g;
					$second	=~ s/^\s+|\s+$//g;
				
					# Only keep non-blank content
					if ($first ne "") { push @sub_content, $first; }

					# Check the signal and separator
					while ($second =~ m/([,|\.|:|;]*)([^,\.:;]*)/g)
					{
						my $sub_first	= $1;
						my $sub_second	= $2;

						# Trim
						$sub_first	=~ s/^\s+|\s+$//g;
						$sub_second	=~ s/^\s+|\s+$//g;
						
						# Only keep non-blank separator
						if ($sub_first ne "") { push @sub_content, $sub_first; }
						# Only keep non-blank signal
						if ($sub_second ne "") { push @sub_content, $sub_second; }
					}
				}

				foreach my $content (@sub_content)
				{
					# Content
					$features .= $content . "\t";
			
					my $content_n	= $content;
					# Remove punctuation
					$content_n		=~ s/[^\w]//g;
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

					# NOTE: Relational classifier features
					# Content
					$rc_features .= $content . "\t";
					# Location
					$rc_features .= $top 	. "\t";
					$rc_features .= $bottom . "\t";
					$rc_features .= $left 	. "\t";
					$rc_features .= $right	. "\t";
					# Index
					if (! defined $size_mismatch)
					{
						$rc_features .= $aff_addrs->[ $counter ]->{ 'L1' } . "\t";
						$rc_features .= $aff_addrs->[ $counter ]->{ 'L2' } . "\t";
						$rc_features .= $aff_addrs->[ $counter ]->{ 'L3' } . "\t";
						$rc_features .= $aff_addrs->[ $counter ]->{ 'L4' } . "\t";
					}
					# Done
					$rc_features .= "\n";
				}
			}			
		}
	}

	return ($features, $rc_features);

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
	my ($aut_lines, $aut_addrs) = @_;

	# NOTE: Relational classifier features
	my $rc_features		= "";
	
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
	$dominate_font = $sorted[ 0 ];

	my $size_mismatch = undef;
	# TODO: serious error if the size of aut_lines and the size of aut_addrs mismatch
	if (scalar(@{ $aut_lines }) != scalar(@{ $aut_addrs })) 
	{ 	
		$size_mismatch = 1;
		# Print the error but still try to continue
		print STDERR "# Total number of author lines (" . scalar(@{ $aut_lines }) . ") != Total number of author addresses (" . scalar(@{ $aut_addrs }) . ")." . "\n";
	}

	my $prev_page = undef;
	my $prev_sect = undef;
	my $prev_para = undef;
	# Each line contains many runs
	for (my $counter = 0; $counter < scalar(@{ $aut_lines }); $counter++)
	{
		# Get the line object
		my $line = $aut_lines->[ $counter ];
		
		# Check the size of aut_line and aut_addrs
		if (! defined $size_mismatch)
		{
			# Check if two consecutive lines are from two different sections 
			if (! defined $prev_page)
			{
				# Init
				$prev_page = $aut_addrs->[ $counter ]->{ 'L1' };
				$prev_sect = $aut_addrs->[ $counter ]->{ 'L2' };
				$prev_para = $aut_addrs->[ $counter ]->{ 'L3' };
			}
			else
			{
				# Authors from different sections will be separated immediately
				if (($prev_page != $aut_addrs->[ $counter ]->{ 'L1' }) ||
					($prev_sect != $aut_addrs->[ $counter ]->{ 'L2' }) ||
					($prev_para != $aut_addrs->[ $counter ]->{ 'L3' }))
				{ 
					$features .= "\n"; 

					# NOTE: Relational classifier features
					$rc_features .= "\n";
				}
				
				# Save the paragraph index
				$prev_page = $aut_addrs->[ $counter ]->{ 'L1' };
				$prev_sect = $aut_addrs->[ $counter ]->{ 'L2' };
				$prev_para = $aut_addrs->[ $counter ]->{ 'L3' };
			}
		}

		# Set first word in line
		$is_first_line = 1;

		# Previous word and the word before this 
		my $prev_prev_word	= undef;
		my $prev_word		= undef;

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
				# Get word location
				my $top 	= $word->get_top_pos();
				my $bottom 	= $word->get_bottom_pos();
				my $left	= $word->get_left_pos();
				my $right	= $word->get_right_pos();

				# NOTE: heuristic rule, for words in the same line
				# If the x-axis distance between this word and the previous word is
				# three times larger than the distance between the previous word and
				# the word before it, then it marks the separator.
				# The better way to do this is to introduce it as a new feature in the
				# author and affiliation model but this step requires re-training these
				# two models, so ...
				#
				# NOTE: Assuming left to right writing
				if (! defined $prev_word)
				{
					$prev_word = $word;	
				}
				elsif (! defined $prev_prev_word)
				{
					# NOTE: Words have the power to both destroy and heal, when words are both
					# true and kind, they can change our world
					if (($prev_word->get_left_pos() != $word->get_left_pos()) && ($prev_word->get_right_pos() != $word->get_right_pos()))
					{
						$prev_prev_word = $prev_word;
						$prev_word		= $word;
					}
				}
				else
				{
					# NOTE: Words have the power to both destroy and heal, when words are both
					# true and kind, they can change our world
					if (($prev_word->get_left_pos() != $word->get_left_pos()) && ($prev_word->get_right_pos() != $word->get_right_pos()))
					{

						my $prev_dist = abs ($prev_word->get_left_pos() - $prev_prev_word->get_right_pos());
						my $curr_dist = abs ($word->get_left_pos() - $prev_word->get_right_pos());

						if ($prev_dist * 5 < $curr_dist)
						{
							$features .= "\n"; 
					
							# NOTE: Relational classifier features
							$rc_features .= "\n";
						}

						$prev_prev_word = $prev_word;
						$prev_word		= $word;
					}
				}

				# Extract features
				my $full_content = $word->get_content();
				# Trim
				$full_content	 =~ s/^\s+|\s+$//g;

				# Skip blank run
				if ($full_content eq "") { next; }

				my @sub_content = ();
				# This is the tricky part, one word e.g. name** will be splitted 
				# into several parts: the name, the signal, and the separator if 
				# possible using regular expression
				while ($full_content =~ m/([\w|-]*)(\W*)/g)
				{
					my $first	= $1;
					my $second	= $2;
						
					# Trim
					$first	=~ s/^\s+|\s+$//g;
					$second	=~ s/^\s+|\s+$//g;
				
					# Only keep non-blank content
					if ($first ne "") { push @sub_content, $first; }

					# Check the signal and separator
					while ($second =~ m/([,|\.|:|;]*)([^,\.:;]*)/g)
					{
						my $sub_first	= $1;
						my $sub_second	= $2;

						# Trim
						$sub_first	=~ s/^\s+|\s+$//g;
						$sub_second	=~ s/^\s+|\s+$//g;
						
						# Only keep non-blank separator
						if ($sub_first ne "") { push @sub_content, $sub_first; }
						# Only keep non-blank signal
						if ($sub_second ne "") { push @sub_content, $sub_second; }
					}
				}

				foreach my $content (@sub_content)
				{
					# Content
					$features .= $content . "\t";
				
					my $content_n	= $content;
					# Remove punctuation
					$content_n		=~ s/[^\w]//g;
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
					my $clen  = scalar @chars;
					# Content length
					my $length =	(scalar(@chars) == 1)	? "1-char"	:
									(scalar(@chars) == 2)	? "2-char"	:
									(scalar(@chars) == 3)	? "3-char"	: "4+char";
					$features .= $length . "\t";
					# First n-gram
					$features .= $chars[ 0 ] . "\t";
					if ($clen >= 2) {
						$features .= join("", @chars[ 0..1 ]) . "\t";
					} else {
						$features .= $length . "\t";
					}
					if ($clen >= 3) {
						$features .= join("", @chars[ 0..2 ]) . "\t";
					} elsif ($clen >= 2) {
						$features .= join("", @chars[ 0..1 ]) . "\t";
					} else {
						$features .= $length . "\t";
					}
					if ($clen >= 4) {
						$features .= join("", @chars[ 0..3 ]) . "\t";
					} elsif ($clen >= 3) {
						$features .= join("", @chars[ 0..2 ]) . "\t";
					} elsif ($clen >= 2) {
						$features .= join("", @chars[ 0..1 ]) . "\t";
					} else {
						$features .= $length . "\t";
					}
	      			# Last n-gram
					$features .= $chars[ -1 ] . "\t";
					if ($clen >= 2) {
						$features .= join("", @chars[ -2..-1 ]) . "\t";
					} else {
						$features .= $chars[ -1 ] . "\t";
					}
					if ($clen >= 3) {
						$features .= join("", @chars[ -3..-1 ]) . "\t";
					} elsif ($clen >= 2) {
						$features .= join("", @chars[ -2..-1 ]) . "\t";
					} else {
						$features .= $chars[ -1 ] . "\t";
					}
					if ($clen >= 4) {
						$features .= join("", @chars[ -4..-1 ]) . "\t";
					} elsif ($clen >= 3) {
						$features .= join("", @chars[ -3..-1 ]) . "\t";
					} elsif ($clen >= 2) {
						$features .= join("", @chars[ -2..-1 ]) . "\t";
					} else {
						$features .= $chars[ -1 ] . "\t";
					}
			
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

					# NOTE: Relational classifier features
					# Content
					$rc_features .= $content . "\t";
					# Location
					$rc_features .= $top 	. "\t";
					$rc_features .= $bottom . "\t";
					$rc_features .= $left 	. "\t";
					$rc_features .= $right	. "\t";
					# Index
					if (! defined $size_mismatch)
					{
						$rc_features .= $aut_addrs->[ $counter ]->{ 'L1' } . "\t";
						$rc_features .= $aut_addrs->[ $counter ]->{ 'L2' } . "\t";
						$rc_features .= $aut_addrs->[ $counter ]->{ 'L3' } . "\t";
						$rc_features .= $aut_addrs->[ $counter ]->{ 'L4' } . "\t";
					}
					# Done
					$rc_features .= "\n";
				}
			}			
		}
	}

	return ($features, $rc_features);
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

















