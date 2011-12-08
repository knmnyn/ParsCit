#!/usr/bin/perl

# Author: Do Hoang Nhat Huy <huydo@comp.nus.edu.sg>
# Modified from template by Min-Yen Kan <kanmy@comp.nus.edu.sg>

require 5.0;
use strict;

# Dependencies
use FindBin;
use Getopt::Long;
use HTML::Entities;

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
use lib "$path/../../lib";

use lib "/home/wing.nus/tools/languages/programming/perl-5.10.0/lib/5.10.0";
use lib "/home/wing.nus/tools/languages/programming/perl-5.10.0/lib/site_perl/5.10.0";

# Local libraries
use Omni::Config;
use Omni::Omnidoc;
use SectLabel::PreProcess;

# Omnilib configuration: object name
my $obj_list = $Omni::Config::obj_list;

### USER customizable section
$0 =~ /([^\/]+)$/; my $progname = $1;
my $version = "1.0";
### END user customizable section

sub License 
{
	print STDERR "# Copyright 2011 \251 by Do Hoang Nhat Huy\n";
}

sub Help 
{
	print STDERR "Process Omnipage XML output (concatenated results fromm all pages of a PDF file), and extract text lines together with other XML infos\n";
	print STDERR "usage: $progname -h\t[invokes help]\n";
	print STDERR "       $progname -in xmlfile -out outfile [-decode] [-log]\n";
	print STDERR "Options:\n";
	print STDERR "\t-q      \tQuiet Mode (don't echo license)\n";
	print STDERR "\t-decode \tDecode HTML entities and then output, to avoid double entity encoding later\n";
}

my $quite			= 0;
my $help			= 0;
my $out_file		= undef;
my $in_file			= undef;
my $is_decode		= 0;
my $is_debug		= 0;
my $address			= 1;

$help = 1 unless GetOptions(	'in=s' 		=> \$in_file,
								'out=s' 	=> \$out_file,
								'decode' 	=> \$is_decode,
								'log'		=> \$is_debug,
								'h'			=> \$help,
								'q'			=> \$quite	);

if ($help || ! defined $in_file || ! defined $out_file) 
{
	Help();
  	exit(0);
}

if (!$quite) 
{
	License();
}

### Untaint ###
$in_file	 = UntaintPath($in_file);
$out_file	 = UntaintPath($out_file);
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
### End untaint ###

# Mark page, para, line, word
my %g_page_hash = ();

# Mark paragraph
my @g_para = ();

# XML features
# Location feature
my @g_pos_hash	= (); 
my $g_maxpos	= 0;
my $g_minpos	= 1000000; 
# Align feature
my @g_align		= (); 
# Bold feature
my @g_bold		= ();
# Italic feature
my @g_italic	= ();
# Pic feature
my @g_pic		= (); 
# Table feature
my @g_table		= ();
# Bullet feature
my @g_bullet	= ();
# Font size feature
my %g_font_size_hash	= (); 
my @g_font_size			= ();
# Font face feature
my %g_font_face_hash	= (); 
my @g_font_face 		= ();

# All lines
my @lines		= ();
# and their address
my @lines_addr	= ();

# BEGIN
ProcessFile($in_file);
# Find header part
my $num_lines	= scalar(@lines);
my ($header_length, $body_length, $body_start_id) = SectLabel::PreProcess::FindHeaderText(\@lines, 0, $num_lines);
# Done
Output(\@lines, $out_file);

if ($address == 1)
{
	my $address_handle = undef;
	# Save the line address for further use
	open($address_handle, ">:utf8", $out_file . ".address") || die"#Can't open file \"$out_file.address\"\n";
	foreach my $addr (@lines_addr)
	{
		print $address_handle $addr->{ 'L1' }, " ", $addr->{ 'L2' }, " ", $addr->{ 'L3' }, " ", $addr->{ 'L4' }, "\n";
	}
	# Done
	close $address_handle;
}
# END

