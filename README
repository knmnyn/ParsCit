ParsCit README

This software is copyrighted 2008, 2009, 2010, 2011 by Min-Yen Kan,
Isaac G. Councill, C. Lee Giles, Minh-Thang Luong and Huy Nhat Hoang
Do.  This program and all its source code is distributed are under the
terms of the GNU General Public License (or the Lesser GPL).

    ParsCit is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    ParsCit is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with ParsCit.  If not, see
    <http://www.gnu.org/licenses/>.

See INSTALL.txt and USAGE.txt for more information.
CHANGELOG.txt for updates on code and model changes.
Also see doc/index.html for the web page describing this project.

----------------------------------------------------------------------
This software has been developed together at IST at Penn State
University and at the National University of Singapore (NUS).

Current development (from 2008 onwards) has been done at NUS only.
The newer version of files are supported only through the newer
scripts written at NUS.

SectLabel has been developed at NUS (2010) to retrieve logical
structure of scientific documents. For further information, please
refer to the webpage description and TroubleShooting section.

----------------------------------------------------------------------
Files:

bin/	- Binaries / scripts for running ParsCit
   /archtest.pl		- Used by IST installation
   /citeExtract.pl 	- Script for running the whole pipeline from a text/XML file 
			  (logical structure parsing, body/references segmentation, reference string parsing)
   /parsecit-client.pl	- Original perl web service client (tested at IST)
   /parsecit-server.pl	- Original perl web service server (tested at IST)
   /ParsCitClient.rb	- Ruby web service client for the parsCit/parsHed modules (tested at NUS)
   /ParsCitClientWSDL.rb - Ruby web service client for parsCit/parsHed modules via WSDL (tested at NUS)
   /ParsCitServer.rb	- Ruby web service server for the parsCit/parsHed modules (tested at NUS)
   /redo.parsCit.pl	- Cross Validation training script and training notes 
			  (at end of script) for ParsCit

   /headExtract.pl	- Script for running header structure parsing.  
   /parsHed/redo.parsHed.pl	- Cross Validation training script and 
				  training notes (at end of script) for ParsHed

   /sectExtract.pl	- Script for running sectLabeler module for logical structure parsing.
   /sectLabel/README.txt	- Detailed descriptions of SectLabel scripts, including GenericSect ones
   /sectLabel/redo.sectLabel.pl	- Cross Validation training script and 
				  training notes (at end of script) for SectLabel 

  /BiblioScript         - Include BiblioScript and BibUtils codes # Thang v100901
CHANGELOG.TXT	- Changes between versions of the code.
crfpp/		- The CRF++ machine learning package used within ParsCit
     /traindata	- Sample training data for the CRF++ code of ParsCit,
                  ParsHed, and SectLabel 
demodata/	- Test data for sanity checking outputs
doc/		- The CGI base installation and documentation (scientific 
                  publications) about ParsCit	
INSTALL.TXT	- installation and basic instructions

lib
   /ParsCit	- perl libraries for ParsCit 
   /ParsHed	- perl libraries for ParsHed 
   /SectLabel	- perl libraries for SectLabel
   /cgiLog.txt	- CGI log for running web interface (nb, different than web 
                  service interface)
README.TXT	- this file
resources/	- dictionary files and CRF++ trained models
         /parsCitDict.txt - dictionary file shared by ParsCit and ParsHed
         /parsCit.model - default model used by ParsCit

         /parsHed/parsHed.model - default model used by ParsHed (trained at line level)
         /parsHed/keywords - most frequent keywords
         /parsHed/bigram - most frequent bigrams
         /parsHed/archive/parsHed.model - old model (trained at token level)

         /sectLabel/sectLabel.model - default model used by SectLabel for plain text input
         /sectLabel/sectLabel.modelXml - default model used by SectLabel for XML input
         /sectLabel/genericSect.model - default model used by GenericSect
         /sectLabel/funcword - English function word list

tmp/		- guess! :-)
USAGE.TXT	- Usage files for the citeExtract and web service interface 
wsdl/		- Web service description language file 
    /parscit.wsdl - WSDL file from describing the ParsCit service from NUS (newer version)
    /ParsCit.wsdl - WSDL file describing the ParsCit service from IST (older version)
