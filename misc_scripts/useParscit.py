#!/usr/bin/env python
import re
import os
import subprocess
import logging

## Ankur
# This script is used to run ParsCit/SectLabel on each crosswalked (xml file
# resembling Omnipage output) found in the cache dir structure as created
# using the script processCorpus.py.

cachedir = '/mnt/compute/ankur/cache/'
parscit = '/mnt/raid/homes/ankur/devbench/workrelated/ParsCit/bin/citeExtract.pl'


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

tot = 0
for dirName, subdirList, fileList in os.walk(cachedir):
    for fname in fileList:
        reg = re.match(r'(.+)-pdfx-omni.xml', fname)
        if reg is not None:
            tot += 1

num = 0
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
            logger.info("Processing " + fname + " " + str(num + 1) + "/" + str(tot))
            if stdout:
                logger.info(stdout)
            if stderr:
                if re.search(r'Die in SectLabel::PreProcess::findHeaderText', stderr) is None:
                    print num
                    logger.error(stderr)
            num += 1

print "Done"