sub ProcessFile 
{
	my ($in_file) = @_;

	my $input_handle = undef;
	if (! open($input_handle, "<:utf8", $in_file)) { die "Could not open xml file " . $in_file; }
	my $xml = do { local $/; <$input_handle> };
	close $input_handle;

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

	# Current position	
	my %current		 = ();

	# All pages in the document
	my $pages = $doc->get_objs_ref();

	# From page, To page
	my $start_page	= 0;
	my $end_page	= scalar(@{ $pages }) - 1;

	# Image area flag
	my $is_pic = 0;

	# Tree traveling is 'not' fun. Seriously.
	# This is like a dungeon seige.
	for (my $x = $start_page; $x <= $end_page; $x++)	
	{
		# Current position
		$current{ 'L1' } = $x;

		# Column or dd
		my $level_2	 =	$pages->[ $x ]->get_objs_ref();
		my $start_l2 =	0;
		my $end_l2	 =	scalar(@{ $level_2 }) - 1;

		for (my $y = $start_l2; $y <= $end_l2; $y++)
		{
			# Thang's code
			# Thang considers <dd> tag as image, I just follow that
			if ($level_2->[ $y ]->get_name() eq $obj_list->{ 'OMNIDD' })
			{
				$is_pic = 1;	
			}
			else
			{
				$is_pic = 0;				
			}
			# End Thang's code

			# Current position
			$current{ 'L2' } = $y;

			# Table or paragraph
			my $level_3	 = 	$level_2->[ $y ]->get_objs_ref();
			my $start_l3 =	0;
			my $end_l3	 =	scalar(@{ $level_3 }) - 1;

			for (my $z = $start_l3; $z <= $end_l3; $z++)
			{
				# Current position
				$current{ 'L3' } = $z;

				# Is a paragraph
				if ($level_3->[ $z ]->get_name() eq $obj_list->{ 'OMNIPARA' })
				{
					# Thang's code
					ProcessPara($level_3->[ $z ], $is_pic, \%current);
					# End Thang's code
				}
				# or a table
				elsif ($level_3->[ $z ]->get_name() eq $obj_list->{ 'OMNITABLE' })
				{
					# Thang's code
					ProcessTable($level_3->[ $z ], $is_pic, \%current, 0);
					# End Thangs's code
				}
				# or a frame
				elsif ($level_3->[ $z ]->get_name() eq $obj_list->{ 'OMNIFRAME' })
				{
					# Frame contains multiple paragraph ?
					ProcessFrame($level_3->[ $z ], $is_pic, \%current);
				}
			}
		}
	}
}

sub Output 
{
	my ($lines, $out_file) = @_;

	my $output_handle = undef;
	# This is the output
	open($output_handle, ">:utf8", $out_file) || die"#Can't open file \"$out_file\"\n";

  	# XML feature label
	my %g_font_size_labels = (); 
	GetFontSizeLabels(\%g_font_size_hash, \%g_font_size_labels);
  	
  	my $output			= "";
 	my $para_line_id	= -1;
  	my $para_line_count	= 0;

	# This is the index of the line
	my $id = 0;
	# For each line in the whole document
	foreach my $line (@{ $lines })
	{
		# Remove empty line 
		$line =~ s/^\s+|\s+$//g;

		# New paragraph
    	if (($g_para[ $id ] eq "yes") && ($output ne ""))
		{
			if ($is_decode) { $output = decode_entities($output); }
			# Write output to file
			print $output_handle $output;
			# Clean output for new paragraph
			$output = "";
      	}
    
    	$output .= $line;

		my $loc_feature = undef;
      	# XML location feature
   		if ($g_pos_hash[ $id ] != (-1)) { $loc_feature = "xmlLoc_".int(($g_pos_hash[$id] - $g_minpos) * 8.0 / ($g_maxpos - $g_minpos + 1)); }

	 	# Align feature
   		my $align_feature = "xmlAlign_" . $g_align[ $id ];

      	my $font_size_feature = undef;
		# Font_size feature
		if (($g_font_size[$id] eq "") || ($g_font_size[$id] == -1))
		{
			$font_size_feature = "xmlFontSize_none";
		} 
		else 
		{
			$font_size_feature = "xmlFontSize_" . $g_font_size_labels{ $g_font_size[ $id ] };
		}

		# Bold feature
      	my $bold_feature	= "xmlBold_"	. $g_bold[ $id ];
		# Italic feature
		my $italic_feature	= "xmlItalic_"	. $g_italic[ $id ];
		# Image feature
   		my $pic_feature		= "xmlPic_"		. $g_pic[ $id ];
		# Table feature
   		my $table_feature	= "xmlTable_"	. $g_table[ $id ];
		# Bullet feature
		my $bullet_feature	= "xmlBullet_"	. $g_bullet[ $id ];
		# Differential features
		my ($align_diff, $font_size_diff, $font_face_diff, $font_sf_diff, $font_sfbi_diff, $font_sfbia_diff, $para_diff) = GetDifferentialFeatures($id);

   		# Each line and its XML features
		$output .= " |XML| $loc_feature $bold_feature $italic_feature $font_size_feature $pic_feature $table_feature $bullet_feature $font_sfbia_diff $para_diff" . "\n"; 

		# Update line index
    	$id++;
  	}

	# New paragraph
	if ($output ne "")
	{
		if ($is_decode) { $output = decode_entities($output); }
		# Write output to file
		print $output_handle $output;
		# Clean output for new paragraph
		$output = "";
  	}
 
 	# Done
  	close $output_handle;
}

