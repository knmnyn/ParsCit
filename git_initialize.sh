#!/bin/sh

if [ $# == 1 ]
then
  dir=$1
else
  dir="."
fi

echo "mkdir $dir"
mkdir $dir

echo "cd $dir"
cd $dir

echo "git init"
git init

echo "cd .git/hooks/"
cd .git/hooks/

echo "rm -rf post-update"
rm -rf post-update

echo "wget http://utsl.gen.nz/git/post-update"
wget http://utsl.gen.nz/git/post-update

echo "chmod 755 post-update"
chmod 755 post-update

echo "cd ../../"
cd ../../

echo "touch .gitignore"
touch .gitignore

echo "git add ."
git add .

echo "git commit -a -m \"$USER@$HOSTNAME: initial commit\""
git commit -a -m "$USER@$HOSTNAME: initial commit"
