package SectLabel::Tr2crfpp;

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

# Dependencies
use FindBin;
use Encode ();

# Local libraries
use SectLabel::Config;

### USER customizable section
my $crf_test	= $SectLabel::Config::crf_test;
$crf_test		= "$FindBin::Bin/../$crf_test";
### END user customizable section

my %dict		= ();
my %func_word	= ();

my %keywords	= (); 
my %bigrams		= ();
my %trigrams	= ();
my %fourthgrams	= ();

# list of tags trained in parsHed
# those with value 0 do not have frequent keyword features
my $all_tags = $SectLabel::Config::tags;

my %config = (	'1token'	=> 0,
	      		'2token'	=> 0,
	      		'3token'	=> 0,
	      		'4token'	=> 0,

	      		# Token-level features
	      		'parscit'		=> 0, # Use all Parscit original features
	      		'parscit_char'	=> 0, # Parscit char features

	      		'tokenCapital'	=> 0,
	      		'tokenNumber'	=> 0,
	      		'tokenName'		=> 0,
	      		'tokenPunct'	=> 0,
	      		'tokenKeyword'	=> 0,
	      
				'1gram'	=> 0,
	      		'2gram'	=> 0,
	      		'3gram'	=> 0,
	      		'4gram'	=> 0,

				'lineNum'		=> 0,
	      		'linePunct'		=> 0,
	      		'linePos'		=> 0,
	      		'lineLength'	=> 0,
	      		'lineCapital'	=> 0,

	      		# Pos
	      		'xmlLoc'	=> 0,
	      		'xmlAlign'	=> 0,
	      		'xmlIndent'	=> 0,
	      
	      		# Format
	      		'xmlFontSize'	=> 0,
	      		'xmlBold'		=> 0,
	      		'xmlItalic'		=> 0,
	      
	      		# Object
	      		'xmlPic'	=> 0,
	      		'xmlTable'	=> 0,
	      		'xmlBullet'	=> 0,

	      		# Bigram differential features
	      		'bi_xmlA' 		=> 0,
	      		'bi_xmlS' 		=> 0,
	      		'bi_xmlF'		=> 0,
	      		'bi_xmlSF'		=> 0,
	      		'bi_xmlSFBI'	=> 0,
	      		'bi_xmlSFBIA'	=> 0,
	      		'bi_xmlPara'	=> 0,

	      		# Unused
	      		'xmlSpace'	=> 0,
			);

my %tag_map = (	"lineLevel"	=> "UL",
	      		"xml"		=> "UX",

	      		"bi_xml"	=> "B", # Bigram
	      		"1token"	=> "U1",
	      		"2token"	=> "U2",
	      		"3token"	=> "U3",
	      		"4token"	=> "U4",

	      		"1gram"	=> "U5",
	      		"2gram"	=> "U6",
	      		"3gram"	=> "U7",
	      		"4gram"	=> "U8",
	      
	      		"capital"	=> "U9",
	      		"number"	=> "UA0",
	      		"punct"		=> "UA1",
	      		"func"		=> "UA2",
	      		"binary"	=> "UA3",
			);

binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

sub Initialize 
{
	my ($dict_file, $func_file, $config_file) = @_;

  	ReadDict($dict_file);
  	LoadListHash($func_file, \%func_word);

  	if (defined $config_file && $config_file ne "")
	{
    	LoadConfigFile($config_file, \%config);
  	} 
	else 
	{
    	die "!defined $config_file || $config_file eq \"\"\n";
  	}

	# if ($kFile ne "")		 { ReadKeywordDict($kFile, \%keywords); }
	# if ($biFile ne "")	 { ReadKeywordDict($biFile, \%bigrams); }
	# if ($triFile ne "")	 { ReadKeywordDict($triFile, \%trigrams); }
	# if ($fourthFile ne "") { ReadKeywordDict($fourthFile, \%fourthgrams); }
}

# Entry point called by sectLabel/tr2crfpp.pl
sub Tr2crfpp 
{
	my ($infile, $outfile, $dict_file, $func_file, $config_file, $is_generate_template) = @_; #$kFile, $biFile, $triFile, $fourthFile

	if(!defined $is_generate_template) { die "Die: Tr2crfpp::tr2crfpp - undefined is_generate_template\n"; }

  	Initialize($dict_file, $func_file, $config_file);

  	# File IOs
  	open (IF, "<:utf8", $infile) || die "# crash\t\tCan't open \"$infile\"";
  	
	my @lines = <IF>;
  	ProcessData(\@lines, $outfile, $is_generate_template);

	close (IF);
}

