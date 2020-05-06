#!/usr/bin/perl
#
# Tester: Tests a ParsCit model with a BibTex-File (.bib) as input.
#		  Output is: #1 line -> number of BibTeX entries actually used
#		             #2 line -> number of all BibTeX entries used as input
#		             #2 line -> rate of correctly labeled tokens (average of the rates calculated for each sentence)
#		             #2 line -> standard deviation
#		             #2 line -> confidence interval for 95%
#
# Matthias Bösinger 15.04.2016
# 

use 5.010;

use strict;
use FindBin;
use Getopt::Long;
use Statistics::Descriptive;
use lib "$FindBin::Bin/../lib";

use Trainer::ConfigTrainer;
use Trainer::BibTeX2TR;
use Trainer::TR2PTR;
use ParsCit::Tr2crfpp;

binmode STDIN, ":encoding(UTF-8)";
binmode STDOUT, ":encoding(UTF-8)";


### data
my $tr2crfpp		= $Trainer::ConfigTrainer::tr2crfpp;
$tr2crfpp			= "$FindBin::Bin/$tr2crfpp";

my $parse_ref_strings 	= $Trainer::ConfigTrainer::parse_ref_strings;
$parse_ref_strings 		= "$FindBin::Bin/$parse_ref_strings";
### data end



### MAIN PROGRAM START

my $tagged_references_mode = '';
if ( !GetOptions( "tr" => \$tagged_references_mode )) {
	print "Usage: $0 [-tr] bibliographie-file(IN) model-file(IN) [result-file(OUT)] \n";
    exit;
}

my $bibtex_file = $ARGV[0];
my $model_file  = $ARGV[1];
my $result_file = $ARGV[2];

if ( !defined $bibtex_file || !defined $model_file ) {
    print "Usage: $0 [-tr] bibliographie-file(IN) model-file(IN) [result-file(OUT)] \n";
    exit;
}

# load .bib file + open tmp file for bibliography + delete all 'crossref'-fields from BibTeX entries

print "=> Loading data of bibliography file\n";

open (IF, "<:utf8", $bibtex_file) || die "Couldn't open bibliography file !\n";

my $bibtex_tmp_file = ParsCit::Tr2crfpp::BuildTmpFile( $Trainer::ConfigTrainer::bibtex_test_tmp );
$bibtex_tmp_file .= '.bib';
open (OF, ">:utf8", $bibtex_tmp_file) || die "Couldn't open bibliography tmp file !\n";

while (<IF>) {
	if (!/^\s*crossref\s*=.*$/) {
		print OF;
	}	
}
close OF;


# format bibliographic entries to tagged and plain reference lists - save both lists to tmp files.
# if $tagged_references_mode is set, tagged references txt file is assumed as input.

print "=> Creating tagged and plain reference lists from bibliography file! ";

my @all_references = ();

if ( $tagged_references_mode ) {
	print "Input is tagged references list by assumption!\n";
	
	@all_references = Trainer::TR2PTR::CreateRefList( $bibtex_tmp_file );
}
else {
	print "Input is BibTeX file by assumption!\n";
	
	@all_references = Trainer::BibTeX2TR::CreateRefList( $bibtex_tmp_file, 1 );
}

if ( !@all_references ) {
	print "Error during reference list creation!\n";
	exit;
}

my $tr_ref = $all_references[0];
my $pr_ref = $all_references[1];
my %tagged_references = %$tr_ref; 
my %plain_references = %$pr_ref; 

if ( !%tagged_references || !%plain_references ) {
	print "Error during reference list creation!\n";
	exit;
}
if ( (keys %tagged_references) != (keys %plain_references ) ) {
	print "Unequal number of sentences!\n";
	exit;
}

my @tr_list;
my @pr_list;
foreach my $key ( keys %tagged_references ) {
	if ( !defined $tagged_references{ $key } || !defined $plain_references{ $key } || !$tagged_references{ $key } || !$plain_references{ $key } ) {
		print "Error in reference list format!\n";
		exit;
	}
	push @tr_list, $tagged_references{ $key }; 	
	push @pr_list, $plain_references{ $key }; 
}

my $tr_output = join "\n", @tr_list;
my $pr_output = join "\n", @pr_list;

my $tr_tmp_file = ParsCit::Tr2crfpp::BuildTmpFile( $Trainer::ConfigTrainer::tr_test_tmp );
my $pr_tmp_file = ParsCit::Tr2crfpp::BuildTmpFile( $Trainer::ConfigTrainer::pr_test_tmp );
	
open (OF, ">:utf8", $tr_tmp_file) || die "Couldn't open tagged reference output tmp file !\n";
print OF $tr_output;
close OF;

open (OF, ">:utf8", $pr_tmp_file) || die "Couldn't open plain reference output tmp file !\n";
print OF $pr_output;
close OF;


# run tr2crfpp.pl (Parent-Thread) and parseRefStrings.pl (Child-Thread) - save results to tmp files

print "=> Run tr2crfpp.pl and parseRefStrings.pl to produce CRF++ Data!\n";

my $crfpp_parscit_tmp_file 	= ParsCit::Tr2crfpp::BuildTmpFile( $Trainer::ConfigTrainer::crfpp_prs_test_tmp );
my $crfpp_tr2crfpp_tmp_file = ParsCit::Tr2crfpp::BuildTmpFile( $Trainer::ConfigTrainer::crfpp_tr2c_test_tmp );

