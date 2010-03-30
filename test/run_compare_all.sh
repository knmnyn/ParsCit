#!/bin/sh

date

if [ $# != "2" ] 
then
  echo "Usage: ./run_compare_all.sh <outDir> <outCompareFile>"
  echo "    outDir: is the output of this new run, and should be different from standard-output"
  echo "    outCompareFile: contains the difference of output files in outDir with standard-output"
  exit
else
  DIR=$1
  OUTFILE=$2
fi

if [ "$DIR" == "standard-output" ]
then
  echo "outDir should be different from \"standard-output\""
  exit
fi

rm -rf $OUTFILE*

echo "./run_compare_single.sh $DIR $$-$OUTFILE.citations _citations"
./run_compare_single.sh $DIR $$-$OUTFILE.citations _citations

echo "./run_compare_single.sh $DIR $$-$OUTFILE.header _header"
./run_compare_single.sh $DIR $$-$OUTFILE.header _header

echo "./run_compare_single.sh $DIR $$-$OUTFILE.section _section"
./run_compare_single.sh $DIR $$-$OUTFILE.section _section

echo "./run_compare_single.sh $DIR $$-$OUTFILE.meta _meta"
./run_compare_single.sh $DIR $$-$OUTFILE.meta _meta

echo "./run_compare_single.sh $DIR $$-$OUTFILE.all _all"
./run_compare_single.sh $DIR $$-$OUTFILE.all _all

cat $$-$OUTFILE.* > $OUTFILE
rm -rf $$-$OUTFILE*
