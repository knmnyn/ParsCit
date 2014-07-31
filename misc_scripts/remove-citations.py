#!/usr/bin/env python

import os
import HTMLParser
from lxml import etree

inputdir = "/home/ankur/devbench/pdfx/proc/"


def remove_citations(infile):
    try:
        inxml = etree.parse(infile)
        algorithms = inxml.getroot()
        parscit = algorithms.find("./algorithm[@name='ParsCit']")
        parscit.getparent().remove(parscit)
        fname, ext = os.path.splitext(infile)
        newname = fname + "-new" + ext
        h = HTMLParser.HTMLParser()
        with open(newname, 'w') as ofile:
            ofile.write('<?xml version="1.0" encoding="UTF-8"?>')
            ofile.write(h.unescape(etree.tostring(algorithms)).encode('utf-8'))
    except Exception as e:
        print infile
        print str(e)


for dirname, subdirList, fileList in os.walk(inputdir):
    for fname in fileList:
        if fname.endswith("section.xml"):
            remove_citations(os.path.join(dirname, fname))
