-- see .busted which uses pandoc lua to run the test spec's, so pandoc is a
-- global, but lua_ls doesn't pickup on it. So, howto remove warning about
-- pandoc being 'undefined global' ?  The following is a bit heavy-handed
---@diagnostic disable: undefined-global
assert(require("src/stitch")) -- create global Stitch func
local stitch = Stitch()
local dump = require("dump")
local F = string.format

-- https://luals.github.io/wiki/diagnostics/#unknown-diag-code

-- `:Open https://pandoc.org/lua-filters.html#pandoc.Pandoc`
-- `:Open https://pandoc.org/lua-filters.html#pandoc.read`
-- `:Open https://pandoc.org/lua-filters.html#pandoc.write`
-- `:Open https://pandoc.org/lua-filters.html#pandoc.Code`
-- `:Open https://pandoc.org/lua-filters.html#pandoc.CodeBlock`
-- `:Open https://pandoc.org/lua-filters.html#pandoc.Meta`

-- option lookup order:
-- 1. codeblock attributes
-- 2. meta cfg-section as per cb.attr.cfg value
-- 3. meta defaults section
-- 4. hardcoded
-- unknown options are not hardcoded and yield nil

describe("stitch options handling", function()
	-- don't indent lines otherwise pandoc reads'em as a single anonymous codeblock
	local markup = [[
---
author: Douglas Adams
answer: 42
stitch:
  defaults: {prg: default, dir: defaults.dir}
  cfg1: {prg: prg_cfg1, fmt: cfg1.fmt}
  cfg2: {fmt: cfg2.fmt}
...

# ex01

```{#id1 .stitch cfg=cfg1 prg=ex01}
#!/usr/bin/env whatever
# ..
```
]]

	it(" - hardcoded values", function()
		-- no cb, i.e. no stitch class -> the cb would be ignored
		local doc_meta = {}
		local cb_attr = {}
		local meta = stitch.mt_cfg(doc_meta)
		local cb_cfg = stitch.cb_cfg(cb_attr)

		assert.same({}, meta)
		assert.equal(0, #meta)
		assert(getmetatable(meta) ~= nil, "opts has a metatable")

		assert.same({}, cb_cfg, "cb_cfg is an empty table")
		assert.equal(0, #cb_cfg)
		assert(getmetatable(cb_cfg) ~= nil)

		-- no cfg=name, so hardcoded values only
		for option, value in pairs(stitch.hardcoded) do
			assert.equal(value, meta.missing[option], F("option %s has its hardcoded value", option))
		end

		assert.equal(nil, meta.missing["not an option"], "unknown options yield nil")
	end)

	it("- resolution order", function()
		-- order is attr -> named -> default -> hardcoded
		local doc_meta = {
			author = "Douglas Adams",
			answer = 42,
			stitch = {
				defaults = { fmt = "meta default value" }, -- a default value
				cb_test = { prg = "meta named value" }, -- a defined meta.<name> option
			},
		}
		local cb_attr = { cfg = "cb_test", dir = "cb attr value" } -- a defined cb attr option

		stitch.mt_cfg(doc_meta) -- sets up stitch's meta_cfg
		local opts = stitch.cb_cfg(cb_attr) -- get codeblock's cfg

		assert.equal("cb attr value", opts.dir)
		assert.equal("meta named value", opts.prg)
		assert.equal("meta default value", opts.fmt)
		assert.equal(stitch.hardcoded.log, opts.log)
	end)

	it("- parses meta.stitch sections", function()
		-- `:Open https://pandoc.org/lua-filters.html#pandoc.read`
		local doc = pandoc.read(markup, "markdown")

		-- assert doc.meta is available and correct
		assert("Douglas Adams", doc.meta.author)
		assert(42, doc.meta.answer)
		assert(doc.meta.stitch)

		-- check parseing of meta.stitch
		local meta = stitch.mt_cfg(doc.meta)

		assert(doc.meta.stitch.defaults) -- doc has defaults section in doc.meta.stitch
		assert(meta.missing) -- meta yields defaults for missing stitch.section
		assert("default", meta.missing.prg) -- meta -> defaults
		assert(stitch.hardcoded.log, meta.missing.log) -- meta -> defaults -> hardcoded
		assert.is_nil(rawget(meta, "defaults")) -- it got "promoted" to metatable

		assert("prg_cfg1", meta.cfg1.prg) -- meta defined
		assert(stitch.hardcoded.log, meta.cfg1.log) -- meta -> default ->  hardcoded

		assert("cfg2.fmt", meta.cfg2.fmt) -- meta defined
		assert("default", meta.cfg2.prg) -- meta -> default
		assert(stitch.hardcoded.log, meta.cfg2.log) -- meta -> default -> hardcoded
	end)

	it("- parses codeblock attributes", function()
		-- see markup above
		local doc = pandoc.read(markup, "markdown")
		local cb = doc.blocks:filter(function(el)
			return el.t == "CodeBlock"
		end)
		-- check markup example hasn't changed
		assert(#cb == 1)
		cb = cb[1]

		-- parse meta and cb attributes
		stitch.mt_cfg(doc.meta) -- setup stitch's meta_cfg
		local opts = stitch.cb_cfg(cb.attributes)

		assert("ex01", opts.prg) -- cb
		assert("cfg1", opts.cfg) -- cb
		assert("cfg1.fmt", opts.fmt) -- cb -> meta
		assert("defaults.dir", opts.dir) -- cb -> meta -> defaults
		assert(stitch.hardcoded.log, opts.log) -- cb -> meta -> defaults -> hardcoded
		assert(stitch.hardcoded.ins, opts.ins) -- cb -> meta -> defaults -> hardcoded
	end)

	it("- marshall's option values", function()
		-- log is a number, ins is list of strings, the rest are strings
		pending("test marshalling of option values", function()
			print("pending")
		end)
	end)
end)
