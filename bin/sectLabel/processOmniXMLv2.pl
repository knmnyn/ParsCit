#!/usr/bin/perl -wT

# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Tue, 02 Jun 2009 01:30:42
# Modified from template by Min-Yen Kan <kanmy@comp.nus.edu.sg>

require 5.0;
use strict;

use Getopt::Long;
use HTML::Entities;

# I do not know a better solution to find a lib path in -T mode.
# So if you know a better solution, I'd be glad to hear.
# See this http://www.perlmonks.org/?node_id=585299 for why I used the below code
use FindBin;
FindBin::again(); # to get correct path in case 2 scripts in different directories use FindBin
my $path;
BEGIN 
{
	if ($FindBin::Bin =~ /(.*)/) { $path = $1; }
}

use lib "$path/../../lib";

use lib "/home/wing.nus/tools/languages/programming/perl-5.10.0/lib/5.10.0";
use lib "/home/wing.nus/tools/languages/programming/perl-5.10.0/lib/site_perl/5.10.0";

use SectLabel::PreProcess;

### USER customizable section
$0 =~ /([^\/]+)$/; my $progname = $1;
my $outputVersion = "1.0";
### END user customizable section

sub License 
{
	print STDERR "# Copyright 2009 \251 by Luong Minh Thang\n";
}

### HELP Sub-procedure
sub Help 
{
	print STDERR "Process Omnipage XML output (concatenated results fromm all pages of a PDF file), and extract text lines together with other XML infos\n";
	print STDERR "usage: $progname -h\t[invokes help]\n";
	print STDERR "       $progname -in xmlFile -out out_file [-xmlFeature -decode -markup -para] [-tag tag_file -allowEmptyLine -log]\n";
	print STDERR "Options:\n";
	print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
	print STDERR "\t-xmlFeature: append XML feature together with text extracted\n";
	print STDERR "\t-decode: decode HTML entities and then output, to avoid double entity encoding later\n";
	print STDERR "\t-para: marking in the output each paragraph with # Para lineId num_lines\n";
	print STDERR "\t-markup: marking in the output detailed word-level info ### Page w h\\n## Para l t r b\\n# Line l t r b\\nword l t r b\n";
	print STDERR "\t-tag tag_file: count XML tags/values for statistics purpose\n";
}

my $quite		= 0;
my $help		= 0;
my $out_file	= undef;
my $in_file		= undef;

my $is_xml_feature		= 0;
my $is_decode			= 0;
my $is_markup			= 0;
my $is_para_delimiter	= 0;
my $is_allow_empty		= 0;
my $is_debug			= 0;
my $tag_file			= "";

$help = 1 unless GetOptions(
					'in=s' 				=> \$in_file,
			    	'out=s' 			=> \$out_file,
			    	'decode' 			=> \$is_decode,
			    	'xmlFeature' 		=> \$is_xml_feature,
					'tag=s' 			=> \$tag_file,
			    	'allowEmptyLine'	=> \$is_allow_empty,
			    	'markup'			=> \$is_markup,
			    	'para'				=> \$is_para_delimiter,
			    	'log'				=> \$is_debug,
			    	'h'					=> \$help,
			    	'q'					=> \$quite	);

if ($help || !defined $in_file || !defined $out_file) 
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
$tag_file	 = UntaintPath($tag_file);
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
### End untaint ###

# Mark page, para, line, word
my %g_page_hash = ();

# Mark paragraph
my @g_para = ();

# XML features
# Location feature
my @g_pos_hash	= (); 
my $g_minpos	= 1000000; 
my $g_maxpos	= 0;
# Align feature
my @g_align		= (); 
# Bold feature
my @g_bold		= ();
# Italic feature
my @g_italic	= ();
# Font size feature
my %g_font_size_hash	= (); 
my @g_font_size			= ();
# Font face feature
my %g_font_face_hash	= (); 
my @g_font_face = ();
# Pic feature
my @g_pic	= (); 
# Table feature
my @g_table	= ();
# Bullet feature
my @g_bullet	= ();
# Space feature
# my %g_space_hash	= (); 
# my @g_space		= ();

my %tags = ();

if ($is_debug)
{
	print STDERR "\n# Processing file $in_file & output to $out_file\n";
}

my $markup_output	= "";
my $all_text		= ProcessFile($in_file, $out_file, \%tags);

# Find header part
my @lines		= split(/\n/, $all_text);
my $num_lines	= scalar(@lines);
my ($header_length, $body_length, $body_start_id) = SectLabel::PreProcess::FindHeaderText(\@lines, 0, $num_lines);

# Output
if ($is_markup)
{
	open(OF, ">:utf8", "$out_file") || die"#Can't open file \"$out_file\"\n";
	print OF "$markup_output";
	close OF;
} 
else 
{
	Output(\@lines, $out_file);
}

if ($tag_file ne "")
{
	PrintTagInfo(\%tags, $tag_file);
}

