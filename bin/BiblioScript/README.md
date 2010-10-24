BiblioScript
============

## Dependencies ##
(For the installation of dependencies see project's websites)

* BibUtils: v. 4.8 <http://www.scripps.edu/~cdputnam/software/bibutils/>
* ParsCit: v. 100401d <http://aye.comp.nus.edu.sg/parsCit/>
* Saxon He 9.2.1.2 <http://saxon.sourceforge.net/#F9.2HE>

## Installation ##

Once cloned the git repo just change the path to executables in file biblio_script.sh accordingly to the local settings:

	# paths to executables 
	PARSCIT_PATH="/Applications/ParsCit/bin/"
	BIBUTILS_PATH="/Applications/bibutils_4.8/"
	SAXON_PATH="/Applications/saxonhe9-2-1-2j/saxon9he.jar"

## Usage ##

You can try out the script using the provieded input_sample.txt file:
	./biblio_script.sh <inputFile> <outDir>
	
## Caveat ##
The degree of accuracy of the resulting .bib file is depending (and it might vary from version to version) on the ParsCit engine used to parse the unstructured (plain text) bibliography.