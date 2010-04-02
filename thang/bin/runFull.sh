#!/bin/sh

if [ $# != 1 ]
then
  echo "Usage: ./runFull.sh <numFolds>"
  exit
fi

ROOT="../../.."
FOLD=$1
LABEL="label-xml"
F=3
NAME="baseline_pc-pos-punct-num-length_xml-Loc-Align-Bold-Italic-fS-Bullet-Dd-Cell"
echo "### $NAME"
date
mkdir "$NAME"
cd "$NAME"
echo "$ROOT/../bin/sectLabel/redo.sectLabel.pl -t \"ACL09-ACM-CHI08\" -in $ROOT/../thang/sectLabel/$LABEL -out . -n $FOLD -p 7 -iter 100 -c ../config/$NAME -f $F"
$ROOT/../bin/sectLabel/redo.sectLabel.pl -t "ACL09-ACM-CHI08" -in $ROOT/../thang/sectLabel/$LABEL -out . -n $FOLD -p 7 -iter 100 -c ../config/$NAME -f $F
cd ..
date
