#!/usr/bin/env python

from lxml import etree
from lxml.etree import Element
from lxml.etree import ElementTree

# TODO main function to handle command line args


def crosswalk(doc):
    # Hopefully an xml file in pdfx format
    # TODO Use StringIO to handle the file if passed as a string
    pdfxdoc = etree.parse(doc)
    pdf2xml = pdfxdoc.getroot()

    # initialize Onmipage Type xml
    omnidoc = Element('document', xmlns="http://www.scansoft.com/omnipage/xml/ssdoc-schema3.xsd",
                      xsi="http://www.w3.org/2001/XMLSchema-instance")
    omnixml = ElementTree(omnidoc)

    # Looping over all the pages from pdfx output
    for page in pdf2xml.iterchildren('page'):
        print page.tag


if __name__ == '__main__':
    crosswalk('../demodata/P10-1024.xml')
