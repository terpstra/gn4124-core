# Makefile for Latex work

TEXFILE= func_spec_GN4124_core.tex
DIAGRAMS= images/GN4124core.svg
OTHERS= images/GN4124core_arch.svg images/GN4124core_sequencer.svg \
        images/GN4124core.svg images/DMA_state_machine.svg \
        images/Sequencer_state_machine.svg images/Wishbone_bus.svg images/FMC.svg 

.PHONY: clean view

$(TEXFILE:.tex=.pdf): $(TEXFILE) $(DIAGRAMS:.svg=.pdf)
	pdflatex $(TEXFILE)
# Not very nice hack to get references right
	pdflatex $(TEXFILE)

%.pdf: %.eps
	epstopdf $<

%.eps: %.svg
	inkscape -E $@ $<

%.png: %.svg
	inkscape $< -d 120 -D -e $@


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
	$(OTHERS:.svg=.pdf) \
	$(OTHERS:.svg=.png) \

diag: $(OTHERS:.svg=.pdf) $(OTHERS:.svg=.png)
