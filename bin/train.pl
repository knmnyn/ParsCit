#!/usr/bin/perl
#
# Trainer: Trains ParsCit model from BibTex (.bib) file automatically.
#
# Matthias Bösinger 09.04.2016
#
# To change in LateX:
# (/usr/share/texlive/texmf/web2c/texmf.cnf -> change openout_any = p to = r )
#

use 5.010;

use strict;
use FindBin;
use Time::HiRes;
use lib "$FindBin::Bin/../lib";

use Trainer::ConfigTrainer;
use Trainer::BibTeX2TR;
use ParsCit::Tr2crfpp;

binmode STDIN, ":encoding(UTF-8)";
binmode STDOUT, ":encoding(UTF-8)";


### data
my $time_start 		= Time::HiRes::gettimeofday();

my $tr2crfpp		= $Trainer::ConfigTrainer::tr2crfpp;
$tr2crfpp			= "$FindBin::Bin/$tr2crfpp";

my $crfpp_learn 	= $Trainer::ConfigTrainer::crfpp_learn;
$crfpp_learn 		= "$FindBin::Bin/../crfpp/$crfpp_learn";

my $crfpp_template 	= $Trainer::ConfigTrainer::crfpp_template;
$crfpp_template		= "$FindBin::Bin/../$crfpp_template";
### data end



### MAIN PROGRAM START

if ( @ARGV > 3 || !defined $ARGV[0] || !defined $ARGV[1] ) {
	print "Usage: $0 bibtex-file(IN) [crfpp-data-file(IN)] model-file(OUT)\n";
    exit;
}

my $bibtex_file	= $ARGV[0];
my $model_file	= ( @ARGV > 2 ) ? $ARGV[2] : $ARGV[1];
my $crfpp_file	= ( @ARGV > 2 ) ? $ARGV[1] : '';

# load .bib file

print "=> Loading data of BibTeX file\n";

open (IF, "<:utf8", $bibtex_file) || die "Couldn't open BibTeX file !\n";


# define and open tmp file for BibTeX entries (.bib)

my $bibtex_tmp_file = ParsCit::Tr2crfpp::BuildTmpFile( $Trainer::ConfigTrainer::bibtex_tmp );
$bibtex_tmp_file .= '.bib';

open (OF1, ">:utf8", $bibtex_tmp_file) || die "Couldn't open BibTeX tmp file !\n";


# delete all 'crossref'-fields from BibTeX entries and write file to tmp file

while (<IF>) {
	if (!/^\s*crossref\s*=.*$/) {
		print OF1;
	}	
}
close OF1;


# format BibTeX entries to tagged reference list and print references to file

print "=> Creating tagged references from BibTeX file!\n";

my @all_references = Trainer::BibTeX2TR::CreateRefList( $bibtex_tmp_file, 0);

my $tr_ref				= $all_references[0];
my %tagged_references 	= %$tr_ref;
my @tr_list 			= values %tagged_references;
if ( !@tr_list ) {
	print "Error during reference list creation!\n";
	return -1;
}

my $tr_output = join "\n", @tr_list;

my $tr_tmp_file = ParsCit::Tr2crfpp::BuildTmpFile( $Trainer::ConfigTrainer::tagged_references_tmp );
	
open (OF2, ">:utf8", $tr_tmp_file);
print OF2 $tr_output;
close OF2;


# create crfpp train data and write to tmp file

print "=> Generating traingsdata for CRF++\n";

open PIPE, "$tr2crfpp -q $tr_tmp_file |" or die "Could not open pipe from tr2crfpp call: $tr2crfpp!\n";

my @crfpp_lines;
while (<PIPE>)
{
	chomp();
	push @crfpp_lines, $_;
}
close PIPE;

my $crfpp_output = join "\n", @crfpp_lines;

	# add additional crfpp data if second optional file has been passed
if ( $crfpp_file ) {
	$crfpp_output .= "\n\n";
	
	open (IF, "<:utf8", $crfpp_file) || die "Couldn't open file: $crfpp_file!\n";
	
	while (<IF>) {
		$crfpp_output .= $_;
	} 
	close IF;
}

my $crfpp_tmp_file = ParsCit::Tr2crfpp::BuildTmpFile( $Trainer::ConfigTrainer::crfpp_tmp );

open (OF3, ">:utf8", $crfpp_tmp_file);
print OF3 $crfpp_output;
close OF3;


# print elapsed time (for training)

my @time = ( $time_start );
my $elapsed = Time::HiRes::tv_interval( \@time );

printf "=> Elapsed time for building training model: %.4f s\n", $elapsed;


# train crfpp model

print "=> Training CRF++ model\n";

!system "$crfpp_learn", "$crfpp_template", "$crfpp_tmp_file", "$model_file" or die "Unexpected termination of crf_learn process: $crfpp_learn!\n";


# unlink files

unlink $bibtex_tmp_file;
unlink $tr_tmp_file;
unlink $crfpp_tmp_file;
