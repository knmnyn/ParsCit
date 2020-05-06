package ParsCit::ConfigLang;

# MB1 (March 2016)

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
