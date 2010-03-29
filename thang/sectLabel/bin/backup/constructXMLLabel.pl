#!/usr/bin/perl -wT
# Author: Luong Minh Thang <luongmin@comp.nus.edu.sg>, generated at Fri, 20 Nov 2009 19:33:13

# Modified from template by Min-Yen Kan <kanmy@comp.nus.edu.sg>

require 5.0;
use strict;
use Getopt::Long;

# I do not know a better solution to find a lib path in -T mode.
# So if you know a better solution, I'd be glad to hear.
# See this http://www.perlmonks.org/?node_id=585299 for why I used the below code
use FindBin;
my $path;
BEGIN {
  if ($FindBin::Bin =~ /(.*)/) {
    $path = $1;
  }
}
use lib "$path/../../lib";
#use Utility::Controller;
#use Morphology::Controller;

### USER customizable section
$0 =~ /([^\/]+)$/; my $progname = $1;
my $outputVersion = "1.0";
### END user customizable section

sub License {
  print STDERR "# Copyright 2009 \251 by Luong Minh Thang\n";
}

### HELP Sub-procedure
sub Help {
  print STDERR "usage: $progname -h\t[invokes help]\n";
  print STDERR "       $progname (-in fileList | -n id) -dir xmlInDir -outDir outDir [-tag -xmlFeature -concat -empty]\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
  print STDERR "\t-tag: print out tags available\n";
  print STDERR "\t-concat: concat multiple XML lines into 1 single line (as in Omnipage normal mode)\n";
  print STDERR "\t-empty: allow empty lines\n";
}
my $QUIET = 0;
my $HELP = 0;
my $id = undef;
my $fileList = undef;
my $xmlDir = undef;
my $outDir = undef;
my $isTag = 0;
my $isXmlFeature = 0;
my $isConcat = 0;
my $isAllowEmpty = 0;
$HELP = 1 unless GetOptions('in=s' => \$fileList,
			    'n=s' => \$id,
			    'dir=s' => \$xmlDir,
			    'outDir=s' => \$outDir,
			    'tag' => \$isTag,
			    'xmlFeature' => \$isXmlFeature,
			    'concat' => \$isConcat,
			    'empty' => \$isAllowEmpty,
			    'h' => \$HELP,
			    'q' => \$QUIET);

if ($HELP || !defined $xmlDir || !defined $outDir) {
  Help();
  exit(0);
}

if(!defined $id && !defined $fileList){
  die "Die: at least one -in or -n should be specified\n";
} elsif(defined $id && defined $fileList){
  die "Die: -in and -n are mutually exclusive\n";
}

if($isConcat && $isXmlFeature){
  die "-concat & -xmlFeature are not used together\n";
}

if (!$QUIET) {
  License();
}

### Untaint ###
$outDir = untaintPath($outDir);
$xmlDir = untaintPath($xmlDir);
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
### End untaint ###

my %fileList = ();
my @sorted_files;
if(defined $fileList){
  $fileList = untaintPath($fileList);
  getFileList($fileList, \%fileList);
  @sorted_files = sort {$a cmp $b} keys %fileList;
} else {
  @sorted_files = ();
  push(@sorted_files, $id);
}

if(!-d $outDir){
  print STDERR "#! Directory $outDir doesn't exist. Creating ...\n";
  execute("mkdir -p $outDir");
}
if(!-d "$outDir/single"){
  execute("mkdir -p $outDir/single");
}


foreach my $inFile (@sorted_files){
  $inFile = untaintPath($inFile);
  processFile($inFile, $xmlDir, $outDir);
}

sub getFileList {
  my ($inFile, $fileList) = @_;

  #file I/O
  if(! (-e $inFile)){
    die "#File \"$inFile\" doesn't exist";
  }
  open(IF, "<:utf8", $inFile) || die "#Can't open file \"$inFile\"";
  
  #process input file
  while(<IF>){
    chomp;

    $fileList->{$_} = 1;
  }
  
  close IF;
}

