PANDOC   = pandoc
BUSTED   = busted
FILTER   = --lua-filter stitch.lua
FILTER2  = --lua-filter src/stitch2.lua
EX_DIR   = examples
ST_DIR   = .stitch
FROM     = --from markdown
EXTS     = inline_code_attributes+lists_without_preceding_blankline
UNICODE  = -V mainfont="DejaVu Serif" -V mainfontfallback="NotoColorEmoji:mode=harf"
ENGINE   = --pdf-engine=xelatex

EXAMPLES = $(sort $(wildcard $(EX_DIR)/*.md))
TARGETS  = $(EXAMPLES:examples/%.md=%)
ALLPDFS  = $(EXAMPLES:examples/%.md=%.pdf)
PDFLOGS  = $(ST_DIR)/readme/readme.pdf.log
GFMLOGS  = $(ST_DIR)/readme/readme.gfm.log
TOCDEPTH = --toc-depth=4

default: show

new:
	@echo "NEW stitch!"
	$(PANDOC) $(FILTER2) $(ENGINE) $(FROM)+$(EXTS) _readme.md -t pdf -o scr/README.pdf 2>&1 | tee scr/stitch2.log

readme: readme.pdf
	@echo "creating README.md, logging to $(GFMLOGS)"
	$(PANDOC) $(FILTER) $(FROM)+$(EXTS) _readme.md -t gfm -o README.md 2>&1 | tee $(GFMLOGS)

readme.pdf:
	@echo "creating examples/README.pdf, logging to $(PDFLOGS)"
	$(PANDOC) $(FILTER) $(ENGINE) $(FROM)+$(EXTS) _readme.md -t pdf -o $(EX_DIR)/README.pdf 2>&1 | tee $(PDFLOGS)


ex%:
	cd $(EX_DIR); $(PANDOC) $(FILTER) $(FROM)+${EXTS} $@.md -o $@.html

%.pdf:
	cd $(EX_DIR); $(PANDOC) $(FILTER) $(TOCDEPTH) $(FROM)+${EXTS} $(ENGINE) ${@:%.pdf=%.md} -o $@

all: $(TARGETS:%=%.pdf)

# %:
# 	cd $(EX_DIR); $(PANDOC) $(FILTER) --from $(FROM)+$(EXTS) $(ENGINE) $@.md -o $@.pdf

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