sub GetDifferentialFeatures 
{
	my ($id) = @_;

  	my $align_diff = "bi_xmlA_";
	# AlignChange feature
	if ($id == 0)
	{
    	$align_diff .= $g_align[ $id ];
  	} 
	elsif ($g_align[ $id ] eq $g_align[ $id - 1 ])
	{
    	$align_diff .= "continue";
  	} 
	else 
	{
    	$align_diff .= $g_align[$id];
  	}
  
	my $font_face_diff = "bi_xmlF_";
  	# FontFaceChange feature
  	if ($id == 0)
	{
    	$font_face_diff .= "new";
  	} 
	elsif ($g_font_face[ $id ] eq $g_font_face[ $id - 1 ])
	{
    	$font_face_diff .= "continue";
  	} 
	else 
	{
    	$font_face_diff .= "new";
  	}

  	my $font_size_diff = "bi_xmlS_";
	# FontSizeChange feature
	if ($id == 0)
	{
    	$font_size_diff .= "new";
	} 
	elsif ($g_font_size[ $id ] == $g_font_size[ $id - 1 ])
	{
    	$font_size_diff .= "continue";
  	} 
	else 
	{
    	$font_size_diff .= "new";
  	}  
  
  	my $font_sf_diff = "bi_xmlSF_";
  	# FontSFChange feature
  	if ($id == 0)
	{
    	$font_sf_diff .= "new";
	} 
	elsif ($g_font_size[ $id ] == $g_font_size[ $id - 1 ] && $g_font_face[ $id ] eq $g_font_face[ $id - 1 ])
	{
    	$font_sf_diff .= "continue";
  	} 
	else 
	{
    	$font_sf_diff .= "new";
  	}
  
  	my $font_sfbi_diff = "bi_xmlSFBI_";
  	# FontSFBIChange feature
	if ($id == 0)
	{
    	$font_sfbi_diff .= "new";
  	} 
	elsif ($g_font_size[ $id ] == $g_font_size[ $id - 1 ] && $g_font_face[ $id ] eq $g_font_face[ $id - 1 ] && $g_bold[ $id ] eq $g_bold[ $id - 1 ] && $g_italic[ $id ] eq $g_italic[ $id - 1 ])
	{
    	$font_sfbi_diff .= "continue";
  	} 
	else 
	{
    	$font_sfbi_diff .= "new";
  	}
  
  	my $font_sfbia_diff = "bi_xmlSFBIA_";
  	# FontSFBIAChange feature
  	if ($id == 0)
	{
    	$font_sfbia_diff .= "new";
  	} 
	elsif ($g_font_size[ $id ] == $g_font_size[ $id - 1 ] && $g_font_face[ $id ] eq $g_font_face[ $id - 1 ] && $g_bold[ $id ] eq $g_bold[ $id - 1 ] && $g_italic[ $id ] eq $g_italic[$id - 1] && $g_align[ $id ] eq $g_align[ $id - 1 ])
	{
    	$font_sfbia_diff .= "continue";
  	} 
	else 
	{
    	$font_sfbia_diff .= "new";
  	}

  	# ParaChange feature
  	my $para_diff = "bi_xmlPara_";
	# Header part, consider each line as a separate paragraph
  	if ($id < $body_start_id)
	{ 
    	$para_diff .= "header";
  	} 
	else 
	{
    	if($g_para[$id] eq "yes")
		{
      		$para_diff .= "new";
    	} 
		else 
		{
      		$para_diff .= "continue";
    	}
  	}

  	return ($align_diff, $font_size_diff, $font_face_diff, $font_sf_diff, $font_sfbi_diff, $font_sfbia_diff, $para_diff);
}

