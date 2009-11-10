#!/bin/sh

date

if [ $# != "1" ] 
then
  date=`date`
  msg="$USER@$HOSTNAME $date"
else
  msg=$1
fi

echo "git add ."
git add .

echo "git commit -a -m \"$msg\""
git commit -a -m "$msg"

echo "git pull origin"
git pull origin

echo "git push origin"
git push origin
