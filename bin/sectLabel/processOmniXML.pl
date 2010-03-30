#!/usr/bin/perl -wT
# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Tue, 02 Jun 2009 01:30:42

# Modified from template by Min-Yen Kan <kanmy@comp.nus.edu.sg>

require 5.0;
use strict;
use Getopt::Long;
use HTML::Entities;

### USER customizable section
$0 =~ /([^\/]+)$/; my $progname = $1;
my $outputVersion = "1.0";
### END user customizable section

sub License {
  print STDERR "# Copyright 2009 \251 by Luong Minh Thang\n";
}

### HELP Sub-procedure
sub Help {
  print STDERR "Process Omnipage XML output (concatenated results fromm all pages of a PDF file), and extract text lines together with other XML infos\n";
  print STDERR "usage: $progname -h\t[invokes help]\n";
  print STDERR "       $progname -in xmlFile -out outFile [-tag tagFile -xmlFeature -markup -para -noEmpty -log -paraFeature -decode]\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
  print STDERR "\t-tag: print out tags available\n";
  print STDERR "\t-markup: add factor infos (bold, italic etc) per word using the format word|||(b|nb)|||(i|ni)\n";
  print STDERR "\t-decode: decode HTML entities and then output, to avoid double entity encoding later\n";
  print STDERR "\t-empty: allow empty lines\n";
}
my $QUIET = 0;
my $HELP = 0;
my $outFile = undef;
my $inFile = undef;
my $tagFile = "";
my $isXmlFeature = 0;
my $isAllowEmpty = 0;
my $isDebug = 0;
my $isMarkup = 0;
my $isParaDelimiter = 0;
my $isParaFeature = 0;
my $isDecode = 0;
$HELP = 1 unless GetOptions('in=s' => \$inFile,
			    'out=s' => \$outFile,
			    'tag=s' => \$tagFile,
			    'xmlFeature' => \$isXmlFeature,
			    'empty' => \$isAllowEmpty,
			    'markup' => \$isMarkup,
			    'decode' => \$isDecode,
			    'para' => \$isParaDelimiter,
			    'paraFeature' => \$isParaFeature,
			    'debug' => \$isDebug,
			    'h' => \$HELP,
			    'q' => \$QUIET);

if ($HELP || !defined $inFile || !defined $outFile) {
  Help();
  exit(0);
}

if (!$QUIET) {
  License();
}

### Untaint ###
$inFile = untaintPath($inFile);
$outFile = untaintPath($outFile);
$tagFile = untaintPath($tagFile);
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
### End untaint ###

### Mark paragraph
my @gPara = ();

### XML features ###
# locFeature
my @gPosHash = ();
my $gMinPos = 1000000;
my $gMaxPos = 0;

# alignFeature
my @gAlign = ();

# font size feature
my %gFontSizeHash = ();
my @gFontSize = ();

# bold feature
my @gBold = ();

# italic feature
my @gItalic = ();

# font face feature
my %gFontFaceHash = ();
my @gFontFace = ();

# dd feature
my @gDd = ();

# cell feature
my @gCell = ();

# bullet feature
my @gBullet = ();

# indent feature
my %gIndentHash = (); #gIndentHash{$indent} = freq
my @gIndent = ();

# space feature
#my %gSpaceHash = (); #gSpaceHash->{$space} = freq
#my @gSpace = ();

my $gCurrentPage = -1;
my %tags = ();

if($isDebug){
  print STDERR "\n# Processing file $inFile & output to $outFile\n";
}
processFile($inFile, $outFile, \%tags);

if($tagFile ne ""){
  open(TAG, ">:utf8", "$tagFile") || die"#Can't open file \"$tagFile\"\n";
  my @sortedTags = sort {$a cmp $b} keys %tags;
  foreach(@sortedTags){
    my @attrs = sort {$a cmp $b} keys %{$tags{$_}};
    print TAG "# Tag = $_\n";
    foreach my $attr (@attrs) {
      print TAG "$attr:";
      my @values = sort {$a cmp $b} keys %{$tags{$_}->{$attr}};
      foreach my $value (@values){
	print TAG " $value-$tags{$_}->{$attr}->{$value}";
      }
      print TAG "\n";
    }
  }
  close TAG;
}