sub GetFontSizeLabels 
{
 	my ($g_font_size_hash, $g_font_size_labels) = @_;

	# Sort by value in desccending order
  	my @sorted_fonts = sort { $g_font_size_hash->{ $b } <=> $g_font_size_hash->{ $a } } keys %{ $g_font_size_hash };
	# and get the 
	my $common_size = $sorted_fonts[ 0 ];

	# Sort by key in ascending order
	@sorted_fonts = sort { $a <=> $b } keys %{ $g_font_size_hash };

	my $common_index = 0; 
	# Index of common font size
	foreach (@sorted_fonts)
	{
		# Found
    	if ($common_size == $_) { last;	}
    	$common_index++;
  	}
  
  	# Small fonts
  	for (my $i = 0; $i < $common_index; $i++)
	{
    	$g_font_size_labels->{ $sorted_fonts[ $i ] } = "smaller";
  	}

  	# Common fonts
  	$g_font_size_labels->{ $common_size } = "common";

  	# Large fonts
  	for (my $i = ($common_index + 1); $i < scalar(@sorted_fonts); $i++)
	{ 
    	if ((scalar(@sorted_fonts) - $i) <= 3)
		{
      		$g_font_size_labels->{ $sorted_fonts[$i] } = "largest" . ($i + 1 - scalar(@sorted_fonts));
    	} 
		else 
		{
      		$g_font_size_labels->{ $sorted_fonts[$i] } = "larger";
    	}
  	}
}

