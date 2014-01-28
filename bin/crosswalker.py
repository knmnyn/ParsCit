#!/usr/bin/env python

from lxml import etree
from lxml.etree import Element
from lxml.etree import ElementTree

# TODO main function to handle command line args


def crosswalk(doc):
    """
    This space is for documenting the properties of the two formats (pdfx and
    omnipage).

    Omnipage :
        - every page has a description header

    Pdfx :
        - every page has a single 'layer' tag under which are all the 'word'
        tags.

    Temporary Space :

    Simplified xml :
    Not Considering the following:
        - attributes of 'page' tag
        - 'font' and 'edges' of word tag
        - 'layer' tag under each 'page' tag
    """
    # Hopefully an xml file in pdfx format
    # TODO Use StringIO to handle the file if passed as a string
    # TODO working on a simplified xml for now. Will have to change once done
    pdfxdoc = etree.parse(doc)
    pdf2xml = pdfxdoc.getroot()

    # initialize Onmipage Type xml
    omnidoc = Element('document', xmlns="http://www.scansoft.com/" +
                      "omnipage/xml/ssdoc-schema3.xsd",
                      xsi="http://www.w3.org/2001/XMLSchema-instance")
    omnixml = ElementTree(omnidoc)

    # Looping over all the pages from pdfx output
    for page in pdf2xml.iterchildren('page'):
        sec = etree.SubElement(omnidoc, 'section')
        col = etree.SubElement(sec, 'column')
        para = etree.SubElement(col, 'para')
        # line(ln) for omnipage has to be included
        for word in page.iterfind('.//word'):
            #height = word.get('height')
            width = word.get('width')
            top = word.get('top')
            left = word.get('left')
            baseline = word.get('baseline')
            wd = etree.SubElement(para, 'wd', l=left, r=left + width,
                                  t=top, b=baseline)
            wd.text = word.text
    print etree.tostring(omnixml, pretty_print=True)


if __name__ == '__main__':
    crosswalk('../demodata/P10-1024.xml')