# Entry point called by SectLabel::Controller
sub ExtractTestFeatures 
{
	my ($text_lines, $filename, $dict_file, $func_file, $config_file, $is_debug) = @_;
  	
	my $tmpfile = BuildTmpFile($filename);
  	Initialize($dict_file, $func_file, $config_file);

	my $is_generate_template = 0;
  	ProcessData($text_lines, $tmpfile, $is_generate_template, $is_debug);

  	return $tmpfile;
}

sub ProcessData 
{
	my ($lines, $outfile, $is_generate_template, $is_debug) = @_;

	open (OF, ">:utf8", $outfile) || die "# crash\t\tCan't open \"$outfile\"";

  	my %count_map	= ();
  	GetDocLineCounts($lines, \%count_map);
  	my $num_docs		= scalar(keys %count_map);

  	my $is_abstract	= 0;
  	my $is_intro	= 0;
  	my $doc_id		= 0;
  	my $tag			= "noTag";
	my $index		= -1;
  	my $num_lines	= $count_map{$doc_id};

	if ($is_debug) { print STDERR "numLines = $num_lines\n"; }

	my $xml_feature = "";
	
	foreach my $line (@{$lines}) 
	{
    	chomp($line);
    	$index++;
    
		# if ($line =~ /^\#/) { next; } # skip comments

		# Blank lines, new documents
    	if ($line =~ /^\s*$/) 
		{
      		print OF "\n";

      		# Reset
      		$is_abstract = 0;
      		$is_intro	 = 0;
      		$index		 = -1;

			$doc_id++;
      		$num_lines = $count_map{$doc_id};

      		next; 
    	} 
		else 
		{
      		if ($line =~ /^(.+?) \|\|\| (.+)$/) 
			{
				$tag	= $1;
				$line	= $2;
				
				if(!defined $all_tags->{$tag})
				{
					# print STDERR "#! Warning: tag \"$tag\" not defined - skip \"$line\"\n";
	  				next;
				}
      		}

      		if ($line =~ /^(.+) \|XML\| (.+?)$/) 
			{
				$line			= $1;
				$xml_feature	= $2;
      		}

      		if ($line =~ /abstract/i)
			{
				$is_abstract = 1;
      		} 
			elsif ($line =~ /introduction/i)
			{
				$is_intro = 1;
      		} 
			else 
			{
				if($is_abstract == 1)
				{
	  				$is_abstract = 2;
				}

				if($is_intro == 1)
				{
	  				$is_intro = 2;
				}
      		}

      		my @feats		= ();
      		my @templates	= CRFFeature($line, $index, $num_lines, $is_abstract, $is_intro, $xml_feature, $tag, \@feats);

			# Generate CRF features
      		if ($is_generate_template)
			{
				$is_generate_template = 0; # Done generate template file
				print STDOUT join("", @templates);
      		}

			# if($index == -1) 
			# {
			# 	last;
			# }

			print OF join (" ", @feats);
      		print OF "\n";
    	}
  	}

  	close (OF);
}

sub GetDocLineCounts 
{
	my ($lines, $count_map) = @_;

  	my $count	= 0;
  	my $doc_id	= 0;
  	my $flag	= 0;

  	foreach my $line (@{$lines}) 
	{
    	chomp($line);
    	$count++;

		# Blank lines, new documents
    	if ($line =~ /^\s*$/) 
		{
			# More than 1 document
      		$flag = 1;

      		$count_map->{$doc_id} = $count;
      
      		$count = 0;
      		$doc_id++;
    	}
  	}

  	if ($flag == 0)
	{
    	$count_map->{$doc_id} = $count;
  	}
}

