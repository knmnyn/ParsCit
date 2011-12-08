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
	if ($FindBin::Bin =~ /(.*)/) 
	{
		$path = $1;
	}
}
use lib "$path/../../lib";

use lib "/home/wing.nus/tools/languages/programming/perl-5.10.0/lib/5.10.0";
use lib "/home/wing.nus/tools/languages/programming/perl-5.10.0/lib/site_perl/5.10.0";

use SectLabel::PreProcess;

# USER customizable section
$0 =~ /([^\/]+)$/; my $progname = $1;
my $outputVersion = "1.0";
# END user customizable section

sub License 
{
	print STDERR "# Copyright 2009 \251 by Luong Minh Thang\n";
}

# HELP sub-procedure
sub Help 
{
	print STDERR "Process Omnipage XML output (concatenated results fromm all pages of a PDF file), and extract text lines together with other XML infos\n";
	print STDERR "usage: $progname -h\t[invokes help]\n";
	print STDERR "       $progname -in xmlFile -out outFile [-xmlFeature -decode -markup -para] [-tag tagFile -allowEmptyLine -log]\n";
	print STDERR "Options:\n";
	print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
	print STDERR "\t-xmlFeature: append XML feature together with text extracted\n";
	print STDERR "\t-decode: decode HTML entities and then output, to avoid double entity encoding later\n";
	print STDERR "\t-para: marking in the output each paragraph with # Para lineId numLines\n";
	print STDERR "\t-markup: marking in the output detailed word-level info ### Page w h\\n## Para l t r b\\n# Line l t r b\\nword l t r b\n";
	print STDERR "\t-tag tagFile: count XML tags/values for statistics purpose\n";
}

my $QUIET 			= 0;
my $HELP 			= 0;
my $outFile 		= undef;
my $inFile 			= undef;

my $isXmlFeature	= 0;
my $isDecode 		= 0;

my $isMarkup 		= 0;
my $isParaDelimiter = 0;

my $tagFile 		= "";
my $isAllowEmpty 	= 0;
my $isDebug 		= 1;

$HELP = 1 unless GetOptions('in=s' 				=> \$inFile,
			 				'out=s' 			=> \$outFile,
			 				'decode' 			=> \$isDecode,
			 				'xmlFeature' 		=> \$isXmlFeature,

			 				'tag=s' 			=> \$tagFile,
			 				'allowEmptyLine'	=> \$isAllowEmpty,
			 				'markup' 			=> \$isMarkup,

			 				'para' 				=> \$isParaDelimiter,
			 				'log' 				=> \$isDebug,
			 				'h' 				=> \$HELP,
			 				'q' 				=> \$QUIET);

if ($HELP || !defined $inFile || !defined $outFile) 
{
	Help();
	exit(0);
}

if (!$QUIET) 
{
	License();
}

# Untaint
$inFile		 = untaintPath($inFile);
$outFile 	 = untaintPath($outFile);
$tagFile 	 = untaintPath($tagFile);
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
# End untaint

# Mark page, para, line, word
my %gPageHash	= ();

# Mark paragraph
my @gPara		= ();

# XML features
# locFeature
my @gPosHash	= (); 
my $gMinPos 	= 1000000; 
my $gMaxPos 	= 0;

# alignFeature
my @gAlign 		= (); 

# boldFeature
my @gBold 		= ();

# italicFeature
my @gItalic 	= (); 

# fontSizeFeature
my %gFontSizeHash	= (); 
my @gFontSize 		= ();

# fontFaceFeature
my %gFontFaceHash	= (); 
my @gFontFace 		= ();

# picFeature
my @gPic			= (); 

# tableFeature
my @gTable			= ();

# bulletFeature
my @gBullet 		= (); 

# spaceFeature
#my %gSpaceHash		= (); 
#my @gSpace			= ();
# End XML features

my %tags = ();

if ($isDebug)
{
	print STDERR "\n# Processing file $inFile & output to $outFile\n";
}

my $markupOutput	= "";
my $allText 		= processFile($inFile, $outFile, \%tags);

# Find header part
my @lines	 = split(/\n/, $allText);
my $numLines = scalar(@lines);
my ($headerLength, $bodyLength, $bodyStartId) =	SectLabel::PreProcess::FindHeaderText(\@lines, 0, $numLines);

# Output
if ($isMarkup)
{
	open(OF, ">:utf8", "$outFile") || die"#Can't open file \"$outFile\"\n";
	print OF "$markupOutput";
	close OF;
} 
else 
{
	output(\@lines, $outFile);
}

if ($tagFile ne "")
{
	printTagInfo(\%tags, $tagFile);
}

