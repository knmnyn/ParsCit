#!/usr/bin/env python
import re
import os
import subprocess
import logging

## Ankur
# This script is used to run ParsCit/SectLabel on each crosswalked (Omnipage
# output resembling xml file) found in the cache dir structure as created
# using the script processCorpus.py.

cachedir = '/home/ankur/devbench/workrelated/cache/'
parscit = '/home/ankur/devbench/workrelated/ParsCit/bin/citeExtract.pl'


# Establish Logging
logger = logging.getLogger('UsingParscit')
logger.setLevel(logging.INFO)

# create a file handler
fhandler = logging.FileHandler('usingParscit.log')
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
        reg = re.match(r'(.+)-pdfx-omni.xml', fname)
        if reg is not None:
            infile = os.path.join(dirName, fname)
            outfile = os.path.join(dirName,
                                   reg.group(1) + '-parscit-section.xml')
            p = subprocess.Popen([parscit, '-m', 'extract_all', '-i', 'xml',
                                  infile, outfile], stdout=subprocess.PIPE,
                                 stderr=subprocess.PIPE)
            stdout, stderr = p.communicate()
            logger.info("Processing " + fname)
            if stdout:
                logger.info(stdout)
            if stderr:
                logger.error(stderr)

print "Done"
