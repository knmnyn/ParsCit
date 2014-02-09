#!/usr/bin/env python

from lxml import etree
from lxml.etree import Element
from lxml.etree import ElementTree

# TODO main function to handle command line args

# Constants and Flags
# Space between lines
LSPACE = 5.0
# Space between paras
PSPACE = 15.0
# Space between sections
SECSPACE = 20.0
# Indent for new para
INDENT = 10.0
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
    # TODO Each page tag has a description and body tag which have to be added.
    # TODO The 'b' attr of the bottom right para and col are being missed.
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
    """
    The 'l', 't' attr of a line, para, column are set when the first line is
    encountered. This is done right in the beginning.
    The 'r' attribute is set when the first line ends and the next line is
    encountered. This is done all the way at the end of the function.
    The 'b' attr of para and column will be set only when a para or column end
    """
    # TODO:Section change has to be included.
    # TODO:Add overflow margin
    global first_line
    # if line doesnt have a 'b' attribute, then we are still on the first line
    if line.get('b') is None:
        #line.set('l', word.get('left'))
        #line.set('t', word.get('top'))
        #line.set('b', word.get('baseline'))
        #line.set('baseline', word.get('baseline'))
        setAttr(line, word, ['l', 't', 'b', 'baseline'],
                ['left', 'top', 'baseline', 'baseline'])
        para = line.getparent()
        setAttr(para, line, ['l', 't'])
        setAttr(para.getparent(), para, ['l', 't'])
        first_line = True
        return line
    # If the baseline attribute of the word is equal to the 'b' attribute of
    # the line, then the word most probably belongs to the same line.
    if abs(float(line.get('b')) - float(word.get('baseline'))) < LSPACE:
        return line
    else:
        # When new line is encountered
        newline = Element('ln', l=word.get('left'), t=word.get('top'),
                          b=word.get('baseline'),
                          baseline=word.get('baseline'))
        if newPara(line, newline) == 1:
            # When a new para is encountered, the 'b' attr of the previous para
            # has to be set.
            # using the left and right attributes of the column to set attr for
            # the new para. Cant rely on line as a line could be shorter.
            current_para = line.getparent()
            current_para.set('b', line.get('b'))
            newleft = current_para.getparent().get('l')
            newright = current_para.getparent().get('r')
            try:
                new_para = Element('para', l=newleft, t=newline.get('t'),
                                   r=newright)
            except Exception as e:
                print str(e)
                print etree.tostring(line)
                print etree.tostring(newline)
            current_para.addnext(new_para)
            new_para.append(newline)
        elif newPara(line, newline) == 2:
            # new column
            # When a new column is encountered, set the 'b' attr of the
            # previous para and column.
            # also, set first_line to true. Since the 'r' attr of the new line
            # is not set as of the point when the new para/col are encountered,
            # setting first_line will ensure that when this line ends, these
            # attributes get set.
            first_line = True
            current_para = line.getparent()
            current_para.set('b', line.get('b'))
            # Also, set the 'b' attr of the previous column
            current_col = current_para.getparent()
            current_col.set('b', current_para.get('b'))
            # Add a new column
            new_col = Element('column')
            setAttr(new_col, newline, ['l', 't'])
            current_col.addnext(new_col)
            # Add a new para to it and append the new line as well
            new_para = Element('para')
            setAttr(new_para, new_col, ['l', 't'])
            new_col.append(new_para)
            new_para.append(newline)
        else:
            line.addnext(newline)
        # The attribute 'r' of the previous line has not been assigned yet. Use
        # the 'r' attribute of the last word of that line for that.
        line.set('r', getLastChild(line, attr='r').get('r'))
        if first_line:
            para = line.getparent()
            column = para.getparent()
            para.set('r', line.get('r'))
            column.set('r', line.get('r'))
        return newline


def newPara(line1, line2):
    """
    Returns
    0 : When there is no change of paragraph
    1 : When there is a change of paragraph
    2 : When there is a change in the column
    """
    # TODO:Section change has to be included.
    # TODO:Better logic with multiple conditions
    # In fact there should be a confidence factor for each of the options and
    # the strongest confidence wins in the end to be returned.
    para1 = line1.getparent()
    newleft = line2.get('l')
    colleft = para1.getparent().get('l')
    diff = abs(float(newleft) - float(colleft))
    para_width = abs(float(para1.get('l')) - float(para1.get('l')))
    # The following will check the space between two paragraphs
    interline_diff = abs(float(line1.get('b')) - float(line2.get('t')))
    if interline_diff > PSPACE and interline_diff < SECSPACE:
        return 1
    # The following will check the indentation of a line to see if it should
    # belong to a new paragraph.
    elif diff > INDENT and diff < para_width:
        return 1
    elif diff > para_width:
        # New column encountered
        return 2
    else:
        return 0


def setAttr(totag, fromtag, to_attr=None, from_attr=None):
    # For now, I am using this to set the attributes for a parant from a child
    # tag and hence only the 'left' and 'top' can be set by default.
    # Specify the attributes as lists to_attr and from_attr for more
    # functionality.
    if to_attr is not None:
        if from_attr is not None:
            for tattr, fattr in zip(to_attr, from_attr):
                totag.set(tattr, fromtag.get(fattr))
        else:
            for attr in to_attr:
                totag.set(attr, fromtag.get(attr))
    else:
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
