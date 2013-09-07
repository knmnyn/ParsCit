package ParsCit::Tr2crfpp;

###
# Created from templateAppl.pl version 3.4 by Min-Yen Kan <kanmy@comp.nus.edu.sg>.
# Modified by Isaac Councill on 7/20/07: wrapped the code as a package for use by
# an external controller.
#
# Copyright 2005 \251 by Min-Yen Kan (not sure what this means for IGC edits, but
# what the hell -IGC)
###

use utf8;
use strict 'vars';

use FindBin;
use Encode ();

use Omni::Config;
use ParsCit::Config;

### USER customizable section
my $tmp_dir		= $ParsCit::Config::tmpDir;
$tmp_dir		= "$FindBin::Bin/../$tmp_dir";

my $dict_file	= $ParsCit::Config::dictFile;
$dict_file		= "$FindBin::Bin/../$dict_file";

my $crf_test	= $ParsCit::Config::crf_test;
$crf_test		= "$FindBin::Bin/../$crf_test";

my $model_file	= $ParsCit::Config::modelFile;
$model_file		= "$FindBin::Bin/../$model_file";

my $split_model_file	= $ParsCit::Config::splitModelFile;
$split_model_file		= "$FindBin::Bin/../$split_model_file";
### END user customizable section

###
# Huydhn: don't know its function
###
my %dict 	 = ();
# Omnilib configuration: object name
my $obj_list = $Omni::Config::obj_list;

