#!/bin/sh

date

if [ $# != "3" ] 
then
  echo "Usage: ./run_compare_single.sh <outDir> <outCompareFile> <suffix>"
  echo "    outDir: is the output of this new run, and should be different from standard-output"
  echo "    outCompareFile: contains the difference of output files in outDir with standard-output"
  echo "    suffix: should be either _citations, _header, _section, _meta, or _all"
  exit
else
  DIR=$1
  OUTFILE=$2
  SUFFIX=$3
fi

if [ "$DIR" == "standard-output" ]
then
  echo "outDir should be different from \"standard-output\""
  exit
fi

#--- runBatch txt ---
echo "./bin/runBatch.pl -q -l fileList -in txt -out $DIR -opt \"-m extract$SUFFIX\" -suf \"$SUFFIX\""
./bin/runBatch.pl -l fileList -in txt -out $DIR -opt "-m extract$SUFFIX" -suf "$SUFFIX"

#--- runBatch xml ---
echo "./bin/runBatch.pl -q -l fileList -in omnipage/xml-concat -out $DIR -opt \"-m extract$SUFFIX -i xml\" -suf \"_xml$SUFFIX\""
./bin/runBatch.pl -l fileList -in omnipage/xml-concat -out $DIR -opt "-m extract$SUFFIX -i xml" -suf "_xml$SUFFIX"

#--- compare txt ---#
COMPAREFILE="$$-$OUTFILE".txt
echo "./bin/compare.pl -q -l fileList -in1 standard-output -in2 $DIR -out $COMPAREFILE -suf \"$SUFFIX\""
./bin/compare.pl -q -l fileList -in1 standard-output -in2 $DIR -out $COMPAREFILE -suf "$SUFFIX"

#--- compare xml ---#
COMPAREFILE="$$-$OUTFILE".xml
echo "./bin/compare.pl -q -l fileList -in1 standard-output -in2 $DIR -out $COMPAREFILE -suf \"_xml$SUFFIX\""
./bin/compare.pl -q -l fileList -in1 standard-output -in2 $DIR -out $COMPAREFILE -suf "_xml$SUFFIX"

cat $$-$OUTFILE.* > $OUTFILE
rm -rf $$-$OUTFILE.*