sub processFile 
{
	my ($inFile, $tags) = @_;
	
	if (!(-e $inFile)) { die "# $progname crash\t\tFile \"$inFile\" doesn't exist"; }
	open (IF, "<:utf8", $inFile) || die "# $progname crash\t\tCan't open \"$inFile\"";
	
	my $isPic	= 0;
	my $isPara	= 0;
	my $isTable = 0;
	my $isSpace = 0;

	my $text	= undef; 
	my $allText	= undef;

	my $lineId = 0;

	# Each line contains a header
	while (<IF>) 
	{
		if (/^\#/) { next; } # skip comments

		chomp;		
		s/\cM$//; # remove ^M character at the end of the file if any

		my $line = $_;
		if($tagFile ne "")
		{
			processTagInfo($line, $tags);
		}

		# if ($line =~ /<\?xml version.+>/) { } ### Xml ###
		# if ($line =~ /^<\/column>$/) { }		### Column ###
		if ($isMarkup && $line =~ /<theoreticalPage (.*)\/>/ && $isMarkup)
		{
			$markupOutput .= "### Page $1\n";
		}

		### pic ###
		if ($line =~ /^<dd (.*)>$/)
		{
			$isPic = 1;
			if($isMarkup)
			{
				$markupOutput .= "### Dd $1\n";
			}
		}
		elsif ($line =~ /^<\/dd>$/)
		{
			$isPic = 0;
		}

		### Table ###
		if ($line =~ /^<table .*>$/)
		{
			$text .= $line."\n"; # we need the header
			$isTable = 1;
		}
		elsif ($line =~ /^<\/table>$/)
		{
			my $tableText = processTable($text, $isPic);
			$allText .= $tableText;

			my @tmpLines = split(/\n/, $tableText);
			$lineId += scalar(@tmpLines);
			
			$isTable = 0;
			$text = "";
		}
		elsif($isTable)
		{
			$text .= $line."\n";
			next;
		}
		### Paragraph ###
		# Note: table processing should have higher priority than paragraph, i.e. the priority does matter
		elsif ($line =~ /^<para (.*)>$/)
		{
			$text .= $line."\n"; # we need the header
			$isPara = 1;

			if($isMarkup)
			{
				$markupOutput .= "## Para $1\n";
			}
		}
		elsif ($line =~ /^<\/para>$/)
		{
			my ($paraText, $l, $t, $r, $b);
			($paraText, $l, $t, $r, $b, $isSpace) = processPara($text, 0, $isPic);
			$allText .= $paraText;

			my @tmpLines = split(/\n/, $paraText);
			$lineId += scalar(@tmpLines);
			$isPara = 0;
			$text = "";
		}
		elsif($isPara)
		{
			$text .= $line."\n";
			next;
		}
	}  
	
	close IF;
	return $allText;
}

sub output 
{
	my ($lines, $outFile) = @_;

	open(OF, ">:utf8", "$outFile") || die"#Can't open file \"$outFile\"\n";

	####### Final output ############
	# xml feature label
	my %gFontSizeLabels = (); 
	# my %gSpaceLabels = (); # yes, no

	if($isXmlFeature)
	{
		getFontSizeLabels(\%gFontSizeHash, \%gFontSizeLabels);
		# getSpaceLabels(\%gSpaceHash, \%gSpaceLabels);
	}

	my $id = -1;
	my $output = "";
	my $paraLineId = -1;
	my $paraLineCount = 0;
	foreach my $line (@{$lines}) 
	{
		$id++;

		$line =~ s/\cM$//; # remove ^M character at the end of each line if any

		# empty lines
		if ($line =~ /^\s*$/)
		{ 
			if (!$isAllowEmpty)
			{
				next; 
			} 
			else 
			{
				if ($isDebug)
				{
	 				print STDERR "#! Line $id empty!\n";
				}
			}
		} 

		if ($gPara[$id] eq "yes")		
		{
			# mark para
			if ($output ne "")
			{       
				if ($isParaDelimiter)
				{
	 				print OF "# Para $paraLineId $paraLineCount\n$output";
	 				$paraLineCount = 0;
				} 
				else 
				{
	 				if($isDecode)
					{
		 				$output = decode_entities($output);
	 				}
	 				print OF $output;
				}

				$output = "";
			}
			$paraLineId = $id;
		}
		
		$output .= $line;
		$paraLineCount++;

		## Output XML features
		if ($isXmlFeature)
		{
			# loc feature
			my $locFeature;

			if($gPosHash[$id] != -1)
			{
				$locFeature = "xmlLoc_".int(($gPosHash[$id] - $gMinPos) * 8.0 / ($gMaxPos - $gMinPos + 1));
			}
			
			# align feature
			my $alignFeature = "xmlAlign_".$gAlign[$id];

			# fontSize feature
			my $fontSizeFeature;
			if($gFontSize[$id] == -1)
			{
				$fontSizeFeature = "xmlFontSize_none";
			} 
			else 
			{
				$fontSizeFeature = "xmlFontSize_".$gFontSizeLabels{$gFontSize[$id]};
			}

			my $boldFeature = "xmlBold_".$gBold[$id]; # bold feature
			my $italicFeature = "xmlItalic_".$gItalic[$id]; # italic feature
			my $picFeature = "xmlPic_".$gPic[$id]; # pic feature
			my $tableFeature = "xmlTable_".$gTable[$id]; # table feature
			my $bulletFeature = "xmlBullet_".$gBullet[$id]; # bullet feature

			# space feature
			#my $spaceFeature;
			#if($gSpace[$id] eq "none")
			#{
			#	$spaceFeature = "xmlSpace_none";
			#} 
			#else 
			#{
			#	$spaceFeature = "xmlSpace_".$gSpaceLabels{$gSpace[$id]};
			#}

			# differential features
			my ($alignDiff, $fontSizeDiff, $fontFaceDiff, $fontSFDiff, $fontSFBIDiff, $fontSFBIADiff, $paraDiff) = getDifferentialFeatures($id);

			$output .= " |XML| $locFeature $boldFeature $italicFeature $fontSizeFeature $picFeature $tableFeature $bulletFeature $fontSFBIADiff $paraDiff\n"; 
			# $alignFeature $alignDiff $fontSizeDiff $fontFaceDiff $fontSFDiff $fontSFBIDiff 
		} 
		else 
		{
			$output .= "\n";
		}
	}

	# mark para
	if ($output ne "")
	{
		if ($isParaDelimiter)
		{
			print OF "# Para $paraLineId $paraLineCount\n$output";
			$paraLineCount = 0;
		} 
		else 
		{
			if ($isDecode)
			{
				$output = decode_entities($output);
			}

			print OF $output;
		}
		$output = ""
	}
	close OF;
}

sub getDifferentialFeatures 
{
	my ($id) = @_;

	# alignChange feature
	my $alignDiff = "bi_xmlA_";
	if ($id == 0)
	{
		$alignDiff .= $gAlign[$id];
	} 
	elsif ($gAlign[$id] eq $gAlign[$id-1])
	{
		$alignDiff .= "continue";
	} 
	else 
	{
		$alignDiff .= $gAlign[$id];
	}
	
	# fontFaceChange feature
	my $fontFaceDiff = "bi_xmlF_";
	if ($id == 0)
	{
		$fontFaceDiff .= "new";
	} 
	elsif ($gFontFace[$id] eq $gFontFace[$id-1])
	{
		$fontFaceDiff .= "continue";
	} 
	else 
	{
		$fontFaceDiff .= "new";
	}

	# fontSizeChange feature
	my $fontSizeDiff = "bi_xmlS_";
	if ($id == 0)
	{
		$fontSizeDiff .= "new";
	} 
	elsif ($gFontSize[$id] == $gFontSize[$id-1])
	{
		$fontSizeDiff .= "continue";
	} 
	else 
	{
		$fontSizeDiff .= "new";
	}  
	
	# fontSFChange feature
	my $fontSFDiff = "bi_xmlSF_";
	if($id == 0){
		$fontSFDiff .= "new";
	} elsif($gFontSize[$id] == $gFontSize[$id-1] && $gFontFace[$id] eq $gFontFace[$id-1]){
		$fontSFDiff .= "continue";
	} else {
		$fontSFDiff .= "new";
	}
	
	# fontSFBIChange feature
	my $fontSFBIDiff = "bi_xmlSFBI_";
	if($id == 0){
		$fontSFBIDiff .= "new";
	} elsif($gFontSize[$id] == $gFontSize[$id-1] && $gFontFace[$id] eq $gFontFace[$id-1] && $gBold[$id] eq $gBold[$id-1] && $gItalic[$id] eq $gItalic[$id-1]){
		$fontSFBIDiff .= "continue";
	} else {
		$fontSFBIDiff .= "new";
	}
	
	# fontSFBIAChange feature
	my $fontSFBIADiff = "bi_xmlSFBIA_";
	if($id == 0){
		$fontSFBIADiff .= "new";
	} elsif($gFontSize[$id] == $gFontSize[$id-1] && $gFontFace[$id] eq $gFontFace[$id-1] && $gBold[$id] eq $gBold[$id-1] && $gItalic[$id] eq $gItalic[$id-1] && $gAlign[$id] eq $gAlign[$id-1]){
		$fontSFBIADiff .= "continue";
	} else {
		$fontSFBIADiff .= "new";
	}

	# para change feature
	my $paraDiff = "bi_xmlPara_";
	if($id < $bodyStartId){ # header part, consider each line as a separate paragraph
		$paraDiff .= "header";
	} else {
		if($gPara[$id] eq "yes"){
			$paraDiff .= "new";
		} else {
			$paraDiff .= "continue";
		}
	}

	return ($alignDiff, $fontSizeDiff, $fontFaceDiff, $fontSFDiff, $fontSFBIDiff, $fontSFBIADiff, $paraDiff);
}

sub getFontSizeLabels {
	my ($gFontSizeHash, $gFontSizeLabels) = @_;

	if($isDebug){ print STDERR "# Map fonts\n"; }
	my @sortedFonts = sort { $gFontSizeHash->{$b} <=> $gFontSizeHash->{$a} } keys %{$gFontSizeHash}; # sort by values, obtain keys
	
	my $commonSize = $sortedFonts[0];
	@sortedFonts = sort { $a <=> $b } keys %{$gFontSizeHash}; # sort by keys, obtain keys
	my $commonIndex = 0; # index of common font size
	foreach(@sortedFonts){
		if($commonSize == $_) { # found
			last;
		}
		$commonIndex++;
	}
	
	# small fonts
	for(my $i = 0; $i<$commonIndex; $i++){ # smallIndex $largeIndex 
		$gFontSizeLabels->{$sortedFonts[$i]} = "smaller";

		if($isDebug){
			print STDERR "$sortedFonts[$i] --> $gFontSizeLabels->{$sortedFonts[$i]}, freq = $gFontSizeHash->{$sortedFonts[$i]}\n";
		}
	}

	# common fonts
	$gFontSizeLabels->{$commonSize} = "common";
	if($isDebug){
		print STDERR "$sortedFonts[$commonIndex] --> $gFontSizeLabels->{$sortedFonts[$commonIndex]}, freq = $gFontSizeHash->{$sortedFonts[$commonIndex]}\n";
	}

	# large fonts
	for(my $i = ($commonIndex+1); $i<scalar(@sortedFonts); $i++){ # ($largeIndex+1) (scalar(@sortedFonts)-1)
		if((scalar(@sortedFonts)-$i) <= 3){
			$gFontSizeLabels->{$sortedFonts[$i]} = "largest".($i+1-scalar(@sortedFonts));
		} else {
			$gFontSizeLabels->{$sortedFonts[$i]} = "larger";
		}

		if($isDebug){	  
			print STDERR "$sortedFonts[$i] --> $gFontSizeLabels->{$sortedFonts[$i]}, freq = $gFontSizeHash->{$sortedFonts[$i]}\n";
		}
	}
}

sub getSpaceLabels {
	my ($gSpaceHash, $gSpaceLabels) = @_;

	if($isDebug){
		print STDERR "\n# Map space\n";
	}
	my @sortedSpaces = sort { $gSpaceHash->{$b} <=> $gSpaceHash->{$a} } keys %{$gSpaceHash}; # sort by freqs, obtain space faces
	
	my $commonSpace = $sortedSpaces[0];
	my $commonFreq = $gSpaceHash->{$commonSpace};
	# find similar common freq with larger spaces
	for(my $i = 0; $i<scalar(@sortedSpaces); $i++){ # 0 ($smallIndex-1)
		my $freq = $gSpaceHash->{$sortedSpaces[$i]};
		if($freq/$commonFreq > 0.8){
			if($sortedSpaces[$i] > $commonSpace){
	$commonSpace = $sortedSpaces[$i];
			}
		} else {
			last;
		}
	}

	for(my $i = 0; $i<scalar(@sortedSpaces); $i++){ # 0 ($smallIndex-1)
		if($sortedSpaces[$i] > $commonSpace){
			$gSpaceLabels->{$sortedSpaces[$i]} = "yes";
		} else {
			$gSpaceLabels->{$sortedSpaces[$i]} = "no";
		}

		if($isDebug){
			print STDERR "$sortedSpaces[$i] --> $gSpaceLabels->{$sortedSpaces[$i]}, freq = $gSpaceHash->{$sortedSpaces[$i]}\n";
		}
	}
}

sub processTable 
{
	my ($inputText, $isPic) = @_;

	my $isCell = 0; # for table cell object

	my $allText = "";
	my $text = ""; 

	my @lines = split(/\n/, $inputText);
	my %tablePos = (); # $tablePos{$cellText} = "$l-$t-$r-$bottom"
	my %table = (); # $table{$row}->{$col} = \@paraTexts
	my $rowFrom;   
	my $colFrom;
	my $rowTill;   
	my $colTill;

	# xml feature
	my $align = "none"; 
	my $pos = -1;
	foreach my $line (@lines) 
	{
		if ($line =~ /^<table (.+?)>$/)
		{
			my $attr = $1;
			
			if($isMarkup) {	$markupOutput .= "### Table $attr\n"; }

			# Fix: wrong regex sequence, huydhn
			#if ($attr =~ /^.*l=\"(\d+)\" t=\"(\d+)\" r=\"(\d+)\" b=\"(\d+)\".*alignment=\"(.+?)\".*$/)
			#{
			#	my ($l, $t, $r, $bottom) = ($1, $2, $3, $4);
			#	$align = $5;

			#	# pos feature
			#	$pos = ($t+$bottom)/2.0;
				
			#	if($pos < $gMinPos) { $gMinPos = $pos; }
			#	if($pos > $gMaxPos) { $gMaxPos = $pos; }
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
				
				if($pos < $gMinPos) { $gMinPos = $pos; }
				if($pos > $gMaxPos) { $gMaxPos = $pos; }
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
			$colFrom = $1;
			$colTill = $2;
			$rowFrom = $3;
			$rowTill = $4;
			#print STDERR "$rowFrom $rowTill $colFrom $colTill\n";
			$isCell = 1;
		}
		elsif ($line =~ /^<\/cell>$/) # end cell
		{ 
			my @paraTexts = ();
			processCell($text, \@paraTexts, \%tablePos, $isPic);
			
			for(my $i = $rowFrom; $i<=$rowTill; $i++)
			{
				for(my $j = $colFrom; $j<=$colTill; $j++)
				{
					if(!$table{$i}) { $table{$i} = (); }
					if(!$table{$i}->{$j}) {	$table{$i}->{$j} = (); }

	 				if($i == $rowFrom && $j == $colFrom)
					{
		 				push(@{$table{$i}->{$j}}, @paraTexts);
						if(scalar(@paraTexts) > 1) { last; }
	 				} 
					else 
					{
		 				push(@{$table{$i}->{$j}}, ""); #add stub "" for spanning rows or cols
	 				}
				}
			}
				
			$isCell = 0;
			$text = "";
		}    
		elsif($isCell)
		{
			$text .= $line."\n";
			next;
		}
	}

	# note: such a complicated code is because in the normal node, Omnipage doesn't seem to strictly print column by column given a row is fixed.
	# E.g if col1: paraText1, col2: paraText21\n$paraText22, and col3: paraText31\n$paraText32
	# It will print  paraText1\tparaText21\tparaText31\n\t$paraText22\t$paraText32
	my @sortedRows = sort {$a <=> $b} keys %table;
	my $isFirstLinePara = 1;
	foreach my $row (@sortedRows)
	{
		my %tableR = %{$table{$row}};
		my @sortedCols = sort {$a <=> $b} keys %tableR;
		while(1)
		{
			my $isStop = 1;
			my $rowText = "";

			foreach my $col (@sortedCols)
			{
				# there's still some thing to process
				if(scalar(@{$tableR{$col}}) > 0)
				{ 
	 				$isStop = 0;
	 				$rowText .= shift(@{$tableR{$col}});
				}
				$rowText .= "\t";
			}

			if ((!$isAllowEmpty && $rowText =~ /^\s*$/) || ($isAllowEmpty && $rowText eq ""))
			{
				$isStop = 1;
			}

			if($isStop) 
			{
				last;
			} 
			else 
			{
				$rowText =~ s/\t$/\n/;
				$allText .= $rowText;
				# print STDERR "$rowText";
				
				# para
				if($isFirstLinePara)
				{
	 				push(@gPara, "yes");
	 				$isFirstLinePara = 0;
				} 
				else 
				{
	 				push(@gPara, "no");
				}

				if($isXmlFeature)
				{
	 				# table feature
	 				push(@gTable, "yes");

	 				# pic feature
	 				if($isPic)
					{
		 				push(@gPic, "yes");
	 				} 
					else 
					{
		 				push(@gPic, "no");
	 				}

	 				push(@gPosHash, $pos); # update xml pos value
	 				push(@gAlign, $align); # update xml alignment value

	 				### Not assign value ###
					push(@gFontSize, -1); # fontSize feature	  
					push(@gFontFace, "none"); # fontFace feature	  
	 				push(@gBold, "no"); # bold feature	  
	 				push(@gItalic, "no"); # italic feature
	 				push(@gBullet, "no"); # bullet feature
					# push(@gSpace, "none"); # space feature
				} # end if xml feature
			}
		}
	}

	return $allText;
}

sub processCell 
{
	my ($inputText, $paraTexts, $tablePos, $isPic) = @_;

	my $text = ""; 
	my @lines = split(/\n/, $inputText);
	my $isPara = 0;
	my $flag = 0;
	foreach my $line (@lines) 
	{    
		if ($line =~ /^<para (.*)>$/)
		{
			$text .= $line."\n"; # we need the header
			$isPara = 1;

			if($isMarkup)
			{
				$markupOutput .= "## ParaTable $1\n";
			}
		}
		elsif ($line =~ /^<\/para>$/)
		{
			my ($paraText, $l, $t, $r, $b) = processPara($text, 1, $isPic);
			my @tokens = split(/\n/, $paraText);

			foreach my $token (@tokens)
			{
				if($token ne "")
				{
	 				push(@{$paraTexts}, $token);
	 				$flag = 1;	
				}
			}

			if(!$tablePos->{$paraText})
			{
				$tablePos->{$paraText} = "$l-$t-$r-$b";
			} 
			else 
			{
				#print STDERR "#! Warning: in method processCell, encounter the same paraText $paraText\n";
			}

			$isPara = 0;
			$text = "";
		}
		elsif ($isPara)
		{
			$text .= $line."\n";
			next;
		}
	}
	
	# at least one value should be added for cell which is ""
	if($flag == 0) 
	{
		push(@{$paraTexts}, "");
	}
}

sub getAttrValue {
	my ($attrText, $attr) = @_;

	my $value = "none";
	if($attrText =~ /^.*$attr=\"(.+?)\".*$/){
		$value = $1;
	}
	
	return $value;
}

sub checkFontAttr {
	my ($attrText, $attr, $attrHash, $count) = @_;

	if($attrText =~ /^.*$attr=\"(.+?)\".*$/){
		my $attrValue = $1;
		
		$attrHash->{$attrValue} = $attrHash->{$attrValue} ? ($attrHash->{$attrValue}+$count) : $count;
	}
}

sub processPara 
{
	my ($inputText, $isCell, $isPic) = @_;
	
	my $isSpace = 0;
	my $isSpecialSpace = 0;
	my $isTab = 0;
	my $isBullet = 0;

	my $isForcedEOF = "none";  # 3 signals for end of L: forcedEOF=\"true\" in attribute of <ln> or || <nl orig=\"true\"\/> || end of </para> without encountering any of the above signal in the para plus $isSpace = 0
	# xml feature
	my $align = "none"; 
	my ($l, $t, $r, $bottom);
	my %fontSizeHash = ();
	my %fontFaceHash = ();
	my @boldArray = ();
	my @italicArray = ();
	my $space = "none";

	my $lnAttr; my $isLn = 0; my $lnBold = "none"; my $lnItalic = "none";
	my $runAttr;  my $runText = ""; my $isRun = 0; my $runBold = "none"; my $runItalic = "none";
	my $wdAttr; my $wdText = ""; my $isWd = 0;

	my $wdIndex = 0; # word index in a line. When encountering </ln>, this parameter indicates the number of words in a line
	my $lnBoldCount = 0;
	my $lnItalicCount = 0;

	my $allText = "";
	my $text = ""; #invariant: when never enter a new line, $text will be copied into $allText, and $text is cleared

	binmode(STDERR, ":utf8");

	my $isFirstLinePara = 1;
	my @lines = split(/\n/, $inputText);
	for (my $i=0; $i<scalar(@lines); $i++)
	{
		my $line = $lines[$i];

		## new para
		if ($line =~ /^<para (.+?)>$/)
		{
			my $attr = $1;
			$align = getAttrValue($attr, "alignment");
			# $indent = getAttrValue($attr, "li");
			$space = getAttrValue($attr, "spaceBefore");
		}
		## new ln
		elsif ($line =~ /^<ln (.+)>$/)
		{ 
			$lnAttr = $1;
			$isLn = 1;

			if ($isMarkup)
			{
				$markupOutput .= "# Line $lnAttr\n";
			}

			# Fix: wrong regex sequence, huydhn
			#if ($lnAttr =~ /^.*l=\"(\d+)\" t=\"(\d+)\" r=\"(\d+)\" b=\"(\d+)\".*$/)
			#{
			#	($l, $t, $r, $bottom) = ($1, $2, $3, $4);
			#}

			if ($lnAttr =~ /^.*l=\"(\d+)\".*$/)	{ $l = $1; } else {	$l = undef; }
			if ($lnAttr =~ /^.*t=\"(\d+)\".*$/)	{ $t = $1; } else {	$t = undef; }
			if ($lnAttr =~ /^.*r=\"(\d+)\".*$/)	{ $r = $1; } else {	$r = undef; }
			if ($lnAttr =~ /^.*b=\"(\d+)\".*$/)	{ $bottom = $1; } else { $bottom = undef; }
			# End.

			$isForcedEOF = getAttrValue($lnAttr, "forcedEOF");
			
			# Bold & Italic
			if($isXmlFeature)
			{ 
				$lnBold = getAttrValue($lnAttr, "bold");
				$lnItalic = getAttrValue($lnAttr, "italic");
			}
		}
		## new run
		elsif ($line =~ /<run (.*)>$/)
		{
			$runAttr = $1;

			$isSpace = 0;
			$isTab = 0;
			$isRun = 1;
			
			# new wd, that consists of many runs
			if($line =~ /^<wd (.*?)>/)
			{
				$isWd = 1;
				$wdAttr = $1;
			}

			# Bold & Italic
			if ($isXmlFeature)
			{ 
				$runBold = getAttrValue($runAttr, "bold");
				$runItalic = getAttrValue($runAttr, "italic");
			}
		}
		## wd
		elsif ($line =~ /^<wd (.+)?>(.+)<\/wd>$/)
		{
			$wdAttr = $1;
			my $word = $2;
			$isSpace = 0;
			$isTab = 0;

			if ($isMarkup)
			{
				$markupOutput .= "$word $wdAttr\n";
			}

			# FontSize & FontFace
			if($isXmlFeature)
			{ 
				checkFontAttr($wdAttr, "fontSize", \%fontSizeHash, 1);
				checkFontAttr($wdAttr, "fontFace", \%fontFaceHash, 1);
			}
			
			# Bold & Italic
			if($isXmlFeature)
			{
				my $wdBold = getAttrValue($wdAttr, "bold");
				my $wdItalic = getAttrValue($wdAttr, "italic");

				if($wdBold eq "true" || $runBold eq "true" || $lnBold eq "true")
				{
	 				$boldArray[$wdIndex] = 1;
	 				$lnBoldCount++;
				}
		
				if($wdItalic eq "true" || $runItalic eq "true" || $lnItalic eq "true")
				{
	 				$italicArray[$wdIndex] = 1;
	 				$lnItalicCount++;
				}
			} # if($isXmlFeature)

			## add text
			$text .= "$word";

			if($isRun) { $runText .= "$word "; }
			$wdIndex++;
		}
		## end wd
		elsif ($line =~ /^<\/wd>$/)
		{
			$isWd = 0;
			
			if($isMarkup)
			{
				$markupOutput .= "$wdText $wdAttr\n";
				$wdAttr = "";
			}
		}
		## end run
		elsif ($line =~ /^(.*)<\/run>$/)
		{ 
			my $word = $1;

			## add text
			if($word ne "")			
			{
				# Bold & Italic
				if($isXmlFeature)
				{ 
	 				if($runBold eq "true" || $lnBold eq "true")
					{
		 				$boldArray[$wdIndex] = 1;
		 				$lnBoldCount++;
	 				}

			 		if($runItalic eq "true" || $lnItalic eq "true")
					{
		 				$italicArray[$wdIndex] = 1;
		 				$lnItalicCount++;
	 				}
				}

				# appear in the final result
				if($isLn) { $text .= "$word"; }

				# for internal record
				if($isRun) { $runText .= "$word "; }	
				if($isWd) { $wdText .= "$word"; }	

				$wdIndex++;
			}

			# xml feature
			# not a space, tab or new-line run
			if($isXmlFeature && $runText ne "") 
			{ 
				my @words = split(/\s+/, $runText);
				my $numWords = scalar(@words);
				checkFontAttr($runAttr, "fontSize", \%fontSizeHash, $numWords);
				checkFontAttr($runAttr, "fontFace", \%fontFaceHash, $numWords);
			}
			
			# reset run
			# <run> not enclosed within <ln>
			if (!$isLn) { $wdIndex = 0;	}
			$runText = "";
			$isRun = 0;      
			$isSpecialSpace = 0;

			# Bold & Italic
			if($isXmlFeature)
			{
				$runBold = "none";
				$runItalic = "none";

				# <run> not enclosed within <ln>
				if (!$isLn)
				{ 
	 				$lnBoldCount = 0;
	 				$lnItalicCount = 0;
				}
			}
		}
		## end ln
		elsif ($line =~ /^<\/ln>$/)
		{
			if((!$isAllowEmpty && $text !~ /^\s*$/) || ($isAllowEmpty && $text ne ""))
			{
				# there's a forced EOL?
				# not an emply line with space character
				if($isForcedEOF eq "true" || (!$isCell && !$isSpecialSpace) )
				{ 
	 				$text .= "\n";
					
					# update allText
	 				$allText .= $text;
	 				$text = "";
				}

				my $numWords = $wdIndex;

				if (!$isCell)
				{
	 				if ($isFirstLinePara)
					{
		 				push(@gPara, "yes");
		 				$isFirstLinePara = 0;
	 				} 
					else 
					{
		 				push(@gPara, "no");
	 				}
				}

				if ($isXmlFeature && $numWords >= 1)
				{
	 				# xml feature
					# assumtion that: fontSize is either occur in <ln>, or within multiple <run> under <ln>, but not both
					checkFontAttr($lnAttr, "fontSize", \%fontSizeHash, $numWords);
					checkFontAttr($lnAttr, "fontFace", \%fontFaceHash, $numWords);
				}
		
				if ($isXmlFeature && !$isCell && !$isSpecialSpace)
				{
	 				my $pos = ($t+$bottom)/2.0;
					if ($pos < $gMinPos) { $gMinPos = $pos;	}
					if ($pos > $gMaxPos) { $gMaxPos = $pos; }

					push(@gPosHash, $pos); # pos feature
	 				push(@gAlign, $align); # alignment feature
	 				push(@gTable, "no"); # table feature

	 				# pic feature
	 				if($isPic)
					{
		 				push(@gPic, "yes");

		 				### Not assign value ###
		 				push(@gFontSize, -1); # bold feature	  
		 				push(@gFontFace, "none"); # bold feature	  
		 				push(@gBold, "no"); # bold feature	  
		 				push(@gItalic, "no"); # italic feature
		 				push(@gBullet, "no"); # bullet feature
	 				} 
					else 
					{
		 				push(@gPic, "no");

		 				updateXMLFontFeature(\%fontSizeHash, \%fontFaceHash);
		 				%fontSizeHash = (); %fontFaceHash = ();

		 				updateXMLFeatures($lnBoldCount, $lnItalicCount, $numWords, $isBullet, $space);
	 				} # end if pic
				} # end if($isXmlFeature && !$isCell && !$isSpecialSpace)
			}

			## reset ln
			$isLn = 0;      
			$isForcedEOF = "none";
			$isSpecialSpace = 0;
			$wdIndex = 0;

			# Bold & Italic
			if ($isXmlFeature)
			{ 
				$lnBold = "none";
				$lnItalic = "none";

				$lnBoldCount = 0;
				$lnItalicCount = 0;
			}
		} # end else </ln>
		## nl newline signal
		elsif ($line =~ /^<nl orig=\"true\"\/>$/)
		{
			if($isLn)
			{
				$isSpace = 0;
			} 
			else 
			{
				if($isDebug)
				{
	 				print STDERR "#!!! Warning: found <nl orig=\"true\"\/> while not in tag <ln>: $line\n";
				}
			}
		}
		## space
		elsif ($line =~ /^<space\/>$/)
		{
			my $startTag = "";
			my $endTag = "";
			if($i>0 && $lines[$i-1] =~ /^<(.+?)\b.*/)
			{
				$startTag = $1;
			}
				
			if($i < (scalar(@lines) -1) && $lines[$i+1] =~ /^<\/(.+)>/)
			{
				$endTag = $1;
			}
			
			if($startTag eq $endTag && $startTag ne "")
			{
				# print STDERR "# Special space after \"$text\"\n";
				$isSpecialSpace = 1;
			}

			## addText
			$text .= " ";
			$isSpace = 1;
		}
		## tab
		elsif ($line =~ /^<tab .*\/>$/)
		{
			## add Text
			$text .= "\t";
			$isTab = 1;
		}
		## bullet
		elsif ($line =~ /^<bullet .*>$/)
		{
			$isBullet = 1;
		}
	}

	$allText .= $text;
	return ($allText, $l, $t, $r, $bottom, $isSpace);
}

sub updateXMLFontFeature {
	my ($fontSizeHash, $fontFaceHash) = @_;

	# font size feature
	if(scalar(keys %{$fontSizeHash}) == 0){
		push(@gFontSize, -1);
	} else {
		my @sortedFonts = sort { $fontSizeHash->{$b} <=> $fontSizeHash->{$a} } keys %{$fontSizeHash};
		
		my $fontSize = $sortedFonts[0];
		push(@gFontSize, $fontSize);
		
		$gFontSizeHash{$fontSize} = $gFontSizeHash{$fontSize} ? ($gFontSizeHash{$fontSize}+1) : 1;
	}
	
	# font face feature
	if(scalar(keys %{$fontFaceHash}) == 0){
		push(@gFontFace, "none");
	} else {
		my @sortedFonts = sort { $fontFaceHash->{$b} <=> $fontFaceHash->{$a} } keys %{$fontFaceHash};
		my $fontFace = $sortedFonts[0];
		push(@gFontFace, $fontFace);
		
		$gFontFaceHash{$fontFace} = $gFontFaceHash{$fontFace} ? ($gFontFaceHash{$fontFace}+1) : 1;
	}
}

sub updateXMLFeatures {
	my ($lnBoldCount, $lnItalicCount, $numWords, $isBullet, $space) = @_;
	# bold feature
	my $boldFeature;
	if ($lnBoldCount/$numWords >= 0.667){
		$boldFeature = "yes";
	} else {
		$boldFeature = "no";
	}
	push(@gBold, $boldFeature);
	
	# italic feature
	my $italicFeature;
	if ($lnItalicCount/$numWords >= 0.667){
		$italicFeature = "yes";
	} else {
		$italicFeature = "no";
	}
	push(@gItalic, $italicFeature);  
	
	# bullet feature
	if($isBullet){
		push(@gBullet, "yes");
	} else {
		push(@gBullet, "no");
	}
	
	# space feature
#  push(@gSpace, $space);
}

## Find the positions of header, body, and citation
sub getStructureInfo {
	my ($lines, $numLines) = @_;

	my ($bodyLength, $citationLength, $bodyEndId) =
		SectLabel::PreProcess::findCitationText($lines, 0, $numLines);
	
	my ($headerLength, $bodyStartId);
	($headerLength, $bodyLength, $bodyStartId) =
		SectLabel::PreProcess::findHeaderText($lines, 0, $bodyLength);
	
	# sanity check
	my $totalLength = $headerLength + $bodyLength + $citationLength;
	if($numLines != $totalLength){
		print STDOUT "Die in getStructureInfo(): different num lines $numLines != $totalLength\n"; # to display in Web
		die "Die in getStructureInfo(): different num lines $numLines != $totalLength\n";
	}
	return ($headerLength, $bodyLength, $citationLength, $bodyStartId, $bodyEndId);
}

## Count XML tags/values for statistics purpose
sub processTagInfo {
	my ($line, $tags) = @_;

	my $tag;
	my $attr;
	if($line =~ /^<(.+?)\b(.*)/){
		$tag = $1;
		$attr = $2;
		if(!$tags->{$tag}){
			$tags->{$tag} = ();
		}
		if($attr =~ /^\s*(.+?)\s*\/?>/){
			$attr = $1;
		}
		
		my @tokens = split(/\s+/, $attr);
		foreach my $token (@tokens){
			if($token =~ /^(.+)=(.+)$/){
	my $attrName = $1;
	my $value = $2;
	if(!$tags->{$tag}->{$attrName}){
	 $tags->{$tag}->{$attrName} = ();
	}
	if(!$tags->{$tag}->{$attrName}->{$value}){
	 $tags->{$tag}->{$attrName}->{$value} = 0;
	}
	$tags->{$tag}->{$attrName}->{$value}++;
			}
		}
	}
}

## Print tag info to file
sub printTagInfo {
	my ($tags, $tagFile) = @_;

	open(TAG, ">:utf8", "$tagFile") || die"#Can't open file \"$tagFile\"\n";
	my @sortedTags = sort {$a cmp $b} keys %{$tags};
	foreach(@sortedTags){
		my @attrs = sort {$a cmp $b} keys %{$tags->{$_}};
		print TAG "# Tag = $_\n";
		foreach my $attr (@attrs) {
			print TAG "$attr:";
			my @values = sort {$a cmp $b} keys %{$tags->{$_}->{$attr}};
			foreach my $value (@values){
	print TAG " $value-$tags->{$_}->{$attr}->{$value}";
			}
			print TAG "\n";
		}
	}
	close TAG;
}

sub untaintPath {
	my ($path) = @_;

	if ( $path =~ /^([-_\/\w\.]*)$/ ) {
		$path = $1;
	} else {
		die "Bad path \"$path\"\n";
	}

	return $path;
}

sub untaint {
	my ($s) = @_;
	if ($s =~ /^([\w \-\@\(\),\.\/]+)$/) {
		$s = $1;               # $data now untainted
	} else {
		die "Bad data in $s";  # log this somewhere
	}
	return $s;
}

sub execute {
	my ($cmd) = @_;
	if($isDebug){
		print STDERR "Executing: $cmd\n";
	}
	$cmd = untaint($cmd);
	system($cmd);
}

sub newTmpFile {
	my $tmpFile = `date '+%Y%m%d-%H%M%S-$$'`;
	chomp($tmpFile);
	return $tmpFile;
}
