#!/usr/bin/env python
import subprocess
import logging
import os
import re
import string
import hashlib

BLKSIZE = 8196

pdfdir = '/home/ankur/devbench/workrelated/public_html/'
cachedir = '/home/ankur/devbench/workrelated/cache/'
crosswalk = '/home/ankur/devbench/workrelated/ParsCit/bin/crosswalker.py'
pdf2xml = '/home/ankur/devbench/workrelated/pdfx/pdf2xml/pdf2xml'

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


total_files = {}
processed_files = {}
for letter in letters:
    curdir = pdfdir + letter
    if os.path.isdir(curdir):
        total_files[letter] = 0
        processed_files[letter] = 0
        for dirName, subdirList, fileList in os.walk(curdir):
            for fname in fileList:
                total_files[letter] += 1
                file = os.path.join(dirName, fname)

                # Create MD5 checksum
                # It could be simply computed but to consume less memory,
                # it is better to not read the whole file at one go.
                #md5hash = hashlib.md5(open(file, 'rb').read()).hexdigest()
                md5hash = getMd5Hash(file)

                # Create directory for caching
                dirpath = cachedir + '/'.join(re.findall(r'....', md5hash))
                if not os.path.exists(dirpath):
                    os.makedirs(dirpath)

                # Pdfx Outfile name
                pfile, exten = os.path.splitext(fname)
                pfilename = pfile + '-pdfx.xml'
                pdfxfile = dirpath + '/' + pfilename
                p = subprocess.Popen([pdf2xml, file, pdfxfile],
                                     stdout=subprocess.PIPE,
                                     stderr=subprocess.PIPE)
                stdout, stderr = p.communicate()
                if stderr:
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
                    logger.error(stderr)
                    continue
                else:
                    logger.info('Crosswalk done for ' + fname)

                # Increase processed file counter
                processed_files[letter] += 1

logger.info("Total Files : {:d}".format(reduce(lambda x, y: x + y,
                                               total_files.values())))
logger.info("Processed Files : {:d}".format(reduce(lambda x, y: x + y,
                                                   processed_files.values())))
logger.info("Breakup :\n\t{0}\n\t{1}".format(total_files, processed_files))
