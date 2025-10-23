PANDOC=pandoc
BUSTED=busted
FILTER=src/stitch.lua
EXAMPLES=examples
SCRATCH=.stitch
# how to enable extension: inline_code_attributes

default: ex00

ex00:
	cd $(EXAMPLES); $(PANDOC) --lua-filter ../$(FILTER) --from markdown+inline_code_attributes ex00.md -o ex00.html

ex01:
	cd $(EXAMPLES); $(PANDOC) --lua-filter ../$(FILTER) --from markdown+inline_code_attributes ex01.md -o ex01.html

gnuplot:
	cd $(EXAMPLES); $(PANDOC) --lua-filter ../$(FILTER) gnuplot.md -o gnuplot.pdf

test:
	$(BUSTED)

clean:
	rm -rf $(EXAMPLES)/$(SCRATCH)/*
	rmdir $(EXAMPLES)/$(SCRATCH)



