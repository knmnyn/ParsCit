CONTENTS
[0] Directory structure
[1] Usage Note
	[1.1] SectLabel
	[1.2] GenericSect
[3] Known issues

==============================================================================
[0] Directory structure
* processOmniXML.pl: Process Omnipage XML output (concatenated results fromm all pages of a PDF file), and extract text lines together with other XML infos
* redo.sectLabel.pl: Perform stratified cross-validation for SectLabel
* tr2crfpp.pl: Generate SectLabel features for CRF++
* single2multi.pl: Convert SectLabel training file (e.g. doc/sectLabel.tagged.txt) from single- to multi-line format. This script is called by tr2crfpp.pl

* genericSectExtract.rb: 
* genericSect/

==============================================================================
[1] Usage note:

=======================================
[1.1] SectLabel
* Process Omnipage XML output
** Usage: processOmniXML.pl -h     [invokes help]
       processOmniXML.pl -in xmlFile -out outFile [-xmlFeature -decode -markup -para] [-tag tagFile -allowEmptyLine -log]
Options:
        -q      Quiet Mode (don't echo license)
        -xmlFeature: append XML feature together with text extracted
        -decode: decode HTML entities and then output, to avoid double entity encoding later
        -tag tagFile: count XML tags/values for statistics purpose
        -markup: add factor infos (bold, italic etc) per word using the format "word|||(b|nb)|||(i|ni)", useful to extract bold/italic phrases

* Perform stratified cross-validation
** Usage: redo.sectLabel.pl -h     [invokes help]
       redo.sectLabel.pl -in trainFile -dir outDir -n folds -c configFile [-p numCpus -iter numIter -f freqCutoff]
Options:
                -in: training file in the format as in doc/sectLabel.tagged.txt
                -dir: output directory, containing all intermediate files and outputs
                -n: num of cross validation folds
                -c: config file to extract features and automatically generate CRF++ template

                -p: CRF++ num of CPUs (deault = 6)
                -iter: CRF++ max iteration (default = 100)
                -f: CRF++ frequency cut-off (default = 3)

** E.g.:
./bin/sectLabel/redo.sectLabel.pl -in ./doc/sectLabel.tagged.txt -dir testRedoDir -n 10 -c ./resources/sectLabel/sectLabel.configXml

* Extract features
** Usage: tr2crfpp.pl -h   [invokes help]
       tr2crfpp.pl -in inFile -c configFile -out outFile [-template -single]
Options:
        -q      Quiet Mode (don't echo license)
        -in inFile: labeled input file
        -c configFile: to specify which feature set to use.
        -out outFile: output file for CRF++ training.
        -template: to output a template used by CRF++ according to the config file.
        -single: indicate that each input document is in single-line format (e.g., doc/sectLabel.tagged.txt)

=======================================
[1.2] GenericSect

==============================================================================
[3] Known issues