sub ProcessFrame
{
	my ($omniframe, $is_pic, $line_addr) = @_;

	# Line index in the whole frame
	my $lindex	= 0;
	# All paragraph or table in the frame
	my $objs	= $omniframe->get_objs_ref();
	# For each paragraph or table in the frame
	for (my $i = 0; $i < scalar(@{ $objs }); $i++)
	{
		if ($objs->[ $i ]->get_name() eq $obj_list->{ 'OMNIPARA' })
		{
			# Paragraph attributes
			my $align	= $objs->[ $i ]->get_alignment();
			my $space	= $objs->[ $i ]->get_space_before();
			# Line attributes
  			my ($left, $top, $right, $bottom) = undef;
			# Run attributes	
			my $bold_count		= 0;
  			my $italic_count	= 0;
  			my %font_size_hash	= ();
		  	my %font_face_hash	= ();

			my $omnilines = $objs->[ $i ]->get_objs_ref();
			# For each line in the paragraph	
			for (my $t = 0; $t < scalar(@{ $omnilines }); $t++)
			{
				# Save the line
				push @lines, $omnilines->[ $t ]->get_content();
				# Save the line's address
				$line_addr->{ 'L4' } = $lindex;
				push @lines_addr, { %{ $line_addr } };
				# Point to the next line in the whole frame
				$lindex++;

				# Line attributes
				$left	= $omnilines->[ $t ]->get_left_pos();
				$right	= $omnilines->[ $t ]->get_right_pos();
				$top	= $omnilines->[ $t ]->get_top_pos();
				$bottom	= $omnilines->[ $t ]->get_bottom_pos();
	
				# Runs
				my $runs	= $omnilines->[ $t ]->get_objs_ref();
				my $start_r	= 0;
				my $end_r	= scalar(@{ $runs }) - 1;

				# Total number of words in a line
				my $words_count = 0;

				for (my $u = $start_r; $u <= $end_r; $u++)
				{			
					# Thang's compatible code (instead of using get_objs_ref)
					my $rcontent = undef;
					# Get run content
					$rcontent	 = $runs->[ $u ]->get_content();
					# Trim
					$rcontent	 =~ s/^\s+|\s+$//g;
					# Split to words
					my @words = split(/\s+/, $rcontent);	

					# Update the number of words
					$words_count += scalar(@words);

					# XML format
					my $font_size					= $runs->[ $u ]->get_font_size();
					$font_size_hash{ $font_size }	= $font_size_hash{ $font_size } ? $font_size_hash{ $font_size } + scalar(@words) : scalar(@words); 
					# XML format
					my $font_face 					= $runs->[ $u ]->get_font_face();
					$font_face_hash{ $font_face }	= $font_face_hash{ $font_face } ? $font_face_hash{ $font_face } + scalar(@words) : scalar(@words); 
					# XML format
					if ($runs->[ $u ]->get_bold() eq "true") { $bold_count += scalar(@words); } 
					# XML format
					if ($runs->[ $u ]->get_italic() eq "true") { $italic_count += scalar(@words); }
				}
			
				# Line attributes - relative position in paragraph
				if ($t == 0)
				{
 					push @g_para, "yes";
				} 
				else 
				{
 					push @g_para, "no";
				}
		
				# Line attributes - line position
				my $pos = ($top + $bottom) / 2.0;
				# Compare to global min and max position
				if ($pos < $g_minpos) { $g_minpos = $pos; }
				if ($pos > $g_maxpos) { $g_maxpos = $pos; }
				# Pos feature
				push @g_pos_hash, $pos;
				# Alignment feature
		  		push @g_align, $align;
				# Table feature
				push @g_table, "no";
	
				if ($is_pic)
				{
		    		push @g_pic, "yes";
   			 		# Not assign value if line is in image area
    				push @g_bold, "no";		
    				push @g_italic, "no";
	    			push @g_bullet, "no";
	    			push @g_font_size, -1; 		
    				push @g_font_face, "none";
	  			} 
				else 
				{
    				push @g_pic, "no";
					UpdateXMLFontFeature(\%font_size_hash, \%font_face_hash);			
					UpdateXMLFeatures($bold_count, $italic_count, $words_count, $omnilines->[ $t ]->get_bullet(), $space);
				}			
		
				# Reset hash
				%font_size_hash = (); 
				%font_face_hash = ();
				# Reset
				$bold_count		= 0;
				$italic_count	= 0;
			}
		}
		elsif ($objs->[ $i ]->get_name() eq $obj_list->{ 'OMNITABLE' })
		{
			$lindex = ProcessTable($objs->[ $i ], $is_pic, $line_addr, $lindex);
		}
	}
}

sub ProcessTable 
{
	my ($omnitable, $is_pic, $line_addr, $lindex) = @_;

	# Table attributes
	my ($left, $top, $right, $bottom) = undef;
	$left		= $omnitable->get_left_pos();
	$right		= $omnitable->get_right_pos();
	$top		= $omnitable->get_top_pos();
	$bottom		= $omnitable->get_bottom_pos();
	# Table attributes
	my $align	= $omnitable->get_alignment();

	# Thang's code
	my $pos = ($top + $bottom) / 2.0;
	# Set new min and max position
	if ($pos < $g_minpos) { $g_minpos = $pos; }
	if ($pos > $g_maxpos) { $g_maxpos = $pos; }
	# End Thangs's code

	# All row in the table
	my $rows	= $omnitable->get_row_content();
	# For each row in the table
	for (my $i = 0; $i < scalar(@{ $rows }); $i++)
	{
		my @row_lines = split(/\n/, $rows->[ $i ]);
		# For each line in the row
		for (my $j = 0; $j < scalar(@row_lines); $j++)
		{
			# Save the line
			push @lines, $row_lines[ $j ];
			# Save the line's address
			$line_addr->{ 'L4' } = $lindex;
			push @lines_addr, { %{ $line_addr } };
			# Point to the next line in the whole table
			$lindex++;

			if (($j == 0) && ($i == 0))
			{
				push @g_para, "yes";
			} 
			else 
			{
	 			push @g_para, "no";
			}

			# Table feature
			push @g_table, "yes";

			# Pic feature
			if ($is_pic)
			{
 				push @g_pic, "yes";
			} 
			else 
			{
				push @g_pic, "no";
			}
		
			# Update xml pos value
			push @g_pos_hash, $pos;
			# Update xml alignment value
	 		push @g_align, $align;
		
			# Fontsize feature	  
			push @g_font_size, -1;
			# Fontface feature	  
			push @g_font_face, "none";
			# Bold feature	  
			push @g_bold, "no";	 				
 			# Italic feature
			push @g_italic, "no";
			# Bullet feature
			push @g_bullet, "no";
		}
	}

	# Nonsense
	return $lindex;
}