###
# Huydhn: prepare data for trfpp, segmenting unmarked reference
###
sub PrepDataUnmarked
{
	my ($omnidoc, $cit_addrs) = @_;

	# Generate a temporary file
	my $tmpfile	= BuildTmpFile("");

	# Fetch te dictionary
	ReadDict($dict_file);

	# Open the temporary file, prepare to write
	my $output_tmp = undef;
	unless (open($output_tmp, ">:utf8", $tmpfile)) 
	{
		fatal("Could not open tmp file " . $tmp_dir . "/" . $tmpfile . " for writing.");
      	return;
    }
	
	# Calculate the average length in character and in word of the whole cite text
	my @avg_chars = ();
	my @avg_words = ();
	# Calculate the average font size
	my @avg_font_sizes	 = ();
	# Calculate the average line starting point
	my @avg_start_points = ();

	# Get all pages
	my $pages		= $omnidoc->get_objs_ref();
	my $start_page	= $cit_addrs->[ 0 ]->{ 'L1' };
	my $end_page	= $cit_addrs->[ -1 ]->{ 'L1' };
	# 
	my $addr_index	= 0;

	for (my $x = $start_page; $x <= $end_page; $x++)
	{
		my $columns 	 = $pages->[ $x ]->get_objs_ref();
		my $start_column =	($x == $cit_addrs->[ 0 ]->{ 'L1' })		? 
							$cit_addrs->[ 0 ]->{ 'L2' }		: 0;
		my $end_column	 =	($x == $cit_addrs->[ -1 ]->{ 'L1' })	? 
							$cit_addrs->[ -1 ]->{ 'L2' }	: (scalar(@{ $columns }) - 1);

		for (my $y = $start_column; $y <= $end_column; $y++)
		{
			my $paras		= $columns->[ $y ]->get_objs_ref();
			my $start_para	=	(($x == $cit_addrs->[ 0 ]->{ 'L1' }) && ($y == $cit_addrs->[ 0 ]->{ 'L2' }))	? 
								$cit_addrs->[ 0 ]->{ 'L3' }		: 0;
			my $end_para	=	(($x == $cit_addrs->[ -1 ]->{ 'L1' }) && ($y == $cit_addrs->[ -1 ]->{ 'L2' }))	? 
								$cit_addrs->[ -1 ]->{ 'L3' }	: (scalar(@{ $paras }) - 1);

			for (my $z = $start_para; $z <= $end_para; $z++)
			{
				my $lines = $paras->[ $z ]->get_objs_ref();

				my $start_line	=	(($x == $cit_addrs->[ 0 ]->{ 'L1' }) && ($y == $cit_addrs->[ 0 ]->{ 'L2' }) && ($z == $cit_addrs->[ 0 ]->{ 'L3' }))		? 
									$cit_addrs->[ 0 ]->{ 'L4' }		: 0;
				my $end_line	=	(($x == $cit_addrs->[ -1 ]->{ 'L1' }) && ($y == $cit_addrs->[ -1 ]->{ 'L2' }) && ($z == $cit_addrs->[ -1 ]->{ 'L3' }))	? 
									$cit_addrs->[ -1 ]->{ 'L4' }	: (scalar(@{ $lines }) - 1);
			
				# Total number of line in the paragraph
				my $total_ln	= 0;
				# Average per paragraph
				my $avg_char	= 0;
				my $avg_word	= 0;
				my $avg_font_size	= 0;
				my $avg_start_point	= 0;

				for (my $t = $start_line; $t <= $end_line; $t++)
				{
					if (($x == $cit_addrs->[ $addr_index ]{ 'L1' }) &&
						($y == $cit_addrs->[ $addr_index ]{ 'L2' }) &&
						($z == $cit_addrs->[ $addr_index ]{ 'L3' }) &&
						($t == $cit_addrs->[ $addr_index ]{ 'L4' }) &&
						($t < scalar(@{ $lines })))
					{
						# Get content
						my $ln = $lines->[ $t ]->get_content();

						# Trim line
						$ln	=~ s/^\s+|\s+$//g;
						# Skip blank lines
						if (($ln =~ m/^\s*$/) || ($lines->[ $t ]->get_name() ne $obj_list->{ 'OMNILINE' }))
						{
							$addr_index++;
							next; 
						}

						# Total length in char
						$avg_char	+= length($ln);

						# All words in a line
						my @tokens	= split(/ +/, $ln);

						# Total length in word
						$avg_word	+= scalar(@tokens);

						my $xml_runs = $lines->[ $t ]->get_objs_ref();
						# Font size
						$avg_font_size	 += ($xml_runs->[ 0 ]->get_font_size() eq '') ? 0 : $xml_runs->[ 0 ]->get_font_size();
						# Line starting point
						$avg_start_point += ($lines->[ $t ]->get_left_pos() eq '') ? 0 : $lines->[ $t ]->get_left_pos();

						# Total number of non-blank line
						$total_ln++;

						#
						$addr_index++;
					}
				}

				# Calculate the average length
				$avg_char = ($total_ln != 0) ? ($avg_char / $total_ln) : 0;
				$avg_word = ($total_ln != 0) ? ($avg_word / $total_ln) : 0;

				# Calculate the average font size
				$avg_font_size	 = ($total_ln != 0) ? ($avg_font_size / $total_ln) : 0;
				# Calculate the average line starting point
				$avg_start_point = ($total_ln != 0) ? ($avg_start_point / $total_ln) : 0;

				# Save the average
				push @avg_chars, $avg_char;
				push @avg_words, $avg_word;
				push @avg_font_sizes, $avg_font_size;
				push @avg_start_points, $avg_start_point;
			}
		}
	}

	# A line which has length Less than 0.8 * average is likely to be the end of a reference
	my $lower_ratio = 0.8;
	my $upper_ratio = 1.2;

	# Line start point ratio
	my $start_lower_ratio = 0.98;
	my $start_upper_ratio = 1.02;

	# Get all pages
	$pages		= $omnidoc->get_objs_ref();
	$start_page	= $cit_addrs->[ 0 ]->{ 'L1' };
	$end_page	= $cit_addrs->[ -1 ]->{ 'L1' };
	# 
	$addr_index	= 0;

	for (my $x = $start_page; $x <= $end_page; $x++)
	{
		my $columns 	 = $pages->[ $x ]->get_objs_ref();
		my $start_column =	($x == $cit_addrs->[ 0 ]->{ 'L1' })		? 
							$cit_addrs->[ 0 ]->{ 'L2' }		: 0;
		my $end_column	 =	($x == $cit_addrs->[ -1 ]->{ 'L1' })	? 
							$cit_addrs->[ -1 ]->{ 'L2' }	: (scalar(@{ $columns }) - 1);

		for (my $y = $start_column; $y <= $end_column; $y++)
		{
			my $paras		= $columns->[ $y ]->get_objs_ref();
			my $start_para	=	(($x == $cit_addrs->[ 0 ]->{ 'L1' }) && ($y == $cit_addrs->[ 0 ]->{ 'L2' }))	? 
								$cit_addrs->[ 0 ]->{ 'L3' }		: 0;
			my $end_para	=	(($x == $cit_addrs->[ -1 ]->{ 'L1' }) && ($y == $cit_addrs->[ -1 ]->{ 'L2' }))	? 
								$cit_addrs->[ -1 ]->{ 'L3' }	: (scalar(@{ $paras }) - 1);
			
			my $prev_para	= (-1);
			for (my $z = $start_para; $z <= $end_para; $z++)
			{
				my $lines = $paras->[ $z ]->get_objs_ref();

				my $start_line	=	(($x == $cit_addrs->[ 0 ]->{ 'L1' }) && ($y == $cit_addrs->[ 0 ]->{ 'L2' }) && ($z == $cit_addrs->[ 0 ]->{ 'L3' }))		? 
									$cit_addrs->[ 0 ]->{ 'L4' }		: 0;
				my $end_line	=	(($x == $cit_addrs->[ -1 ]->{ 'L1' }) && ($y == $cit_addrs->[ -1 ]->{ 'L2' }) && ($z == $cit_addrs->[ -1 ]->{ 'L3' }))	? 
									$cit_addrs->[ -1 ]->{ 'L4' }	: (scalar(@{ $lines }) - 1);

				# Average value
				my $avg_char	= shift(@avg_chars);
				my $avg_word	= shift(@avg_words);
				my $avg_font_size	= shift(@avg_font_sizes);
				my $avg_start_point	= shift(@avg_start_points);

				for (my $t = $start_line; $t <= $end_line; $t++)
				{
					# This line does not belong to the citation section
					if (($x != $cit_addrs->[ $addr_index ]{ 'L1' }) ||
						($y != $cit_addrs->[ $addr_index ]{ 'L2' }) ||
						($z != $cit_addrs->[ $addr_index ]{ 'L3' }) ||
						($t != $cit_addrs->[ $addr_index ]{ 'L4' }) ||
						($t >= scalar(@{ $lines })))
					{
						next ;
					}

					# Get content
					my $ln = $lines->[ $t ]->get_content();

					# Trim line
					$ln	=~ s/^\s+|\s+$//g;
					# Skip blank lines
					if ($ln =~ m/^\s*$/) 
					{ 
						$addr_index++;
						next; 
					}

					# All words in a line
					my @tokens	= split(/\s+/, $ln);
				
					# Features will be stored here
					my @feats	= ();
					# Current feature
					my $current = 0;

					# The first one is the whole line, separate by |||
					push @feats, $tokens[ 0 ];
					for (my $i = 1; $i < scalar(@tokens); $i++)
					{
						$feats[ $current ] = $feats[ $current ] . "|||" . $tokens[ $i ];
					}
					$current++;

					# Length in characters
					push @feats, ((length($ln) > $lower_ratio * $avg_char) ? "normal" : "short");
					$current++;

					# Line has year number
					if ($ln =~ m/\b\(?[1-2][0-9]{3}[\p{IsLower}]?[\)?\s,\.]*(\s|\b)/s)
					{
						push @feats, "hasYear";
					}
					else
					{
						push @feats, "noYear";
					}
					$current++;

					# The line contains many authors and doesn't has number
					if ($ln =~ m/\d/) 
					{ 
						push @feats, "noLongAuthorLine";
					}
					else
					{
						$_			= $ln;
						my $n_sep	= s/([,;])/$1/g;

						# Have enough author, this line is a long author line
						if ($n_sep >= 3)
						{
							push @feats, "isLongAuthorLine";		
						}
						else
						{
							push @feats, "noLongAuthorLine";	
						}
					}
					$current++;

					# Ending punctuation
					my $last_word		= $tokens[ scalar(@tokens) - 1 ];
					# Last character
					my @last_word_chars	= split(//, $last_word);
					my $last_char		= $last_word_chars[ scalar(@last_word_chars) - 1 ];
					# Last char is a dot					
					if ($last_char eq ".")
					{
						push @feats, "period";
					}
					elsif ($last_char eq ",")
					{
						push @feats, "comma";
					}
					elsif ($last_char eq ";")
					{
						push @feats, "semicolon";
					}
					elsif ($last_char eq ":")
					{
						push @feats, "colon";
					}
					elsif ($last_char eq "?")
					{
						push @feats, "question";
					}
					elsif ($last_char eq "!")
					{
						push @feats, "exclamation";
					}
					elsif (($last_char eq ")") || ($last_char eq "]") || ($last_char eq "}"))
					{
						push @feats, "cbracket";
					}
					elsif (($last_char eq ")") || ($last_char eq "]") || ($last_char eq "}"))
					{
						push @feats, "obracket";
					}
					elsif ($last_char eq "-")
					{
						push @feats, "hyphen";
					}
					else
					{
						push @feats, "other";
					}
					$current++;

					# First word
					my $first_word	= $tokens[ 0 ];
					PrepDataUnmarkedToken($first_word, \@feats, \$current);
					# Second word
					my $second_word	= (scalar(@tokens) > 1) ? $tokens[ 1 ] : "EMPTY";
					PrepDataUnmarkedToken($second_word, \@feats, \$current);
					# Last word
					PrepDataUnmarkedToken($last_word, \@feats, \$current);
	
					# XML features
					# Bullet
					my $bullet = undef;
					if ($lines->[ $t ]->get_name() eq $obj_list->{ 'OMNILINE' }) { $bullet = $lines->[ $t ]->get_bullet(); }
					if ((defined $bullet) && ($bullet eq 'true'))
					{
						push @feats, 'xmlBullet_yes';	
					}
					else
					{
						push @feats, 'xmlBullet_no';
					}
					$current++;

					# First word format: bold, italic, font size
					my $xml_runs = undef;
					if (($lines->[ $t ]->get_name() eq $obj_list->{ 'OMNILINE' })) { $xml_runs = $lines->[ $t ]->get_objs_ref(); }
			
					# First word format: bold
					my $bold = undef;
					if (defined $xml_runs) { $bold = $xml_runs->[ 0 ]->get_bold(); }
					if ((defined $bold) && ($bold eq 'true'))
					{	
						push @feats, 'xmlBold_yes'; 
					}
					else
					{
						push @feats, 'xmlBold_no';	
					}
					$current++;

					# First word format: italic
					my $italic = undef;
					if (defined $xml_runs) { $italic = $xml_runs->[ 0 ]->get_italic(); }
					if ((defined $italic) && ($italic eq 'true'))
					{
						push @feats, 'xmlItalic_yes'; 
					}	
					else
					{
						push @feats, 'xmlItalic_no';	
					}
					$current++;

					# First word format: font size
					my $font_size = undef;
					if (defined $xml_runs) { $font_size = $xml_runs->[ 0 ]->get_font_size(); }
					if ((defined $font_size) && ($font_size > $avg_font_size * $upper_ratio))
					{
						push @feats, 'xmlFontSize_large';
					}
					elsif ((defined $font_size) && ($font_size < $avg_font_size * $lower_ratio))
					{
						push @feats,  'xmlFontSize_small';
					}
					else
					{
						push @feats,  'xmlFontSize_normal';
					}
					$current++;

					# First word format: starting point, left alignment
					my $start_point = undef;
					if (($lines->[ $t ]->get_name() eq $obj_list->{ 'OMNILINE' })) { $start_point = $lines->[ $t ]->get_left_pos(); }
					if ((defined $start_point) && ($start_point > $avg_start_point * $start_upper_ratio))
					{
						push @feats, 'xmlBeginLine_right';
					}
					elsif ((defined $start_point) && ($start_point < $avg_start_point * $start_lower_ratio))
					{
						push @feats, 'xmlBeginLine_left';
					}
					else
					{
						push @feats, 'xmlBeginLine_normal';
					}
					$current++;

					# Paragraph
					if ($z != $prev_para)
					{
						push @feats, 'xmlPara_new';
						$prev_para = $z;
					}
					else
					{
						push @feats, 'xmlPara_continue';
					}
					$current++;

					# Output tag
					push @feats, "parsCit_unknown";
					$current++;

					# Export output: print
					print $output_tmp $feats[ 0 ];
					for (my $i = 1; $i < scalar(@feats); $i++) { print $output_tmp " " . $feats[ $i ]; }
					print $output_tmp "\n";

					#
					$addr_index++;
				}
			}
		}
	}

	close $output_tmp;

	# Finish preparing data
    return $tmpfile;
}

###
# Huydhn: prepare data for trfpp, segmenting unmarked reference, token level
###
sub PrepDataUnmarkedToken
{
	my ($token, $feats, $current) = @_;
	
	# No punctuation
	my $token_np	= $token;
   	$token_np		=~ s/[^\w]//g;

	# and in lower case
	my $token_lc_np	= lc($token_np);    

	push @{ $feats }, "TOKEN-" . $token;
	$$current++;

	# Characters
	my @token_chars = split(//, $token);
	my $token_len   = scalar @token_chars;
		
	# First char
	push @{ $feats }, $token_chars[ 0 ];
	$$current++;
		
	# First 2 chars
	if ($token_len >= 2) {
		push @{ $feats }, join("", @token_chars[0..1]);
	} else {
		push @{ $feats }, $token_chars[ 0 ];
	}
	$$current++;

	# First 3 chars
	if ($token_len >= 3) {
		push @{ $feats }, join("", @token_chars[0..2]);
	} elsif ($token_len >= 2) {
		push @{ $feats }, join("", @token_chars[0..1]);
	} else {
		push @{ $feats }, $token_chars[ 0 ];
	}
	$$current++;

	# First 4 chars
    if ($token_len >= 4) {
		push @{ $feats }, join("", @token_chars[0..3]);
	} elsif ($token_len >= 3) {
		push @{ $feats }, join("", @token_chars[0..2]);
	} elsif ($token_len >= 2) {
		push @{ $feats }, join("", @token_chars[0..1]);
	} else {
		push @{ $feats }, $token_chars[ 0 ];
	}
	$$current++;
			
	# Last char
    push @{ $feats }, $token_chars[-1];
	$$current++;
			
	# Last 2 chars
    if ($token_len >= 2) {
		push @{ $feats }, join("", @token_chars[-2..-1]);
	} else {
    	push @{ $feats }, $token_chars[-1];
	}
	$$current++;

	# Last 3 chars
    if ($token_len >= 3) {
		push @{ $feats }, join("", @token_chars[-3..-1]);
	} elsif ($token_len >= 2) {
		push @{ $feats }, join("", @token_chars[-2..-1]);
	} else {
    	push @{ $feats }, $token_chars[-1];
	}
	$$current++;

	# Last 4 chars
	if ($token_len >= 4) {
		push @{ $feats }, join("", @token_chars[-4..-1]);
	} elsif ($token_len >= 3) {
		push @{ $feats }, join("", @token_chars[-3..-1]);
	} elsif ($token_len >= 2) {
		push @{ $feats }, join("", @token_chars[-2..-1]);
	} else {
    	push @{ $feats }, $token_chars[-1];
	}
	$$current++;

	# Caption
	if ($token_np eq "")
	{
		push @{ $feats }, "other";
	}
	else
	{
		my $ortho =	($token_np =~ /^[\p{IsUpper}]$/)				? "singleCap"	:				
					($token_np =~ /^[\p{IsUpper}][\p{IsLower}]+/)	? "InitCap"		: 
					($token_np =~ /^[\p{IsUpper}]+$/)				? "AllCap"		: "others";
    	push @{ $feats }, $ortho;
	}
	$$current++;

	# Numbers
   	my $num =	($token_np	=~ /^(19|20)[0-9][0-9]$/)	? "year"		 :
				($token		=~ /[0-9]\-[0-9]/)			? "possiblePage" :
				($token		=~ /[0-9]\([0-9]+\)/)		? "possibleVol"	 :
				($token_np	=~ /^[0-9]$/)				? "1dig"		 :
				($token_np	=~ /^[0-9][0-9]$/)			? "2dig"		 :
				($token_np	=~ /^[0-9][0-9][0-9]$/)		? "3dig"		 :
				($token_np	=~ /^[0-9]+$/)				? "4+dig"		 :
				($token_np	=~ /^[0-9]+(th|st|nd|rd)$/)	? "ordinal"		 :
				($token_np	=~ /[0-9]/)					? "hasDig"		 : "nonNum";
	push @{ $feats }, $num;
	$$current++;

	# Gazetteer (names)
	my $dict_status	= (defined $dict{ $token_lc_np }) ? $dict{ $token_lc_np } : 0;
	my $is_in_dict	= $dict_status;

	my ($publisher_name, $place_name, $month_name, $last_name, $female_name, $male_name) = undef;

   	if ($dict_status >= 32) 
	{
		$dict_status	-= 32;
		$publisher_name	= "publisherName";
   	} 
	else 
	{
		$publisher_name	= "no";
   	}
	
	if ($dict_status >= 16) 
	{
		$dict_status	-= 16;
		$place_name		= "placeName";
	} 
	else 
	{
		$place_name		= "no";
	}

   	if ($dict_status >= 8) 
	{
		$dict_status	-= 8;
		$month_name		= "monthName";
   	} 
	else 
	{
		$month_name		= "no";
   	}

	if ($dict_status >= 4) 
	{
		$dict_status	-= 4;
		$last_name		= "lastName";
	} 
	else 
	{
		$last_name		= "no";
	}

   	if ($dict_status >= 2) 
	{
		$dict_status	-= 2;
		$female_name	= "femaleName";
   	} 
	else 
	{
		$female_name	= "no";
   	}
			
	if ($dict_status >= 1) 
	{
		$dict_status	-= 1;
		$male_name		= "maleName";
   	} 
	else 
	{
		$male_name		= "no";
   	}

	# Name status
   	push @{ $feats }, $is_in_dict;
	$$current++;

	# Male name
	push @{ $feats }, $male_name;
	$$current++;

	# Female name
	push @{ $feats }, $female_name;
	$$current++;
			
	# Last name
	push @{ $feats }, $last_name;
	$$current++;

	# Month name
	push @{ $feats }, $month_name;
	$$current++;

	# Place name
	push @{ $feats }, $place_name;
	$$current++;
			
	# Publisher name
 	push @{ $feats }, $publisher_name;
	$$current++;
}

# Prepare data for trfpp
sub PrepData 
{
    my ($rcite_text, $filename) = @_;

	# Generate a temporary file
    my $tmpfile = BuildTmpFile($filename);

	###
	# Thang Mar 10: move inside the method, only load when running
	###
    ReadDict($dict_file); 

    unless (open(TMP, ">:utf8", $tmpfile)) 
	{
		fatal("Could not open tmp file " . $tmp_dir . "/" . $tmpfile . " for writing.");
      	return;
    }

    foreach (split "\n", $$rcite_text) 
	{	
		# Skip blank lines
		if (/^\s*$/) { next; }

		my $tag		= "";
		my @tokens	= split(/ +/);
		my @feats	= ();
		
		###
		# Modified by Artemy Kolchinsky (v090625): 'ed.' also matches things like 'Med.', 
		# which are found extremely often in my document database. To avoid this situation, 
		# I changed this string to match 'ed.', 'editor', 'editors', and 'eds.' if *not* 
		# preceeded by an alphabetic character.
		###
		my $has_possible_editor = (/[^A-Za-z](ed\.|editor|editors|eds\.)/) ? "possibleEditors" : "noEditors";

		my $j = 0;
		for (my $i = 0; $i <= $#tokens; $i++) 
		{
	    	if ($tokens[$i] =~ /^\s*$/) { next; }

			###
			# Thang v100401: /^\<\/([\p{IsLower}]+)/)
			###
	    	if ($tokens[$i] =~ /^<\/[a-zA-Z]+/) { next; }
			
			###
			# Thang v100401: /^\<([\p{IsLower}]+)/)
			###
	    	if ($tokens[$i] =~ /^<([a-zA-Z]+)/) 
			{
				$tag = $1;
				next;
	    	}

	    	# Prep
	    	my $word	= $tokens[$i];
			
			# No punctuation
	    	my $word_np	 = $tokens[$i];			      
	    	$word_np	 =~ s/[^\w]//g;
	    	if ($word_np =~ /^\s*$/) { $word_np	= "EMPTY"; }

			# Lowercased word, no punctuation
			my $word_lc_np	= lc($word_np);    
	    	if ($word_lc_np	=~ /^\s*$/) { $word_lc_np = "EMPTY"; }

	    	# Feature generation

			# 0 = lexical word	# 20 = possible editor

	    	$feats[ $j ][ 0 ] = $word;

	    	my @chars = split(//, $word);
			my $chars_len = scalar @chars;

	    	my $last_char = $chars[ -1 ];
	    	if ($last_char =~ /[\p{IsLower}]/) 
			{ 
				$last_char = 'a'; 
			}
	    	elsif ($last_char =~ /[\p{IsUpper}]/) 
			{ 
				$last_char = 'A'; 
			}
	    	elsif ($last_char =~ /[0-9]/) 
			{ 
				$last_char = '0'; 
			}

			# 1 = last char
			push(@{ $feats[ $j ] }, $last_char);

			# 2 = first char
			push(@{ $feats[ $j ] }, $chars[0]);

		    # 3 = first 2 chars
			if ($chars_len >= 2) { 
				push(@{ $feats[ $j ] }, join("", @chars[0..1]));
			} else {
				push(@{ $feats[ $j ] }, $chars[0]);
			}

		    # 4 = first 3 chars
			if ($chars_len >= 3) {
				push(@{ $feats[ $j ] }, join("", @chars[0..2]));
			} elsif ($chars_len >= 2) {
				push(@{ $feats[ $j ] }, join("", @chars[0..1]));
			} else {
				push(@{ $feats[ $j ] }, $chars[0]);
			}

			# 5 = first 4 chars
	    	if ($chars_len >= 4) {
				push(@{ $feats[ $j ] }, join("", @chars[0..3]));
			} elsif ($chars_len >= 3) {
				push(@{ $feats[ $j ] }, join("", @chars[0..2]));
			} elsif ($chars_len >= 2) {
				push(@{ $feats[ $j ] }, join("", @chars[0..1]));
			} else {
				push(@{ $feats[ $j ] }, $chars[0]);
			}
			
			# 6 = last char
	    	push(@{ $feats[ $j ] }, $chars[-1]);
			
			# 7 = last 2 chars
	    	if ($chars_len >= 2) {
				push(@{ $feats[ $j ] }, join("", @chars[-2..-1]));
			} else {
	    		push(@{ $feats[ $j ] }, $chars[-1]);
			}

			# 8 = last 3 chars
	    	if ($chars_len >= 3) {
				push(@{ $feats[ $j ] }, join("", @chars[-3..-1]));
			} elsif ($chars_len >= 2) {
				push(@{ $feats[ $j ] }, join("", @chars[-2..-1]));
			} else {
	    		push(@{ $feats[ $j ] }, $chars[-1]);
			}

			# 9 = last 4 chars
		    if ($chars_len >= 4) {
				push(@{ $feats[ $j ] }, join("", @chars[-4..-1]));
			} elsif ($chars_len >= 3) {
				push(@{ $feats[ $j ] }, join("", @chars[-3..-1]));
			} elsif ($chars_len >= 2) {
				push(@{ $feats[ $j ] }, join("", @chars[-2..-1]));
			} else {
	    		push(@{ $feats[ $j ] }, $chars[-1]);
			}

			# 10 = lowercased word, no punct
		    push(@{ $feats[ $j ] }, $word_lc_np);  

	    	# 11 - capitalization
	    	my $ortho = ($word_np =~ /^[\p{IsUpper}]$/) ? "singleCap" : 
						($word_np =~ /^[\p{IsUpper}][\p{IsLower}]+/) ? "InitCap" : 
						($word_np =~ /^[\p{IsUpper}]+$/) ? "AllCap" : "others";
	    	push(@{ $feats[ $j ] }, $ortho);

	    	# 12 - numbers
	    	my $num =	($word_np	=~ /^(19|20)[0-9][0-9]$/) ? "year" :
						($word		=~ /[0-9]\-[0-9]/) ? "possiblePage" :
						($word		=~ /[0-9]\([0-9]+\)/) ? "possibleVol" :
						($word_np	=~ /^[0-9]$/) ? "1dig" :
						($word_np	=~ /^[0-9][0-9]$/) ? "2dig" :
						($word_np	=~ /^[0-9][0-9][0-9]$/) ? "3dig" :
						($word_np	=~ /^[0-9]+$/) ? "4+dig" :
						($word_np	=~ /^[0-9]+(th|st|nd|rd)$/) ? "ordinal" :
						($word_np	=~ /[0-9]/) ? "hasDig" : "nonNum";
			push(@{ $feats[ $j ] }, $num);

	    	# Gazetteer (names)
	    	my $dict_status	= (defined $dict{ $word_lc_np }) ? $dict{ $word_lc_np } : 0;
	    	my $is_in_dict	= $dict_status;

	    	my ($publisher_name, $place_name, $month_name, $last_name, $female_name, $male_name);

	    	if ($dict_status >= 32) 
			{
				$dict_status	-= 32;
				$publisher_name	= "publisherName";
	    	} 
			else 
			{
				$publisher_name	= "no";
	    	}

	    	if ($dict_status >= 16) 
			{
				$dict_status	-= 16;
				$place_name		= "placeName";
	    	} 
			else 
			{
				$place_name		= "no";
	    	}

	    	if ($dict_status >= 8) 
			{
				$dict_status	-= 8;
				$month_name		= "monthName";
	    	} 
			else 
			{
				$month_name		= "no";
	    	}

	    	if ($dict_status >= 4) 
			{
				$dict_status	-= 4;
				$last_name		= "lastName";
	    	} 
			else 
			{
				$last_name		= "no";
	    	}

	    	if ($dict_status >= 2) 
			{
				$dict_status	-= 2;
				$female_name	= "femaleName";
	    	} 
			else 
			{
				$female_name	= "no";
	    	}
			
			if ($dict_status >= 1) 
			{
				$dict_status	-= 1;
				$male_name		= "maleName";
	    	} 
			else 
			{
				$male_name		= "no";
	    	}

			# 13 = name status
	    	push(@{ $feats[ $j ] }, $is_in_dict);

			# 14 = male name
			push(@{ $feats[ $j ] }, $male_name);

			# 15 = female name
			push(@{ $feats[ $j ] }, $female_name);
			
			# 16 = last name
	    	push(@{ $feats[ $j ] }, $last_name);

			# 17 = month name
	    	push(@{ $feats[ $j ] }, $month_name);

			# 18 = place name
	    	push(@{ $feats[ $j ] }, $place_name);
			
			# 19 = publisher name
	    	push(@{ $feats[ $j ] }, $publisher_name);

			# 20 = possible editor
	    	push(@{ $feats[ $j ] }, $has_possible_editor);

	    	# Not accurate ($#tokens counts tags too)
	    	if ($#tokens <= 0) { next; }

	    	my $location = int ($j / $#tokens * 12);
			
			# 21 = relative location
	    	push(@{ $feats[ $j ]}, $location);	      

	    	# 22 - punctuation
	    	my $punct =	($word	=~ /^[\"\'\`]/) ? "leadQuote" :
						($word	=~ /[\"\'\`][^s]?$/) ? "endQuote" :
						($word	=~ /\-.*\-/) ? "multiHyphen" :
						($word	=~ /[\-\,\:\;]$/) ? "contPunct" :
						($word	=~ /[\!\?\.\"\']$/) ? "stopPunct" :
						($word	=~ /^[\(\[\{\<].+[\)\]\}\>].?$/) ? "braces" :
						($word	=~ /^[0-9]{2-5}\([0-9]{2-5}\).?$/) ? "possibleVol" : "others";
		    # 22 = punctuation
			push(@{ $feats[ $j ] }, $punct);

		    # output tag
		    push(@{ $feats[ $j ] }, $tag);

	    	$j++;
		}

		# Export output: print
		for (my $j = 0; $j <= $#feats; $j++) 
		{
	    	print TMP join (" ", @{ $feats[ $j ] });
	    	print TMP "\n";
		}

		print TMP "\n";
    }
    close TMP;

	# Finish prepare data for crfpp
    return $tmpfile;
}

sub BuildTmpFile 
{
    my ($filename) = @_;

    my $tmpfile	= $filename;
    $tmpfile	=~ s/[\.\/]//g;
    $tmpfile	.= $$ . time;

	# Untaint tmpfile variable
    if ($tmpfile =~ /^([-\@\w.]+)$/) { $tmpfile = $1; }
    
	###
	# Altered by Min (Thu Feb 28 13:08:59 SGT 2008)
	###
    return "/tmp/$tmpfile"; 
    # return $tmpfile;
}

sub Fatal 
{
    my $msg = shift;
    print STDERR "Fatal Exception: $msg\n";
}

###
# Huydhn: split the reference portion using crf++ model
###
sub SplitReference
{
	my ($infile, $outfile) = @_;

	unless (open(PIPE, "$crf_test -m $split_model_file $infile |")) 
	{
		Fatal("Could not open pipe from crf call: $!");
		return;
    }

	my $output;
    {
		local $/ = undef;
		$output = <PIPE>;
    }
    close PIPE;

    unless(open(IN, "<:utf8", $infile)) 
	{
		Fatal("Could not open input file: $!");
		return;
    }
    
	my @code_lines = ();

	while(<IN>) 
	{
		chomp();
		push @code_lines, $_;
    }
    close IN;

    my @output_lines = split "\n", $output;
    for (my $i = 0; $i <= $#output_lines; $i++) 
	{
		# Remove blank line
		if ($output_lines[$i] =~ m/^\s*$/) { next; }
	
		my @output_tokens	= split(/\s+/, $output_lines[$i]);
		my $class			= $output_tokens[ $#output_tokens ];
		my @code_tokens		= split(/\s+/, $code_lines[ $i ]);

		if ($#code_tokens < 0) { next; }

		$code_tokens[ $#code_tokens ] = $class;
		$code_lines[$i]	= join " ", @code_tokens;
    }

    unless (open(OUT, ">:utf8", $outfile)) 
	{
		Fatal("Could not open crf output file for writing: $!");
		return;
    }

    foreach my $line (@code_lines) 
	{
		###
		# Thang v100401: add this to avoid double decoding
		###
      	if (!Encode::is_utf8($line))
		{
			print OUT Encode::decode_utf8($line), "\n";
		} 
		else 
		{
			print OUT $line, "\n";
      	}
    }
    close OUT;
	return 1;
}

sub Decode 
{
    my ($infile, $outfile) = @_;

    unless (open(PIPE, "$crf_test -m $model_file $infile |")) 
	{
		Fatal("Could not open pipe from crf call: $!");
		return;
    }

    my $output;
    {
		local $/ = undef;
		$output = <PIPE>;
    }
    close PIPE;

    unless(open(IN, "<:utf8", $infile)) 
	{
		Fatal("Could not open input file: $!");
		return;
    }

    my @code_lines = ();

	while(<IN>) 
	{
		chomp();
		push @code_lines, $_;
    }
    close IN;

    my @output_lines = split "\n", $output;
    for (my $i = 0; $i <= $#output_lines; $i++) 
	{
		# Remove blank line
		if ($output_lines[$i] =~ m/^\s*$/) { next; }
	
		my @output_tokens	= split(/\s+/, $output_lines[$i]);
		my $class			= $output_tokens[ $#output_tokens ];
		my @code_tokens		= split(/\s+/, $code_lines[ $i ]);

		if ($#code_tokens < 0) { next; }

		$code_tokens[ $#code_tokens ] = $class;
		$code_lines[$i]	= join "\t", @code_tokens;
    }

    unless (open(OUT, ">:utf8", $outfile)) 
	{
		Fatal("Could not open crf output file for writing: $!");
		return;
    }

    foreach my $line (@code_lines) 
	{
		###
		# Thang v100401: add this to avoid double decoding
		###
      	if (!Encode::is_utf8($line))
		{
			print OUT Encode::decode_utf8($line), "\n";
		} 
		else 
		{
			print OUT $line, "\n";
      	}
    }
    close OUT;
	return 1;
}

sub ReadDict 
{
	my $dict_file_loc = shift @_;

  	my $mode = 0;
  	open (DATA, "<:utf8", $dict_file_loc) || die "Could not open dict file $dict_file_loc: $!";

	while (<DATA>) 
	{
    	if		(/^\#\# Male/) 		{ $mode = 1; }		# male names
    	elsif	(/^\#\# Female/)	{ $mode = 2; }		# female names
    	elsif	(/^\#\# Last/)		{ $mode = 4; }		# last names
    	elsif	(/^\#\# Chinese/)	{ $mode = 4; }		# last names
    	elsif	(/^\#\# Months/)	{ $mode = 8; }		# month names
    	elsif	(/^\#\# Place/)		{ $mode = 16; }		# place names
    	elsif	(/^\#\# Publisher/)	{ $mode = 32; }		# publisher names
    	elsif	(/^\#/)				{ next; }
    	else 
		{
      		chop;
      		my $key = $_;
      		my $val = 0;

			# Has probability
			if (/\t/) { ($key, $val) = split (/\t/,$_); }

      		# Already tagged (some entries may appear in same part of lexicon more than once
			if ((defined $dict{ $key }) && ($dict{ $key } >= $mode))
			{ 
				next; 
			}
			# not yet tagged
      		else 
			{ 
				$dict{ $key } += $mode; 
			}
    	}
  	}

	close (DATA);
}

1;