defined(my $pid = fork) or die "Could not create child process for parseRefStrings.pl!\n";
unless ($pid) {
	
	# start parseRefStrings.pl	
	exec "$parse_ref_strings", "$pr_tmp_file", "$crfpp_parscit_tmp_file", "-split", "-crfpp", "-model=$model_file";

	die "Could not execute child process for parseRefStrings.pl!\n"	
}

	# start tr2crfpp.pl
open PIPE, "$tr2crfpp -q $tr_tmp_file |" or die "Could not open pipe from tr2crfpp call: $tr2crfpp!\n";

my @crfpp_tr2c_lines;
while (<PIPE>) {
	chomp();
	push @crfpp_tr2c_lines, $_;
}
close PIPE;

my $crfpp_tr2c_output = join "\n", @crfpp_tr2c_lines;

open (OF, ">:utf8", $crfpp_tr2crfpp_tmp_file) || die "Couldn't open Crf++ output tmp file !\n";
print OF $crfpp_tr2c_output;
close OF;

waitpid($pid, 0);


# compare parseRefString and (as answer) tagged result

print "=> calculate results\n";

my %parscit_tags	= &extractTagLists( $crfpp_parscit_tmp_file );
my %tex_tags 		= &extractTagLists( $crfpp_tr2crfpp_tmp_file );

if ( (keys %parscit_tags) != (keys %tex_tags) ) {
	print "Unequal number of sentences!\n";
	exit;
}

my @per_sentence_results;
my @below_hundred_results;
my $nr_of_sentences = keys %parscit_tags;
my $rate;

foreach my $sent_index (1 .. (keys %tex_tags) )
{
	my $pc_ref				= $parscit_tags{ $sent_index };
	my $lx_ref				= $tex_tags{ $sent_index };
	my @parscit_sentence	= @$pc_ref;
	my @latex_sentence		= @$lx_ref;
	
	if (@parscit_sentence != @latex_sentence ) {
		print "Unequal number of tags in sentence #" . $sent_index . "!\n";
		next;
	}
	
	my $correct_tags_per_sentence	= 0;
	my $tag1, my $tag2;
	foreach my $index (0 .. $#parscit_sentence) {
		$tag1 = $parscit_sentence[ $index ];
		$tag2 = $latex_sentence[ $index ];
		$tag1 = ( $tag1 eq 'booktitle' ) ? 'title' : $tag1;
		$tag2 = ( $tag2 eq 'booktitle' ) ? 'title' : $tag2;
		if ( $tag1 eq $tag2 ) {
			$correct_tags_per_sentence++;
		}
	}
	$rate = $correct_tags_per_sentence / @parscit_sentence;
	push @per_sentence_results, $rate;
	push @below_hundred_results, $sent_index if ( $rate < 1);
}


# calculate and output result

system "clear";

my $stat = Statistics::Descriptive::Full->new();
$stat->add_data( @per_sentence_results );
my $n 		= $stat->count();
my $avg		= $stat->mean(); 
my $std_dev	= $stat->standard_deviation();
my @conf 	= &confInterval( $n, $avg, $std_dev );

my $result = '';
$result .= sprintf "number(used) = %d\n", $n;
$result .= sprintf "number(all)  = %d\n", $nr_of_sentences;
$result .= sprintf "average      = %.4f\n", $avg;
$result .= sprintf "std-dev      = %.4f\n", $std_dev;
$result .= sprintf "conf(95)     = %.4f\t%.4f\n", $conf[0], $conf[1];
$result .= sprintf "< 1.00       = %s\n", join ", ", @below_hundred_results;	
$result .= "### Rate of correct tags of every (of $n) reference(s) is (random) variable.\n### 'average' is calculated as average of each reference rate.\n### Confidence interval of 95% is chosen.\n### Ensure n > 30, since statistical z-values are used.\n### '< 1.00' lists numbers of sentences with incorrect tags.\n";

if (open(OUT, ">:utf8", $result_file)) {
	print OUT $result;
}
else {
	print $result;
}	


# unlink files

#unlink $bibtex_tmp_file;
#unlink $tr_tmp_file;
#unlink $pr_tmp_file;
#unlink $crfpp_parscit_tmp_file;
#unlink $crfpp_tr2crfpp_tmp_file;


### SUB FUNCTIONS

# subfunction to extract tags lists from crfpp output - return nested array where each inner array is a crfpp sentence 

sub extractTagLists 
{	
	( my $filename ) = @_;
	
	open (IF, "<:utf8", $filename) || die "Couldn't open crf++ input tmp file !\n";
	
	my $sentence = 1;
	my %tags = ();
	
	while (<IF>) {
		if (/^\s*$/) {
			$sentence++;
			next; 
		}
		
		my @all_tokens	= split /\s+/, $_;
		my $tag			= $all_tokens[ $#all_tokens ];
		
		push @{$tags{ $sentence }}, $tag;
	}
	close (IF);

	return %tags;
}


sub confInterval 
{	
	( my $n, my $avg, my $std_dev ) = @_;
	
	my @result = ();
	
	my $kov = 1.96 * ( $std_dev / sqrt( $n ));
	
	$result[0] = $avg - $kov;
	$result[1] = $avg + $kov;
	
	return @result;
}
