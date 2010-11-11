# Makefile for Latex work

TEXFILE_FUNC_SPEC= func_spec_GN4124_core.tex
TEXFILE_TECH_SPEC= tech_spec_GN4124_core.tex
DIAG_FUNC_SPEC= images/GN4124core.svg
DIAG_TECH_SPEC= images/GN4124core_arch.svg \
	        images/GN4124core_DMA_controller.svg \
		images/State_Machine_DMA_controller.svg \
		images/GN4124core_L2P_DMA_master.svg \
		images/GN4124core_P2L_DMA_master.svg \
		images/GN4124core_wb_master.svg
DOT_TECH_SPEC= images/dma_controller_state_machine.dot
DIAG_ALL= images/GN4124core.svg \
	images/GN4124core_arch.svg \
	images/GN4124core_DMA_controller.svg \
	images/State_Machine_DMA_controller.svg \
        images/GN4124core_L2P_DMA_master.svg \
	images/GN4124core_P2L_DMA_master.svg

.PHONY: clean view

all: func tech

func: func_spec_GN4124_core.pdf 

tech: tech_spec_GN4124_core.pdf 

$(TEXFILE_FUNC_SPEC:.tex=.pdf): $(TEXFILE_FUNC_SPEC) $(DIAG_FUNC_SPEC:.svg=.pdf)
	pdflatex $(TEXFILE_FUNC_SPEC)
# Not very nice hack to get references right
	pdflatex $(TEXFILE_FUNC_SPEC)

$(TEXFILE_TECH_SPEC:.tex=.pdf): $(TEXFILE_TECH_SPEC) $(DIAG_TECH_SPEC:.svg=.pdf) $(DOT_TECH_SPEC:.dot=.pdf)
	pdflatex $(TEXFILE_TECH_SPEC)
# Not very nice hack to get references right
	pdflatex $(TEXFILE_TECH_SPEC)

%.pdf: %.eps
	epstopdf $<

%.eps: %.svg
	inkscape -E $@ $<

%.png: %.svg
	inkscape $< -d 120 -D -e $@

%.pdf: %.dot
	dot -Tpdf -o $@ $<

view: $(TEXFILE_TECH_SPEC:.tex=.pdf)
	evince $(TEXFILE_TECH_SPEC:.tex=.pdf)

clean:
	@rm -f \
	$(TEXFILE_FUNC_SPEC:.tex=.aux) \
	$(TEXFILE_FUNC_SPEC:.tex=.log) \
	$(TEXFILE_FUNC_SPEC:.tex=.out) \
	$(TEXFILE_FUNC_SPEC:.tex=.toc) \
	$(TEXFILE_FUNC_SPEC:.tex=.lof) \
	$(TEXFILE_FUNC_SPEC:.tex=.lot) \
	$(TEXFILE_TECH_SPEC:.tex=.aux) \
	$(TEXFILE_TECH_SPEC:.tex=.log) \
	$(TEXFILE_TECH_SPEC:.tex=.out) \
	$(TEXFILE_TECH_SPEC:.tex=.toc) \
	$(TEXFILE_TECH_SPEC:.tex=.lof) \
	$(TEXFILE_TECH_SPEC:.tex=.lot) \
	$(DIAG_FUNC_SPEC:.svg=.pdf) \
	$(DIAG_ALL:.svg=.png) \
#	$(DIAG_TECH_SPEC:.svg=.pdf) \
#	$(DIAG_ALL:.svg=.pdf) \
#	$(TEXFILE_TECH_SPEC:.tex=.pdf) \
#	$(TEXFILE_FUNC_SPEC:.tex=.pdf) \
#	$(DOT_TECH_SPEC:.dot=.pdf) \

diag: $(DIAG_ALL:.svg=.pdf) $(DIAG_ALL:.svg=.png)
