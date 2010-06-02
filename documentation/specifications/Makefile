# Makefile for Latex work

TEXFILE= func_spec_GN4124_core.tex
DIAGRAMS= images/GN4124core_arch.svg images/GN4124core.svg

.PHONY: clean view

$(TEXFILE:.tex=.pdf): $(TEXFILE) $(DIAGRAMS:.svg=.pdf)
	pdflatex $(TEXFILE)
# Not very nice hack to get references right
	pdflatex $(TEXFILE)

%.pdf: %.eps
	epstopdf $<

%.eps: %.svg
	inkscape -E $@ $<

view: $(TEXFILE:.tex=.pdf)
	evince $(TEXFILE:.tex=.pdf)

clean:
	@rm -f \
	$(TEXFILE:.tex=.aux) \
	$(TEXFILE:.tex=.log) \
	$(TEXFILE:.tex=.out) \
	$(TEXFILE:.tex=.toc) \
	$(TEXFILE:.tex=.pdf) \
	$(DIAGRAMS:.svg=.pdf) \
	$(DIAGRAMS:.svg=.eps) 

