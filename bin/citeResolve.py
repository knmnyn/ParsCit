#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Parsing of command-line arguments
# https://docs.python.org/3/howto/argparse.html
import argparse

# Subprocess management, such as invoking ParsCit
# https://docs.python.org/3/library/subprocess.html
import subprocess
import io
import os
import re
import xml.etree.ElementTree as ET

"""
Example usage:
python3 citex.py -h
python3 citex.py file1.txt file2.txt file3.txt

"""
WORDS_RE = re.compile(r'\w\w\w\w+')
AUTHOR_RE = re.compile(r'\w\w+')
YEAR_RE = re.compile(r'\d\d\d\d')

def identify(author, year, title):
    """ Transforms meta-data into unique identifier
    >>> identifier("Galke, L., Scherp, A.", "17 Sept 2017", "Evaluating the Impact of Word Embeddings on Similarity Scoring in Practical Information Retrieval")
    '@galke2017evaluating'
    >>> identifier("Sadaati, Hamidreza", 2016, "Inspecting some things")
    '@sadaati2016inspecting'
    """
    try:
        year = str(int(year))
    except ValueError:
        m = YEAR_RE.search(year)
        year = m.group(0) if m else ""

    # Find first word with more than 3 characters
    m = WORDS_RE.search(title)
    word = m.group(0).lower() if m else ""

    # We try to find first author, even if multiple authors are given
    m = AUTHOR_RE.search(author)
    author = m.group(0).lower() if m else ""

    return "@{}{}{}".format(author, year, word)


def process_file(path, fileOut):
    """ Extracts citations of the document specified by the "path", parses the
    xml output, makes an identifier for each citation and prints them
    in one line in the file object specified by the "fileOut"
    """
    print("Processing", path)
    process = subprocess.Popen(["ParsCit/bin/citeExtract.pl", path],
                               stdout=subprocess.PIPE)
    root = ET.fromstring(process.stdout.read())

    # build the identifier for each citation
    citation_ids = []
    for citation in root.iter("citation"):
        # get the last name of the of the current citation's first author
        author = citation[0][0].text

        # get the first two words of the current citation's title as the title
        title = citation[1].text
        # get the date of the current citation
        date = citation[2].text
        # write the identifiers for the current citation in the given file
        # object
        ident = identify(author, date, title)
        citation_ids.append(ident)
    in_document = os.path.splitext(os.path.basename(path))[0]
    print(in_document, *citation_ids, file=fileOut)


def main():
    print("[citex] Hello world")

    # argument parser setup
    parser = argparse.ArgumentParser()
    parser.add_argument('paths',    # the identifier
                        nargs='+',  # at least one but arbirary amount of files
                        help='Specify the files to extract citations from.')

    # invoke actual parsing of command line arguments
    args = parser.parse_args()

    # make a file object (for writing the output) in the working directory
    try:
        os.mknod("corpus")
        fp = open("corpus", 'w')
    except Exception:
        fp = open("corpus", 'w')

    for path in args.paths:          # Loop over all provided paths...
        process_file(path, fp)       # ...and process each file.


if __name__ == '__main__':
    import doctest
    doctest.testmod()
    main()
