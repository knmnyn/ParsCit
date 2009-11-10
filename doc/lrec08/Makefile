all: lrec08.pdf

clean:
	rm -f *~ *.bbl *.aux *.log *.dvi *.pdf *.ps *.blg

lrec08.pdf: lrec08.ps
	ps2pdf lrec08.ps lrec08.pdf

lrec08.ps: lrec08.dvi
	dvips -t a4 -o lrec08.ps lrec08.dvi 

lrec08.dvi: lrec08.tex lrec08.bib
	-latex lrec08.tex
	bibtex lrec08
	latex lrec08.tex
	latex lrec08.tex
