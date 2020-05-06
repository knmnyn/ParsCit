package ParsHed::Config;

use ParsCit;

$algorithmName		= "ParsHed";
$algorithmVersion	= "110505";

## Tr2crfpp
## Paths relative to ParsCit root dir ($FindBin::Bin/..)
$tmpDir			= "tmp";
$dictFile		= ParsCit->_resource_path("resources/parsCitDict.txt");
$keywordFile	= ParsCit->_resource_path("resources/parsHed/keywords");
$bigramFile		= ParsCit->_resource_path("resources/parsHed/bigram");

$crf_test = $ENV{'CRFPP_HOME'} ? "$ENV{'CRFPP_HOME'}/bin/crf_test" : "crfpp/crf_test";

$modelFile		= ParsCit->_resource_path("resources/parsHed/parsHed.model");
$oldModelFile	= ParsCit->_resource_path("resources/parsHed/archive/parsHed.090316.model");

# Flags for different types of CRF features for line-level training
$isFullFormToken	= 1;
$isFirstToken  		= 1;
$isLastToken  		= 1;
$isSecondToken  	= 1;
$isSecondLastToken	= 1;
$isBack1 			= 1;
$isForw1 			= 1;
$isKeyword  		= 1;
$isBigram 			= 0;

# List of tags trained in parsHed
# Those with value 0 do not have frequent keyword features
%hash = (	'abstract'    => 1,
	 		'address'     => 1 ,
	 		'affiliation' => 1,
	 		'author'      => 0, #
	 		'date'        => 0, #
	 		'degree'      => 1,
	 		'email'       => 0, #
	 		'intro'       => 1,
	 		'keyword'     => 1,
	 		'note'        => 1,
	 		'page'        => 1,
	 		'phone'       => 0, #
	 		'pubnum'      => 1,
	 		'title'       => 1,
	 		'web'         => 0	);
$tags = \%hash;

1;
