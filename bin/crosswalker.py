#!/usr/bin/env python

import re
import os
import argparse
from lxml import etree
from lxml.etree import Element
from lxml.etree import ElementTree

# TODO main function to handle command line args

# Constants and Flags
# Space between lines
LSPACE = 5.0
# Space between paras
PSPACE = 13.0  # Changes : 15.0, 14.0,
# Space between sections
SECSPACE = 20.0
# Indent for new para
INDENT = 10.0
# Flag for first line in the para
first_line = False
# Flag for indent on the first line of the para
para_indent = False
# List of font tags given in the beginning of each pdfx xml
FONTS = {}
# Flag for Debugging
DEBUG = False


def crosswalk(doc, outfile=None):
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
        - there is no way to know if a word is in sub/super-script or not. pdfx
        only gives the difference in font size.

    Temporary Space :
        1. The 'font' attribute in a wd tag is removed after processing each
        line for font attributes in the function checkForRuns().

    Assumptions :
        1. A para is demarcated when either the spacing between two lines is
        greater than 20 or if the first word of a line is not aligned with the
        rest of the lines. Look at getCurrentLine() for the logic

    Things not accounting for in Omnixml:
        - 'ln' attributes apart from dimensions

    Simplified xml :
    Not Considering the following:
        - attributes of 'page' tag
        - 'edges' of word tag
        - 'layer' tag under each 'page' tag
    """
    # Hopefully an xml file in pdfx format
    # Use StringIO to handle the file if passed as a string
    pdfxdoc = etree.parse(doc)
    pdf2xml = pdfxdoc.getroot()
    # initialize Onmipage Type xml
    omnidoc = Element('document', xmlns="http://www.scansoft.com/" +
                      "omnipage/xml/ssdoc-schema3.xsd",
                      xsi="http://www.w3.org/2001/XMLSchema-instance")
    omnixml = ElementTree(omnidoc)
    # Collect all fonts in the global dictionary before continuing
    for font in pdf2xml.iterchildren('fontspec'):
        FONTS[font.get('id')] = font
    # Looping over all the pages from pdfx output
    for page in pdf2xml.iterchildren('page'):
        if len(page) == 0:
            continue
        # As it turns out, there can be just an image tag within a page.
        elif len(page.findall('.//word')) == 0:
            continue
        omnipage = etree.SubElement(omnidoc, 'page')
        descrip = etree.SubElement(omnipage, 'description')
        descrip.append(Element('description', file=doc))
        body = etree.SubElement(omnipage, 'body')
        sec = etree.SubElement(body, 'section')
        col = etree.SubElement(sec, 'column')
        para = etree.SubElement(col, 'para', alignment='justified',
                                language='en')
        line = etree.SubElement(para, 'ln')
        for word in page.iterfind('.//word'):
            line = getCurrentLine(line, word)
            addWord(line, word)
        finalTouches(word, line, para, sec)
        processPageNum(omnipage)
    # Copy the generated xml into a new file
    if outfile is None:
        file, exten = os.path.splitext(doc)
        newfile = file + '-omni.xml'
        with open(newfile, 'w') as outf:
            outf.write(etree.tostring(omnixml, pretty_print=True))
    else:
        outfile.write(etree.tostring(omnixml, pretty_print=True))
    #print(etree.tostring(omnixml, pretty_print=True))


def getCurrentLine(line, word):
    """
    The 'l', 't' attr of a line, para, column are set when the first line is
    encountered. This is done right in the beginning.
    The 'r' attribute is set when the first line ends and the next line is
    encountered. This is done all the way at the end of the function.
    The 'b' attr of para and column will be set only when a para or column end
    """
    # TODO:Section change has to be included.
    global first_line
    # if line doesnt have a 'b' attribute, then we are still on the first line
    if line.get('b') is None:
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
        # Set the attributes for the previous line before processing the next
        # line.
        # The attribute 'r' of the previous line has not been assigned yet. Use
        # the 'r' attribute of the last word of that line for that.
        line.set('r', getLastChild(line, attr='r').get('r'))
        if first_line:
            para = line.getparent()
            column = para.getparent()
            para.set('r', line.get('r'))
            column.set('r', line.get('r'))
        # Before moving on to initiating a new line, process the current line
        # for the presence runs.
        checkForRuns(line)
        newline = Element('ln', l=word.get('left'), t=word.get('top'),
                          b=word.get('baseline'),
                          baseline=word.get('baseline'))
        # Adjust the left margin overflow. Happens when the first line of a
        # column in indented.
        adjustleftMargin(line, newline)
        if newPara(line, newline) == 1:
            # When a new para is encountered, the 'b' attr of the previous para
            # has to be set.
            # using the left and right attributes of the column to set attr for
            # the new para. Cant rely on line as a line could be shorter.
            current_para = line.getparent()
            current_para.set('b', line.get('b'))
            newleft = current_para.getparent().get('l')
            newright = current_para.getparent().get('r')
            new_para = Element('para', l=newleft, t=newline.get('t'),
                               r=newright, alignment='justified',
                               language='en')
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
        # Add logic at this level for adjusting para/col margins.
        return newline


def newPara(line1, line2):
    """
    Returns
    0 : When there is no change of paragraph
    1 : When there is a change of paragraph
    2 : When there is a change in the column
    """
    # The values represent the confidence levels that would be updated when
    # different conditions are true.
    no_change = 0.51
    para_change = 0.5
    col_change = 0.5
    para1 = line1.getparent()
    newleft = line2.get('l')
    colleft = para1.getparent().get('l')
    diff = abs(float(newleft) - float(colleft))
    para_width = abs(float(para1.get('r')) - float(para1.get('l')))
    # The following will check the space between two paragraphs
    interline_diff = abs(float(line1.get('b')) - float(line2.get('t')))
    if interline_diff > PSPACE:
        para_change = updateConfidence(para_change, 0.2)
    # The following will check the indentation of a line to see if it should
    # belong to a new paragraph.
    #if para_width is not None:
    if diff > INDENT and diff < para_width and \
       newleft > colleft:
        para_change = updateConfidence(para_change, 0.5)
    elif diff > para_width:
        # New column encountered
        col_change = updateConfidence(col_change, 0.5)
    maxval, toreturn = max(zip([no_change, para_change, col_change],
                               [0, 1, 2]))
    return toreturn


def updateConfidence(var, amt):
    return (var + (1 - var) * amt)


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


def adjustleftMargin(line, newline):
    curr_para = line.getparent()
    curr_col = curr_para.getparent()
    paraleft = curr_para.get('l')
    colleft = curr_col.get('l')
    newleft = newline.get('l')
    if paraleft != colleft:
        raise Exception("Para and Column left attributes dont match")
    diff = abs(float(newleft) - float(colleft))
    para_width = abs(float(curr_col.get('r')) - float(curr_col.get('l')))
    # the differnce should not be greater than the para width.
    if float(curr_para.get('l')) > float(newline.get('l')) and \
       diff < para_width:
        # This means the margins of the para and col have to be reset
        curr_col.set('l', newleft)
        curr_para.set('l', newleft)


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


def checkForRuns(line):
    # Check to see if there any font changes within a line. If so, include
    # 'run' tags. If not, include font attributes in the same line tag.
    # For now, I have assumed that at this stage of processing, a line would
    # only have words and spaces as its children so the first item in the tag
    # list of line should be a word.
    font_type = list(line)[0].get('font')
    # boundary_idx will store all run boundaries
    # we need a list so that we can check if there is in fact a change of font
    # or not. The line tag does not contain a run tag if there are no font
    # differences along that line.
    boundary_idx = []
    for index, word in enumerate(line.iterfind('.//wd')):
        if word.get('font') == font_type:
            #word.attrib.pop('font')
            continue
        else:
            boundary_idx.append(index)
            font_type = word.get('font')
            #word.attrib.pop('font')
    if len(boundary_idx) > 0:
        pntr = 0
        current_run = etree.SubElement(line, 'run')
        setFont(current_run, line.find('./wd').get('font'))
        for index, word in enumerate(line.iterfind('./wd')):
            if pntr == len(boundary_idx):
                # The space tag after the current word tag ahs to be shifted
                # under the run tag as well.
                space = word.getnext()
                current_run.append(word)
                current_run.append(space)
            else:
                if index < boundary_idx[pntr]:
                    space = word.getnext()
                    current_run.append(word)
                    current_run.append(space)
                else:
                    pntr += 1
                    new_run = Element('run')
                    current_run.addnext(new_run)
                    current_run = new_run
                    space = word.getnext()
                    current_run.append(word)
                    current_run.append(space)
                    setFont(current_run, word.get('font'))
            word.attrib.pop('font')
    else:
        # This part of the function will be executed if there are no runs in a
        # line. In such a case, the font attributes of the line tag have to be
        # set.
        setFont(line, line.find('./wd').get('font'))
        for word in line.iterfind('./wd'):
            word.attrib.pop('font')


def setFont(tag, fontid):
    # For now, this will set the fontSize and fontFace attributes of the tag
    # passed to it. Also, if the font has the word 'bold' in it, then the
    # 'bold' attribute of the tag will also be set
    font = FONTS[fontid]
    size = int(float(font.get('size'))) * 100
    fonttype = font.get('family')
    if re.search(r'.*(bold).*', fonttype.lower()) is not None:
        tag.set('bold', 'true')
    tag.set('fontSize', str(size))
    tag.set('fontFace', fonttype)


def processPageNum(omnipage):
    # Look for the page number and add it as 'dd' tag
    # The page number can either be wrapped by a para or a column. So both
    # the wrappers need to be checked for
    toremove = 0
    for colm in omnipage.iterfind('.//column'):
        # The column would contain a single para that would contain a
        # single line which in turn would contain a wd and a space tag.
        if len(list(colm)) == 1 and len(colm[0]) == 1 and \
           len(colm[0][0]) == 2 and colm[0][0].find('run') is None:
            #len(colm[0][0]) == 2:
            if re.match(r'[0-9ivxcmIVXCM]+', colm[0][0][0].text) \
               is not None:
                toremove = colm
                break
    if toremove == 0:
        # If the page number was not found wrapped within a column tag,
        # then each para within all columns need to be examined.
        for parapg in omnipage.iterfind('.//para'):
            # Now you cant just look for a single line because normally a
            # para can have a single line if it is the last line in a
            # column.
            # Another condition is that the line should not contain any 'run'
            # tags. There can be situations where a line has 2 'run' tags.
            if len(list(parapg)) == 1 and len(parapg[0]) == 2 and \
               parapg[0].find('run') is None:
                if re.match(r'[0-9ivxcmIVXCM]+', parapg[0][0].text) \
                   is not None:
                    toremove = parapg
                    break
    if toremove == 0:
        return
    body = omnipage.find('body')
    toappend = toremove[0] if toremove.tag == 'column' else toremove
    dd_page_num = etree.SubElement(body, 'dd')
    setAttr(dd_page_num, toappend, ['l', 't', 'r', 'b'])
    # Appending the element to another tag automatically removes it from its
    # former parent tag. So if one tries to remove the tag after appending it,
    # the child tag will be removed from the new parent.
    dd_page_num.append(toappend)
    #toremove.getparent().remove(toremove)


def addWord(parent, word, space=True):
    #general space element
    ele_space = Element('space')
    #height = str(word.get('height')
    width = word.get('width')
    top = word.get('top')
    left = word.get('left')
    baseline = word.get('baseline')
    right = str(float(left) + float(width))
    wd = etree.SubElement(parent, 'wd', l=left, r=right,
                          t=top, b=baseline, font=word.get('font'))
    wd.text = word.text
    if space:
        wd.addnext(ele_space)


def finalTouches(word, line, para, sec):
    #try:
    if line.get('r') is None:
        line.set('r', getLastChild(line, attr='r').get('r'))
    #except:
    #    print(etree.tostring(sec, pretty_print=True))
    # The 'b' attr of the last line has to be set
    last_para = line.getparent()
    # presumably the last line
    last_para.set('b', line.get('b'))
    if last_para.get('r') is None:
        last_para.set('r', line.get('r'))
    last_para.getparent().set('b', line.get('b'))
    # Assign attr to the section
    setAttr(sec, para, ['l', 't'])
    setAttr(sec, last_para, ['r', 'b'])


if __name__ == '__main__':
    outfilename = None
    helpstr = 'Enter options.\nIf the output file name is not specified ' +\
              'then the same name as the input file will be used with ' + \
              '"-omni" appended to it'
    parser = argparse.ArgumentParser(description=helpstr)
    #parser.add_argument('--dbg', action='store_true', default=False,
    #                    help='Turn on debugging output')
    parser.add_argument('input', help='Input file')
    parser.add_argument('-o', '--outf', action='store', dest='outfile',
                        type=argparse.FileType('w'),
                        help='Specify the location & name of the output file')
    args = parser.parse_args()
    if args.outfile:
        outfilename = args.outfile
    crosswalk(args.input, outfilename)
