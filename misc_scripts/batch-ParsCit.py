#!/usr/bin/env python
import re
import os
import subprocess
import logging

## Ankur - 30/05/2014
# This script can be used to run ParsCit in batch mode.
# Just change the path of 'cachedir' to the root of the dir structure
# containing scientific articles and this script will look for pdfs in all sub
# directories and try to run ParsCit over them.
# Please note that there is no need to preprocess the pdf file. This version of
# ParsCit has inbuilt pdfx functionality (only on 32-bit machines though).

cachedir = '/home/ankur/devbench/workrelated/work/'
parscit = '/home/ankur/devbench/workrelated/ParsCit/bin/citeExtract.pl'


# Establish Logging
logger = logging.getLogger('BatchParscit')
logger.setLevel(logging.INFO)

# create a file handler
fhandler = logging.FileHandler('batchParscit.log')
fhandler.setLevel(logging.INFO)

# create a stream handler
chandler = logging.StreamHandler()
chandler.setLevel(logging.ERROR)

# create a logging format
formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
fhandler.setFormatter(formatter)
chandler.setFormatter(formatter)

# add the handlers to the logger
logger.addHandler(fhandler)
logger.addHandler(chandler)

for dirName, subdirList, fileList in os.walk(cachedir):
    for fname in fileList:
        reg = re.match(r'(.+).pdf', fname)
        if reg is not None:
            infile = os.path.join(dirName, fname)
            outfile = os.path.join(dirName,
                                   reg.group(1) + '-parscit-section.xml')
            p = subprocess.Popen([parscit, '-m', 'extract_all', '-i', 'pdf',
                                  infile, outfile], stdout=subprocess.PIPE,
                                 stderr=subprocess.PIPE)
            stdout, stderr = p.communicate()
            logger.info("Processing " + fname)
            if stdout:
                logger.info(stdout)
            if stderr:
                logger.error(stderr)

print "Done"
