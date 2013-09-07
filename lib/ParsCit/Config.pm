package ParsCit::Config;

## Global
$algorithmName		= "ParsCit";
$algorithmVersion	= "110505";

## Repository Mappings
%repositories	= (	'rep1'		=> '/repositories/rep1',
                 	'example1'	=> '/',
		 		 	'example2'	=> '/home');

## WS settings
$serverURL	= '130.203.133.46';
$serverPort	= 10555;
$URI		= 'http://citeseerx.org/algorithms/parscit/wsdl';

## Tr2crfpp
## Paths relative to ParsCit root dir ($FindBin::Bin/..)
$tmpDir		= "tmp";
$dictFile	= "resources/parsCitDict.txt";
$crf_test	= "crfpp/crf_test";

## Tr2crfpp parscit model
$modelFile		= "resources/parsCit.model";
## Tr2crfpp parscit split reference model
$splitModelFile	= "resources/parsCit.split.model";

## Citation Context
$contextRadius	= 600;
$maxContexts	= 10;

## Write citation and body file components
$bWriteSplit	= 1;

1;
