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

gnuplot:
	cd $(EX_DIR); $(PANDOC) $(FILTER) --from $(FROM)+$(EXTS) gnuplot.md -o gnuplot.pdf

scope:
	cd $(EX_DIR); $(PANDOC) $(FILTER) --file-scope  --from $(FROM)+${EXTS} ex00.md ex01.md -o ex0x.html

cetz:
	cd $(EX_DIR); $(PANDOC) $(FILTER) --from $(FROM)+$(EXTS) cetz-01.md -o cetz-01.html

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
	@echo "- Individual targets -"
	@echo $(TARGETS) | tr " " "\n"
	@echo
	@echo "- Usage --------"
	@echo "make <target>  (one of the individual targets, see above)"
	@echo "make show      (this output)"
	@echo "make all       (make all individual targets)"
	@echo "make clean     (removes directory $(EX_DIR)/$(ST_DIR)) and its contents"


