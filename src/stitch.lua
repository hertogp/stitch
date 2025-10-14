local M = {} -- returned by global Stitch() for testing

local ctx = {} -- holds meta.stitch configuration

local hardcoded = {
	-- codeblock option resolution order: cb -> meta.<cfg> -> defaults -> hardcoded

	cfg = "", -- this codeblock's config in doc.meta.stitch.<cfg> (if any)
	prg = "", -- program name to run, "" means cb itself
	arg = "", -- (extra) arguments to pass in to `cmd`-program on the cli (if any)
	dir = ".stitch", -- where to store files (abs/rel path to cwd)
	fmt = "png", -- format for images (if any)
	log = 0, -- log notification level
	ins = "cb:fcb out:fcb err:fcb art:img oops", -- "<file>[:type], .." -> ordered list of what to insert
	cmd = "#prg #arg #art 1>#out 2>#err", -- cmd template string, expanded last
}

local hardfiles = {
	-- filename templates, TODO: this is not platform independant
	inp = "#dir/#cid-#sha.cb", -- the codeblock.text as file on disk
	out = "#dir/#cid-#sha.stdout", -- capture of stdout
	err = "#dir/#cid-#sha.stderr", -- capture of stderr
	art = "#dir/#cid-#sha.#fmt", -- artifact (output) file (if any)
}

--Notes:
--bash -x hash.cb --> shows what happens on stderr

--[[ helpers ]]

