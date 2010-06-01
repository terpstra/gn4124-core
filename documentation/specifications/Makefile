# Makefile for Latex work

TEXFILE = func_spec_GN4124_core.tex
DIAGRAMS = GN4124core.svg

.PHONY: clean view

$(TEXFILE:.tex=.pdf): $(TEXFILE) images/$(DIAGRAMS:.svg=.pdf)
	pdflatex $(TEXFILE)
# Not very nice hack to get references right
	pdflatex $(TEXFILE)

images/$(DIAGRAMS:.svg=.pdf): images/$(DIAGRAMS:.svg=.eps)
	epstopdf images/$(DIAGRAMS:.svg=.eps)

images/$(DIAGRAMS:.svg=.eps): images/$(DIAGRAMS)
	inkscape -E images/$(DIAGRAMS:.svg=.eps) images/$(DIAGRAMS)

view: $(TEXFILE:.tex=.pdf)
	evince $(TEXFILE:.tex=.pdf)

clean:
	@rm -f \
	$(TEXFILE:.tex=.aux) \
	$(TEXFILE:.tex=.log) \
	$(TEXFILE:.tex=.out) \
	$(TEXFILE:.tex=.toc) \
	$(TEXFILE:.tex=.pdf) \
	images/$(DIAGRAMS:.svg=.pdf) \
	images/$(DIAGRAMS:.svg=.eps) 

