#!/bin/sh

echo "thang"
echo "rm -rf parshed_diff.txt"
rm -rf parshed_diff.txt

echo "../../bin/headExtract.pl txt/W00-0102.txt newParshed/W00-0102.txt"
../../bin/headExtract.pl txt/W00-0102.txt newParshed/W00-0102.txt
echo "diff oldParshed/W00-0102.txt newParshed/W00-0102.txt" >> parshed_diff.txt
diff oldParshed/W00-0102.txt newParshed/W00-0102.txt >> parshed_diff.txt

#echo "../../bin/headExtract.pl txt/W02-0102.txt newParshed/W02-0102.txt"
#../../bin/headExtract.pl txt/W02-0102.txt newParshed/W02-0102.txt
#echo "diff oldParshed/W02-0102.txt newParshed/W02-0102.txt" >> parshed_diff.txt
#diff oldParshed/W02-0102.txt newParshed/W02-0102.txt >> parshed_diff.txt

echo "../../bin/headExtract.pl txt/W03-0102.txt newParshed/W03-0102.txt"
../../bin/headExtract.pl txt/W03-0102.txt newParshed/W03-0102.txt
echo "diff oldParshed/W03-0102.txt newParshed/W03-0102.txt" >> parshed_diff.txt
diff oldParshed/W03-0102.txt newParshed/W03-0102.txt >> parshed_diff.txt

echo "../../bin/headExtract.pl txt/W05-0102.txt newParshed/W05-0102.txt"
../../bin/headExtract.pl txt/W05-0102.txt newParshed/W05-0102.txt
echo "diff oldParshed/W05-0102.txt newParshed/W05-0102.txt" >> parshed_diff.txt
diff oldParshed/W05-0102.txt newParshed/W05-0102.txt >> parshed_diff.txt

echo "../../bin/headExtract.pl txt/W06-0102.txt newParshed/W06-0102.txt"
../../bin/headExtract.pl txt/W06-0102.txt newParshed/W06-0102.txt
echo "diff oldParshed/W06-0102.txt newParshed/W06-0102.txt" >> parshed_diff.txt
diff oldParshed/W06-0102.txt newParshed/W06-0102.txt >> parshed_diff.txt

echo "../../bin/headExtract.pl txt/W90-0102.txt newParshed/W90-0102.txt"
../../bin/headExtract.pl txt/W90-0102.txt newParshed/W90-0102.txt
echo "diff oldParshed/W90-0102.txt newParshed/W90-0102.txt" >> parshed_diff.txt
diff oldParshed/W90-0102.txt newParshed/W90-0102.txt >> parshed_diff.txt

echo "../../bin/headExtract.pl txt/W91-0102.txt newParshed/W91-0102.txt"
../../bin/headExtract.pl txt/W91-0102.txt newParshed/W91-0102.txt
echo "diff oldParshed/W91-0102.txt newParshed/W91-0102.txt" >> parshed_diff.txt
diff oldParshed/W91-0102.txt newParshed/W91-0102.txt >> parshed_diff.txt

#echo "../../bin/headExtract.pl txt/W93-0102.txt newParshed/W93-0102.txt"
#../../bin/headExtract.pl txt/W93-0102.txt newParshed/W93-0102.txt
#echo "diff oldParshed/W93-0102.txt newParshed/W93-0102.txt" >> parshed_diff.txt
#diff oldParshed/W93-0102.txt newParshed/W93-0102.txt >> parshed_diff.txt

echo "../../bin/headExtract.pl txt/W94-0102.txt newParshed/W94-0102.txt"
../../bin/headExtract.pl txt/W94-0102.txt newParshed/W94-0102.txt
echo "diff oldParshed/W94-0102.txt newParshed/W94-0102.txt" >> parshed_diff.txt
diff oldParshed/W94-0102.txt newParshed/W94-0102.txt >> parshed_diff.txt

echo "../../bin/headExtract.pl txt/W95-0102.txt newParshed/W95-0102.txt"
../../bin/headExtract.pl txt/W95-0102.txt newParshed/W95-0102.txt
echo "diff oldParshed/W95-0102.txt newParshed/W95-0102.txt" >> parshed_diff.txt
diff oldParshed/W95-0102.txt newParshed/W95-0102.txt >> parshed_diff.txt

echo "../../bin/headExtract.pl txt/W96-0102.txt newParshed/W96-0102.txt"
../../bin/headExtract.pl txt/W96-0102.txt newParshed/W96-0102.txt
echo "diff oldParshed/W96-0102.txt newParshed/W96-0102.txt" >> parshed_diff.txt
diff oldParshed/W96-0102.txt newParshed/W96-0102.txt >> parshed_diff.txt

echo "../../bin/headExtract.pl txt/W97-0102.txt newParshed/W97-0102.txt"
../../bin/headExtract.pl txt/W97-0102.txt newParshed/W97-0102.txt
echo "diff oldParshed/W97-0102.txt newParshed/W97-0102.txt" >> parshed_diff.txt
diff oldParshed/W97-0102.txt newParshed/W97-0102.txt >> parshed_diff.txt

echo "../../bin/headExtract.pl txt/W99-0102.txt newParshed/W99-0102.txt"
../../bin/headExtract.pl txt/W99-0102.txt newParshed/W99-0102.txt
echo "diff oldParshed/W99-0102.txt newParshed/W99-0102.txt" >> parshed_diff.txt
diff oldParshed/W99-0102.txt newParshed/W99-0102.txt >> parshed_diff.txt

echo "../../bin/headExtract.pl txt/1.txt newParshed/1.txt"
../../bin/headExtract.pl txt/1.txt newParshed/1.txt
echo "diff oldParshed/1.txt newParshed/1.txt" >> parshed_diff.txt
diff oldParshed/1.txt newParshed/1.txt >> parshed_diff.txt

echo "../../bin/headExtract.pl txt/2.txt newParshed/2.txt"
../../bin/headExtract.pl txt/2.txt newParshed/2.txt
echo "diff oldParshed/2.txt newParshed/2.txt" >> parshed_diff.txt
diff oldParshed/2.txt newParshed/2.txt >> parshed_diff.txt

echo "../../bin/headExtract.pl txt/3.txt newParshed/3.txt"
../../bin/headExtract.pl txt/3.txt newParshed/3.txt
echo "diff oldParshed/3.txt newParshed/3.txt" >> parshed_diff.txt
diff oldParshed/3.txt newParshed/3.txt >> parshed_diff.txt