local dump = require("dump")
local format = string.format
local pd = {
	stringify = require("pandoc.utils").stringify,
	type = require("pandoc.utils").type,
	sha1 = require("pandoc.utils").sha1,
	path = require("pandoc").path,
	sys = require("pandoc.system"),
	read = require("pandoc").read,
	CodeBlock = require("pandoc").CodeBlock,
	pdoc = require("pandoc"),
}

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
	local ptype = pd.type(val)
	sep = string.format("[%s]+%%s*", sep or ",") --> [sep]+%s*

	if ptype == "List" or ptype == "table" then
		-- keep stringified entries in table or a List of Inlines
		for _, v in ipairs(val) do
			parts[#parts + 1] = trim(pd.stringify(v))
		end
	else
		-- everything else (incl. a single Inline) gets stringified and split
		-- for part in stringify(val):gsub(",%s*", ","):gmatch("[^,]+") do
		for part in pd.stringify(val):gsub(sep, ","):gmatch("[^,]+") do
			parts[#parts + 1] = trim(part)
		end
	end
	return parts
end

--[[ stitch options ]]

local marshal = {
	-- convert options from pandoc AST -> lua values
	log = tonumber,
	ins = split,
}
setmetatable(marshal, {
	__index = function()
		return pd.stringify -- standard conversion
	end,
})

--[[ file handling ]]

-- -- filepath based on cb hash, options and desired extension
-- ---@param cb table pandoc's CodeBlock
-- ---@param opts table options derived from cb's attrributes, meta & defaults
-- ---@param ext? string|nil desired file extension (if any)
-- ---@return string path for a desired file
-- local function fname(cb, opts, ext)
-- 	ext = #ext > 0 and "." .. ext or ".cb"
-- 	-- use cached hash or created it on first call to fname
-- 	-- opts.sha = opts.sha or mksha(cb, opts)
-- 	-- local base = pd.path.join({ opts.dir, opts.hash })
-- 	local base = pd.path.join({ opts.dir, opts.sha })
-- 	return string.format("%s%s", base, ext)
-- end
--
-- -- checks if a path on the system exists or not
-- ---@param path string directory or file to check
-- ---@return boolean ok true if `path` exists, false otherwise
-- local function exists(path)
-- 	return true == os.rename(path, path) -- returns true or nil, msg
-- end
--
-- -- create working directory for a codeblock, using its options
-- ---@param opts table codeblock options
-- ---@return boolean ok true if succesful, false otherwise
-- local function mkdir(opts)
-- 	if exists(opts.dir) or os.execute("mkdir -p " .. opts.dir) then
-- 		return true
-- 	end
--
-- 	return false
-- end

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

	-- fingerprint is hash on option values + cb.text
	local fp = {}
	table.sort(keys) -- eliminate random key order
	for _, key in ipairs(keys) do
		fp[#fp + 1] = pd.stringify(opts[key])
	end
	-- ignore whitespace in codeblock (only)
	fp[#fp + 1] = cb.text:gsub("%s", "")

	return pd.sha1(pd.stringify(fp))
end

-- create the command to execute
---@param cb table pandoc CodeBlock
---@param opts table cb's options
---@return string|nil command system command and arguments to execute
---@return string|nil error error description (if any, nil otherwise)
local function mkcmd(cb, opts)
	-- cmd gets expanded last since it may use any of the dynamic opts
	if #opts.prg == 0 then
		opts.prg = opts.inp -- no prg defined, the cb will be the executable
	end

	-- make the dir
	if not os.execute("mkdir -p " .. opts.dir) then
		return nil, format("[error] could not create dir %s", opts.dir)
	end

	-- open file for cb.text
	local fh = io.open(opts.inp, "w")
	if not fh then
		return nil, format("[error] could not open %s for writing", opts.inp)
	end

	-- write out cb.text (i.e the codeblock)
	if not fh:write(cb.text) then
		return nil, format("[error] could not write to %s", opts.inp)
	end
	fh:close()

	-- make executable
	if not os.execute("chmod u+x " .. opts.inp) then
		return nil, format("[error] could not make executable %s", opts.inp)
	end

	-- interpolate & finalize the runnable command
	local cmd = opts.cmd:gsub("%#(%w+)", opts) -- maybe error check here?
	return opts.cmd:gsub("%#(%w+)", opts) -- maybe error check here?
end

-- returns file contents of file `opts[key]` or nil on empty file
---@param path string opts field that denotes file to read
---@return string|nil data file contents or nil if file has no data
local function fread(path)
	local fh = io.open(path, "r")

	if fh then
		local txt = fh:read("a")
		fh:close()
		if #txt > 0 then
			return txt
		end
	end

	return nil
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

local mkres = {
	-- functin signature (cb, opts, opt)
	cb = function(cb, _, opt)
		local ncb = cb:clone()
		if "fcb" == opt then
			ncb.text = pd.pdoc.write(pd.pdoc.Pandoc({ cb }, {}))
		else
			ncb = cb:clone()
		end
		return ncb
	end,

	out = function(cb, opts, _)
		local ncb = mkfcb(cb, opts)
		local txt = fread(opts.out)
		ncb.text = txt or "[stitch] stdout - no output"
		ncb.identifier = opts.cid .. "-stitched-out" or nil
		return ncb
	end,

	err = function(cb, opts, _)
		local ncb = mkfcb(cb, opts)
		local txt = fread(opts.err)
		ncb.text = txt or "[stitch] stderr - no output"
		ncb.identifier = opts.cid .. "-stitched-err" or nil
		return ncb
	end,

	art = function(cb, opts, _)
		local ncb = mkfcb(cb, opts)
		local caption = cb.attributes.caption or ""
		ncb.identifier = opts.cid .. "-stitched-art" or nil
		local img = pd.pdoc.Image(caption, opts.art, ncb.attributes.title, ncb.attr)
		return img
	end,
}

setmetatable(mkres, {
	__index = function(_, key)
		return function()
			return pd.pdoc.Str(format("alas, unknown element '%s'", key))
		end
	end,
})

local function result(cb, opts)
	-- insert pieces as per opts.ins
	local elms = {}
	for _, v in ipairs(split(opts.ins, ",%s")) do
		local elm, opt = table.unpack(split(v, ":"))
		elms[#elms + 1] = mkres[elm](cb, opts, opt)
	end

	-- TODO: maybe put rv in a para or put all elements in their own para
	-- with class stitched-{out, err, art}  (cb org is kept as-is, no changes)
	return elms
end

--[[ option handling ]]

-- `:Open https://yaml.org/spec/1.2/spec.html`
-- `:Open https://pandoc.org/lua-filters.html#type-attr`
-- `:Open https://pandoc.org/MANUAL.html#extension-header_attributes`
-- `:Open https://pandoc.org/MANUAL.html#extension-backtick_code_blocks`

---@param cb table pandoc codeblock with `.stitch` class
---@return table opts option,value store derived from codeblock `cb`
function M.options(cb)
	local opts = {}
	local attr = cb.attributes or cb

	-- only known stitch options
	for k, _ in pairs(hardcoded) do
		opts[k] = attr[k] and marshal[k](attr[k])
	end

	-- cb opts falls back to ctx[cfg] or defaults (if cfg not present)
	setmetatable(opts, { __index = ctx[opts.cfg] })

	-- set cb specific, non-stitch options
	opts.cid = cb.identifier or ""
	opts.cid = #opts.cid > 0 and opts.cid or "x"
	opts.sha = mksha(cb, opts)

	-- derive the filenames
	for k, v in pairs(hardfiles) do
		opts[k] = v:gsub("%#(%w+)", opts):gsub("^-", "")
	end

	return opts
end

--- extract `doc.meta.stitch` config from a doc's meta block (if any)
---@param doc table the doc's AST
---@return table config doc.meta.stitch's named configs: option,value-pairs
function M.context(doc)
	-- resolution order: cb -> meta[cb.cfg] -> defaults -> hardcoded

	ctx = {} -- reset
	for name, attr in pairs(doc.meta.stitch or {}) do
		ctx[name] = {}
		-- only known stich options
		for k, _ in pairs(hardcoded) do
			ctx[name][k] = attr[k] and marshal[k](attr[k])
		end
	end

	-- defaults fallback to hardcoded
	local defaults = ctx.defaults or {}
	setmetatable(defaults, { __index = hardcoded })

	-- named ctxpcfg] section falls back to defaults
	ctx.defaults = nil
	for _, attr in pairs(ctx) do
		setmetatable(attr, { __index = defaults })
	end

	-- missing ctx[cfg] section falls back to defaults
	setmetatable(ctx, {
		__index = function()
			return defaults
		end,
	})

	return ctx -- make available for testing
end
--[[ checks ]]
-- `:Open https://pandoc.org/lua-filters.html#global-variables`
-- `:Open https://pandoc.org/lua-filters.html#type-version`
-- print("PANDOC_VERSION", PANDOC_VERSION) -- 3.1.3

---@poram cb pandoc.CodeBlock
function M.codeblock(cb)
	if not cb.classes:find("stitch") then
		return nil -- keep cb as-is
	end

	local opts = M.options(cb)

	local cmd, err = mkcmd(cb, opts)
	if not cmd then
		print(err)
		return nil
	end

	-- execute
	local ok, code, nr = os.execute(cmd)
	if not ok then
		print(format("[error] codeblock failed %s(%s): %s", code, nr, cmd))
	end

	return result(cb, opts)
end

function Pandoc(doc)
	ctx = M.context(doc)
	return doc:walk({ CodeBlock = M.codeblock })
end

function Busted()
	-- only meant for testing with busted
	M.hardcoded = hardcoded
	M.ctx = ctx
	return M
end
