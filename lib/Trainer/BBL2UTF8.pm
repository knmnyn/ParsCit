package Trainer::BBL2UTF8;

###
# To transform latex special characters to UTF-8.
#
# Copyright 2016 by Matthias Bösinger
###

use utf8;
use strict;

sub Convert
{
	( my $text ) = @_;
	
	$text =~ s/\\'{a}/á/g;
	$text =~ s/\\`{a}/à/g;
	$text =~ s/\\^{a}/â/g;
	$text =~ s/\\~{a}/ã/g;
	$text =~ s/\\"{a}/ä/g;
	$text =~ s/\\r{a}/å/g;
	$text =~ s/\\ae/æ/g;
	$text =~ s/\\'{A}/Á/g;
	$text =~ s/\\`{A}/À/g;
	$text =~ s/\\^{A}/Â/g;
	$text =~ s/\\~{A}/Ã/g;
	$text =~ s/\\"{A}/Ä/g;
	$text =~ s/\\r{A}/Å/g;
	$text =~ s/\\Ae/Æ/g;
	
	$text =~ s/\\'{e}/é/g;
	$text =~ s/\\`{e}/è/g;
	$text =~ s/\\^{e}/ê/g;
	$text =~ s/\\"{e}/ë/g;
	$text =~ s/\\'{E}/É/g;
	$text =~ s/\\`{E}/È/g;
	$text =~ s/\\^{E}/Ê/g;
	$text =~ s/\\"{E}/Ë/g;
	
	$text =~ s/\\'{i}/í/g;
	$text =~ s/\\`{i}/ì/g;
	$text =~ s/\\^{i}/î/g;
	$text =~ s/\\"{i}/ï/g;
	$text =~ s/\\'{I}/Í/g;
	$text =~ s/\\`{I}/Ì/g;
	$text =~ s/\\^{I}/Î/g;
	$text =~ s/\\"{I}/Ï/g;

	$text =~ s/\\'{o}/ó/g;
	$text =~ s/\\`{o}/ò/g;
	$text =~ s/\\^{o}/ô/g;
	$text =~ s/\\~{o}/õ/g;
	$text =~ s/\\"{o}/ö/g;
	$text =~ s/\\o/ø/g;
	$text =~ s/\\'{O}/Ó/g;
	$text =~ s/\\`{O}/Ò/g;
	$text =~ s/\\^{O}/Ô/g;
	$text =~ s/\\~{O}/Õ/g;
	$text =~ s/\\"{O}/Ö/g;
	$text =~ s/\\O/Ø/g;
	
	$text =~ s/\\'{u}/ú/g;
	$text =~ s/\\`{u}/ù/g;
	$text =~ s/\\^{u}/û/g;
	$text =~ s/\\"{u}/ü/g;
	$text =~ s/\\'{U}/Ú/g;
	$text =~ s/\\`{U}/Ù/g;
	$text =~ s/\\^{U}/Û/g;
	$text =~ s/\\"{U}/Ü/g;
	
	$text =~ s/\\c{c}/ç/g;
	$text =~ s/\\k{a}/ą/g;
	$text =~ s/\\ss/ß/g;
	
	$text =~ s/\\_/_/g;
	$text =~ s/\\underline/_/g;
	$text =~ s/\\backslash/\\/g;
	$text =~ s/\\textbackslash/\\/g;
	$text =~ s/\\lbrack/[/g;
	$text =~ s/\\rbrack/]/g;
	$text =~ s/\\langle/</g;
	$text =~ s/\\rangle/>/g;
	$text =~ s/\\\$/\$/g;
	$text =~ s/\\&/&/g;
	$text =~ s/\\#/#/g;
	$text =~ s/\\%/%/g;
	$text =~ s/\\textasciitilde/~/g;
	
	
	return $text;
}

1;
