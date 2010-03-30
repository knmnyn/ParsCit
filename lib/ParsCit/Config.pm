package ParsCit::Config;

## Global

$algorithmName = "ParsCit";
$algorithmVersion = "090625";

## Repository Mappings

%repositories = ('rep1' => '/repositories/rep1',
                 'example1' => '/',
		 'example2' => '/home',
		 );

## WS settings
$serverURL = '130.203.133.46';
$serverPort = 10555;
$URI = 'http://citeseerx.org/algorithms/parscit/wsdl';

## Tr2crfpp
## Paths relative to ParsCit root dir ($FindBin::Bin/..)
$tmpDir = "tmp";
$dictFile = "resources/parsCitDict.txt";
$crf_test = "crfpp/crf_test";
$modelFile = "resources/parsCit.model";

## Citation Context
$contextRadius = 200;
$maxContexts = 5;

## Write citation and body file components
$bWriteSplit = 1;

1;