sub processFile {
  my ($inFile, $outFile, $tags) = @_;
  
  if (!(-e $inFile)) { die "# $progname crash\t\tFile \"$inFile\" doesn't exist"; }
  open (IF, "<:utf8", $inFile) || die "# $progname crash\t\tCan't open \"$inFile\"";
  open(OF, ">:utf8", "$outFile") || die"#Can't open file \"$outFile\"\n";
  
  my $isPara = 0;
  my $isTable = 0;
  my $isSpace = 0;
  my $isDd = 0;
  my $allText = "";
  my $text = ""; 
  my $tag;
  my $attr;
  my %pageIdMap = ();
  my $lineId = 0;
  while (<IF>) { #each line contains a header
    if (/^\#/) { next; }			# skip comments
#    if (/^\s*$/) { next; }			# skip empty lines
    chomp;
    s/\cM$//; # remove ^M character at the end of the file if any

    my $line = $_;

    if($tagFile ne ""){
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

    ### Xml ###
    if ($line =~ /<\?xml version.+>/){
      $gCurrentPage++;
      $pageIdMap{$gCurrentPage} = $lineId;
      #print STDERR "Map $lineId\tpage $gCurrentPage\n";
    }

    ### Column ###
#    if ($line =~ /^<\/column>$/){    }

    ### dd ###
    if ($line =~ /^<dd .*>$/){
      $isDd = 1;
    }
    elsif ($line =~ /^<\/dd>$/){
      $isDd = 0;
    }

    ### Table ###
    if ($line =~ /^<table .*>$/){
      $text .= $line."\n"; # we need the header
      $isTable = 1;
    }
    elsif ($line =~ /^<\/table>$/){
      my $tableText = processTable($text, $isDd);
      $allText .= $tableText;

      my @tmpLines = split(/\n/, $tableText);
      $lineId += scalar(@tmpLines);
      
      $isTable = 0;
      $text = "";
    }
    elsif($isTable){
      $text .= $line."\n";
      next;
    }

    ### Paragraph ###
    # Note: table processing should have higher priority than paragraph, i.e. the priority does matter
    elsif ($line =~ /^<para .+>$/){
      $text .= $line."\n"; # we need the header
      $isPara = 1;
    }
    elsif ($line =~ /^<\/para>$/){
      my ($paraText, $l, $t, $r, $b);
      ($paraText, $l, $t, $r, $b, $isSpace) = processPara($text, 0, $isDd);
      $allText .= $paraText;

      my @tmpLines = split(/\n/, $paraText);
      $lineId += scalar(@tmpLines);
      $isPara = 0;
      $text = "";
    }
    elsif($isPara){
      $text .= $line."\n";
      next;
    }
  }  


  ####### Final output ############
  my @lines = split(/\n/, $allText);

  if($isXmlFeature){
    if(scalar(@lines) != scalar(@gPosHash)){
      die "Die: different size lines ".scalar(@lines)." != gPosHash ".scalar(@gPosHash)."\n";
#    } else {
#      print STDERR scalar(@lines)."\n";
    }
    if(scalar(@lines) != scalar(@gAlign)){
      die "Die: different size lines ".scalar(@lines)." != gAlign ".scalar(@gAlign)."\n";
    }
  }



  # xml feature label
  my %gFontSizeLabels = (); # common font -> smallest/2, common font -> largest/2, smallest -> smallest/2, largest -> largest/2
  my %gIndentLabels = (); # yes, no
  my %gFontFaceLabels = (); # common font -> less ones
#  my %gSpaceLabels = (); # yes, no
  if($isXmlFeature){
    getFontSizeLabels(\%gFontSizeHash, \%gFontSizeLabels);
    getIndentLabels(\%gIndentHash, \%gIndentLabels);

    getFontFaceLabels(\%gFontFaceHash, \%gFontFaceLabels);
#    getSpaceLabels(\%gSpaceHash, \%gSpaceLabels);
  }

  my $id = -1;
  my $pageId = -1;
  my $output = "";
  my $paraLineId = -1;
  my $paraLineCount = 0;
  foreach my $line (@lines) {
    $id++;
    if(defined $pageIdMap{$pageId+1} && 
       ($id == $pageIdMap{$pageId+1})){
      $pageId++;
    }

    if($line =~ /^\s*$/){ # # empty lines
      if(!$isAllowEmpty){
	next; 
      } else {
	if($isDebug){
	  print STDERR "#! Line $id empty!\n";
	}
      }
    } 

    if($gPara[$id] eq "yes"){
      if($output ne ""){       ## mark para
	if($isParaDelimiter){
	  print OF "# Para $paraLineId $paraLineCount\n$output";
	  $paraLineCount = 0;
	} else {
	  if($isDecode){
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

    ## Output XML features ###
    if($isXmlFeature){
      # loc feature
      my $locFeature;
      if($gPosHash[$id] != -1){
	$locFeature = "xmlLoc_".int(($gPosHash[$id] - $gMinPos)*8.0/($gMaxPos - $gMinPos + 1));
      }
 
      # align feature
      my $alignFeature = "xmlAlign_".$gAlign[$id];

      # fontFace feature
      my $fontFaceFeature;
      if($gFontFace[$id] eq "none"){
	$fontFaceFeature = "xmlFontFace_none";
      } else {
	$fontFaceFeature = "xmlFontFace_".$gFontFaceLabels{$gFontFace[$id]};
      }

      # fontFaceChange feature
      my $fontFaceChangeFeature = "xmlFontFaceChange_";
      if($id == 0){
	$fontFaceChangeFeature .= "begin";
      } elsif($gFontFace[$id] ne $gFontFace[$id-1]){
	$fontFaceChangeFeature .= "yes";
      } else {
	$fontFaceChangeFeature .= "no";
      }

      # fontSize feature
      my $fontSizeFeature;
      if($gFontSize[$id] == -1){
	$fontSizeFeature = "xmlFontSize_none";
      } else {
	$fontSizeFeature = "xmlFontSize_".$gFontSizeLabels{$gFontSize[$id]};
      }

      # fontSizeChange feature
      my $fontSizeChangeFeature = "xmlFontSizeChange_";
      if($id == 0){
	$fontSizeChangeFeature .= "begin";
      } elsif($gFontSize[$id] > $gFontSize[$id-1]){
	$fontSizeChangeFeature .= "bigger";
      } elsif($gFontSize[$id] < $gFontSize[$id-1]){
	$fontSizeChangeFeature .= "smaller";
      } else {
	$fontSizeChangeFeature .= "no";
      }

      # bold feature
      my $boldFeature = "xmlBold_".$gBold[$id];

      # italic feature
      my $italicFeature = "xmlItalic_".$gItalic[$id];

      # dd feature
      my $ddFeature = "xmlDd_".$gDd[$id];

      # cell feature
      my $cellFeature = "xmlCell_".$gCell[$id];

      # bullet feature
      my $bulletFeature = "xmlBullet_".$gBullet[$id];

      # indent feature
      my $indentFeature;
      if($gIndent[$id] eq "none"){
	$indentFeature = "xmlIndent_no";
      } else {
	$indentFeature = "xmlIndent_".$gIndentLabels{$gIndent[$id]};
      }

      # space feature
#      my $spaceFeature;
#      if($gSpace[$id] eq "none"){
#	$spaceFeature = "xmlSpace_no";
#      } else {
#	$spaceFeature = "xmlSpace_".$gSpaceLabels{$gSpace[$id]};
#      }

      $output .= " |XML| $locFeature $alignFeature $fontFaceFeature $fontFaceChangeFeature $fontSizeFeature $fontSizeChangeFeature $boldFeature $italicFeature $ddFeature $cellFeature $bulletFeature $indentFeature"; # xmlIndentNum_$gIndent[$id] $spaceFeature xmlSpaceNum_$gSpace[$id]\n";
#      print OF "$line |XML| $locFeature $alignFeature $boldFeature $italicFeature\n";

      # para feature
      if($isParaFeature){
	my $paraFeature;
	if($gPara[$id] eq "yes"){
	  $paraFeature = "xmlPara_new";
	} else {
	  $paraFeature = "xmlPara_same";
	}
	$output .= " $paraFeature";
      }

      $output .= "\n";
      #      print OF "$line |XML| $locFeature $alignFeature\n";
    } else {
      $output .= "\n";
    }
  }

  if($output ne ""){       ## mark para
    if($isParaDelimiter){
      print OF "# Para $paraLineId $paraLineCount\n$output";
      $paraLineCount = 0;
    } else {
      if($isDecode){
	$output = decode_entities($output);
      }

      print OF $output;
    }
    $output = ""
  }

#  print OF $allText;

  close OF;
  close IF;
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
#    if(($commonIndex-$i) <= 2){

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

sub getFontFaceLabels {
  my ($gFontFaceHash, $gFontFaceLabels) = @_;

  my @sortedFonts = sort { $gFontFaceHash->{$b} <=> $gFontFaceHash->{$a} } keys %{$gFontFaceHash}; # sort by freqs, obtain font faces

  if($isDebug){
    print STDERR "\n# Map font faces\n";
  }
  for(my $i = 0; $i<scalar(@sortedFonts); $i++){ # 0 ($smallIndex-1)
    $gFontFaceLabels->{$sortedFonts[$i]} = ($i == 0) ? "common" : "different";
    
    if($isDebug){
      print STDERR "$sortedFonts[$i] --> $gFontFaceLabels->{$sortedFonts[$i]}, freq = $gFontFaceHash->{$sortedFonts[$i]}\n";
    }
  }
}

sub getIndentLabels {
  my ($gIndentHash, $gIndentLabels) = @_;

  if($isDebug){
    print STDERR "\n# Map indent\n";
  }
  my @sortedIndents = sort { $gIndentHash->{$b} <=> $gIndentHash->{$a} } keys %{$gIndentHash}; # sort by freqs, obtain indent faces
  
  my $commonIndent = $sortedIndents[0];
  for(my $i = 0; $i<scalar(@sortedIndents); $i++){ # 0 ($smallIndex-1)
    if($sortedIndents[$i] > $commonIndent){
      $gIndentLabels->{$sortedIndents[$i]} = "yes";
    } else {
      $gIndentLabels->{$sortedIndents[$i]} = "no";
    }
   
    if($isDebug){
      print STDERR "$sortedIndents[$i] --> $gIndentLabels->{$sortedIndents[$i]}, freq = $gIndentHash->{$sortedIndents[$i]}\n";
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


sub processTable {
  my ($inputText, $isDd) = @_;

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
  my %tableFontSizeHash = ();
  my %tableFontFaceHash = ();

  foreach my $line (@lines) {
    if ($line =~ /^<table (.+?)>$/){
      my $attr = $1;
      if ($attr =~ /^.*l=\"(\d+)\" t=\"(\d+)\" r=\"(\d+)\" b=\"(\d+)\".*alignment=\"(.+?)\".*$/){
	my ($l, $t, $r, $bottom) = ($1, $2, $3, $4);
	$align = $5;

	# pos feature
	$pos = ($t+$bottom)/2.0;
	if($pos < $gMinPos){
	  $gMinPos = $pos;
	}
	if($pos > $gMaxPos){
	  $gMaxPos = $pos;
	}
      } else {
	print STDERR "# no table alignment or location \"$line\"\n";
	$align = "";
      }
    }
    elsif ($line =~ /^<cell .*gridColFrom=\"(\d+)\" gridColTill=\"(\d+)\" gridRowFrom=\"(\d+)\" gridRowTill=\"(\d+)\".*>$/){ # new cell

#      if($1 != $2){
#	print STDERR "#! Different col from vs col till: $line\n";
#      }
#      if($3 != $4){
#	print STDERR "#! Different row from vs row till: $line\n";
#      }
 
      $colFrom = $1;
      $colTill = $2;
      $rowFrom = $3;
      $rowTill = $4;
#      print STDERR "$colFrom $2 $rowFrom $4: ";
	
      $isCell = 1;
    }
    elsif ($line =~ /^<\/cell>$/){ # end cell
      my @paraTexts = ();
      processCell($text, \@paraTexts, \%tablePos, \%tableFontSizeHash, \%tableFontFaceHash, $isDd);
#      binmode(STDERR, ":utf8");
#      my $tmpText = join(" ||| ", @paraTexts);
#      print STDERR "$tmpText\n";
      
      for(my $i = $rowFrom; $i<=$rowTill; $i++){
	for(my $j = $colFrom; $j<=$colTill; $j++){
	  if(!$table{$i}){
	    $table{$i} = ();
	  }
	  if(!$table{$i}->{$j}){
	    $table{$i}->{$j} = ();
	  }

	  if($i == $rowFrom && $j == $colFrom){
	    push(@{$table{$i}->{$j}}, @paraTexts);
	    if(scalar(@paraTexts) > 1){
	      last;
	    }
	  } else {
	    push(@{$table{$i}->{$j}}, ""); #add stub "" for spanning rows or cols
	  }
	}
      }
	
      $isCell = 0;
      $text = "";
    }    
    elsif($isCell){
      $text .= $line."\n";
      next;
    }
  }

  # note: such a complicated code is because in the normal node, Omnipage doesn't seem to strictly print column by column given a row is fixed.
  # E.g if col1: paraText1, col2: paraText21\n$paraText22, and col3: paraText31\n$paraText32
  # It will print  paraText1\tparaText21\tparaText31\n\t$paraText22\t$paraText32
  my @sortedRows = sort {$a <=> $b} keys %table;
  my $isFirstLinePara = 1;
  foreach my $row (@sortedRows){
    my %tableR = %{$table{$row}};
    my @sortedCols = sort {$a <=> $b} keys %tableR;
    while(1){
      my $isStop = 1;
      my $rowText = "";

      foreach my $col (@sortedCols){
	if(scalar(@{$tableR{$col}}) > 0){ # there's still some thing to process
	  $isStop = 0;
	  $rowText .= shift(@{$tableR{$col}});
	}
	$rowText .= "\t";
      }

      if((!$isAllowEmpty && $rowText =~ /^\s*$/)
	 || ($isAllowEmpty && $rowText eq "")){
	$isStop = 1;
      }

      if($isStop) {
	last;
      } else {
#	print STDERR "Row: $row: \"$rowText\"\n";
	$rowText =~ s/\t$/\n/;
	$allText .= $rowText;

	if($isFirstLinePara){
	  push(@gPara, "yes");
	  $isFirstLinePara = 0;
	} else {
	  push(@gPara, "no");
	}

	if($isXmlFeature){
	  push(@gPosHash, $pos); # update xml pos value
	  push(@gAlign, $align); # update xml alignment value

	  # font size feature
	  if(scalar(keys %tableFontSizeHash) == 0){
	    push(@gFontSize, -1);
	  } else {
	    my @sortedFonts = sort { $tableFontSizeHash{$b} <=> $tableFontSizeHash{$a} } keys %tableFontSizeHash;
	    my $fontSize = $sortedFonts[0];
	    push(@gFontSize, $fontSize);
	    
	    $gFontSizeHash{$fontSize} = $gFontSizeHash{$fontSize} ? ($gFontSizeHash{$fontSize}+1) : 1;
	  }
	  
	  # bold feature
	  push(@gBold, "no");
	  
	  # italic feature
	  push(@gItalic, "no");

	  # font face feature
	  if(scalar(keys %tableFontFaceHash) == 0){
	    push(@gFontFace, "none");
	  } else {
	    my @sortedFonts = sort { $tableFontFaceHash{$b} <=> $tableFontFaceHash{$a} } keys %tableFontFaceHash;
	    my $fontFace = $sortedFonts[0];
	    push(@gFontFace, $fontFace);
	    
	    $gFontFaceHash{$fontFace} = $gFontFaceHash{$fontFace} ? ($gFontFaceHash{$fontFace}+1) : 1;
	  }
	  
	  # dd feature
	  if($isDd){
	    push(@gDd, "yes");
	  } else {
	    push(@gDd, "no");
	  }

	  # cell feature
	  push(@gCell, "yes");

	  # bullet feature
	  push(@gBullet, "no");

	  # indent feature
	  push(@gIndent, "none");

	  # space feature
#	  push(@gSpace, "none");
	} # end if xml feature
      }
    }

  }

  return $allText;
}

sub processCell {
  my ($inputText, $paraTexts, $tablePos, $tableFontSizeHash, $tableFontFaceHash, $isDd) = @_;

  my $text = ""; 
  my @lines = split(/\n/, $inputText);
  my $isPara = 0;
  my $flag = 0;
  foreach my $line (@lines) {    
    if ($line =~ /^<para .+>$/){
      $text .= $line."\n"; # we need the header
      $isPara = 1;
    }
    elsif ($line =~ /^<\/para>$/){
      my ($paraText, $l, $t, $r, $b) = processPara($text, 1, $isDd, $tableFontSizeHash, $tableFontFaceHash);
      my @tokens = split(/\n/, $paraText);
#      print STDERR "\n#\n";
      foreach my $token (@tokens){
	if($token ne ""){
	  push(@{$paraTexts}, $token);
#	  print STDERR "$token\n";
	  $flag = 1;
	}
      }

      if(!$tablePos->{$paraText}){
	$tablePos->{$paraText} = "$l-$t-$r-$b";
      } else {
#	print STDERR "#! Warning: in method processCell, encounter the same paraText $paraText\n";
      }

      $isPara = 0;
      $text = "";
    }
    elsif($isPara){
      $text .= $line."\n";
      next;
    }
  }

  if($flag == 0) {# at least one value should be added for cell which is ""
    push(@{$paraTexts}, "");
  }
#  print STDERR scalar(@{$paraTexts})."\t\"".join("|||", @{$paraTexts})."\"\n";

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
  my ($attrText, $attr, $isCell, $attrHash, $tableAttrHash, $count) = @_;

  if($attrText =~ /^.*$attr=\"(.+?)\".*$/){
    my $attrValue = $1;
    
    if($isCell){
      $tableAttrHash->{$attrValue} = $tableAttrHash->{$attrValue} ? ($tableAttrHash->{$attrValue}+$count) : $count;
    } else {
      $attrHash->{$attrValue} = $attrHash->{$attrValue} ? ($attrHash->{$attrValue}+$count) : $count;
    }
  }
}

sub processPara {
  my ($inputText, $isCell, $isDd, $tableFontSizeHash, $tableFontFaceHash) = @_;
  
  my $isSpace = 0;
  my $isSpecialSpace = 0;
  my $isTab = 0;
  my $isBullet = 0;

  my $isForcedEOF = "none";  # 3 signals for end of L: forcedEOF=\"true\" in attribute of <ln> or || <nl orig=\"true\"\/> || end of </para> without encountering any of the above signal in the para plus $isSpace = 0
  my $isWd = 0;

  # xml feature
  my $align = "none"; 
  my ($l, $t, $r, $bottom);
  my %fontSizeHash = ();
  my %fontFaceHash = ();
  my @boldArray = ();
  my @italicArray = ();
  my $indent = "none";
  my $space = "none";

  my $lnAttr; my $isLn = 0; my $lnBold = "none"; my $lnItalic = "none";
  my $runAttr;  my $runText = ""; my $isRun = 0; my $runBold = "none"; my $runItalic = "none";

  my $wdIndex = 0; # word index in a line. When encountering </ln>, this parameter indicates the number of words in a line
  my $lnBoldCount = 0;
  my $lnItalicCount = 0;

  my $allText = "";
  my $text = ""; #invariant: when never enter a new line, $text will be copied into $allText, and $text is cleared

  binmode(STDERR, ":utf8");

  my $isFirstLinePara = 1;
  my @lines = split(/\n/, $inputText);
  for(my $i=0; $i<scalar(@lines); $i++){
    my $line = $lines[$i];

    ## new para
    if ($line =~ /^<para (.+?)>$/){
      my $attr = $1;
      $align = getAttrValue($attr, "alignment");
      $indent = getAttrValue($attr, "li");
      $space = getAttrValue($attr, "spaceBefore");
    }

    ## new ln
    elsif ($line =~ /^<ln (.+)>$/){ 
      $lnAttr = $1;
      $isLn = 1;

      if ($lnAttr =~ /^.*l=\"(\d+)\" t=\"(\d+)\" r=\"(\d+)\" b=\"(\d+)\".*$/){
	($l, $t, $r, $bottom) = ($1, $2, $3, $4);
      }
      $isForcedEOF = getAttrValue($lnAttr, "forcedEOF");

      if($isXmlFeature || $isMarkup){ # Bold & Italic
	$lnBold = getAttrValue($lnAttr, "bold");
	$lnItalic = getAttrValue($lnAttr, "italic");
      }
    }

    ## new run
    elsif ($line =~ /<run (.*)>$/){
      $runAttr = $1;

      $isSpace = 0;
      $isTab = 0;
      $isRun = 1;

      if($line =~ /^<wd .*?>/){  # new wd
	$isWd = 1;
      }

      if($isXmlFeature || $isMarkup){ # Bold & Italic
	$runBold = getAttrValue($runAttr, "bold");
	$runItalic = getAttrValue($runAttr, "italic");
      }
    }

    ## wd
    elsif ($line =~ /^<wd (.+)?>(.+)<\/wd>$/){
      my $wdAttr = $1;
      my $word = $2;
      $isSpace = 0;
      $isTab = 0;

      if($isXmlFeature){ # FontSize & FontFace
	checkFontAttr($wdAttr, "fontSize", $isCell, \%fontSizeHash, $tableFontSizeHash, 1);
	checkFontAttr($wdAttr, "fontFace", $isCell, \%fontFaceHash, $tableFontFaceHash, 1);
      }
	
      if($isXmlFeature || $isMarkup){ # Bold & Italic
	my $wdBold = getAttrValue($wdAttr, "bold");
	my $wdItalic = getAttrValue($wdAttr, "italic");

#	print STDERR "$wdBold\t$wdItalic\n";
	if($wdBold eq "true" || $runBold eq "true" || $lnBold eq "true"){
	  $boldArray[$wdIndex] = 1;
	  $lnBoldCount++;

	  if($isMarkup){
	    $word .= "|b";
	  }
	} elsif($isMarkup){
	  $word .= "|nb";
	}
	
	if($wdItalic eq "true" || $runItalic eq "true" || $lnItalic eq "true"){
	  $italicArray[$wdIndex] = 1;
	  $lnItalicCount++;

	  if($isMarkup){
	    $word .= "|i";
	  }
	} elsif($isMarkup){
	  $word .= "|ni";
	}
      }

      ## add text
      $text .= "$word";

      if($isRun) {
	$runText .= "$word ";
      }
      $wdIndex++;
    }

    ## end wd
    elsif ($line =~ /^<\/wd>$/){
      $isWd = 0;
    }

    ## end run
    elsif ($line =~ /^(.*)<\/run>$/){ 
      my $word = $1;
      ## add text
      if($word ne ""){
	if($isXmlFeature || $isMarkup){ # Bold & Italic
	  if($runBold eq "true" || $lnBold eq "true"){
	    $boldArray[$wdIndex] = 1;
	    $lnBoldCount++;
	 
	    if($isMarkup){
	      $word .= "|b";
	    }
	  } elsif($isMarkup){
	    $word .= "|nb";
	  }
	  
	  if($runItalic eq "true" || $lnItalic eq "true"){
	    $italicArray[$wdIndex] = 1;
	    $lnItalicCount++;
	 
	    if($isMarkup){
	      $word .= "|i";
	    }
	  } elsif($isMarkup){
	    $word .= "|ni";
	  }
	}

	if($isLn){
	  $text .= "$word";
	  
	  if($isMarkup){
	    $text .= " ";
	  }
	}

	if($isRun){
	  $runText .= "$word ";
	}	
	$wdIndex++;
      }

      # xml feature
      if($isXmlFeature && $runText ne "") { # not a space, tab or new-line run
	my @words = split(/\s+/, $runText);
	my $numWords = scalar(@words);
	checkFontAttr($runAttr, "fontSize", $isCell, \%fontSizeHash, $tableFontSizeHash, $numWords);
	checkFontAttr($runAttr, "fontFace", $isCell, \%fontFaceHash, $tableFontFaceHash, $numWords);
      }
      
      ## reset run
      if(!$isLn){ # <run> not enclosed within <ln>
	$wdIndex = 0;
      }
      $runText = "";
      $isRun = 0;      
      $isSpecialSpace = 0;

      if($isXmlFeature || $isMarkup){ # Bold & Italic
	$runBold = "none";
	$runItalic = "none";

	if(!$isLn){ # <run> not enclosed within <ln>
	  $lnBoldCount = 0;
	  $lnItalicCount = 0;
	}
      }
    }

    ## end ln
    elsif ($line =~ /^<\/ln>$/){
      if((!$isAllowEmpty && $text !~ /^\s*$/)
	 || ($isAllowEmpty && $text ne "")){
	if($isForcedEOF eq "true" || # there's a forced EOL?
	   (!$isCell && !$isSpecialSpace) # not an emply line with space character
	  ){ 
	  $text .= "\n";
	  
	  # update allText
	  $allText .= $text;
	  $text = "";
	}

	my $numWords = $wdIndex;

	if(!$isCell){
	  if($isFirstLinePara){
	    push(@gPara, "yes");
	    $isFirstLinePara = 0;
	  } else {
	    push(@gPara, "no");
	  }
	}

	if($isXmlFeature && $numWords >= 1){
	  # xml feature
	  # assumtion that: fontSize is either occur in <ln>, or within multiple <run> under <ln>, but not both
	  checkFontAttr($lnAttr, "fontSize", $isCell, \%fontSizeHash, $tableFontSizeHash, $numWords);
	  checkFontAttr($lnAttr, "fontFace", $isCell, \%fontFaceHash, $tableFontFaceHash, $numWords);
	  if($indent ne "none"){
	    $gIndentHash{$indent} = $gIndentHash{$indent} ? ($gIndentHash{$indent}+1) : 1;
	  }
#	  if($space ne "none"){
#	    $gSpaceHash{$space} = $gSpaceHash{$space} ? ($gSpaceHash{$space}+1) : 1;
#	  }
	}
	
	if($isXmlFeature && !$isCell && !$isSpecialSpace){
	  # pos feature
	  my $pos = ($t+$bottom)/2.0;
	  push(@gPosHash, $pos);

	  if($pos < $gMinPos){
	    $gMinPos = $pos;
	    }
	  if($pos > $gMaxPos){
	    $gMaxPos = $pos;
	  }

	  # alignment feature
	  push(@gAlign, $align);

	  # font size feature
	  if(scalar(keys %fontSizeHash) == 0){
	    push(@gFontSize, -1);
	  } else {
	    my @sortedFonts = sort { $fontSizeHash{$b} <=> $fontSizeHash{$a} } keys %fontSizeHash;

	    my $fontSize = $sortedFonts[0];
	    push(@gFontSize, $fontSize);

	    $gFontSizeHash{$fontSize} = $gFontSizeHash{$fontSize} ? ($gFontSizeHash{$fontSize}+1) : 1;

	    %fontSizeHash = ();
	  }

	  # font face feature
	  if(scalar(keys %fontFaceHash) == 0){
	    push(@gFontFace, "none");
	  } else {
	    my @sortedFonts = sort { $fontFaceHash{$b} <=> $fontFaceHash{$a} } keys %fontFaceHash;
	    my $fontFace = $sortedFonts[0];
	    push(@gFontFace, $fontFace);

	    $gFontFaceHash{$fontFace} = $gFontFaceHash{$fontFace} ? ($gFontFaceHash{$fontFace}+1) : 1;

	    %fontFaceHash = ();
	  }

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

	  # dd feature
	  if($isDd){
	    push(@gDd, "yes");
	  } else {
	    push(@gDd, "no");
	  }

	  # cell feature
	  push(@gCell, "no");

	  # bullet feature
	  if($isBullet){
	    push(@gBullet, "yes");
	  } else {
	    push(@gBullet, "no");
	  }

	  # indent feature
	  push(@gIndent, $indent);

	  # space feature
#	  push(@gSpace, $space);
	}
      }

      ## reset ln
      $isLn = 0;      
      $isForcedEOF = "none";
      $isSpecialSpace = 0;
      $wdIndex = 0;

      if($isXmlFeature || $isMarkup){ # Bold & Italic
	$lnBold = "none";
	$lnItalic = "none";

	$lnBoldCount = 0;
	$lnItalicCount = 0;
      }
    } # end else </ln>

    ## nl newline signal
    elsif ($line =~ /^<nl orig=\"true\"\/>$/){
      if($isLn){
	$isSpace = 0;
      } else {
	if($isDebug){
	  print STDERR "#!!! Warning: found <nl orig=\"true\"\/> while not in tag <ln>: $line\n";
	}
      }
    }

    ## space
    elsif ($line =~ /^<space\/>$/){
      my $startTag = "";
      my $endTag = "";
      if($i>0 && $lines[$i-1] =~ /^<(.+?)\b.*/){
	$startTag = $1;
      }
	
      if($i < (scalar(@lines) -1) && $lines[$i+1] =~ /^<\/(.+)>/){
	$endTag = $1;
      }
      
      if($startTag eq $endTag && $startTag ne ""){
#	print STDERR "# Special space after \"$text\"\n";
	$isSpecialSpace = 1;
      }

      ## addText
      $text .= " ";
      $isSpace = 1;
    }

    ## tab
    elsif ($line =~ /^<tab .*\/>$/){
      ## add Text
      $text .= "\t";

      $isTab = 1;
    }

    ## bullet
    elsif ($line =~ /^<bullet .*>$/){
      $isBullet = 1;
    }
  }

  $allText .= $text;
  return ($allText, $l, $t, $r, $bottom, $isSpace);
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
