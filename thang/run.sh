#!/bin/sh

echo "thang"
echo "../../bin/citeExtract.pl txt/W00-0102.txt $1/W00-0102.txt"
../../bin/citeExtract.pl txt/W00-0102.txt $1/W00-0102.txt
diff txt/W00-0102.txt $1/W00-0102.txt

echo "../../bin/citeExtract.pl txt/W02-0102.txt $1/W02-0102.txt"
../../bin/citeExtract.pl txt/W02-0102.txt $1/W02-0102.txt
diff txt/W02-0102.txt $1/W02-0102.txt

echo "../../bin/citeExtract.pl txt/W03-0102.txt $1/W03-0102.txt"
../../bin/citeExtract.pl txt/W03-0102.txt $1/W03-0102.txt
diff txt/W03-0102.txt $1/W03-0102.txt

echo "../../bin/citeExtract.pl txt/W05-0102.txt $1/W05-0102.txt"
../../bin/citeExtract.pl txt/W05-0102.txt $1/W05-0102.txt
diff txt/W05-0102.txt $1/W05-0102.txt

echo "../../bin/citeExtract.pl txt/W06-0102.txt $1/W06-0102.txt"
../../bin/citeExtract.pl txt/W06-0102.txt $1/W06-0102.txt
diff txt/W06-0102.txt $1/W06-0102.txt

echo "../../bin/citeExtract.pl txt/W90-0102.txt $1/W90-0102.txt"
../../bin/citeExtract.pl txt/W90-0102.txt $1/W90-0102.txt
diff txt/W90-0102.txt $1/W90-0102.txt

echo "../../bin/citeExtract.pl txt/W91-0102.txt $1/W91-0102.txt"
../../bin/citeExtract.pl txt/W91-0102.txt $1/W91-0102.txt
diff txt/W91-0102.txt $1/W91-0102.txt

echo "../../bin/citeExtract.pl txt/W93-0102.txt $1/W93-0102.txt"
../../bin/citeExtract.pl txt/W93-0102.txt $1/W93-0102.txt
diff txt/W93-0102.txt $1/W93-0102.txt

echo "../../bin/citeExtract.pl txt/W94-0102.txt $1/W94-0102.txt"
../../bin/citeExtract.pl txt/W94-0102.txt $1/W94-0102.txt
diff txt/W94-0102.txt $1/W94-0102.txt

echo "../../bin/citeExtract.pl txt/W95-0102.txt $1/W95-0102.txt"
../../bin/citeExtract.pl txt/W95-0102.txt $1/W95-0102.txt
diff txt/W95-0102.txt $1/W95-0102.txt

echo "../../bin/citeExtract.pl txt/W96-0102.txt $1/W96-0102.txt"
../../bin/citeExtract.pl txt/W96-0102.txt $1/W96-0102.txt
diff txt/W96-0102.txt $1/W96-0102.txt

echo "../../bin/citeExtract.pl txt/W97-0102.txt $1/W97-0102.txt"
../../bin/citeExtract.pl txt/W97-0102.txt $1/W97-0102.txt
diff txt/W97-0102.txt $1/W97-0102.txt

echo "../../bin/citeExtract.pl txt/W99-0102.txt $1/W99-0102.txt"
../../bin/citeExtract.pl txt/W99-0102.txt $1/W99-0102.txt
diff txt/W99-0102.txt $1/W99-0102.txt

echo "mv txt/*.body $1"
mv txt/*.body $1

echo "mv txt/*.cite $1"
mv txt/*.cite $1
