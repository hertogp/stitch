PANDOC=pandoc
BUSTED=busted
FILTER=src/stitch.lua
EXAMPLES=examples
SCRATCH=.stitch

# 'make' w/o a target will build this (first) one
# cd is executed in its own subshell, to tag on cmd after ';'
# default: test # runs busted
default: ex01 # working on examples

ex01: clean
	cd $(EXAMPLES); $(PANDOC) --lua-filter ../$(FILTER) ex01.md -o ex01.html

test:
	$(BUSTED)

clean:
	rm $(EXAMPLES)/$(SCRATCH)/*
	rmdir $(EXAMPLES)/$(SCRATCH)