sub ProcessPara 
{
	my ($paragraph, $is_pic, $line_addr) = @_;
 
 	# Paragraph attributes
	my $align	= $paragraph->get_alignment();
	my $space	= $paragraph->get_space_before();
	# Line attributes
  	my ($left, $top, $right, $bottom) = undef;
	# Run attributes	
	my $bold_count		= 0;
  	my $italic_count	= 0;
  	my %font_size_hash	= ();
  	my %font_face_hash	= ();

	# Lines
	my $omnilines	= $paragraph->get_objs_ref();
	my $start_l		= 0;
	my $end_l		= scalar(@{ $omnilines }) - 1;

	# Lines
	for (my $t = $start_l; $t <= $end_l; $t++)
	{
		# Skip blank line
		my $lcontent = $omnilines->[ $t ]->get_content();
		$lcontent	 =~ s/^\s+|\s+$//g;
		# Skip blank line
		if ($lcontent eq "") { next; }

		# Save the line
		push @lines, $omnilines->[ $t ]->get_content();
		# Save the line's address
		$line_addr->{ 'L4' } = $t;
		push @lines_addr, { %{ $line_addr } };

		# Line attributes
		$left	= $omnilines->[ $t ]->get_left_pos();
		$right	= $omnilines->[ $t ]->get_right_pos();
		$top	= $omnilines->[ $t ]->get_top_pos();
		$bottom	= $omnilines->[ $t ]->get_bottom_pos();

		# Runs
		my $runs	= $omnilines->[ $t ]->get_objs_ref();
		my $start_r	= 0;
		my $end_r	= scalar(@{ $runs }) - 1;

		# Total number of words in a line
		my $words_count = 0;

		for (my $u = $start_r; $u <= $end_r; $u++)
		{			
			# Thang's compatible code (instead of using get_objs_ref)
			my $rcontent = undef;
			# Get run content
			$rcontent	 = $runs->[ $u ]->get_content();
			# Trim
			$rcontent	 =~ s/^\s+|\s+$//g;
			# Split to words
			my @words = split(/\s+/, $rcontent);	

			# Update the number of words
			$words_count += scalar(@words);

			# XML format
			my $font_size					= $runs->[ $u ]->get_font_size();
			$font_size_hash{ $font_size }	= $font_size_hash{ $font_size } ? $font_size_hash{ $font_size } + scalar(@words) : scalar(@words); 
			# XML format
			my $font_face 					= $runs->[ $u ]->get_font_face();
			$font_face_hash{ $font_face }	= $font_face_hash{ $font_face } ? $font_face_hash{ $font_face } + scalar(@words) : scalar(@words); 
			# XML format
			if ($runs->[ $u ]->get_bold() eq "true") { $bold_count += scalar(@words); } 
			# XML format
			if ($runs->[ $u ]->get_italic() eq "true") { $italic_count += scalar(@words); }
		}
			
		# Line attributes - relative position in paragraph
		if ($t == $start_l)
		{
 			push @g_para, "yes";
		} 
		else 
		{
 			push @g_para, "no";
		}
		
		# Line attributes - line position
		my $pos = ($top + $bottom) / 2.0;
		# Compare to global min and max position
		if ($pos < $g_minpos) { $g_minpos = $pos; }
		if ($pos > $g_maxpos) { $g_maxpos = $pos; }
		# Pos feature
		push @g_pos_hash, $pos;
		# Alignment feature
  		push @g_align, $align;
		# Table feature
		push @g_table, "no";

		if ($is_pic)
		{
    		push @g_pic, "yes";
   	 		# Not assign value if line is in image area
    		push @g_bold, "no";		
    		push @g_italic, "no";
    		push @g_bullet, "no";
    		push @g_font_size, -1; 		
    		push @g_font_face, "none";
  		} 
		else 
		{
    		push @g_pic, "no";
			UpdateXMLFontFeature(\%font_size_hash, \%font_face_hash);			
			UpdateXMLFeatures($bold_count, $italic_count, $words_count, $omnilines->[ $t ]->get_bullet(), $space);
		}		
		
		# Reset hash
		%font_size_hash = (); 
		%font_face_hash = ();
		# Reset
		$bold_count		= 0;
		$italic_count	= 0;
	}
}

