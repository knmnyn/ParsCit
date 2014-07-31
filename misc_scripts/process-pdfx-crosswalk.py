#!/usr/bin/env python
import subprocess
import logging
import os
import string
import hashlib

## Ankur
# This script will take dir structure (containing only pdf files) and for each
# pdf file found, it will run 1) Pdfx on the pdf file and then 2) crosswalker
# on the output of the pdfx xml.
# The root of the dir structure can be defined below with the variable
# pdfdir.
# This script was created becasue the binaries for pdfx that have been procured
# from Alex of U. of Manchester are for 32-bit machines. Hence, to run
# Pdfx-ParsCit over the entire ACL meant dividing the pipeline between the
# available 32-bit machine and the 64-bit WING server.
# For running everything together (on a 32-bit machine) use batch-ParsCit.py

BLKSIZE = 8196

pdfdir = '/home/ankur/devbench/pdfx/pdfs/'
crosswalk = '/home/ankur/devbench/pdfx/crosswalker.py'
pdf2xml = '/home/ankur/devbench/pdfx/pdf2xml/pdf2xml'

letters = string.uppercase


def getMd5Hash(fname):
    hasher = hashlib.md5()
    with open(fname, 'rb') as file:
        buf = file.read(BLKSIZE)
        while len(buf) > 0:
            hasher.update(buf)
            buf = file.read(BLKSIZE)
    return hasher.hexdigest()


# Establish Logging
logger = logging.getLogger('ProcessingCorpus')
logger.setLevel(logging.INFO)

# create a file handler
fhandler = logging.FileHandler('processingCorpus.log')
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


total_files = 0
processed_files = 0
for dirName, subdirList, fileList in os.walk(pdfdir):
    for fname in fileList:
        total_files += 1
        file = os.path.join(dirName, fname)

        # Pdfx Outfile name
        pfile, exten = os.path.splitext(fname)
        pfilename = pfile + '-pdfx.xml'
        pdfxfile = dirName + '/' + pfilename
        p = subprocess.Popen([pdf2xml, file],
                             stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE)
        stdout, stderr = p.communicate()
        if stderr:
            logger.error("At pdfx conversion for " + fname)
            logger.error(stderr)
            continue
        else:
            logger.info('Conversion using pdfx done for ' + fname)

        # Crosswalk
        p = subprocess.Popen([crosswalk, pdfxfile],
                             stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE)
        stdout, stderr = p.communicate()
        if stderr:
            logger.error("At crosswalk conversion for " + fname)
            logger.error(stderr)
            continue
        else:
            logger.info('Crosswalk done for ' + fname)

        # Increase processed file counter
        processed_files += 1

logger.info("Total Files : {:d}".format(total_files))
logger.info("Processed Files : {:d}".format(processed_files))