###
# Main method to extract features
###
sub CRFFeature 
{
	my ($line, $index, $num_lines, $is_abstract, $is_intro, $xml_feature, $tag, $feats) = @_;
  	
	my $token			= "";
  	my @templates		= ();
  	my %feature_counts	= (); # To perform feature linking

	my @tmp_tokens	= split(/\s+/, $line);
  	# Filter out empty token
  	my @tokens		= ();

  	foreach my $token (@tmp_tokens)
	{
    	$token =~ s/^\s+//g; # Strip off leading spaces
    	$token =~ s/\s+$//g; # Strip off trailing spaces

		if ($token ne "")
		{
      		push(@tokens, $token);
    	}
  	}

  	# Full form: does not count in crf template file, simply for outputing purpose to get the whole line data
  	my $lineFull = join("|||", @tokens);
  	push(@{$feats}, "$lineFull");

  	###
  	# Line-level features
  	###
	GenerateLineFeature($line, \@tokens, $index, $num_lines, $is_abstract, $is_intro, $feats, "# Line-level features\n", $tag_map{"lineLevel"}, \@templates, \%feature_counts);

	###
  	# XML features
	###
  	GenerateXmlFeature($xml_feature, $feats, "# Xml features\n", $tag_map{"xml"}, $tag_map{"bi_xml"}, \@templates, \%feature_counts);

	# GenerateNumberFeature(\@tokens, $feats, "#number. features\n", $tag_map{"number"}, \@templates, \%feature_counts);
  
  	# Keyword features
	for (my $i = 1; $i <= 4; $i++)
	{
    	if ($config{"${i}gram"})
		{
      		my @top_tokens = ();
      		GetNgrams($line, $i, \@top_tokens);
      		GenerateKeywordFeature(\@top_tokens, $feats, \%keywords, "# ${i}gram features\n", $tag_map{"${i}gram"}, \@templates, \%feature_counts);
    	}
  	}

  	###
  	# Token-level features
  	###
  	# Apply most of Parscit features
  	for (my $i = 1; $i <= 4; $i++)
	{
    	if($config{"${i}token"})
		{
      		GenerateTokenFeature(\@tokens, ($i-1), \%keywords, $feats, "#${i}token general features\n", $tag_map{"${i}token"}, \@templates, \%feature_counts);
    	}
  	}

  	###
  	# Feature linking
  	###
  	my $i = undef;

	if ($config{"back1"})
	{
    	FeatureLink(\@templates, "UA", "#constraint on first token features at -1 relative position \n", $feature_counts{$tag_map{"1token"}}->{"start"}, $feature_counts{$tag_map{"1token"}}->{"end"}, "-1");
  	}
  	push(@templates, "\n");

  	if ($config{"forw1"})
	{
    	FeatureLink(\@templates, "UB", "#constraint on first token features at +1 relative position \n", $feature_counts{$tag_map{"1token"}}->{"start"}, $feature_counts{$tag_map{"1token"}}->{"end"}, "1");
  	}
  	push(@templates, "\n");

  	# Output tag
  	push(@{$feats}, $tag);

  	push(@templates, "# Output\nB0\n");
  	return @templates;
}

sub GenerateXmlFeature 
{
	my ($xml_feature, $feats, $msg, $label, $biLabel, $templates, $feature_counts) = @_;

  	my @features	= split(/\s+/, $xml_feature);  	
	my $count		= 0;
 	my $type		= undef;

  	my %bi_feature_flag = ();
	foreach my $feature (@features) 
	{
    	if ($feature =~ /^bi_xml/) { $bi_feature_flag{$count} = 1; }

    	if ($feature =~ /^((bi_)?xml[a-zA-Z]+)\_.+$/)
		{
      		$type = $1;
      		if ($config{$type}) 
			{
				push(@{$feats}, $feature);
				$count++;
      		}
    	} 
		else 
		{
      		die "Die: xml feature doesn't match \"$feature\"\n";
    	}
  	}
  
  	UpdateTemplate(scalar(@{$feats}), $count, $msg, $label, $templates, $feature_counts, $biLabel, \%bi_feature_flag);
}

sub UpdateTemplate 
{
	my ($cur_size, $num_features, $msg, $label, $templates, $feature_counts, $biLabel, $bi_feature_flag) = @_;

  	# Crfpp template
  	push(@{$templates}, $msg);
  	my $prev_size = $cur_size - $num_features;
  	$feature_counts->{$label}->{"start"} = $prev_size;
  	$feature_counts->{$label}->{"end"} = $cur_size;
  
  	my $i = 0;
  	for (my $j = $prev_size; $j < $cur_size; $j++)
	{
    	if ($bi_feature_flag->{$i})
		{
      		push(@{$templates}, "$biLabel".$i++.":%x[0,$j]\n");
    	} 
		else 
		{
      		push(@{$templates}, "$label".$i++.":%x[0,$j]\n");
    	}
  	}
  	
	push(@{$templates}, "\n");
}

