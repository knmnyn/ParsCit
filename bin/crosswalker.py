#!/usr/bin/env python

from lxml import etree
from lxml.etree import Element
from lxml.etree import ElementTree

# TODO main function to handle command line args

# Constants and Flags
# Space between lines
LSPACE = 5.0
# Space between paras
PSPACE = 20.0
# Flag for first line in the para
first_line = False


def crosswalk(doc):
    """
    This space is for documenting the properties of the two formats (pdfx and
    omnipage).

    Omnipage :
        - every page has a description header
        - 'dd' tag is used for page number as well
        - there seems to be a 'space' tag after every word.
        - 'ln' tag has a 'baseline' attribute which has been captured by
        Omnilib but is not being used apparently. This baseline seems to
        represent the base of the entire line (excluding extensions) whereas,
        in Pdfx, the baseline includes the extensions.

    Pdfx :
        - every page has a single 'layer' tag under which are all the 'word'
        tags.

    Temporary Space :

    Assumptions :
        1. Interline spacing within a para : 12.0 (approx)
        2. A para is demarcated when either the spacing between two lines is
        greater than 20 or if the first word of a line is not aligned with the
        rest of the lines. Look at getCurrentLine() for the logic

    Things not accounting for in Omnixml:
        - 'ln' attributes apart from dimensions

    Simplified xml :
    Not Considering the following:
        - attributes of 'page' tag
        - 'font' and 'edges' of word tag
        - 'layer' tag under each 'page' tag
    """
    # Hopefully an xml file in pdfx format
    # Use StringIO to handle the file if passed as a string
    # Working on a simplified xml for now. Will have to change once done
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
        line = etree.SubElement(para, 'ln')
        for word in page.iterfind('.//word'):
            line = getCurrentLine(line, word)
            addWord(line, word)
    print etree.tostring(omnixml, pretty_print=True)


def getCurrentLine(line, word):
    global first_line
    if line.get('b') is None:
        line.set('l', word.get('left'))
        line.set('t', word.get('top'))
        line.set('b', word.get('baseline'))
        line.set('baseline', word.get('baseline'))
        para = line.getparent()
        setnew(para, line)
        setnew(para.getparent(), para)
        first_line = True
        return line
    if abs(float(line.get('b')) - float(word.get('baseline'))) < LSPACE:
        return line
    else:
        # When new line is encountered
        # TODO check for column
        # TODO still havent looked at chenge of column
        newline = Element('ln', l=word.get('left'), t=word.get('top'),
                          b=word.get('baseline'),
                          baseline=word.get('baseline'))
        if newPara(line, newline):
            current_para = line.getparent()
            current_para.set('b', line.get('b'))
            newleft = current_para.getparent().get('l')
            newright = current_para.getparent().get('r')
            new_para = Element('para', l=newleft, t=newline.get('t'),
                               r=newright)
            current_para.addnext(new_para)
            new_para.append(newline)
        else:
            line.addnext(newline)
        line.set('r', getLastChild(line, attr='r').get('r'))
        if first_line:
            para = line.getparent()
            column = para.getparent()
            para.set('r', line.get('r'))
            column.set('r', line.get('r'))
        return newline


def newPara(line1, line2):
    newleft = line2.get('l')
    # will have to see what happens when the column is changed
    colleft = line1.getparent().getparent().get('l')
    if abs(float(line1.get('b')) - float(line2.get('t'))) > 20:
        return True
    elif abs(float(newleft) - float(colleft)) > 100:
        return True
    else:
        return False


def setnew(totag, fromtag):
    totag.set('l', fromtag.get('l'))
    totag.set('t', fromtag.get('t'))


def getLastChild(tag, attr=None, cond=None):
    """
    This will return the last child for which the given attribute exists or
    the given condition satifies. Condition has to be a function. If both are
    specified, it will return the lattermost child that satisfies either of
    the conditions. Condition should be a function that takes the tag and the
    child as its first and second arguments respectively and return a boolean
    value.
    """
    for child in reversed(list(tag)):
        if attr is not None and child.get(attr) is not None:
            return child
        if cond is not None and cond(tag, child):
            return child


def addWord(parent, word, space=True):
    #general space element
    ele_space = Element('space')
    #height = str(word.get('height')
    width = str(word.get('width'))
    top = str(word.get('top'))
    left = str(word.get('left'))
    baseline = str(word.get('baseline'))
    right = str(float(left) + float(width))
    wd = etree.SubElement(parent, 'wd', l=left, r=right,
                          t=top, b=baseline)
    wd.text = word.text
    if space:
        wd.addnext(ele_space)


if __name__ == '__main__':
    crosswalk('../demodata/temp-pdfx-simp.xml')
