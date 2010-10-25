#
# Makefile for the documentation directory
#
# Copyright 1994,2000,2010   Alessandro Rubini <rubini@linux.it>
#
#################
#
# BE CAREFUL in editing:
#	due to the large number of index files, and my use of a non standard
#	info input file, any file $(TARGET).* is removed by "make clean"
#
#	I chose to use a prefix for the input file ("doc.$(TARGET)"), to ease
#	makeing clean and applying my own rules.
#
###################################################################

TARGET = gnurabbit

# Assume makeinfo can do images and --html.
# In any case, MAKEINFO can be specified on the commandline

MAKEINFO = makeinfo

##############################################

INPUT = $(wildcard *.in)
TEXI = $(INPUT:.in=.texi)

.SUFFIXES: .in .texi .info .html .txt

.in.texi:
	@rm -f $@ 2> /dev/null
	sed -f ./infofilter $< > $@
	chmod -w $@

# unfortuantely implicit rules are not concatenated, so force a make run
%.pdf: %.texi $(TEXI)
	$(MAKE) $(TEXI)
	texi2pdf --batch $<

%.info: %.texi $(TEXI)
	$(MAKE) $(TEXI)
	$(MAKEINFO) $< -o $@

%.html: %.texi $(TEXI)
	$(MAKE) $(TEXI)
	$(MAKEINFO) --html --no-split -o $@ $<

%.txt: %.texi $(TEXI)
	$(MAKE) $(TEXI)
	$(MAKEINFO) --no-headers $< > $@

##############################################

ALL    = $(TARGET).info $(TARGET).txt $(TARGET).html $(TARGET).pdf

all: images $(TEXI) $(ALL)

images::
	if [ -d images ]; then $(MAKE) -C images || exit 1; fi

info: $(TARGET).info

check: _err.ps
	gs -sDEVICE=linux -r320x200x16 $<

terse:
	for n in cp fn ky pg toc tp vr; do \
	   rm -f $(TARGET).$$n; \
	done
	rm -f *~

clean: terse
	rm -f $(ALL) $(TEXI)

install:

