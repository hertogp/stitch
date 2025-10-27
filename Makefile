PANDOC   = pandoc
BUSTED   = busted
FILTER   = --lua-filter stitch.lua
EX_DIR   = examples
ST_DIR   = .stitch
FROM     = markdown
EXTS     = inline_code_attributes

EXAMPLES = $(sort $(wildcard $(EX_DIR)/*.md))
TARGETS  = $(EXAMPLES:examples/%.md=%)

# make any ex(ample) converting markdown -> html
default: show

ex%:
	cd $(EX_DIR); $(PANDOC) $(FILTER) --from $(FROM)+${EXTS} $@.md -o $@.html

%.pdf:
	cd $(EX_DIR); $(PANDOC) $(FILTER) --from $(FROM)+${EXTS} $@.md -o $@.pdf

all: $(TARGETS)

# gnuplot:
# 	cd $(EXAMPLES); $(PANDOC) --lua-filter $(FILTER) gnuplot.md -o gnuplot.pdf

# TODO:
# test:
# 	$(BUSTED)

clean:
	rm -rf $(EX_DIR)/$(ST_DIR)/*
	rmdir $(EX_DIR)/$(ST_DIR)


help: show

show:
	@echo ""
	@echo "- VARS ----------"
	@echo "PANDOC          = $(PANDOC)"
	@echo "FILTER          = $(FILTER)"
	@echo "FROM            = $(FROM)"
	@echo "EXTS            = $(EXTS)"
	@echo "BUSTED          = $(BUSTED)"
	@echo "EX_DIR          = $(EX_DIR)"
	@echo ""
	@echo "- CMD -----------"
	@echo "cd $(EX_DIR); $(PANDOC) $(FILTER) --from $(FROM)+${EXTS} $@.md -o $@.html"
	@echo ""
	@echo "- Available -----"
	@echo $(TARGETS) | tr " " "\n"
	@echo
	@echo "- Usage --------"
	@echo "make ex<..> (see Available)"
	@echo