sub GenerateLineFeature 
{
	my ($line, $tokens, $index, $num_lines, $is_abstract, $is_intro, $feats, $msg, $label, $templates, $feature_counts) = @_;

  	# Crfpp template
  	push(@{$templates}, $msg);
  	my $prev_size = scalar(@{$feats});
  	$feature_counts->{$label}->{"start"} = $prev_size;

  	# Editor
  	my $has_possible_editor = ($line =~ /[^A-Za-z](ed\.|editor|editors|eds\.)/) ? "possibleEditors" : "noEditors";
  	push(@{$feats}, $has_possible_editor);
  
  	if ($config{"lineNum"})
	{
    	my $word	= $tokens->[0];
    	my $num		= "";

    	if (scalar(@{$tokens}) > 1)
		{
      		$num =	($word =~ /^[1-9]\.[1-9]\.?$/)			? "posSubsec"		: 
					($word =~ /^[1-9]\.[1-9]\.[1-9]\.?$/)	? "posSubsubsec"	: 
					($word =~ /^\w\.[1-9]\.[1-9]\.?$/)		? "posCategory"		:
					"";
    	}
    
    	if ($num eq "")
		{
      		$num =	($word =~ /^[1-9][A-Za-z]\w*$/)		? "numFootnote" 	:
					($word =~ /^[1-9]\s*(http|www)/) 	? "numWebfootnote" 	:
	  				"lineNumOthers";
    	}
    
    	push(@{$feats}, $num);
  	}
  
  	if ($config{"linePunct"})
	{
    	my $punct	= "";
    	$punct		=	($line =~ /@\w+\./)			? "possibleEmail"	: 
      					($line =~ /(www|http)/)		? "possibleWeb" 	: 
						($line =~ /\(\d\d?\)\s*$/)	? "endNumbering" 	: 
	  					"linePunctOthers";
  
    	push(@{$feats}, $punct);
  	}
  
  	if ($config{"lineCapital"})
	{
    	my $cap = GetCapFeature($tokens);
    	push(@{$feats}, $cap);
  	}
  
  	if ($config{"linePos"})
	{
    	my $position = "POS-".int($index*8.0/$num_lines);
    	push(@{$feats}, $position);
  	}
  
  	if ($config{"lineLength"})
	{ 
    	# Num tokens, words
    	my @tokens		= split(/\s+/, $line);    
    	my $num_words	= 0;

    	foreach my $token (@tokens)
		{
      		if ($token =~ /^\p{P}*[a-zA-Z]+\p{P}*$/)
			{
				$num_words++;
      		}
    	}
    
		my $word_length = 
      	($num_words >= 5) ? "5+Words" : "${num_words}Words";

    	push(@{$feats}, $word_length);
  	}

  	# For crfpp template
  	my $cur_size = scalar(@{$feats});
  	$feature_counts->{$label}->{"end"} = $cur_size;
  
  	my $i = 0;
  	for (my $j = $prev_size; $j < $cur_size; $j++)
	{
    	push(@{$templates}, "$label".$i++.":%x[0,$j]\n");
  	}
  
  	push(@{$templates}, "\n");
}

