README for sectLabel module (v100401)

CONTENTS
[0] Directory structure
[1] Command line Usage
	[1.1] SectLabel
	[1.2] GenericSect
[3] Known issues

------------------------------------------------------------
[0] DIRECTORY STRUCTURE

* processOmniXML.pl: Process Omnipage XML output (concatenated results
  fromm all pages of a PDF file), and extract text lines together with
  other XML infos
Note: the current script is complicated since it mixes 2 things: process Omnipage XML as well as extract XML features. We are planning to break into 2 scripts: 1) simplifyOmniXML.pl (Done!) -- to convert Omnipage into output into internal format, and 2) extractXMLFeatures.pl (TODO) -- to take input as the internal results produced by simplifyOmniXML.pl and generate XML features.

* redo.sectLabel.pl: Perform stratified cross-validation for SectLabel
* tr2crfpp.pl: Generate SectLabel features for CRF++
* single2multi.pl: Convert SectLabel training file
  (e.g. doc/sectLabel.tagged.txt) from single- to multi-line
  format. This script is called by tr2crfpp.pl
* genericSectExtract.rb: given a list of section headers of a
  scientific document in an input file, assign generic headers for the
  section headers.
* genericSect/

------------------------------------------------------------
[1] COMMAND LINE USAGE

------------------------------
[1.1] SectLabel
* Process Omnipage XML output

** Usage: processOmniXML.pl -h     [invokes help]
          processOmniXML.pl -in xmlFile -out outFile [-xmlFeature -decode -markup -para] [-tag tagFile -allowEmptyLine -log]
Options:
        -q      Quiet Mode (don't echo license)
        -xmlFeature: append XML feature together with text extracted
        -decode: decode HTML entities and then output, to avoid double
         entity encoding later
        -tag tagFile: count XML tags/values for statistics
        -markup: add factor infos (bold, italic etc) per word using
         the format "word|||(b|nb)|||(i|ni)", useful in extracting
         bold/italic phrases

* Perform stratified cross-validation

** Usage: redo.sectLabel.pl -h     [invokes help]
          redo.sectLabel.pl -in trainFile -dir outDir -n folds -c configFile [-p numCpus -iter numIter -f freqCutoff]

Options:

                -in: training file in the format as in
                 doc/sectLabel.tagged.txt
                -dir: output directory, containing all intermediate
                 files and outputs
                -n: num of cross validation folds
                -c: config file to extract features and automatically
                 generate CRF++ template

                -p: CRF++ num of CPUs (deault = 6)
                -iter: CRF++ max iteration (default = 100)
                -f: CRF++ frequency cut-off (default = 3)

** E.g.:
./bin/sectLabel/redo.sectLabel.pl -in ./doc/sectLabelXml.tagged.txt
-dir testRedoDir -n 10 -c ./resources/sectLabel/sectLabel.configXml

* Extract features

** Usage: tr2crfpp.pl -h   [invokes help]
          tr2crfpp.pl -in inFile -c configFile -out outFile [-template -single]

Options:
        -q      Quiet Mode (don't echo license)
        -in inFile: labeled input file
        -c configFile: to specify which feature set to use.
        -out outFile: output file for CRF++ training.
        -template: to output a template used by CRF++ according to the
         config file.
        -single: indicate that each input document is in single-line
         format (e.g., ./doc/sectLabel.tagged.txt)

------------------------------
[1.2] GenericSect
* Create feature file 

** Usage: ruby extractFeature.rb filePath
   filePath: path to the labeled data file which lists the actual
   section headers and their corressponding manually assigned generic
   section headers (if it exists)
   syntax: generic_header ||| actual_header

* Generate generic section headers for a document

** Usage: ruby genericSectExtract.rb filePath

   where filePath is a file which lists the actual headers of a
   document (automaticaly extracted by other module of SectLabel)

* Perform stratified cross-validation

** Usage: ruby crossValidation.rb dataFile numFold

   Note that data file has the format as in doc/genericSect.tagged.txt

------------------------------------------------------------
[3] KNOWN ISSUES

