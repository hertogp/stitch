-- stitch turns codeblocks into images, figures, codeblocks and more
-- Examples -> `:Open https://pandoc.org/extras.html#lua-filters`

local M = {} -- returned by global Stitch() for testing
local ctx = {} -- holds meta.stitch configuration for current document

--[[ helpers ]]

local dump = require("dump") -- tmp, delme
local F = string.format
local pd = require("pandoc")
local function msg(label, text)
	text = F("[stitch](%s) %s\n", label, text)
	io.stderr:write(text)
	return text
end
-- trim string `s`, if nil, return empty string
---@param s string|nil string to trim (both leading/trailing whitespace)
---@return string
local function trim(s)
	return s and s:match("^%s*(.-)%s*$") or ""
end

-- Create list of lowercase strings from a table or string in csv-notation
---@param val any a parameter value shaped as a string, Inlines or List (of Inlines)
---@param sep? string|nil separator(s), defaults to ","
---@return table parts list of zero or more strings
local function split(val, sep)
	-- NOTE: using [a,b] for a value in a meta section (yaml) -> List of Inlines,
	-- while in a cb.attr (not yaml!) it yields a string. So better to never use
	-- [..] and always use "a, b" to specify a list of string values (to be split
	-- here)
	local parts = {}
	local ptype = pd.utils.type(val)
	sep = F("[%s]+%%s*", sep or ",") --> [sep]+%s*

	if ptype == "List" or ptype == "table" then
		-- keep stringified entries in table or a List of Inlines
		for _, v in ipairs(val) do
			parts[#parts + 1] = trim(pd.utils.stringify(v))
		end
	else
		-- everything else (incl. a single Inline) gets stringified and split
		-- for part in stringify(val):gsub(",%s*", ","):gmatch("[^,]+") do
		for part in pd.utils.stringify(val):gsub(sep, ","):gmatch("[^,]+") do
			parts[#parts + 1] = trim(part)
		end
	end
	return parts
end

-- parse `opts.inc` into list: {{what, format, filter, how}, ..}
---@param str string the opts.inc string with include directives
---@return table directives list of 4-element lists of strings
local function parse_inc(str)
	str = pd.utils.stringify(str)
	local todo = {}
	local word = "([^!@:]+)"
	for p in str:gsub("[,%s]+", " "):gmatch("%S+") do
		todo[#todo + 1] = {
			p:match("^" .. word) or "", -- what to include
			p:match("!" .. word) or "", -- read as type
			p:match("@" .. word) or "", -- filter
			p:match(":" .. word) or "", -- element/how
		}
	end
	return todo
end

--[[ stitch options ]]

local marshal = {
	-- convert option MetaValues or hardcoded string -> lua values
	log = tonumber,
	-- ins = split,
	inx = function(val)
		local str = pd.utils.stringify(val)
		local todo = {}
		local word = "([^!@:]+)"
		for p in str:gsub("[,%s]+", " "):gmatch("%S+") do
			table.insert(todo, {
				p:match("^" .. word) or "", -- what to include
				p:match("!" .. word) or "", -- read as type
				p:match("@" .. word) or "", -- filter
				p:match(":" .. word) or "", -- element/how
			})
		end
		return todo
	end,
}
setmetatable(marshal, {
	__index = function()
		return pd.utils.stringify -- standard conversion
	end,
})

local hardcoded = {
	-- last resort for cb option resolution: cb -> meta.<cfg> -> defaults -> hardcoded
	-- note: values should have final (marshalled) form, otherwise lsp complains

	cid = "x", -- x marks the spot if cb has no identifier
	cfg = "", -- this codeblock's config in doc.meta.stitch.<cfg> (if any)
	arg = "", -- (extra) arguments to pass in to `cmd`-program on the cli (if any)
	dir = ".stitch", -- where to store files (abs/rel path to cwd)
	fmt = "png", -- format for images (if any)
	log = 0, -- log notification level
	-- ins = marshal.ins("cbx:fcb out:fcb err:fcb art:img"), -- "<file>[:type], .." -> ordered list of what to insert
	-- ^what:how!read@filter
	inc = "out:fcb cbx:fcb@debug art!markdown@my-filter err:fcb",
	-- expandables
	-- filename templates
	cbx = "#dir/#cid-#sha.cb", -- the codeblock.text as file on disk
	out = "#dir/#cid-#sha.out", -- capture of stdout (if any)
	err = "#dir/#cid-#sha.err", -- capture of stderr (if any)
	art = "#dir/#cid-#sha.#fmt", -- artifact (output) file (if any)
	-- expanded last
	cmd = "#cbx #art #arg 1>#out 2>#err", -- cmd template string, expanded last
}

-- Turn doc.meta data into a table of lua values
---@param elm any doc.meta, one of its elements or a regular lua-table
---@return table|string|nil regular table holding the metadata w/ lua values
local function metalua(elm)
	-- Meta = string indexed collection of MetaValues: (ie. a MetaMap)
	local ptype = pd.utils.type(elm)

	if "Meta" == ptype or "table" == ptype then
		local t = {}
		for k, v in pairs(elm) do
			t[k] = metalua(v)
		end
		return t
	elseif "List" == ptype or "Blocks" == ptype then
		local l = {}
		for _, v in ipairs(elm) do
			l[#l + 1] = metalua(v)
		end
		return l
	elseif "Inlines" == ptype or "string" == ptype then
		return pd.utils.stringify(elm)
	elseif "boolean" == ptype or "number" == ptype then
		return elm
	elseif "nil" == ptype then
		return nil
	else
		return F("%s, todo: %s", ptype, tostring(elm))
	end
end

-- converts (only) doc.meta to list of lines to complement `pandoc.write(doc, "native")`
---@param elm any doc.meta of one of its elements
---@param indent? number number of indent spaces, defaults to 0
---@param acc? table accumulator for lines, defaults to empty list
---@return table acc the list of lines describing docs.meta
local function meta2lines(elm, indent, acc)
	-- doc.meta is (potentially) part of a cb's options
	-- simple dump of doc.meta for debugging
	indent = indent or 0
	acc = acc or {}
	if #acc == 0 then
		elm.hardcoded = hardcoded
	end
	local tab = string.rep(" ", indent)
	local type_ = pd.utils.type(elm)

	if "Meta" == type_ or "table" == type_ then
		for k, v in pairs(elm) do
			acc[#acc + 1] = F("%s%s: ", tab, k)
			meta2lines(v, indent + 2, acc)
		end
	elseif "Inlines" == type_ or "List" == type_ then
		acc[#acc] = acc[#acc] .. "["
		for _, v in pairs(elm) do
			meta2lines(v, indent, acc)
		end
		acc[#acc] = acc[#acc]:gsub(",?%s*$", " ]")
	elseif "Inline" == type_ then
		acc[#acc] = acc[#acc] .. F(" %s, ", elm)
	elseif "number" == type_ or "string" == type_ or "boolean" == type_ then
		acc[#acc] = acc[#acc] .. F(" %q ", elm)
	else
		acc[#acc + 1] = F("unknown type %s %s", type_, tostring(elm))
	end
	return acc
end

--[[ file handling ]]

-- sha1 hash of (stitch) option values and codeblock text
---@param cb table a pandoc codeblock
---@param opts table the codeblocks options
---@return string sha1 hash of option values and codeblock content
local function mksha(cb, opts)
	-- sorting ensures repeatable fingerprints
	local keys = {}
	for key in pairs(hardcoded) do
		keys[#keys + 1] = key
	end
	table.sort(keys) -- sorts inplace

	-- fingerprint is hash on option values + cb.text
	local vals = {}
	for _, key in ipairs(keys) do
		vals[#vals + 1] = pd.utils.stringify(opts[key]):gsub("%s", "")
	end
	-- eliminate whitespace as well for repeatable fingerprints
	vals[#vals + 1] = cb.text:gsub("%s", "")

	return pd.utils.sha1(table.concat(vals, ""))
end

-- create the command to execute from `cb`
---@param cb table pandoc CodeBlock
---@return string|nil command system command and arguments to execute
---@return table|nil opts system command and arguments to execute
---@return string|nil error description of the error encountered
local function mkcmd(cb)
	local opts = M.options(cb)
	if not opts then
		return nil, nil, msg("error", "no options available for codeblock")
	end

	for _, fpath in ipairs({ "cbx", "out", "err", "art" }) do
		-- normalize turns '/' into platform dependent path separator
		local dir = pd.path.normalize(pd.path.directory(opts[fpath]))
		if not os.execute("mkdir -p " .. dir) then
			return nil, opts, msg("error", "could not create dir" .. dir)
		end
	end

	local fh = io.open(opts.cbx, "w")
	if not fh then
		return nil, opts, msg("error", "could not open file %s" .. opts.cbx)
	end
	if not fh:write(cb.text) then
		fh:close()
		return nil, opts, F("error", "could not write to %s" .. opts.cbx)
	end
	fh:close()

	if not os.execute("chmod u+x " .. opts.cbx) then
		return nil, opts, msg("error", "could not mark executable %s" .. opts.cbx)
	end

	-- expand cmd template string
	return opts.cmd:gsub("%#(%w+)", opts), opts
end

-- read file `name` and, possibly, convert to pandoc AST using `format`
---@param name string file to read
---@param format? string convert file data to AST using a pandoc reader ("" to skip)
---@return string|table? data file data, AST or nil (in case of errors)
local function fread(name, format)
	local ok, dta
	local fh, err = io.open(name, "r")

	if nil == fh then
		msg("error", err)
		return nil
	end

	dta = fh:read("*a")
	fh:close()
	msg("info", F("read %d bytes from: %s", #dta, name))

	if format and #format > 0 then
		ok, dta = pcall(pd.read, dta, format)
		if ok then
			return dta
		else
			msg("error", F("%s", dta))
			return nil
		end
	end

	return dta
end

-- run doc through lua filter(s), count how many were actually applied
---@param doc any file data, pandoc AST or nil
---@param filter string name of lua mod.fun to run (if any)
---@return string|table? doc the, possibly, modified doc
---@return number count the number of filters actually applied
local function fluaf(doc, filter)
	local count = 0
	local ok, filters, tmp
	if #filter == 0 then
		return doc, count
	end

	local mod, fun = filter:match("(%w+)%.?(%w*)")
	fun = #fun > 0 and fun or "Pandoc" -- default to mod.Pandoc
	ok, filters = pcall(require, mod)
	if not ok then
		msg("warn", F("skipping @%s: module %s not found", filter, mod))
		return doc, count
	elseif filters == true then
		msg("warn", F("skipping @%s: not a list of filters", filter))
		return doc, count
	end

	if doc and "Pandoc" == pd.utils.type(doc) then
		doc.meta.stitch = pd.MetaMap(ctx)
	end

	for n, f in ipairs(filters) do
		if f[fun] then
			ok, tmp = pcall(f[fun], doc)
			if not ok then
				msg("warn", F("ignoring results filter %s[%s].%s since it failed", mod, fun))
			else
				doc = tmp
				count = count + 1
			end
		else
			msg("warn", F("skipping filter %s[%d], function '%s' missing", mod, n, fun))
		end
	end
	return doc, count
end

-- save `doc` to given `fname`, except when it's an AST
---@param doc string|table? doc to be saved
---@param fname string filename to save doc with
---@return boolean ok success indicator
local function fsave(doc, fname)
	-- save doc to fname
	if "string" ~= type(doc) or #doc == 0 then
		msg("info", F("not writing doc (%s) to %s", type(doc), fname))
		return false
	end

	local fh = io.open(fname, "w")
	if nil == fh then
		msg("error", F("could not open %s for writing", fname))
		return false
	end

	local ok, err = fh:write(doc)
	fh:close()

	if not ok then
		msg("error", F("error writing to %s: %s", fname, err))
		return false
	end

	msg("debug", F("wrote %d bytes to %s", #doc, fname))
	return true
end

-- TODO
-- local function fsave(doc, name, filter?)
-- filter

-- wrap lines so they're less than `maxlen` long
---@param txt string text string whose lines are to be wrapped
---@param maxlen? number maxlen for a line (defaults to 65)
---@return string txt the wrapped text
local function wrap(txt, maxlen)
	-- may be use `:Open https://pandoc.org/lua-filters.html#pandoc.layout.render`
	-- instead?
	maxlen = maxlen or 65
	txt = txt or ""
	if #txt < maxlen + 1 then
		return txt
	end

	local lines = { "" }
	for chunk in txt:gmatch("%s*%S+") do
		-- for chunk in txt:gmatch("[, ]+[^, ]+") do
		if #lines[#lines] + #chunk < maxlen then
			lines[#lines] = lines[#lines] .. chunk
		else
			lines[#lines] = lines[#lines]
			lines[#lines + 1] = "  " .. chunk
		end
	end
	return table.concat(lines, "\n")
end
-- clones `cb`, removes stitch properties and adds a 'stitched' class
---@param cb table CodeBlock instance
---@param opts table the cb's stitch options
---@return table clone a new CodeBlock instance with only non-stitch attributes
local function mkfcb(cb, opts)
	-- `:Open https://pandoc.org/lua-filters.html#type-codeblock`
	-- `:Open https://pandoc.org/lua-filters.html#pandoc.CodeBlock`

	local clone = cb:clone()

	-- class stitch := stitched
	clone.classes = cb.classes:map(function(c)
		return c:gsub("^stitch$", "stitched")
	end)

	-- remove attributes present in opts
	for k, _ in pairs(cb.attributes) do
		if opts[k] then
			clone.attributes[k] = nil
		end
	end

	return clone
end

local mkins = {}
mkins._mt = {}
mkins._mt.__index = function(_, key)
	return function()
		return pd.Str(F("alas, unknown element '%s'", key))
	end
end
setmetatable(mkins, mkins._mt)

function mkins.cbx(cb, _, how)
	-- as fcb or ocb
	local ncb = cb:clone()
	if "fcb" == how then
		ncb.text = pd.write(pd.Pandoc({ cb }, {}))
	end
	return ncb
end

function mkins.out(cb, opts, _)
	local ncb = mkfcb(cb, opts)
	ncb.text = fread(opts.out) or "[stitch] stdout - no output"
	ncb.identifier = opts.cid .. "-stitched-out" or nil
	return ncb
end

function mkins.err(cb, opts, _)
	local ncb = mkfcb(cb, opts)
	ncb.text = wrap(fread(opts.err) or "[stitch] stderr - no output")
	ncb.identifier = opts.cid .. "-stitched-err" or nil
	return ncb
end

function mkins.art(cb, opts, how)
	local ncb = mkfcb(cb, opts)
	-- local title = cb.attributes.title or "no-title"
	local caption = pd.Str(cb.attributes.caption or "no-caption")
	ncb.identifier = opts.cid .. "-stitched-art" or nil
	local img = pd.Image({ caption }, opts.art)
	img = "fig" == how and pd.Figure(img, { caption }, ncb.attr) or img
	return img
end

-- create doc elements for codeblock
---@param cb table codeblock
---@param opts table codeblock options
---@return table result sequence of pandoc AST elements
local function result(cb, opts)
	local elms, count = {}, 0

	for _, elm in ipairs(parse_inc(opts.inc)) do
		local what, format, filter, how = table.unpack(elm)
		local doc = fread(opts[what], format)
		doc, count = fluaf(doc, filter)
		if count > 0 or true then
			-- a filter could post-process an image so save it, if applicable
			fsave(doc, opts[what])
		end

		local ncb = mkfcb(cb, opts)
		ncb.identifier = opts.cid .. "-stitched-" .. what -- TODO make unique
		if doc and "fcb" == how then
			if "Pandoc" == pd.utils.type(doc) then
				ncb.text = pd.write(doc, "native")
			else
				ncb.text = pd.write(pd.Pandoc({ cb }, {}))
			end
			elms[#elms + 1] = ncb
		elseif "img" == how then
			local title = ncb.attributes.title or ""
			elms[#elms + 1] = pd.Image({ ncb.attributes.caption }, opts[what], title, ncb.attr)
		elseif "fig" == how then
			local title = ncb.attributes.title or ""
			local img = pd.Image({ ncb.attributes.caption }, opts[what], title, ncb.attr)
			elms[#elms + 1] = pd.Figure(img, { ncb.attributes.caption }, ncb.attr)
		elseif doc and "" == how then
			if "Pandoc" == pd.utils.type(doc) then
				for _, block in ipairs(doc.blocks) do
					elms[#elms + 1] = block
				end
			else
				if "cbx" == what then
					msg("info", F("cbx has %d bytes", #doc))
				end
				ncb.text = doc
				elms[#elms + 1] = ncb
			end
		else
			msg("error", F("skipping '%s', no output was produced", what))
			elms[#elms + 1] = pd.Plain(F("directive '%s' either unknown or no output seen\n", what))
		end
	end

	return elms
end

--[[ option handling ]]

---@param cb table codeblock with `.stitch` class
---@return table|nil opts the `cb`-specific options, nil on errors
function M.options(cb)
	-- resolution: cb -> meta.stitch[cb.cfg] -> defaults -> hardcoded
	local opts = {}
	local expandables = { "cbx", "out", "err", "art", "cmd" } -- cmd must be last

	-- get the (known) stitch options present in cb.attributes
	local attr = cb.attributes
	for k, _ in pairs(hardcoded) do
		opts[k] = attr[k] and marshal[k](attr[k])
	end
	setmetatable(opts, { __index = ctx[opts.cfg] })

	-- options outside cb.attributes ("" is an absent identifier)
	opts.cid = #cb.identifier > 0 and cb.identifier or nil

	-- derived settings
	opts.sha = mksha(cb, opts) -- derived only

	-- expand cmd and filenames for this codeblock
	for _, k in ipairs(expandables) do
		opts[k] = opts[k]:gsub("%#(%w+)", opts)
	end

	-- check against circular refs
	for k, _ in pairs(hardcoded) do
		if "string" == type(opts[k]) and opts[k]:match("#%w+") then
			msg("error", F("option %s not entirely expanded: %s", k, opts[k]))
			return nil
		end
	end

	return opts
end

--- extract `doc.meta.stitch` config from a doc's meta block (if any)
---@param doc table the doc's AST
---@return table config doc.meta.stitch's named configs: option,value-pairs
function M.context(doc)
	-- resolution order: cb -> stitch[cb.cfg] -> defaults -> hardcoded

	ctx = {} -- reset
	for name, attr in pairs(doc.meta.stitch or {}) do
		ctx[name] = {}
		for k, _ in pairs(hardcoded) do
			ctx[name][k] = attr[k] and marshal[k](attr[k])
		end
	end

	-- defaults -> hardcoded
	local defaults = ctx.defaults or {}
	setmetatable(defaults, { __index = hardcoded })
	ctx.defaults = nil

	-- sections -> defaults -> hardcoded
	for _, attr in pairs(ctx) do
		setmetatable(attr, { __index = defaults })
	end

	-- missing ctx.keys also fallback to defaults -> hardcoded
	setmetatable(ctx, {
		__index = function()
			return defaults
		end,
	})

	return ctx
end

--[[ checks ]]
msg("info", F("PANDOC_VERSION %s", _ENV.PANDOC_VERSION)) -- 3.1.3
-- assert(PANDOC_API_VERSION >= {1, 23}, "need at least pandoc x.x.x")

---@poram cb a pandoc.CodeBlock
---@return any list of nodes in pandoc's AST
---@return string? err non-empty string in case of errors, or nil
function M.codeblock(cb)
	if not cb.classes:find("stitch") then
		return nil, nil -- noop
	end

	local cmd, opts, err = mkcmd(cb)
	if err then
		return nil, err
	end

	local ok, code, nr = os.execute(cmd)
	if not ok then
		return nil, msg("error", F("codeblock failed %s(%s): %s", code, nr, cmd))
	end

	return result(cb, opts or {})
end

local function pandoc(doc)
	-- process CodeBlocks, gather context first
	ctx = M.context(doc)
	print(metalua(doc.meta.stitch))
	msg("metalua", dump(metalua(doc.meta.stitch)))
	msg("ctx", dump(ctx))

	return doc:walk({ CodeBlock = M.codeblock })
end

-- TODO: for testing
-- * create stitch = M in table returned here
-- * busted then can use whatever we put in M

return {
	-- a filter is a list of filters
	-- traverse = "topdown" -- could be used to direct order of filters to run
	{ Pandoc = pandoc },
}
