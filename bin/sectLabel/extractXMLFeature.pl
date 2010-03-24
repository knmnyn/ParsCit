#!/usr/bin/perl -wT
# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Tue, 02 Jun 2009 01:30:42

# Modified from template by Min-Yen Kan <kanmy@comp.nus.edu.sg>

require 5.0;
use strict;
use Getopt::Long;

### USER customizable section
$0 =~ /([^\/]+)$/; my $progname = $1;
my $outputVersion = "1.0";
### END user customizable section

sub License {
  print STDERR "# Copyright 2009 \251 by Luong Minh Thang\n";
}

### HELP Sub-procedure
sub Help {
  print STDERR "Parse tagged header file into line-level data\n";
  print STDERR "usage: $progname -h\t[invokes help]\n";
  print STDERR "       $progname -in xmlFile -out outFile -tag tagFile\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
}
my $QUIET = 0;
my $HELP = 0;
my $outFile = undef;
my $inFile = undef;
my $tagFile = "";
$HELP = 1 unless GetOptions('in=s' => \$inFile,
			    'out=s' => \$outFile,
			    'tag=s' => \$tagFile,
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

my $gLineId = 0;

# locFeature
my @gPosHash = ();
my $gMinPos = 1000000;
my $gMaxPos = 0;

# alignmentFeature
#my @g
my %tags = ();
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

  my $allText = "";
  my $text = ""; 
  my $tag;
  my $attr;
  while (<IF>) { #each line contains a header
    if (/^\#/) { next; }			# skip comments
    chomp;
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

    ### Table ###
    if ($line =~ /^<table .*>$/){
      $isTable = 1;
    }
    elsif ($line =~ /^<\/table>$/){
      $allText .= processTable($text);

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
      my ($paraText, $l, $t, $r, $b) = processPara($text, 0);
      $allText .= $paraText;

      $isPara = 0;
      $text = "";
    }
    elsif($isPara){
      $text .= $line."\n";
      next;
    }


  }  

  my @lines = split(/\n/, $allText);
#  print STDERR "$allText\n";
  my $id = 0;
  foreach my $line (@lines) {
    my $locFeature;
    if($gPosHash[$id] != -1){
      $locFeature = "LOC-".int(($gPosHash[$id] - $gMinPos)*8.0/($gMaxPos - $gMinPos + 1));
    } else {
      $locFeature = "LOC-table";
    }
    print OF "$line ||| $locFeature\n";
    $id++;
  }

  print STDERR "$id\t".scalar(@gPosHash)."\n";
#  print OF $allText;
  close OF;
  close IF;
}

sub processTable {
  my ($inputText) = @_;

  my $isCell = 0; # for table cell object

  my $allText = "";
  my $text = ""; 

  my @lines = split(/\n/, $inputText);
  my %tablePos = (); # $tablePos{$cellText} = "$l-$t-$r-$b"
  my %table = (); # $table{$row}->{$col} = \@paraTexts
  my $rowFrom;   
  my $colFrom;
  my $rowTill;   
  my $colTill;
  foreach my $line (@lines) {
    if ($line =~ /^<cell .*gridColFrom=\"(\d+)\" gridColTill=\"(\d+)\" gridRowFrom=\"(\d+)\" gridRowTill=\"(\d+)\".*>$/){ # new cell
      if($1 != $2){
	print STDERR "#! Different col from vs col till: $line\n";
      }
      if($3 != $4){
	print STDERR "#! Different row from vs row till: $line\n";
      }
      $colFrom = $1;
      $colTill = $2;
      $rowFrom = $3;
      $rowTill = $4;
#      print STDERR "$colFrom $2 $rowFrom $4: ";
	
      $isCell = 1;
    }
    elsif ($line =~ /^<\/cell>$/){ # end cell
      my @paraTexts = ();
      processCell($text, \@paraTexts, \%tablePos);
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

      if($isStop) {
	last;
      } else {
#	print STDERR "$row: \"$rowText\"\n";
	$rowText =~ s/\t$/\n/;
	$allText .= $rowText;

	push(@gPosHash, "-1"); # update xml pos value
      }
    }

  }

  return $allText;
}

sub processCell {
  my ($inputText, $paraTexts, $tablePos) = @_;

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
      my ($paraText, $l, $t, $r, $b) = processPara($text, 1);
      my @tokens = split(/\n/, $paraText);
      foreach my $token (@tokens){
	if($token ne ""){
	  push(@{$paraTexts}, $token);
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

sub processPara {
  my ($inputText, $isCell) = @_;
  
  my $isSpace = 0;
  my $isTab = 0;
  my $isBullet = 0;

  my $isForcedEOF = 0;  # 3 signals for end of L: forcedEOF=\"true\" in attribute of <ln> or || <nl orig=\"true\"\/> || end of </para> without encountering any of the above signal in the para plus $isSpace = 0
  my $isLn = 0;
  my $isWd = 0;

  my ($l, $t, $r, $b);
  my $allText = "";
  my $text = ""; #invariant: when never enter a new line, $text will be copied into $allText, and $text is cleared
  my @lines = split(/\n/, $inputText);
  foreach my $line (@lines) {    
    if ($line =~ /^<para .*>$/){
    }
    elsif ($line =~ /^<ln.*l=\"(\d+)\" t=\"(\d+)\" r=\"(\d+)\" b=\"(\d+)\".*>$/){ # new ln
      ($l, $t, $r, $b) = ($1, $2, $3, $4);
      $isLn = 1;

      if ($line =~ /^<ln .*forcedEOF=\"true\".*>$/){
	$isForcedEOF = 1;
      }
    }
    elsif ($line =~ /^<wd .*?>(.+)<\/wd>$/){ # a wd
      $isSpace = 0;
      $isTab = 0;
      $isBullet = 0;

      my $word = $1;
      $text .= "$word";
    }
    elsif ($line =~ /^<wd .*?><run (.*)>$/){ # new wd
      $isSpace = 0;
      $isTab = 0;
      $isBullet = 0;

      $isWd = 1;
    }
    elsif ($line =~ /^<\/wd>$/){ # end wd
      $isWd = 0;
    }
    elsif ($line =~ /^(.*)<\/run>$/){ # end run
      my $word = $1;
      if($isLn && $word ne ""){
	$text .= "$word";
      } elsif($word ne "") {
#	print STDERR "#!!! Found a word not in <ln>: $line\n";
      }
    }
    elsif ($line =~ /^<\/ln>$/){ # end ln
      if($text ne ""){
	if(!$isCell){
	  my $pos = ($t+$b)/2.0;
	  push(@gPosHash, $pos);
	  if($pos < $gMinPos){
	    $gMinPos = $pos;
	  }
	  if($pos > $gMaxPos){
	    $gMaxPos = $pos;
	  }
	  $gLineId++;
	}

#	$text .= "|||($l, $t, $r, $b)\n";
	$text .= "\n";
      }

      $isForcedEOF = 0;
      $isLn = 0;
    }

=pod
    elsif ($line =~ /^<nl orig=\"true\"\/>$/){
      if($isLn){
	if(!$isCell){ #$text ne "" && 
	  $text =~ s/ \+L\+ $//;
	  $text .= "\n";
	  $allText .= $text;
	  $text = "";
	}
      } else {
	print STDERR "#!!! Warning: found <nl orig=\"true\"\/> while not in tag <ln>: $line\n";
      }
    }
=cut

    elsif ($line =~ /^<space\/>$/){
      $text .= " ";
      $isSpace = 1;
    }
    elsif ($line =~ /^<tab .*\/>$/){
      $text .= "\t";
      $isTab = 1;
    }

=pod
    elsif ($line =~ /^<bullet .*>$/){
      $isBullet = 1;
    }
=cut

  }

=pod
  $text =~ s/ \+L\+ $//;
  if($text ne ""){
    if(!$isSpace && !$isTab && !$isCell){
      $text .= "\n";
    }
  } else {
    if($isBullet){
      $text .= "\n";
    }
  }
=cut

  $allText .= $text;

  return ($allText, $l, $t, $r, $b);
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
  print STDERR "Executing: $cmd\n";
  $cmd = untaint($cmd);
  system($cmd);
}

sub newTmpFile {
  my $tmpFile = `date '+%Y%m%d-%H%M%S-$$'`;
  chomp($tmpFile);
  return $tmpFile;
}