sub ProcessFile 
{
	my ($in_file, $tags) = @_;
	
	if (!(-e $in_file)) { die "# $progname crash\t\tFile \"$in_file\" doesn't exist"; }
	open (IF, "<:utf8", $in_file) || die "# $progname crash\t\tCan't open \"$in_file\"";
  
  	my $is_para		= 0;
	my $is_table	= 0;
	my $is_space	= 0;
  	my $is_pic		= 0;
  	my $all_text	= "";
  	my $text		= "";
  	my $line_id		= 0;

	# Each line contains a header
  	while (<IF>) 
	{
		# Skip comments
		if (/^\#/) { next; }
		chomp;

		# Remove ^M character at the end of the file if any
		s/\cM$//; 
    	my $line = $_;

    	if($tag_file ne "") { ProcessTagInfo($line, $tags); }

	    # if ($line =~ /<\?xml version.+>/) {    } ### XML ###
    	# if ($line =~ /^<\/column>$/) {    } ### Column ###
		if ($is_markup && $line =~ /<theoreticalPage (.*)\/>/ && $is_markup) { $markup_output .= "### Page $1\n"; }

		# Pic
		if ($line =~ /^<dd (.*)>$/)
		{
			$is_pic = 1;
			if($is_markup) { $markup_output .= "### Figure $1\n"; }
		}
    	elsif ($line =~ /^<\/dd>$/)
		{
      		$is_pic = 0;
    	}
	    
		# Table
		if ($line =~ /^<table .*>$/)
		{
			$text		.= $line."\n"; # we need the header
			$is_table	= 1;
		}
		elsif ($line =~ /^<\/table>$/)
		{
			my $table_text	= ProcessTable($text, $is_pic);
			$all_text		.= $table_text;

			my @tmp_lines	= split(/\n/, $table_text);
			$line_id		+= scalar(@tmp_lines);
			
			$is_table		= 0;
			$text			= "";
		}
		elsif ($is_table)
		{
			$text .= $line."\n";
			next;
		}
		# Paragraph
		# Note: table processing should have higher priority than paragraph, i.e. the priority does matter
    	elsif ($line =~ /^<para (.*)>$/)
		{
      		$text		.= $line."\n"; # we need the header
      		$is_para	= 1;
			if ($is_markup) { $markup_output .= "## Para $1\n"; }
    	}
    	elsif ($line =~ /^<\/para>$/)
		{
      		my ($para_text, $l, $t, $r, $b) = undef;
			($para_text, $l, $t, $r, $b, $is_space) = ProcessPara($text, 0, $is_pic);
			$all_text .= $para_text;

      		my @tmp_lines = split(/\n/, $para_text);
      		$line_id += scalar(@tmp_lines);
      		$is_para = 0;
      		$text = "";
    	}
		elsif ($is_para)
		{
      		$text .= $line."\n";
      		next;
    	}
  	}  

	close IF;  
  	return $all_text;
}

sub Output 
{
	my ($lines, $out_file) = @_;
	open(OF, ">:utf8", "$out_file") || die"#Can't open file \"$out_file\"\n";

	####### Final output ############
  	# XML feature label
	my %g_font_size_labels = (); 
	# my %g_space_labels = (); # yes, no

  	if($is_xml_feature) 
	{
		GetFontSizeLabels(\%g_font_size_hash, \%g_font_size_labels);
		# GetSpaceLabels(\%g_space_hash, \%g_space_labels);
  	}

  	my $id				= -1;
  	my $output			= "";
 	my $para_line_id	= -1;
  	my $para_line_count	= 0;

	foreach my $line (@{$lines}) 
	{
    	$id++;

		# Remove ^M character at the end of each line if any
		$line =~ s/\cM$//; 
	
		# Empty lines
    	if($line =~ /^\s*$/)
		{      
			if(!$is_allow_empty) 
			{ 
				next; 
			} 
			else 
			{
				if($is_debug) { print STDERR "#! Line $id empty!\n"; }
      		}
    	} 

    	if ($g_para[$id] eq "yes")
		{
			# Mark para
      		if($output ne "")
			{
				if($is_para_delimiter)
				{
	  				print OF "# Para $para_line_id $para_line_count\n$output";
	  				$para_line_count = 0;
				} 
				else 
				{
	  				if ($is_decode) { $output = decode_entities($output); }
					print OF $output;
				}

				$output = "";
      		}
      
	  		$para_line_id = $id;
		}
    
    	$output .= $line;
    	$para_line_count++;

    	# Output XML features
		if ($is_xml_feature)
		{
      		# Loc feature
			my $loc_feature;
      		if ($g_pos_hash[$id] != -1)
			{
				$loc_feature = "xmlLoc_".int(($g_pos_hash[$id] - $g_minpos)*8.0/($g_maxpos - $g_minpos + 1));
      		}
 
		 	# Align feature
      		my $align_feature = "xmlAlign_" . $g_align[$id];

			# Font_size feature
      		my $font_size_feature;
			if ($g_font_size[$id] == -1)
			{
				$font_size_feature = "xmlFontSize_none";
			} 
			else 
			{
				$font_size_feature = "xmlFontSize_" . $g_font_size_labels{$g_font_size[$id]};
			}

      		my $bold_feature	= "xmlBold_"	. $g_bold[$id]; 	# Bold feature
      		my $italic_feature	= "xmlItalic_"	. $g_italic[$id]; 	# Italic feature
      		my $pic_feature		= "xmlPic_"		. $g_pic[$id]; 		# Pic feature
      		my $table_feature	= "xmlTable_"	. $g_table[$id]; 	# Table feature
      		my $bullet_feature	= "xmlBullet_"	. $g_bullet[$id]; 	# Bullet feature

			# Space feature
			# my $space_feature;
			# if($g_space[$id] eq "none")
			# {
			#	$space_feature = "xmlSpace_none";
			# } 
			# else 
			# {
			#	$space_feature = "xmlSpace_" . $g_space_labels{$g_space[$id]};
			# }

      		# Differential features
			my ($align_diff, $font_size_diff, $font_face_diff, $font_sf_diff, $font_sfbi_diff, $font_sfbia_diff, $para_diff) = GetDifferentialFeatures($id);

      		# Each line and its XML features
			$output .= " |XML| $loc_feature $bold_feature $italic_feature $font_size_feature $pic_feature $table_feature $bullet_feature $font_sfbia_diff $para_diff\n"; 
		} 
		else 
		{
      		$output .= "\n";
    	}
  	}

	# Mark para
	if ($output ne "")
	{
    	if ($is_para_delimiter)
		{
      		print OF "# Para $para_line_id $para_line_count\n$output";
      		$para_line_count = 0;
    	}
		else 
		{
      		if($is_decode){ $output = decode_entities($output); }
			print OF $output;
    	}
    	$output = ""
  	}
  
  	close OF;
}

sub GetDifferentialFeatures 
{
	my ($id) = @_;

	# AlignChange feature
  	my $align_diff = "bi_xmlA_";

	if ($id == 0)
	{
    	$align_diff .= $g_align[$id];
  	} 
	elsif ($g_align[$id] eq $g_align[$id-1])
	{
    	$align_diff .= "continue";
  	} 
	else 
	{
    	$align_diff .= $g_align[$id];
  	}
  
  	# FontFaceChange feature
	my $font_face_diff = "bi_xmlF_";
  	if ($id == 0)
	{
    	$font_face_diff .= "new";
  	} 
	elsif ($g_font_face[$id] eq $g_font_face[$id-1])
	{
    	$font_face_diff .= "continue";
  	} 
	else 
	{
    	$font_face_diff .= "new";
  	}

	# FontSizeChange feature
  	my $font_size_diff = "bi_xmlS_";
	if ($id == 0)
	{
    	$font_size_diff .= "new";
	} 
	elsif ($g_font_size[$id] == $g_font_size[$id-1])
	{
    	$font_size_diff .= "continue";
  	} 
	else 
	{
    	$font_size_diff .= "new";
  	}  
  
  	# FontSFChange feature
  	my $font_sf_diff = "bi_xmlSF_";
  	if ($id == 0)
	{
    	$font_sf_diff .= "new";
	} 
	elsif ($g_font_size[$id] == $g_font_size[$id-1] && $g_font_face[$id] eq $g_font_face[$id-1])
	{
    	$font_sf_diff .= "continue";
  	} 
	else 
	{
    	$font_sf_diff .= "new";
  	}
  
  	# FontSFBIChange feature
  	my $font_sfbi_diff = "bi_xmlSFBI_";
	if ($id == 0)
	{
    	$font_sfbi_diff .= "new";
  	} 
	elsif ($g_font_size[$id] == $g_font_size[$id-1] && $g_font_face[$id] eq $g_font_face[$id-1] && $g_bold[$id] eq $g_bold[$id-1] && $g_italic[$id] eq $g_italic[$id-1])
	{
    	$font_sfbi_diff .= "continue";
  	} 
	else 
	{
    	$font_sfbi_diff .= "new";
  	}
  
  	# FontSFBIAChange feature
  	my $font_sfbia_diff = "bi_xmlSFBIA_";
  	if ($id == 0)
	{
    	$font_sfbia_diff .= "new";
  	} 
	elsif ($g_font_size[$id] == $g_font_size[$id-1] && $g_font_face[$id] eq $g_font_face[$id-1] && $g_bold[$id] eq $g_bold[$id-1] && $g_italic[$id] eq $g_italic[$id-1] && $g_align[$id] eq $g_align[$id-1])
	{
    	$font_sfbia_diff .= "continue";
  	} 
	else 
	{
    	$font_sfbia_diff .= "new";
  	}

  	# Para change feature
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

  	if ($is_debug) { print STDERR "# Map fonts\n"; }
  	my @sorted_fonts = sort { $g_font_size_hash->{$b} <=> $g_font_size_hash->{$a} } keys %{$g_font_size_hash}; # Sort by values, obtain keys
 
	my $common_size = $sorted_fonts[0];
	@sorted_fonts = sort { $a <=> $b } keys %{$g_font_size_hash}; # Sort by keys, obtain keys

	# Index of common font size
	my $common_index = 0; 
	foreach (@sorted_fonts)
	{
		# Found
    	if ($common_size == $_) 
		{
      		last;
    	}
    	$common_index++;
  	}
  
  	# Small fonts
  	for (my $i = 0; $i < $common_index; $i++)
	{
    	$g_font_size_labels->{$sorted_fonts[$i]} = "smaller";
		
		if($is_debug)
		{
      		print STDERR "$sorted_fonts[$i] --> $g_font_size_labels->{$sorted_fonts[$i]}, freq = $g_font_size_hash->{$sorted_fonts[$i]}\n";
    	}
  	}

  	# Common fonts
  	$g_font_size_labels->{$common_size} = "common";
  	if ($is_debug)
	{
    	print STDERR "$sorted_fonts[$common_index] --> $g_font_size_labels->{$sorted_fonts[$common_index]}, freq = $g_font_size_hash->{$sorted_fonts[$common_index]}\n";
  	}		

  	# Large fonts
  	for (my $i = ($common_index + 1); $i < scalar(@sorted_fonts); $i++)
	{ 
    	if ((scalar(@sorted_fonts)-$i) <= 3)
		{
      		$g_font_size_labels->{$sorted_fonts[$i]} = "largest".($i+1-scalar(@sorted_fonts));
    	} 
		else 
		{
      		$g_font_size_labels->{$sorted_fonts[$i]} = "larger";
    	}

    	if($is_debug)
		{	  
      		print STDERR "$sorted_fonts[$i] --> $g_font_size_labels->{$sorted_fonts[$i]}, freq = $g_font_size_hash->{$sorted_fonts[$i]}\n";
    	}
  	}
}

sub GetSpaceLabels 
{
	my ($g_space_hash, $g_space_labels) = @_;

  	if ($is_debug)
	{
    	print STDERR "\n# Map space\n";
  	}
  	my @sorted_spaces = sort { $g_space_hash->{$b} <=> $g_space_hash->{$a} } keys %{$g_space_hash}; # sort by freqs, obtain space faces
  
	my $common_space = $sorted_spaces[0];
  	my $common_freq	 = $g_space_hash->{$common_space};

	# Find similar common freq with larger spaces
  	for (my $i = 0; $i < scalar(@sorted_spaces); $i++)
	{
    	my $freq = $g_space_hash->{$sorted_spaces[$i]};
    	if ($freq/$common_freq > 0.8)
		{
      		if($sorted_spaces[$i] > $common_space)
			{
				$common_space = $sorted_spaces[$i];
      		}
    	} 
		else 
		{
      		last;
    	}
  	}

  	for (my $i = 0; $i < scalar(@sorted_spaces); $i++)
	{
    	if ($sorted_spaces[$i] > $common_space)
		{
      		$g_space_labels->{$sorted_spaces[$i]} = "yes";
    	} 
		else 
		{
      		$g_space_labels->{$sorted_spaces[$i]} = "no";
    	}

    	if($is_debug)
		{
      		print STDERR "$sorted_spaces[$i] --> $g_space_labels->{$sorted_spaces[$i]}, freq = $g_space_hash->{$sorted_spaces[$i]}\n";
    	}
  	}
}

sub GetAttrValue 
{
	my ($attr_text, $attr) = @_;

	my $value = "none";
  	if ($attr_text =~ /^.*$attr=\"(.+?)\".*$/)
	{
    	$value = $1;
  	}
  
  	return $value;
}

sub CheckFontAttr 
{
	my ($attr_text, $attr, $attr_hash, $count) = @_;

  	if ($attr_text =~ /^.*$attr=\"(.+?)\".*$/)
	{
		my $attr_value = $1;
   		$attr_hash->{$attr_value} = $attr_hash->{$attr_value} ? ($attr_hash->{$attr_value} + $count) : $count;
	}
}

sub ProcessTable 
{
	my ($input_text, $is_pic) = @_;

	# For table cell object
	my $is_cell		= 0;

	my $all_text	= "";
	my $text		= ""; 

	my @lines = split(/\n/, $input_text);

	my %table_pos	= (); # $table_pos{$cellText} = "$l-$t-$r-$bottom"
	my %table		= (); # $table{$row}->{$col} = \@para_texts
	my $row_from;   
	my $col_from;
	my $row_till;   
	my $col_till;

	# xml feature
	my $align	= "none"; 
	my $pos		= -1;
	foreach my $line (@lines) 
	{
		if ($line =~ /^<table (.+?)>$/)
		{
			my $attr = $1;
			
			if($is_markup) {	$markup_output .= "### Table $attr\n"; }

			# Fix: wrong regex sequence, huydhn
			#if ($attr =~ /^.*l=\"(\d+)\" t=\"(\d+)\" r=\"(\d+)\" b=\"(\d+)\".*alignment=\"(.+?)\".*$/)
			#{
			#	my ($l, $t, $r, $bottom) = ($1, $2, $3, $4);
			#	$align = $5;

			#	# pos feature
			#	$pos = ($t+$bottom)/2.0;
				
			#	if($pos < $g_minpos) { $g_minpos = $pos; }
			#	if($pos > $g_maxpos) { $g_maxpos = $pos; }
			#} 
			#else 
			#{
			#	print STDERR "# no table alignment or location \"$line\"\n";
			#	$align = "";
			#}

			my ($l, $t, $r, $bottom) = undef;
			if ($attr =~ /^.*l=\"(\d+)\".*$/) { $l = $1; }
			if ($attr =~ /^.*t=\"(\d+)\".*$/) { $t = $1; }
			if ($attr =~ /^.*r=\"(\d+)\".*$/) { $r = $1; }
			if ($attr =~ /^.*b=\"(\d+)\".*$/) { $bottom = $1; }

			if ($t && $bottom)
			{
				# pos feature
				$pos = ($t + $bottom) / 2.0;
				
				if($pos < $g_minpos) { $g_minpos = $pos; }
				if($pos > $g_maxpos) { $g_maxpos = $pos; }
			}
			else
			{
				die "# Undefined table location \"$line\"\n";
			}

			if ($attr =~ /^.*alignment=\"(\d+)\".*$/) 
			{ 
				$align = $1; 
			} 
			else 
			{
				print STDERR "# no table alignment \"$line\"\n";
				$align = "";
			}
			# End.
		}
		elsif ($line =~ /^<cell .*gridColFrom=\"(\d+)\" gridColTill=\"(\d+)\" gridRowFrom=\"(\d+)\" gridRowTill=\"(\d+)\".*>$/) # new cell
		{ 
			$col_from = $1;
			$col_till = $2;
			$row_from = $3;
			$row_till = $4;
			#print STDERR "$row_from $row_till $col_from $col_till\n";
			$is_cell = 1;
		}
		elsif ($line =~ /^<\/cell>$/) # end cell
		{ 
			my @para_texts = ();
			ProcessCell($text, \@para_texts, \%table_pos, $is_pic);
			
			for(my $i = $row_from; $i<=$row_till; $i++)
			{
				for(my $j = $col_from; $j<=$col_till; $j++)
				{
					if(!$table{$i}) { $table{$i} = (); }
					if(!$table{$i}->{$j}) {	$table{$i}->{$j} = (); }

	 				if($i == $row_from && $j == $col_from)
					{
		 				push(@{$table{$i}->{$j}}, @para_texts);
						if(scalar(@para_texts) > 1) { last; }
	 				} 
					else 
					{
		 				push(@{$table{$i}->{$j}}, ""); #add stub "" for spanning rows or cols
	 				}
				}
			}
				
			$is_cell = 0;
			$text = "";
		}    
		elsif($is_cell)
		{
			$text .= $line."\n";
			next;
		}
	}

	# note: such a complicated code is because in the normal node, Omnipage doesn't seem to strictly print column by column given a row is fixed.
	# E.g if col1: paraText1, col2: paraText21\n$paraText22, and col3: paraText31\n$paraText32
	# It will print  paraText1\tparaText21\tparaText31\n\t$paraText22\t$paraText32
	my @sorted_rows = sort {$a <=> $b} keys %table;
	my $is_first_line_para = 1;
	foreach my $row (@sorted_rows)
	{
		my %table_r = %{$table{$row}};
		my @sorted_cols = sort {$a <=> $b} keys %table_r;
		while(1)
		{
			my $is_stop = 1;
			my $row_text = "";

			foreach my $col (@sorted_cols)
			{
				# there's still some thing to process
				if(scalar(@{$table_r{$col}}) > 0)
				{ 
	 				$is_stop = 0;
	 				$row_text .= shift(@{$table_r{$col}});
				}
				$row_text .= "\t";
			}

			if ((!$is_allow_empty && $row_text =~ /^\s*$/) || ($is_allow_empty && $row_text eq ""))
			{
				$is_stop = 1;
			}

			if($is_stop) 
			{
				last;
			} 
			else 
			{
				$row_text =~ s/\t$/\n/;
				$all_text .= $row_text;
				# print STDERR "$row_text";
				
				# para
				if($is_first_line_para)
				{
	 				push(@g_para, "yes");
	 				$is_first_line_para = 0;
				} 
				else 
				{
	 				push(@g_para, "no");
				}

				if($is_xml_feature)
				{
	 				# table feature
	 				push(@g_table, "yes");

	 				# pic feature
	 				if($is_pic)
					{
		 				push(@g_pic, "yes");
	 				} 
					else 
					{
		 				push(@g_pic, "no");
	 				}

	 				push(@g_pos_hash, $pos); # update xml pos value
	 				push(@g_align, $align); # update xml alignment value

	 				### Not assign value ###
					push(@g_font_size, -1); # fontSize feature	  
					push(@g_font_face, "none"); # fontFace feature	  
	 				push(@g_bold, "no"); # bold feature	  
	 				push(@g_italic, "no"); # italic feature
	 				push(@g_bullet, "no"); # bullet feature
					# push(@gSpace, "none"); # space feature
				} # end if xml feature
			}
		}
	}

	return $all_text;
}

sub ProcessCell 
{
	my ($input_text, $para_texts, $table_pos, $is_pic) = @_;

	my $text = ""; 
	my @lines = split(/\n/, $input_text);
	my $is_para = 0;
	my $flag = 0;
	foreach my $line (@lines) 
	{    
		if ($line =~ /^<para (.*)>$/)
		{
			$text .= $line."\n"; # we need the header
			$is_para = 1;

			if($is_markup)
			{
				$markup_output .= "## ParaTable $1\n";
			}
		}
		elsif ($line =~ /^<\/para>$/)
		{
			my ($para_text, $l, $t, $r, $b) = ProcessPara($text, 1, $is_pic);
			my @tokens = split(/\n/, $para_text);

			foreach my $token (@tokens)
			{
				if($token ne "")
				{
	 				push(@{$para_texts}, $token);
	 				$flag = 1;	
				}
			}

			if(!$table_pos->{$para_text})
			{
				$table_pos->{$para_text} = "$l-$t-$r-$b";
			} 
			else 
			{
				#print STDERR "#! Warning: in method processCell, encounter the same para_text $para_text\n";
			}

			$is_para = 0;
			$text = "";
		}
		elsif ($is_para)
		{
			$text .= $line."\n";
			next;
		}
	}
	
	# at least one value should be added for cell which is ""
	if ($flag == 0) 
	{
		push(@{$para_texts}, "");
	}
}

sub ProcessPara 
{
	my ($input_text, $is_cell, $is_pic) = @_;
  
	my $is_space		 = 0;
  	my $is_special_space = 0;
  	my $is_tab			 = 0;
  	my $is_bullet		 = 0;
  	my $is_forced_eof	 = "none";  # 3 signals for end of L: forcedEOF=\"true\" in attribute of <ln> or || <nl orig=\"true\"\/> || end of </para> without encountering any of the above signal in the para plus $is_space = 0
 
 	# XML feature
	my $align = "none"; 
  	my ($l, $t, $r, $bottom);
  
  	my %font_size_hash	= ();
  	my %font_face_hash	= ();
  	my @bold_array		= ();
  	my @italic_array	= ();
  	my $space			= "none";

	my $ln_attr; 
	my $is_ln		= 0; 
	my $ln_bold 	= "none"; 
	my $ln_italic	= "none";
  
  	my $run_attr;  
	my $run_text	= ""; 
	my $is_run 		= 0; 
	my $run_bold 	= "none"; 
	my $run_italic 	= "none";

  	my $wd_attr; 
	my $wd_text		= ""; 
	my $is_wd 		= 0;

	# Word index in a line. When encountering </ln>, this parameter indicates the number of words in a line
	my $wd_index		= 0; 
  	my $ln_bold_count	= 0;
  	my $ln_italic_count	= 0;

	my $all_text = "";
	# Invariant: when never enter a new line, $text will be copied into $all_text, and $text is cleared
  	my $text	 = ""; 

	binmode(STDERR, ":utf8");
	
	my $is_first_line_para = 1;
	my @lines = split(/\n/, $input_text);

	for (my $i=0; $i < scalar(@lines); $i++)
	{
    	my $line = $lines[$i];

		# New para
		if ($line =~ /^<para (.+?)>$/)
		{
      		my $attr = $1;
      		$align	 = GetAttrValue($attr, "alignment");
			# $indent = GetAttrValue($attr, "li");
			$space	 = GetAttrValue($attr, "spaceBefore");
    	}
    	# New ln
		elsif ($line =~ /^<ln (.+)>$/)
		{
      		$ln_attr = $1;
      		$is_ln	 = 1;

			if ($is_markup) { $markup_output .= "# Line $ln_attr\n"; }

			# Fix: wrong regex sequence, huydhn
			#if ($ln_attr =~ /^.*l=\"(\d+)\" t=\"(\d+)\" r=\"(\d+)\" b=\"(\d+)\".*$/)
			#{
			#	($l, $t, $r, $bottom) = ($1, $2, $3, $4);
			#}

			if ($ln_attr =~ /^.*l=\"(\d+)\".*$/)	{ $l = $1; } else {	$l = undef; }
			if ($ln_attr =~ /^.*t=\"(\d+)\".*$/)	{ $t = $1; } else {	$t = undef; }
			if ($ln_attr =~ /^.*r=\"(\d+)\".*$/)	{ $r = $1; } else {	$r = undef; }
			if ($ln_attr =~ /^.*b=\"(\d+)\".*$/)	{ $bottom = $1; } else { $bottom = undef; }
			# End.

			$is_forced_eof = GetAttrValue($ln_attr, "forcedEOF");

			# Bold & Italic
      		if ($is_xml_feature)
			{ 
				$ln_bold	= GetAttrValue($ln_attr, "bold");
				$ln_italic	= GetAttrValue($ln_attr, "italic");
      		}
    	}
    	# New run
    	elsif ($line =~ /<run (.*)>$/)
		{
      		$run_attr	= $1;
			$is_space	= 0;
			$is_tab		= 0;
			$is_run		= 1;

			# New wd, that consists of many runs
      		if ($line =~ /^<wd (.*?)>/)
			{
				$is_wd = 1;
				$wd_attr = $1;
      		}

			# Bold & Italic
      		if ($is_xml_feature)
			{
				$run_bold	= GetAttrValue($run_attr, "bold");
				$run_italic	= GetAttrValue($run_attr, "italic");
      		}
    	}
    	# Word
    	elsif ($line =~ /^<wd (.+)?>(.+)<\/wd>$/)
		{
      		$wd_attr	= $1;
			my $word	= $2;
      		$is_space	= 0;
      		$is_tab		= 0;
 
			if ($is_markup)
			{
				$markup_output .= "$word $wd_attr\n";
				# If both bold and italic, then just use one
				if ($is_run && $run_attr =~ /(bold|italic)=\"true\"/)
				{ 
	  				$markup_output .= " $1=\"true\"";
				}
				$markup_output .= "\n";
      		}
			
			# FontSize & FontFace
      		if ($is_xml_feature)
			{ 
				CheckFontAttr($wd_attr, "fontSize", \%font_size_hash, 1);
				CheckFontAttr($wd_attr, "fontFace", \%font_face_hash, 1);
      		}

			# Bold & Italic
      		if ($is_xml_feature)
			{
				my $wd_bold		= GetAttrValue($wd_attr, "bold");
				my $wd_italic	= GetAttrValue($wd_attr, "italic");

				if ($wd_bold eq "true" || $run_bold eq "true" || $ln_bold eq "true")
				{
	  				$bold_array[$wd_index] = 1;
	  				$ln_bold_count++;
				}
	
				if ($wd_italic eq "true" || $run_italic eq "true" || $ln_italic eq "true")
				{
	  				$italic_array[$wd_index] = 1;
	  				$ln_italic_count++;
				}
      		}

      		# Add text
			$text .= "$word";

     	 	if ($is_run) 
			{
				$run_text .= "$word ";
      		}
      
	  		$wd_index++;
    	}
    	# End wd
    	elsif ($line =~ /^<\/wd>$/)
		{
      		$is_wd = 0;
      
      		if ($is_markup)
			{
				$markup_output .= "$wd_text $wd_attr\n";
				# If both bold and italic, then just use one
				if ($is_run && $run_attr =~ /(bold|italic)=\"true\"/)
				{
	  				$markup_output .= " $1=\"true\"";
				}
	
				$markup_output .= "\n";				
				$wd_attr		= "";
      		}
    	}
    	# End run
    	elsif ($line =~ /^(.*)<\/run>$/)
		{ 
      		my $word = $1;

      		# Add text
			if ($word ne "")
			{
				# Bold & Italic
				if ($is_xml_feature)
				{ 
	  				if ($run_bold eq "true" || $ln_bold eq "true")
					{
	    				$bold_array[$wd_index] = 1;
	    				$ln_bold_count++;
	  				}
	  
	  				if ($run_italic eq "true" || $ln_italic eq "true")
					{
	    				$italic_array[$wd_index] = 1;
	    				$ln_italic_count++;
	  				}
				}

				# Appear in the final result
				if ($is_ln) { $text .= "$word"; }

				# For internal record
				if ($is_run) { $run_text	.= $word . " "; }	
				if ($is_wd)  { $wd_text		.= $word; }	

				$wd_index++;
      		}

      		# Xml feature
			# Not a space, tab or new-line run
      		if ($is_xml_feature && $run_text ne "") 
			{
				my @words		= split(/\s+/, $run_text);
				my $num_words	= scalar(@words);
				CheckFontAttr($run_attr, "fontSize", \%font_size_hash, $num_words, 1);
				CheckFontAttr($run_attr, "fontFace", \%font_face_hash, $num_words, 1);
      		}

      		# Reset run
			# <run> not enclosed within <ln>
      		if (!$is_ln)
			{
				$wd_index = 0;
      		}
      
	  		$run_text			= "";
      		$is_run				= 0;      
      		$is_special_space	= 0;

			# Bold & Italic
      		if ($is_xml_feature)
			{
				$run_bold = "none";
				$run_italic = "none";
				
				# <run> not enclosed within <ln>
				if(!$is_ln)
				{
	  				$ln_bold_count = 0;
	  				$ln_italic_count = 0;
				}
      		}
    	}
    	# End ln
    	elsif ($line =~ /^<\/ln>$/)
		{
      		if((!$is_allow_empty && $text !~ /^\s*$/) || ($is_allow_empty && $text ne ""))
			{
				if ($is_forced_eof eq "true" || (!$is_cell && !$is_special_space) )
				{ 
	  				$text		.= "\n";	  
	  				# Update all_text
	  				$all_text	.= $text;
	  				$text		= "";
				}

				my $num_words = $wd_index;

				if (!$is_cell)
				{
	 				if ($is_first_line_para)
					{
		 				push(@g_para, "yes");
		 				$is_first_line_para = 0;
	 				} 
					else 
					{
		 				push(@g_para, "no");
	 				}
				}

				if ($is_xml_feature && $num_words >= 1)
				{
	  				# XML feature
	  				# Assumtion that: font_size is either occur in <ln>, or within multiple <run> under <ln>, but not both
	  				CheckFontAttr($ln_attr, "fontSize", \%font_size_hash, $num_words);
	  				CheckFontAttr($ln_attr, "fontFace", \%font_face_hash, $num_words);
				}
	
				if ($is_xml_feature && !$is_cell && !$is_special_space)
				{
	  				my $pos = ($t + $bottom)/2.0;
	  				if ($pos < $g_minpos) { $g_minpos = $pos; }
	  				if ($pos > $g_maxpos) { $g_maxpos = $pos; }

					push(@g_pos_hash, $pos);	# pos feature
	  				push(@g_align, $align);		# alignment feature
	 				push(@g_table, "no"); 		# table feature

					if ($is_pic)
					{
	    				push(@g_pic, "yes");

	   	 				# Not assign value
	    				push(@g_font_size, -1); 	# bold feature	  
	    				push(@g_font_face, "none");	# bold feature	  
	    				push(@g_bold, "no");		# bold feature	  
	    				push(@g_italic, "no");		# italic feature
	    				push(@g_bullet, "no");		# bullet feature
	  				} 
					else 
					{
	    				push(@g_pic, "no");

	    				UpdateXMLFontFeature(\%font_size_hash, \%font_face_hash);
	   	 				
						%font_size_hash = (); 
						%font_face_hash = ();

	    				UpdateXMLFeatures($ln_bold_count, $ln_italic_count, $num_words, $is_bullet, $space);
	  				}
				}
			}
      		
			# Reset ln
      		$is_ln				= 0;      
      		$is_forced_eof		= "none";
      		$is_special_space	= 0;
      		$wd_index			= 0;

			# Bold & Italic
      		if ($is_xml_feature)
			{
				$ln_bold			= "none";
				$ln_italic			= "none";
				$ln_bold_count		= 0;
				$ln_italic_count	= 0;
      		}
    	}
    	# Newline signal
    	elsif ($line =~ /^<nl orig=\"true\"\/>$/)
		{
      		if($is_ln)
			{
				$is_space = 0;
      		} 
			else 
			{
				if($is_debug)
				{
	  				print STDERR "#!!! Warning: found <nl orig=\"true\"\/> while not in tag <ln>: $line\n";
				}
      		}
    	}
    	# Space
    	elsif ($line =~ /^<space\/>$/)
		{
      		my $start_tag	= "";
      		my $end_tag		= "";
      
	  		if ($i>0 && $lines[$i-1] =~ /^<(.+?)\b.*/) { $start_tag = $1; }
	
      		if ($i < (scalar(@lines) -1) && $lines[$i+1] =~ /^<\/(.+)>/) { $end_tag = $1; }
      
      		if ($start_tag eq $end_tag && $start_tag ne "")
			{
				# print STDERR "# Special space after \"$text\"\n";
				$is_special_space = 1;
      		}

      		# Add text
      		$text .= " ";
      		$is_space = 1;
    	}
    	# Tab
    	elsif ($line =~ /^<tab .*\/>$/)
		{
      		# Add text
      		$text .= "\t";
      		$is_tab = 1;
    	}
    	# Bullet
    	elsif ($line =~ /^<bullet .*>$/)
		{
      		$is_bullet = 1;
    	}
  	}

  	$all_text .= $text;
  	return ($all_text, $l, $t, $r, $bottom, $is_space);
}

sub UpdateXMLFontFeature 
{
	my ($font_size_hash, $font_face_hash) = @_;

  	# Font size feature
  	if (scalar(keys %{$font_size_hash}) == 0)
	{
    	push(@g_font_size, -1);
  	} 
	else 
	{
    	my @sorted_fonts = sort { $font_size_hash->{$b} <=> $font_size_hash->{$a} } keys %{$font_size_hash};
    
    	my $font_size = $sorted_fonts[0];
    	push(@g_font_size, $font_size);
    
    	$g_font_size_hash{$font_size} = $g_font_size_hash{$font_size} ? ($g_font_size_hash{$font_size}+1) : 1;
  	}
  
  	# Font face feature
  	if (scalar(keys %{$font_face_hash}) == 0)
	{
    	push(@g_font_face, "none");
  	} 
	else 
	{
    	my @sorted_fonts = sort { $font_face_hash->{$b} <=> $font_face_hash->{$a} } keys %{$font_face_hash};
    	my $font_face = $sorted_fonts[0];
    	push(@g_font_face, $font_face);
    
    	$g_font_face_hash{$font_face} = $g_font_face_hash{$font_face} ? ($g_font_face_hash{$font_face}+1) : 1;
  	}
}

sub UpdateXMLFeatures 
{
	my ($ln_bold_count, $ln_italic_count, $num_words, $is_bullet, $space) = @_;

	# Bold feature
  	my $bold_feature;
  	if ($ln_bold_count/$num_words >= 0.667)
	{
    	$bold_feature = "yes";
  	} 
	else 
	{
    	$bold_feature = "no";
  	}
  	push(@g_bold, $bold_feature);
  
  	# Italic feature
  	my $italic_feature;
  	if ($ln_italic_count/$num_words >= 0.667)
	{
    	$italic_feature = "yes";
  	} 
	else 
	{
    	$italic_feature = "no";
  	}
  	push(@g_italic, $italic_feature);  
  
  	# Bullet feature
  	if ($is_bullet)
	{
    	push(@g_bullet, "yes");
  	} 
	else 
	{
    	push(@g_bullet, "no");
  	}
  
  	# Space feature
	# push(@gSpace, $space);
}

# Find the positions of header, body, and citation
sub GetStructureInfo 
{
  	my ($lines, $num_lines) = @_;

  	my ($body_length, $citation_length, $body_end_id) = SectLabel::PreProcess::findCitationText($lines, 0, $num_lines);
  
  	my ($header_length, $body_start_id);

	($header_length, $body_length, $body_start_id) = SectLabel::PreProcess::findHeaderText($lines, 0, $body_length);
  
  	# Sanity check
  	my $totalLength = $header_length + $body_length + $citation_length;
 
 	if ($num_lines != $totalLength)
	{
    	print STDOUT "Die in getStructureInfo(): different num lines $num_lines != $totalLength\n"; # to display in Web
    	die "Die in getStructureInfo(): different num lines $num_lines != $totalLength\n";
  	}
  
  	return ($header_length, $body_length, $citation_length, $body_start_id, $body_end_id);
}

# Count XML tags/values for statistics purpose
sub ProcessTagInfo 
{
	my ($line, $tags) = @_;

  	my $tag;
  	my $attr;
  
  	if ($line =~ /^<(.+?)\b(.*)/)
	{
    	$tag = $1;
    	$attr = $2;
    	if (!$tags->{$tag})
		{
      		$tags->{$tag} = ();
    	}	
    
		if ($attr =~ /^\s*(.+?)\s*\/?>/)
		{
      		$attr = $1;
    	}
    
    	my @tokens = split(/\s+/, $attr);
    	foreach my $token (@tokens)
		{
      		if($token =~ /^(.+)=(.+)$/)
			{
				my $attr_name = $1;
				my $value = $2;
	
				if (!$tags->{$tag}->{$attr_name})
				{
	  				$tags->{$tag}->{$attr_name} = ();
				}
				if (!$tags->{$tag}->{$attr_name}->{$value})
				{
	  				$tags->{$tag}->{$attr_name}->{$value} = 0;
				}
				$tags->{$tag}->{$attr_name}->{$value}++;
      		}
    	}
  	}
}

# Print tag info to file
sub PrintTagInfo 
{
	my ($tags, $tag_file) = @_;

  	open(TAG, ">:utf8", "$tag_file") || die"#Can't open file \"$tag_file\"\n";

	my @sortedTags = sort {$a cmp $b} keys %{$tags};

  	foreach(@sortedTags)
	{
    	my @attrs = sort {$a cmp $b} keys %{$tags->{$_}};
    	print TAG "# Tag = $_\n";
    	
		foreach my $attr (@attrs) 
		{
      		print TAG "$attr:";
      		my @values = sort {$a cmp $b} keys %{$tags->{$_}->{$attr}};
      		
			foreach my $value (@values)
			{
				print TAG " $value-$tags->{$_}->{$attr}->{$value}";
      		}
      
	  		print TAG "\n";
    	}
  	}
  
  	close TAG;
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
  	
	if ($is_debug)
	{
    	print STDERR "Executing: $cmd\n";
  	}
  
  	$cmd = Untaint($cmd);
	system($cmd);
}

sub NewTmpFile 
{
	my $tmpFile = `date '+%Y%m%d-%H%M%S-$$'`;
  	chomp($tmpFile);
  	return $tmpFile;
}