sub processFile{
  my ($inFile, $xmlDir, $outDir) = @_;
  
  ### Get a list of labeled files ###
  if(!-d $xmlDir) {
    die "Die: directory $xmlDir does not exist!\n";
  }
  opendir DIR, $xmlDir or die "cannot open dir $xmlDir: $!";
  my @files= grep { $_ ne '.' && $_ ne '..' && $_ !~ /~$/ && $_ =~ /^$inFile\D/ } readdir DIR;
  closedir DIR;
  my @sorted_xmls = sort { $a cmp $b } @files;
  print STDERR "\n### $inFile\n";

  my $outFile = "$outDir/$inFile.txt";
  if(-e $outFile){
    print STDERR "#! $outFile exists. Removing ...\n";
    execute("rm -rf $outFile");
  }

  my $tagFile = "$outDir/$inFile.tag";
  my $tmpFile = "$outDir/".newTmpFile();
  $tmpFile = untaintPath($tmpFile);
  foreach my $xml (@sorted_xmls){    
    my $txtFile = "$outDir/single/$xml";
    $txtFile =~ s/\.xml$/\.txt/;
    print STDERR "$txtFile\n";

    my $cmd = "$path/processOmniXML.pl -q -in $xmlDir/$xml -out $txtFile";
    if($isXmlFeature) {
      $cmd .= " -xmlFeature";
    }

    if($isConcat) {
      $cmd .= " -concat";
    }

    if($isAllowEmpty) {
      $cmd .= " -empty";
    }

    if($isTag) {
      $cmd .= " -tag $tmpFile";
    }
    execute1($cmd); 
    execute1("cat $txtFile >> $outFile");

    if($isTag){
      execute1("cat $tmpFile >> $tagFile.tmp");
    }
  }

  my %tags = ();
  if($isTag){
    open(IF, "<:utf8", "$tagFile.tmp") || die "#Can't open file \"$tagFile.tmp\"";
    my $tag;
    while(<IF>){
      chomp;

      if(/^\# Tag = (.+)$/){
	$tag = $1;
	if(!$tags{$tag}){
	  $tags{$tag} = ();
	}
      } elsif(/^(.+?): (.+)$/){
	my $attr = $1;
	my @values = split(/\s+/, $2);

	if(!$tags{$tag}->{$attr}){
	  $tags{$tag}->{$attr} = ();
	}

	foreach my $value (@values) {
	  if($value =~ /^(.+)\-(\d+)$/){
	    $value = $1;
	    my $count = $2;
	    if(!$tags{$tag}->{$attr}->{$value}){
	      $tags{$tag}->{$attr}->{$value} = 0;
	    }
	    $tags{$tag}->{$attr}->{$value} += $count;
	  } else {
	    die "Die: mismatch \"$value\" vs pattern /^(.+)\\-(\\d+)$\n";
	  }
	}
      }
    }
    close IF;

    open(OF, ">:utf8", "$tagFile") || die "#Can't open file \"$tagFile\"";

    my @sortedTags = sort {$a cmp $b} keys %tags;
    foreach(@sortedTags){
      my @attrs = sort {$a cmp $b} keys %{$tags{$_}};
      print OF "# Tag = $_\n";
      foreach my $attr (@attrs) {
	print OF "$attr:";
	my @values = sort {$tags{$_}->{$attr}->{$b} <=> $tags{$_}->{$attr}->{$a} } keys %{$tags{$_}->{$attr}};
	my $count = 0;
	foreach my $value (@values){
	  print OF " $value-$tags{$_}->{$attr}->{$value}";
	  
	  $count++;
	  if($count == 10){
	    last;
	  }
	}
	print OF "\n";
      }
    }

    close OF;
  }

  unlink("$tmpFile");
  unlink("$tagFile.tmp");
}

sub untaintPath {
  my ($path) = @_;

  if ( $path =~ /^([-_\/\w\.]+)$/ ) {
    $path = $1;
  } else {
    die "Bad path \"$path\"\n";
  }

  return $path;
}

sub untaint {
  my ($s) = @_;
  if ($s =~ /^([\w \-\@\(\),\.\/<>]+)$/) {
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

sub execute1 {
  my ($cmd) = @_;
  #print STDERR "Executing: $cmd\n";
  $cmd = untaint($cmd);
  system($cmd);
}

sub newTmpFile {
  my $tmpFile = `date '+%Y%m%d-%H%M%S-$$'`;
  chomp($tmpFile);
  return $tmpFile;
}
