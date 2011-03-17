#!/usr/bin/env python
# Author: Matteo Romanello, <matteo.romanello@gmail.com>

import os,sys,getopt,re

# paths to executables 
# Thang v100901: minor modifications in the code so that it doesn't matter if the below directory paths end with / or not
PARSCIT_PATH=sys.path[0] + "/../../bin/"
BIBUTILS_PATH=sys.path[0] + "/bibutils_4.10"
SAXON_PATH=sys.path[0] + "/saxonhe9-2-1-2j/saxon9he.jar"

# paths to resources
XSLT_TRANFORM_PATH=sys.path[0] + "/parscit2mods.xsl"

def parscit_to_mods(parscit_out, is_quiet):
	saxon_cmd="java -jar %s -xsl:%s -s:%s" %(SAXON_PATH,XSLT_TRANFORM_PATH,parscit_out)
	out=os.popen(saxon_cmd).readlines()
        if is_quiet == "no":
	  print "Transforming Parscit's output into mods xml..."
	return out
	
def export_mods(mods_xml, out_type, is_quiet):
	bibutils_cmd="%s/xml2%s %s"%(BIBUTILS_PATH, out_type, mods_xml) # Thang v100901: modify to add multiple export format
	
        if is_quiet == "yes": bibutils_cmd = "%s 2>/dev/null" %(bibutils_cmd)
        out=os.popen(bibutils_cmd).readlines()
	return out

def usage():
	print "Usage: %s [-h] [-q] [-i <inputType>] [-o <outputType>] <inputFile> <outDir>" %(sys.argv[0])
        print "Options:"
        print "\t-h\tPrint this message"
        print "\t-q\tDo not pritn log message"
        print "\t-i <inputType>\tType=\"all\" (full-text input),\"ref\" (input contains only individual reference strings, one per line), \"xml\" (Omnipage XML input), \"parscit\" (ParsCit citation output), or \"mods\" (MODS file) (default=\"ref\")"
        print "\t-o <outputType>\tType=(ads|bib|end|isi|ris|wordbib) (default=bib)"

# Thang v100901: process argv array using getopt
def process_argv(argv):
  try:
    opts, args = getopt.getopt(argv[1:], "hqi:o:", ["help", "quiet", "input=", "output="])
  except getopt.GetoptError, err:
    print str(err)
    usage()
    sys.exit(2)

  in_type = "ref"
  out_type = "bib"
  is_quiet = "no"

  for o, a in opts:
    if o in ("-h", "--help"):
      usage()
      sys.exit()
    elif o in ("-q", "--quiet"):
      is_quiet = "yes" 
    elif o in ("-i", "--input"):
      in_type = a
      if(not re.match("(all|ref|xml|parscit|mods)", in_type)):
        sys.stderr.write("#! in_type \"%s\" does not match (all|ref|mods)\n" % in_type)
        sys.exit(1)
    elif o in ("-o", "--output"):
      out_type = a

      if(not re.match("(ads|bib|end|isi|ris|word)", out_type)):
        sys.stderr.write("#! Output type \"%s\" does not match(ads|bib|end|isi|ris|wordbib)\n" % out_type)
        sys.exit(1)
  
    else:
      assert False, "unhandled in_type"

  # get inp_file, out_dir & check validity
  inp_file = ""
  out_dir = ""
  if(len(args) > 1):
    inp_file = args[0]
    out_dir = args[1]
  else:
    usage()
    sys.exit(1)

  if is_quiet == "no": sys.stderr.write("# (in_type, outputType, inputFile, outDir) = (\"%s\", \"%s\", \"%s\", \"%s\")\n" %(in_type, out_type, inp_file, out_dir))

  # check if the input file exists
  if not os.path.isfile(inp_file):
    sys.stderr.write("#! File \"%s\" doesn't exist\n" % inp_file)
    sys.exit(1)
  
  # check if directory exists, create if not:
  if not os.path.exists(out_dir):
    if is_quiet == "no": sys.stderr.write("#! Directory \"%s\" doesn't exist. Creating ...\n" % out_dir)
    os.makedirs(out_dir)

  return (out_type, in_type, inp_file, out_dir, is_quiet)
# End Thang v100901: process argv array

############
### MAIN ###
############
(out_type, in_type, inp_file, out_dir, is_quiet) = process_argv(sys.argv)
if is_quiet == "no": print "# Extracting references from the input file... "

# Thang v100901: handle in_type
if (in_type == "ref"):
  parscit_out = os.popen("%s/parseRefStrings.pl %s" %(PARSCIT_PATH,inp_file)).readlines()
elif(in_type == "all"):
  parscit_out = os.popen("%s/citeExtract.pl -m extract_citations %s" %(PARSCIT_PATH,inp_file)).readlines()
elif(in_type == "xml"):
  parscit_out = os.popen("%s/citeExtract.pl -m extract_citations -i xml %s" %(PARSCIT_PATH,inp_file)).readlines()

if(in_type != "mods" and in_type != "parscit"):
  parscit_xml='%s/parscit_temp.xml'%out_dir
  file = open(parscit_xml,'w')
  for line in parscit_out:
	file.write(line)
  file.close()
elif(in_type == "parscit"):
  parscit_xml = inp_file

# transform parscit's output into mods 3.x
if(in_type != "mods"):
  parscit_mods='%s/parscit_mods.xml'%out_dir
  file = open(parscit_mods,'w')
  for line in parscit_to_mods(parscit_xml, is_quiet):
	file.write(line)
  file.close()
else: # already an MODS file, copy over
  parscit_mods = inp_file

# transform mods intermediate xml into other export format
# Thang v100901: modify to handle multiple format 
export_file='%s/parscit.%s' %(out_dir, out_type)
if is_quiet == "no": print "# Transforming intermediate mods xml into %s format. Output to %s ..." % (out_type, export_file)

file = open(export_file,'w')
for line in export_mods(parscit_mods, out_type, is_quiet):
	file.write(line)
file.close()

