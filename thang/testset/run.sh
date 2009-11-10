#!/bin/sh

echo "thang"
echo "../../bin/citeExtract.pl txt/W00-0102.txt newParscit/W00-0102.txt"
../../bin/citeExtract.pl txt/W00-0102.txt newParscit/W00-0102.txt
diff txt/W00-0102.txt newParscit/W00-0102.txt

echo "../../bin/citeExtract.pl txt/W02-0102.txt newParscit/W02-0102.txt"
../../bin/citeExtract.pl txt/W02-0102.txt newParscit/W02-0102.txt
diff txt/W02-0102.txt newParscit/W02-0102.txt

echo "../../bin/citeExtract.pl txt/W03-0102.txt newParscit/W03-0102.txt"
../../bin/citeExtract.pl txt/W03-0102.txt newParscit/W03-0102.txt
diff txt/W03-0102.txt newParscit/W03-0102.txt

echo "../../bin/citeExtract.pl txt/W05-0102.txt newParscit/W05-0102.txt"
../../bin/citeExtract.pl txt/W05-0102.txt newParscit/W05-0102.txt
diff txt/W05-0102.txt newParscit/W05-0102.txt

echo "../../bin/citeExtract.pl txt/W06-0102.txt newParscit/W06-0102.txt"
../../bin/citeExtract.pl txt/W06-0102.txt newParscit/W06-0102.txt
diff txt/W06-0102.txt newParscit/W06-0102.txt

echo "../../bin/citeExtract.pl txt/W90-0102.txt newParscit/W90-0102.txt"
../../bin/citeExtract.pl txt/W90-0102.txt newParscit/W90-0102.txt
diff txt/W90-0102.txt newParscit/W90-0102.txt

echo "../../bin/citeExtract.pl txt/W91-0102.txt newParscit/W91-0102.txt"
../../bin/citeExtract.pl txt/W91-0102.txt newParscit/W91-0102.txt
diff txt/W91-0102.txt newParscit/W91-0102.txt

echo "../../bin/citeExtract.pl txt/W93-0102.txt newParscit/W93-0102.txt"
../../bin/citeExtract.pl txt/W93-0102.txt newParscit/W93-0102.txt
diff txt/W93-0102.txt newParscit/W93-0102.txt

echo "../../bin/citeExtract.pl txt/W94-0102.txt newParscit/W94-0102.txt"
../../bin/citeExtract.pl txt/W94-0102.txt newParscit/W94-0102.txt
diff txt/W94-0102.txt newParscit/W94-0102.txt

echo "../../bin/citeExtract.pl txt/W95-0102.txt newParscit/W95-0102.txt"
../../bin/citeExtract.pl txt/W95-0102.txt newParscit/W95-0102.txt
diff txt/W95-0102.txt newParscit/W95-0102.txt

echo "../../bin/citeExtract.pl txt/W96-0102.txt newParscit/W96-0102.txt"
../../bin/citeExtract.pl txt/W96-0102.txt newParscit/W96-0102.txt
diff txt/W96-0102.txt newParscit/W96-0102.txt

echo "../../bin/citeExtract.pl txt/W97-0102.txt newParscit/W97-0102.txt"
../../bin/citeExtract.pl txt/W97-0102.txt newParscit/W97-0102.txt
diff txt/W97-0102.txt newParscit/W97-0102.txt

echo "../../bin/citeExtract.pl txt/W99-0102.txt newParscit/W99-0102.txt"
../../bin/citeExtract.pl txt/W99-0102.txt newParscit/W99-0102.txt
diff txt/W99-0102.txt newParscit/W99-0102.txt

echo "mv txt/*.body newParscit"
mv txt/*.body newParscit

echo "mv txt/*.cite newParscit"
mv txt/*.cite newParscit