sub GenerateTokenFeature 
{
	my ($tokens, $index, $keywords, $feats, $msg, $label, $templates, $feature_counts) = @_;

  	my $num_tokens	= scalar(@{$tokens});
  	my $token		= "EMPTY";
  	if ($num_tokens > $index) { $token = $tokens->[$index]; }

  	# Crfpp template
  	push(@{$templates}, $msg);
  	my $prev_size = scalar(@{$feats});
  	$feature_counts->{$label}->{"start"} = $prev_size;

  	# Prep
  	my $word	= $token;
  	my $word_lc	= lc($token);

	# No punctuation
	my $word_np	= $token;
	$word_np	=~ s/[^\w]//g;  	
	if ($word_np =~ /^\s*$/) { $word_np = "EMPTY"; }

	# Lowercased word, no punctuation
  	my $word_lcnp = lc($word_np);    
  	if ($word_lcnp =~ /^\s*$/) { $word_lcnp = "EMPTY"; }
  
  	# Lexical features
  	push(@{$feats}, "TOKEN-$word"); # Lexical word
  	push(@{$feats}, "$word_lc");  	# Lowercased word
  	push(@{$feats}, "$word_lcnp");  # Lowercased word, no punct

	# Parscit char feature
	if ($config{"parscit"})
	{
		# Parscit char feature
    	if ($config{"parscit_char"})
		{
      		my @chars 		= split(//,$word);
      		my $last_char 	= $chars[-1];
      	
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
	  		push(@{$feats}, $last_char);		       

      		# Thang added 02-Mar-10 this to avoid uninitialized warnning messages when using -w
      		for (my $i = scalar(@chars); $i < 4;$i++)
			{
				push(@chars, '|');
      		}

      		push(@{$feats}, $chars[0]);		      		# 2 = first char
      		push(@{$feats}, join("",@chars[0..1]));  	# 3 = first 2 chars
      		push(@{$feats}, join("",@chars[0..2]));  	# 4 = first 3 chars
      		push(@{$feats}, join("",@chars[0..3]));  	# 5 = first 4 chars
      
      		push(@{$feats}, $chars[-1]);		       	# 6 = last char
      		push(@{$feats}, join("",@chars[-2..-1])); 	# 7 = last 2 chars
      		push(@{$feats}, join("",@chars[-3..-1])); 	# 8 = last 3 chars
      		push(@{$feats}, join("",@chars[-4..-1]));	# 9 = last 4 chars
    	}
  	}

  	# Capitalization features
  	if ($config{"tokenCapital"})
	{
    	my $ortho = ($word_np =~ /^[\p{IsUpper}]$/) 				? "singleCap" 	:
      				($word_np =~ /^[\p{IsUpper}][\p{IsLower}]+/)	? "InitCap" 	:
					($word_np =~ /^[\p{IsUpper}]+$/) 				? "AllCap" 		: "others";
    
		push(@{$feats}, $ortho);
  	}

  	# Number features
  	if ($config{"tokenNumber"})
	{
    	my $num = undef;
    
    	if ($config{"parscit"})
		{
      		$num = 	($word_np =~ /^(19|20)[0-9][0-9]$/) 	? "year" 			:
					($word =~ /[0-9]\-[0-9]/) 				? "possiblePage" 	:
	  				($word =~ /[0-9]\([0-9]+\)/)	 		? "possibleVol"		:
	    			($word_np =~ /^[0-9]$/) 				? "1dig" 			:
	      			($word_np =~ /^[0-9][0-9]$/) 			? "2dig" 			:
					($word_np =~ /^[0-9][0-9][0-9]$/) 		? "3dig" 			:
		  			($word_np =~ /^[0-9]+$/) 				? "4+dig" 			:
		    		($word_np =~ /^[0-9]+(th|st|nd|rd)$/) 	? "ordinal" 		:
		      		($word_np =~ /[0-9]/) 					? "hasDig" 			: "nonNum";
    	} 
		else 
		{
      		$num =	($word =~ /^[1-9]+\.$/)					? "endDot" 			:
	  				($word =~ /^[1-9]+:$/) 					? "endCol"			:
	    	    	# Parscit features
	    			($word_np =~ /^(19|20)[0-9][0-9]$/) 	? "year" 			:
	      			($word =~ /[0-9]\-[0-9]/) 				? "possiblePage"	:
					($word =~ /[0-9]\([0-9]+\)/) 			? "possibleVol" 	:
		  			($word_np =~ /^[0-9]$/) 				? "1dig" 			:
		    		($word_np =~ /^[0-9][0-9]$/) 			? "2dig" 			:
		      		($word_np =~ /^[0-9][0-9][0-9]$/) 		? "3dig" 			:
					($word_np =~ /^[0-9]+$/) 				? "4+dig" 			:
			  		($word_np =~ /^[0-9]+(th|st|nd|rd)$/) 	? "ordinal" 		:
			    	($word_np =~ /[0-9]/) 					? "hasDig" 			: "nonNum";
    	}
    
		push(@{$feats}, $num);
  	}

  	# Gazetteer (names) features
  	if ($config{"tokenName"})
	{
    	my $dict_status = (defined $dict{$word_lcnp}) ? $dict{$word_lcnp} : 0;
    	# my $is_in_dict = ($dict_status != 0) ? "is_in_dict" : "no";
    
		my $is_in_dict = $dict_status;
    
		my ($publisher_name, $place_name, $month_name, $last_name, $female_name, $male_name) = undef;
    
    	if ($dict_status >= 32) { $dict_status -= 32; 	$publisher_name	= "publisherName"	} else { $publisher_name	= "no"; }
    	if ($dict_status >= 16)	{ $dict_status -= 16; 	$place_name 	= "placeName" 		} else { $place_name 		= "no"; }
    	if ($dict_status >= 8)	{ $dict_status -= 8; 	$month_name 	= "monthName" 		} else { $month_name 		= "no"; }
    	if ($dict_status >= 4)	{ $dict_status -= 4; 	$last_name 		= "lastName" 		} else { $last_name 		= "no"; }
    	if ($dict_status >= 2) 	{ $dict_status -= 2; 	$female_name 	= "femaleName" 		} else { $female_name 		= "no"; }
    	if ($dict_status >= 1) 	{ $dict_status -= 1; 	$male_name 		= "maleName" 		} else { $male_name 		= "no"; }
    
    	push(@{$feats}, $is_in_dict);		# 13 = name status
    	push(@{$feats}, $male_name);	    # 14 = male name
    	push(@{$feats}, $female_name);		# 15 = female name
    	push(@{$feats}, $last_name);	    # 16 = last name
    	push(@{$feats}, $month_name);		# 17 = month name
    	push(@{$feats}, $place_name);		# 18 = place name
    	push(@{$feats}, $publisher_name);	# 19 = publisher name
  	}
  
  	# Punctuation features
  	if ($config{"tokenPunct"})
	{
    	my $punct = undef;

    	if ($config{"parscit"})
		{
      		$punct = 	($word =~ /^[\"\'\`]/) 						? "leadQuote" 	:
						($word =~ /[\"\'\`][^s]?$/) 				? "endQuote" 	:
	  					($word =~ /\-.*\-/) 						? "multiHyphen"	:
	    				($word =~ /[\-\,\:\;]$/) 					? "contPunct" 	:
	      				($word =~ /[\!\?\.\"\']$/) 					? "stopPunct" 	:
	        			($word =~ /^[\(\[\{\<].+[\)\]\}\>].?$/) 	? "braces" 		:
		  				($word =~ /^[0-9]{2-5}\([0-9]{2-5}\).?$/)	? "possibleVol" : "others";
    	} 
		else 
		{
      		$punct =	($word =~ /^[a-z]\d$/) 						? "possibleVar" : # x1, x2
	  		# Parscit
			#			($word =~ /^[\"\'\`]/) 						? "leadQuote" 	:
			#			($word =~ /[\"\'\`][^s]?$/) 				? "endQuote" 	:
			#			($word =~ /\-.*\-/) 						? "multiHyphen" :
						($word =~ /[\-\,\:\;]$/) 					? "contPunct" 	:
		  				($word =~ /[\!\?\.\"\']$/) 					? "stopPunct" 	:
		    			($word =~ /^[\(\[\{\<].+[\)\]\}\>].?$/) 	? "braces" 		:
		     	 		($word =~ /^[0-9]{2-5}\([0-9]{2-5}\).?$/)	? "possibleVol"	: "punctOthers";

			#			($word =~ /^[\*\^\x{0608}\x{0708}\x{07A0}][A-Za-z]\w*$/  && $index == 0)	? "punctFootnote" 	:
			#			($word =~ /^[\p{P}\p{Math_Symbol}]*\p{Math_Symbol}\p{P}\p{Math_Symbol}]*/)	? "mathSym" 		:
    	}

    	push(@{$feats}, $punct);
	}

  	if ($config{"tokenKeyword"})
	{
    	my $keyword_fea = "noKeyword";
    	my $token = $word;

		$token =~ s/^\p{P}+//g; # Strip out leading punctuations
    	$token =~ s/\p{P}+$//g; # Strip out trailing punctuations
    	$token =~ s/\d/0/g; 	# Canocalize number into "0"
    
		foreach (keys %{$all_tags})
		{
      		if ($all_tags->{$_} == 0) { next; }
      
      		if ($keywords->{$_}->{$token})
			{
				$keyword_fea = "keyword-$_";
				last;
      		}
    	}

    	push(@{$feats}, $keyword_fea);
  	}

  	# For crfpp template
  	my $cur_size = scalar(@{$feats});
  	$feature_counts->{$label}->{"end"} = $cur_size;
  	
	my $i = 0;
  	for(my $j = $prev_size; $j < $cur_size; $j++)
	{
    	push(@{$templates}, "$label".$i++.":%x[0,$j]\n");
  	}
  
  	push(@{$templates}, "\n");
}

sub GetCapFeature 
{
	my ($tokens) = @_;
	
	my $cap 	= "OthersCaps";
 	my $n 		= 0;
  	my $count 	= 0; # non-word
  	my $count1 	= 0;
  	my $line 	= "";

  	# Check capitalization
  	my $is_skip = 0;
  	for (my $i = 0; $i < scalar(@{$tokens}); $i++)
	{
    	my $token = $tokens->[$i];
    	if ($token =~ /^\p{P}*$/) { next; }
	
		my @chars = split(//, $token);    
		# Exclude non-word or an important words such as a, an, the, on, in ...
    	if (scalar(@chars) < 4) 
		{ 
			# Dont' consider skip if it is the first token as numbers
      		if (!($i == 0 && $token =~ /\d/))
			{
				$is_skip = 1; 
      		}
      		
			next;
    	} 
	
		# Capitalized
    	if ($token =~ /^[A-Z][A-Za-z]*$/)
		{ 
      		$count++;
      		$line .= "$token ";
    	}
    
    	$n++;
  	}

	# Consider only if at lest 1 capitalized word
  	if ($count >0)
	{
    	if ($count == $n)
		{
      		$cap = ($is_skip) ? "Most" : "All";
      
	  		if($line =~ /[a-z]/)
			{
				$cap .= "InitCaps";
      		} 
			else 
			{
				$cap .= "CharCaps";
      		}

			# First token contains number
	  		if ($tokens->[0] =~ /\d/) 
			{
				$cap = "number$cap";
      		} 
			# Two few capitalized letter to conclude any pattern
			elsif ($count == 1)
			{
				$cap = "OthersCaps";
      		}
    	}
  	}
  
  	return $cap;
}

sub FeatureLink 
{
	my ($templates, $label, $msg, $start, $end, $rel_pos) = @_;

  	# To constraint on last token features at $rel_pos relative position
  	my $i = 0;  	
	push(@{$templates}, $msg);
  
  	for (my $j = $start; $j < $end; $j++)
	{
    	push(@{$templates}, "$label".$i++.":%x[$rel_pos,$j]\n");
  	}
  
  	push(@{$templates}, "\n");
}

sub GenerateKeywordFeature 
{

	my ($tokens, $feats, $keywords, $msg, $label, $templates, $feature_counts) = @_;

  	# Crfpp template
  	push(@{$templates}, $msg);
  	my $prev_size = scalar(@{$feats});
  	$feature_counts->{$label}->{"start"} = $prev_size;

  	foreach (keys %{$all_tags})
	{
    	if($all_tags->{$_} == 0) { next; };

    	my $i=0;
    	for(; $i<scalar(@{$tokens}); $i++)
		{
      		if ($keywords->{$_}->{$tokens->[$i]})
			{
				push(@{$feats}, "$_-".$tokens->[$i]);
				last;
      		}
    	}

    	if ($i==scalar(@{$tokens}))
		{
      		push(@{$feats}, "none");
    	}
  	}

  	# For crfpp template
  	my $cur_size = scalar(@{$feats});
  	$feature_counts->{$label}->{"end"} = $cur_size;
  
  	my $i = 0;
  	for (my $j = $prev_size; $j < $cur_size; $j++)
	{
    	push(@{$templates}, "$label".$i++.":%x[0,$j]\n");
  	}
  	
	push(@{$templates}, "\n");
}

# Get ngrams
sub GetNgrams 
{
	my ($line, $num_ngram, $ngrams) = @_;

	# $line = lc($line);

  	my @tmp_tokens = split(/\s+/, $line);

  	# Filter out empty token
  	my @tokens = ();
	foreach my $token (@tmp_tokens)
	{ 
    	if ($token ne "")
		{
      		$token =~ s/^\s+//g; 	# Strip off leading spaces
      		$token =~ s/\s+$//g; 	# Strip off trailing spaces
      		$token =~ s/^\p{P}+//g; # Strip out leading punctuations
      		$token =~ s/\p{P}+$//g; # Strip out trailing punctuations
      		$token =~ s/\d/0/g; 	# Canocalize number into "0"
			
			# Email pattern, try to normalize
      		if ($token =~ /(\w.*)@(.*\..*)/)
			{
				# $token =~ /(http:\/\/|www\.)/){
				$token = $1;
				
				my $remain = $2;
				$token =~ s/\w+/x/g;
				$token =~ s/\d+/0/g;
				$token .= "@".$remain;
      		} 

      		if ($token ne "")
			{
				push(@tokens, $token);
      		}
    	}
  	}

  	my $count = 0;  
	for (my $i = 0; $i <= $#tokens; $i++)
	{ 
		# not enough ngrams
    	if (($#tokens-$i + 1) < $num_ngram) { last; };
    
		my $ngram = "";
    	for (my $j=$i; $j <= ($i+$num_ngram-1); $j++)
		{
      		my $token = $tokens[$j];

      		if ($j < ($i+$num_ngram-1))
			{
				$ngram .= "$token-";
      		} 
			else 
			{
				$ngram .= "$token";
      		}
    	}

    	if ($ngram =~ /^\s*$/)	{ next; } # Skip those with white spaces
    	if ($ngram =~ /^\d*$/)	{ next; } # Skip those with only digits
    	if ($func_word{$ngram})	{ next; } # Skip function words, matter for ngram = 1

		push(@{$ngrams}, $ngram);

    	$count++;
    	if ($count == 4) { last; }
  	}
}

sub GenerateNumberFeature 
{
	my ($tokens, $feats, $msg, $label, $templates, $feature_counts) = @_;

  	# crfpp template
  	push(@{$templates}, $msg);
  	my $prev_size = scalar(@{$feats});
  	$feature_counts->{$label}->{"start"} = $prev_size;

  	my $line 	= join("", @{$tokens});
  	$line 		=~ s/\s+//g;
  	my @chars	= split(//, $line);

  	my $count 	= 0;
  	my $n 		= scalar(@chars);

	foreach(@chars)
	{
    	if (/\d/) { $count++; }
  	}

  	my $num = "otherNum";
  
  	if ($n > 1)
	{
    	my $ratio = $count/$n;
    	if ($ratio >= 0.7)
		{
      		$num = "HighNum";
    	} 
		elsif ($ratio >= 0.4)
		{
     		$num = "MeidumNum";
    	}
  	}

  	push(@{$feats}, $num);
  
  	# For crfpp template
  	my $cur_size = scalar(@{$feats});
  	$feature_counts->{$label}->{"end"} = $cur_size;
  
  	my $i = 0;
  	for (my $j = $prev_size; $j < $cur_size; $j++)
	{
    	push(@{$templates}, "$label".$i++.":%x[0,$j]\n");
  	}
  
  	push(@{$templates}, "\n");
}

sub GenerateFuncFeature 
{
	my ($tokens, $feats, $msg, $label, $templates, $feature_counts) = @_;

  	# Crfpp template
  	push(@{$templates}, $msg);
  	my $prev_size = scalar(@{$feats});
  	$feature_counts->{$label}->{"start"} = $prev_size;

  	my $n 		= scalar(@{$tokens});
  	my $count 	= 0;
  
  	foreach my $token (@{$tokens})
	{
    	$token =~ s/^\p{P}+//; # Strip leading punct
    	$token =~ s/\p{P}+$//; # Strip traiing punct
    	$token = lc($token);

		if ($func_word{$token})
		{
      		$count++;
    	}
  	}

  	if ($count == 0)
	{
    	push(@{$feats}, "NoFunc");
  	} 
	elsif ($count <= 5)
	{
    	push(@{$feats}, "FewFunc");
  	} 
	else 
	{
    	push(@{$feats}, "AlotFunc");
  	}

  	# For crfpp template
  	my $cur_size = scalar(@{$feats});
  	$feature_counts->{$label}->{"end"} = $cur_size;
  
  	my $i = 0;
  	for (my $j = $prev_size; $j < $cur_size; $j++)
	{
    	push(@{$templates}, "$label".$i++.":%x[0,$j]\n");
  	}
  
  	push(@{$templates}, "\n");
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


sub Fatal 
{
    my $msg = shift;
    print STDERR "Fatal Exception: $msg\n";
}


sub Decode 
{
	my ($infile, $model_file, $outfile) = @_;
  
  	my $labeled_file = BuildTmpFile($infile);
  	Execute("$crf_test -v1 -m $model_file $infile > $labeled_file"); #  -v1: output confidence information

  	open (PIPE, "<:utf8", $labeled_file) || die "# crash\t\tCan't open \"$labeled_file\"";
  	open (OUT, ">:utf8", $outfile) || die "# crash\t\tCan't open \"$outfile\"";

  	while(<PIPE>)
	{
    	chomp;
    	print OUT "$_\n";
  	}
  	
	close PIPE;
  	close OUT;
 
 	unlink($labeled_file);
  	return 1;
}

sub ReadKeywordDict 
{
  	my ($infile, $keywords) = @_;

  	open (IF, "<:utf8", $infile) || die "fatal\t\tCannot open \"$infile\"!";
  	# Process input file
  	while(<IF>)
  	{
  		chomp;
    
    	if (/^(.+?): (.+)$/)
		{
      		my $tag 	= $1;
      		my @tokens 	= split(/\s+/, $2);
      
	  		$keywords->{$tag} = ();
      		foreach(@tokens)
			{
				$keywords->{$tag}->{$_} = 1;
      		}
    	}
  	}

  	close (IF);
}

sub LoadConfigFile 
{
	my ($infile, $configs) = @_;

  	open (IF, "<:utf8", $infile) || die "fatal\t\tCannot open \"$infile\"!";
  
  	while(<IF>)
	{
    	chomp;
    
    	if (/^(.+)=(.+)$/)
		{
      		my $name = $1;
      		my $value = $2;
      		$configs->{$name} = $value;
    	}
  	}

  	close (IF);
}

sub ReadDict 
{
  	my ($dictFileLoc) = @_;

  	my $mode = 0;
  	open (DATA, "<:utf8", $dictFileLoc) || die "Could not open dict file $dictFileLoc: $!";
  	while (<DATA>) 
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
      		if (!$dict{$key})
			{
				$dict{$key} = $mode;
      		} 
			else 
			{
				if ($dict{$key} >= $mode) 
				{ 
					next; 
				}
				# Not yet tagged
				else 
				{ 
					$dict{$key} += $mode; 
				}
      		}
    	}
  	}
  
	close (DATA);
}

sub LoadListHash 
{
	my ($infile, $hash) = @_;

  	open(IF, "<:utf8", $infile) || die "#Can't open file \"$infile\"";

  	while(<IF>)
	{
    	chomp;
    	$hash->{$_} = 1;
  	}

  	close IF;
}

sub Untaint 
{
	my ($s) = @_;
  	if ($s =~ /^([\w \-\@\(\),\.\/<>]+)$/) 
	{
    	$s = $1;               # $data now untainted
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
  	$cmd = Untaint($cmd);
  	system($cmd);
}

1;
