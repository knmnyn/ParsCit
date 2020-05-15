package ParsCit::ConfigLang;

################
# Written By Matthias Bösinger (29.03.2016)
# 
# Modul is used to set language specific data fields.
# Call of 'Init' with language type passed as parameter, will cause the initialization of the gloabl data fields.
# hasEditor: Regex used in feature determination to decide if a reference contains editor tokens.
# authorSplit: Regex used to split contiguous as author tags labeled tokens, into several author-names.
# authorDelete: Regex used to delete parts of an as author tag labeled token.
# inMarker: not in use in this version -> could be used for additional feature that marks a collective volume in the reference string
################

use utf8;

## Global
$hasEditorRegex = '';
$authorSplitRegex = '';
$authorDeleteRegex = '';
$inMarker = '';

## Language specific data
my %enData = ( 	'editor' => '[^A-Za-z](ed\.?|editor|editors|eds\.?)',
				'author' => '^(&|/|and|a\.)$',
				'delete' => 'et\.? al\.?.*$',
				'in' 	 => 'in' );

my %deData = ( 	'editor' => '[^A-Za-z](Hrsg\.?|Herausgeber|Hg\.?|hgg\.?)',
				'author' => '^(&|/|und|u\.)$',
				'delete' => '(u\.a\..*|et\.? al\.?.*)$',
				'in' 	 => 'in' );


## initialization methods
sub Init {
	my ($lang) = @_;
	
	if ($lang eq "en") {
		initData(%enData);
	}
	elsif ($lang eq "de") {
		initData(%deData);
	}
	#additional languages might be included here - MB
	else {
		return 0;
	}
	
	1;
}


sub initData {
	my (%data) = @_;
	
	$hasEditorRegex = $data{'editor'};
	$authorSplitRegex = $data{'author'};
	$authorDeleteRegex = $data{'delete'};
	$inMarker = $data{'in'};
	
}

1;
