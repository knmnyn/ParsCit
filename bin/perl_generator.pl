#!/usr/bin/perl -w

use strict;
use Getopt::Long;

### USER customizable section
$0 =~ /([^\/]+)$/; my $progname = $1;
my $outputVersion = "1.0";
my $tmpFile = `date '+%Y%m%d-%H%M%S'`;
chomp($tmpFile);
### END user customizable section

sub License {
  print STDERR "# Copyright 2008 \251 by Luong Minh Thang\n";
}

### HELP Sub-procedure
sub Help {
  print STDERR "usage: $progname -h\t[invokes help]\n";
  print STDERR "       $progname [-in templateFile] -out outFile\n";
  print STDERR "Options:\n";
  print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
}

my $QUIET = 0;
my $HELP = 0;
my $templateFile = "$ENV{SMT_HOME}/scripts/new_template";
my $outFile = undef;

$HELP = 1 unless GetOptions('in=s' => \$templateFile,
			    'out=s' => \$outFile,
			    'h' => \$HELP,
			    'q' => \$QUIET);

if ($HELP || !defined $outFile) {
  Help();
  exit(0);
}

if (!$QUIET) {
  License();
}

if(!defined $templateFile){
  $templateFile = "$ENV{SMT_HOME}/scripts/new_template";
}

# file I/O
if(! (-e $templateFile)){
  die "#File \"$templateFile\" doesn't exist";
}
open(IF, $templateFile) || die "#Can't open file \"$templateFile\"";
open(OF, ">$outFile") || die "#Can't open file \"$outFile\"";

#printing startup comments: name + time
my @days = qw(Sunday Monday Tuesday Wednesday Thursday Friday Saturday);
my @shortdays = qw( Sun Mon Tue Wed Thu Fri Sat );
my @months = qw(January February March April May June July August September October November December);
my @shortmonths = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

my ( $sec, $min, $hr, $mday, $mon, $year, $wday, $yday, $isdst ) =
    localtime(time);
my $longyr = $year + 1900;
my $fixmo  = $mon + 1;

# Wed, 03 Oct 1999 12:23:55 CST
my $time;
$time = sprintf("%3s, %02d %3s %04d %02d:%02d:%02d\n", $shortdays[$wday], $mday,
	$shortmonths[$mon], $longyr, $hr, $min, $sec );
print OF "#!/usr/bin/perl -wT\n";
print OF "# Author: Luong Minh Thang <luongmin\@comp.nus.edu.sg>, generated at $time\n";

#process input file
my $count = 0;
while(<IF>){
  chomp;
  if($count != 0){
    print OF "$_\n";
  } else {
    $count = 1;
  }
}

close(IF);
close(OF);
`chmod +x $outFile`;
#foreach $word (keys (%words)){
#}

#foreach $word (@sorted_words){
#}

