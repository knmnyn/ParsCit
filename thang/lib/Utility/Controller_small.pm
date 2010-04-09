package Utility::Controller;
#
# This package contains handy methods to use
#
# Minh-Thang Luong 03 June 09
#
require 'dumpvar.pl';
use strict;

#### List methods ###
# checkDir
# getNumLines
# getFilesInDir
# execute
# executeQuiet
# newTmpFile
#####################

# checkDir
sub checkDir {
  my ($outDir) = @_;

  if(-d $outDir){
    print STDERR "#! Directory $outDir exists!\n";
  } else {
    print STDERR "# Directory $outDir does not exist! Creating ...\n";
    execute("mkdir -p $outDir");
  }
}

# get the number of lines in a file
sub getNumLines {
  my ($inFile) = @_;

  ### Count & verify the totalLines ###
  chomp(my $tmp = `wc -l $inFile`);
  my @tokens = split(/ /, $tmp);
  return $tokens[0];
}

### Get a list of files in the provided directory, and sort them alphabetically###
sub getFilesInDir{
  my ($inDir, $files) = @_;

  if(!-d $inDir) {
    die "Die: directory $inDir does not exist!\n";
  }
  
  opendir DIR, $inDir or die "cannot open dir $inDir: $!";
  my @files= grep { $_ ne '.' && $_ ne '..' && $_ !~ /~$/} readdir DIR;
  closedir DIR;
  
  my @sorted_files = sort { $a cmp $b } @files;
  @{$files} = @sorted_files;
}

sub execute {
  my ($cmd) = @_;
  print STDERR "Executing: $cmd\n";
  system($cmd);
}

sub executeQuiet {
  my ($cmd) = @_;
  #print STDERR "Executing: $cmd\n";
  system($cmd);
}

sub newTmpFile {
  my $tmpFile = `date '+%Y%m%d-%H%M%S-$$'`;
  chomp($tmpFile);
  return $tmpFile;
}

1;
