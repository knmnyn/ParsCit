from lxml import etree
from lxml.etree import Element

page = etree.parse('./temp-pdfx.xml')
newpage = Element('page')
for word in page.iterfind('.//word'):
    h = word.get('height')
    w = word.get('width')
    t = word.get('top')
    l = word.get('left')
    b = word.get('baseline')
    newword = etree.SubElement(newpage, 'word', height=h, width=w, top=t,
                               baseline=b, left=l)
    newword.text = word.text
with open('./temp-pdfx-simp.xml', 'w') as file:
    file.write(etree.tostring(newpage, pretty_print=True))
