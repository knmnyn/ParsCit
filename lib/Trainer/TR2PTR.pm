package Trainer::TR2PTR;

###
# To transform BibTeX entries to list of tagged references.
# Using styles defined in ConfigTrainer.pm
#
# Copyright 2016 Matthias Bösinger 25.04.2016
###

use 5.010;
use strict;

binmode STDIN, ":encoding(UTF-8)";
binmode STDOUT, ":encoding(UTF-8)";

sub CreateRefList
{
	( my $file_name ) = @_;
	
	open IF, "<:utf8", $file_name or die "Couldn't open bibliography file: $file_name\n";
	
	my %tagged_references = ();
	my %plain_references = ();
	my $tagged_reference, my $plain_reference, my $check_reference;
	my $key;
	my $counter = 1;

	while (<IF>) 
	{
		chomp();
		if (/^\s*$/) {
			next;
		}
		
		while (s/<(.+?)>(.+?)<\/(\1)>([^<>]+?)<(.+?)>(.+?)<\/(\5)>/<$1>$2$4<\/$3><$5>$6<\/$7>/g) { }  # reset tags so that no text is in between two tags
		while (s/<(.+?)>([^\s])(.*?)<\/(\1)>/<$1> $2$3<\/$4>/) { };									  # ensure single space character before/after each tag
		while (s/<(.+?)>(.*?)([^\s])<\/(\1)>/<$1>$2$3 <\/$4>/) { };
		while (s/<(.+?)>(.+?)<\/(\1)>(|[^\s])*<(.+?)>(.+?)<\/(\5)>/<$1>$2<\/$3> <$5>$6<\/$7>/) { }; 
		s/^.*?<(.*)>.*$/<$1>/; 																		  # delete characters before/after first/last tag
		while (s/(\p{L})\.(\p{isUpper})/$1. $2/g) { }												  # Rule 1) (Rules acccording to Tr2Crfpp::PrepData)
		s/([\p{L}\.;]) ?\/ ?([\p{L}\.;])/$1 \/ $2/g; 												  # Rule 2)
		while (s/:([^\s])/: $1/g) { }																  # Rule 3)
		while (s/([^\s])([({])/$1 $2/g) { }															  # Rule 4)

		$tagged_reference 	= $_;
		s/<(.+?)>(.+?)<\/(\1)>/$2/g;
		$check_reference 	= $_;
		s/\s+/ /g;
		$plain_reference 	= $_;
		
		if ( !( $tagged_reference eq $check_reference ) ) {
			$key = sprintf "#%d", $counter;
			$tagged_references{ $key } = $tagged_reference;
			$plain_references{ $key } = $plain_reference;	
		}
		
		$counter++;
	}
	close IF;
	
	my @result = ();
	$result[0] = \%tagged_references;
	$result[1] = \%plain_references;
	return @result;	
}

1;
