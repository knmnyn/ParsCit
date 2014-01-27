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
        sec = etree.SubElement(omnidoc, 'section')
        col = etree.SubElement(sec, 'column')
        para = etree.SubElement(col, 'para')
        for word in page.iterchildren('word'):
            height = word.get('height')
            width= word.get('width')
            top = word.get('top')
            left = word.get('left')
            baseline = word.get('baseline')
            wd = etree.SubElement(para, 'wd', l = left, r = left + width, t = top,
                        b = basline)
            wd.text = word.text
    print etree.tostring(omnidoc)


if __name__ == '__main__':
    crosswalk('../demodata/P10-1024.xml')
