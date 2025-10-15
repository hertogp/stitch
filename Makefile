PANDOC=pandoc
BUSTED=busted
FILTER=src/stitch.lua
EXAMPLES=examples
SCRATCH=.stitch
# how to enable extension: inline_code_attributes

default: gnuplot

ex01:
	cd $(EXAMPLES); $(PANDOC) --lua-filter ../$(FILTER) --from markdown+inline_code_attributes -t native ex01.md -o ex01.native

gnuplot:
	cd $(EXAMPLES); $(PANDOC) --lua-filter ../$(FILTER) gnuplot.md -o gnuplot.pdf

test:
	$(BUSTED)

clean:
	rm $(EXAMPLES)/$(SCRATCH)/*
	rmdir $(EXAMPLES)/$(SCRATCH)



