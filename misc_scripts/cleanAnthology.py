import os
import string

## Ankur
# This will take the directory which is root for ACL anthology type dir
# structure and remove all files from each folder except for the pdf files.

pdfdir = '/home/ankur/devbench/workrelated/public_html/'
letters = string.uppercase
for letter in letters:
    curdir = pdfdir + letter
    if os.path.isdir(curdir):
        for dirName, subdirList, fileList in os.walk(curdir):
            for fname in fileList:
                name, ext = os.path.splitext(fname)
                if ext != '.pdf':
                    os.remove(os.path.join(dirName, fname))
print "Done"