sub UpdateXMLFontFeature 
{
	my ($font_size_hash, $font_face_hash) = @_;

  	# Font size feature
  	if (scalar(keys %{ $font_size_hash }) == 0)
	{
    	push @g_font_size, -1;
  	} 
	else 
	{
    	my @sorted_fonts = sort { $font_size_hash->{ $b } <=> $font_size_hash->{ $a } } keys %{ $font_size_hash };
   
   		my $font_size = undef;
		# Iw two font sizes are equal in number, get the larger one
   		if ((scalar(@sorted_fonts) != 1) && ($font_size_hash->{ $sorted_fonts[ 0 ] } == $font_size_hash->{ $sorted_fonts[ 1 ] }))
		{
			$font_size = ($sorted_fonts[ 0 ] > $sorted_fonts[ 1 ]) ? $sorted_fonts[ 0 ] : $sorted_fonts[ 1 ];
		}
		else
		{
    		$font_size = $sorted_fonts[ 0 ];
		}

		if ($font_size eq "") { $font_size = 0; }
   
		push @g_font_size, $font_size;
    	$g_font_size_hash{ $font_size } = $g_font_size_hash{ $font_size } ? $g_font_size_hash{ $font_size } + 1 : 1;
  	}
  
  	# Font face feature
  	if (scalar(keys %{ $font_face_hash }) == 0)
	{
    	push @g_font_face, "none";
  	} 
	else 
	{
    	my @sorted_fonts = sort { $font_face_hash->{ $b } <=> $font_face_hash->{ $a } } keys %{ $font_face_hash };		

    	my $font_face = $sorted_fonts[ 0 ];
    	push @g_font_face, $font_face;
		
		$g_font_face_hash{ $font_face } = $g_font_face_hash{ $font_face } ? $g_font_face_hash{ $font_face } + 1 : 1;
  	}
}

sub UpdateXMLFeatures 
{
	my ($bold_count, $italic_count, $words_count, $is_bullet, $space) = @_;

	# Bold feature
  	my $bold_feature = undef;
  	if (($words_count != 0) && ($bold_count / $words_count >= 0.667))
	{
    	$bold_feature = "yes";
  	} 
	else 
	{
    	$bold_feature = "no";
  	}
  	push @g_bold, $bold_feature;
  
  	# Italic feature
  	my $italic_feature = undef;
  	if (($words_count != 0) && ($italic_count / $words_count >= 0.667))
	{
    	$italic_feature = "yes";
  	} 
	else 
	{
    	$italic_feature = "no";
  	}
  	push @g_italic, $italic_feature;
  
  	# Bullet feature
  	if ((defined $is_bullet) && ($is_bullet eq "true"))
	{
    	push @g_bullet, "yes";
  	} 
	else 
	{
    	push @g_bullet, "no";
  	}
}

sub UntaintPath 
{
	my ($path) = @_;

  	if ( $path =~ /^([-_\/\w\.]*)$/ ) 
	{
    	$path = $1;
  	} 
	else 
	{
    	die "Bad path \"$path\"\n";
  	}

  	return $path;
}

sub Untaint 
{
	my ($s) = @_;
  	if ($s =~ /^([\w \-\@\(\),\.\/]+)$/) 
	{
    	$s = $1;               # $data now untainted
  	} 
	else 
	{
    	die "Bad data in $s";  # log this somewhere
  	}
  	
	return $s;
}

sub Execute 
{
	my ($cmd) = @_;
  	$cmd = Untaint($cmd);
	system($cmd);
}

sub NewTmpFile 
{
	my $tmp_file = `date '+%Y%m%d-%H%M%S-$$'`;
  	chomp  $tmp_file;
  	return $tmp_file;
}



