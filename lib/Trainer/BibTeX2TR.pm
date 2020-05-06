package Trainer::BibTeX2TR;

###
# To transform BibTeX entries to list of tagged references.
# Using styles defined in ConfigTrainer.pm
#
# Copyright 2016 Matthias Bösinger 19.04.2016
###

use 5.010;

use strict;
use FindBin;
use File::Basename;
use lib "$FindBin::Bin/../lib";

use Text::BibTeX;

use Trainer::ConfigTrainer;
use Trainer::BBL2UTF8;

use ParsCit::Tr2crfpp;
use ParsCit::Config;


### data
my $tex_dir			= $Trainer::ConfigTrainer::tex_dir;
$tex_dir			= "$FindBin::Bin/../$tex_dir";

my @used_bibstyles	= @Trainer::ConfigTrainer::used_bibstyles;
my $nr_of_styles = @used_bibstyles;
### END data



### MAIN FUNCTION

sub CreateRefList
{	
	my ( $bibtexTmpFile, $addPlainReferences ) = @_;
	
	# create list of files for splitted .bib output
	
	my @bib_file_handles = ();
	my @bib_part_filenames = ();
	
	foreach my $index ( 0 .. $#used_bibstyles ) 
	{
		my $bibtex_part_tmp = ParsCit::Tr2crfpp::BuildTmpFile( $Trainer::ConfigTrainer::bibtex_part_tmp );
		$bibtex_part_tmp .= "$used_bibstyles[ $index ].bib";
		push @bib_part_filenames, $bibtex_part_tmp;
		
		open my $file_handle, ">:utf8", $bibtex_part_tmp;
		push @bib_file_handles, $file_handle;
	}
	
	
	# create lists of keys of bibtex entries (one list for each style)
	
	my $bibtex_list = new Text::BibTeX::File $bibtexTmpFile or die "Couldn't open bibliography file: $bibtexTmpFile\n";
	
	my $index = 0;
	while (my $entry = new Text::BibTeX::Entry $bibtex_list) {
		my $file_handle = $bib_file_handles[ $index ];
		$entry->print( $file_handle );
	
		$index = ($index + 1) % $nr_of_styles;
	}
	
	$bibtex_list->close();
	
	
	# create reference string for each (style-)list of BibTeX keys 
	
	my %tagged_references = ();
	my %plain_references = ();
	
	my $dir = "/$ParsCit::Config::tmpDir";
	chdir($dir);
	
	foreach my $index ( 0 .. $#used_bibstyles ) 
	{
		my $style = $used_bibstyles[ $index ];
		my $bib_file = $bib_part_filenames[ $index ];
		
		my $references = &getReferencesText( $style . "TR", $bib_file );
		
		&storeReferences( $references, \%tagged_references, 1 );
		
		if ( $addPlainReferences ) 
		{
			my $references = &getReferencesText( $style, $bib_file );
		
			&storeReferences( $references, \%plain_references, 0 );
		}
	}	
	
	# unlink tmp files
	
	foreach my $filename ( @bib_part_filenames ) {
		unlink $filename;
	}
	
	my $bin = $FindBin::Bin;
	chdir( $bin );
	
	# return result
	
	my @result = ();
	
	$result[0] = \%tagged_references;
	$result[1] = \%plain_references;
	
	return @result;	
}


### SUB FUNCTIONS

sub getReferencesText
{
	( my $style, my $bib_file ) = @_;
	
	# create bib tex pattern file with stylename and .bib-file location as variables
	
	my $bibtex_pattern_file = "$tex_dir/$Trainer::ConfigTrainer::tex_pattern";
	my $style_file 			= "$tex_dir/$style";
	
	open IF, "<:utf8", $bibtex_pattern_file or die "Couldn't open .tex pattern file: $bibtex_pattern_file\n";
	my $bibtex_pattern = '';
	while (<IF>) {
		chomp();
		$bibtex_pattern .= $_ . "\n";
	}
	$bibtex_pattern = sprintf($bibtex_pattern, $bib_file, $style_file);
	close IF;
	
	my $bibtex_pattern_tmpfile_stomp = ParsCit::Tr2crfpp::BuildTmpFile( $Trainer::ConfigTrainer::tex_pattern_tmp );
	$bibtex_pattern_tmpfile_stomp .= $style;
	my $bibtex_pattern_tmpfile_tex = "$bibtex_pattern_tmpfile_stomp.tex";
	open OF, ">:utf8", $bibtex_pattern_tmpfile_tex or die "Couldn't open .tex pattern tmp file: $bibtex_pattern_tmpfile_tex\n";
	print OF $bibtex_pattern;
	close OF;
	
	# run latex and bibtex (/usr/share/texlive/texmf/web2c/texmf.cnf -> change openout_any = p to = r )
	
	system "latex", "$bibtex_pattern_tmpfile_stomp";
	system "bibtex", "$bibtex_pattern_tmpfile_stomp";
	
	# get text from .bbl file
	
	my $bibtex_bbl_file = "$bibtex_pattern_tmpfile_stomp.bbl";
	open IF, "<:utf8", $bibtex_bbl_file or die "Couldn't open .bbl file: $bibtex_bbl_file\n";
	
	my $result = '';
	while (<IF>) {
		chomp();
		$result .= $_ . "\n";
	}

	#unlink tmp files and return result;
	
	if ($bibtex_pattern_tmpfile_stomp && !($bibtex_pattern_tmpfile_stomp =~ /.*\*.*/)) {
		unlink glob "$bibtex_pattern_tmpfile_stomp.*";
	}
	
	return $result;
}



sub storeReferences
{
	(my $text, my $mapRef, my $tagged_refs) = @_;
	
	my $line = '';	
	my $key = '';	
	my $flag = 0;	

	foreach (split "\n", $text) 
	{
		chomp();
		
		my $start_end = /^\s*$/ || /^\s*\\(end|begin).*{.+}.*$/;
		my $item 	  = /^\s*\\bibitem.*{(.+)}\s*$/;
		
		if ($start_end || $item) 
		{ 
			if ($flag && $line) {
				if ( $tagged_refs ) {
					$line = &filterTaggedReferences( $line );
				}
				else {
					$line = &filterReferences( $line );
				}
				$$mapRef{ $key } = $line;
			}
			
			if ($start_end) {
				$line = '';
				$flag = 0;
			}
			elsif (s/^\s*\\bibitem.*{(.+)}\s*$/$1/) {
				$key = $_;
				$line = '';
				$flag = 1;
			}	
			next;
		}
		
		if ( $flag ) {
			$line .= $_;
		}
	}
}


sub filterTaggedReferences
{
	( $_ ) = @_;
	
	while (s/<(.+?)>(.+?)<\/(\1)>([^<>]+?)<(.+?)>(.+?)<\/(\5)>/<$1>$2$4<\/$3><$5>$6<\/$7>/g) { }  # reset tags so that no text is in between two tags
	while (s/<(.+?)>([^\s])(.*?)<\/(\1)>/<$1> $2$3<\/$4>/) { };									  # ensure single space character before/after each tag
	while (s/<(.+?)>(.*?)([^\s])<\/(\1)>/<$1>$2$3 <\/$4>/) { };
	while (s/<(.+?)>(.+?)<\/(\1)>(|[^\s])*<(.+?)>(.+?)<\/(\5)>/<$1>$2<\/$3> <$5>$6<\/$7>/) { }; 
	s/^.*?<(.*)>.*$/<$1>/; 																		  # delete characters before/after first/last tag
	
	my $cleaned_text = &filterReferences( $_ );
	
	return $cleaned_text;
}


sub filterReferences
{
	( $_ ) = @_;
	
	my $cleaned_text = Trainer::BBL2UTF8::Convert( $_ );

	$cleaned_text =~ s/{(.+?)}/$1/g;
	$cleaned_text =~ s/~/ /g;
	$cleaned_text =~ s/--/-/g;
	
	while ($cleaned_text =~ s/(\p{L})\.(\p{isUpper})/$1. $2/g) { }		# Rule 1) (Rules acccording to Tr2Crfpp::PrepData)
	$cleaned_text =~ s/([\p{L}\.;]) ?\/ ?([\p{L}\.;])/$1 \/ $2/g; 		# Rule 2)
	while ($cleaned_text =~ s/:([^\s])/: $1/g) { }						# Rule 3)
	while ($cleaned_text =~ s/([^\s])([({])/$1 $2/g) { }				# Rule 4)
	
	return $cleaned_text;
}

1;
