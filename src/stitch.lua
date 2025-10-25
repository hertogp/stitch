--[[ stitch ]]
-- TODO:
-- * add option value checker for reporting errors in stitch option values
-- * add old = "keep|purge|move"-flag for previous (old) files named id-<old sha>.*
-- * -or advise to set path's to .stitch/tmp for files that can be removed
-- * check utf8 requirements (if any)
-- * add all functions to S so they can be tested { {Pandoc=S.Pandoc}, [0] = S}
-- * add pandoc version check, see (vx.yz) or pd.xx funcs to check
-- * add hardcoded.cbc = 0, cb count, "cb"..I.opts.cbc is fallback for I.opts.cid
-- * add mediabag to store files related to cb's
-- * add Code handler to insert pieces of a CodeBlock
--
-- NOTES:
-- * pd.system.os () -> for checking OS type
-- * pd.system.list_directory('dir') (v2.19)
-- * pd.system.make_directory('dir/subdir', true) (v2.19)
-- * pd.system.remove_directory('dir) (v2.19)

local I = {} -- implementation for Stitch

I.ctx = {} --> set per doc, holds meta.stitch (i.e. per doc)
I.opts = { log = "info" } --> set per cb being processed
I.level = {
	silent = 0,
	error = 1,
	warn = 2,
	info = 3,
	debug = 4,
}

I.optvalues = {
	-- list possible values for some of the options (for error reporting)
	exe = { "yes", "no", "maybe" },
}

I.hardcoded = {
	-- resolution order: cb -> meta.<cfg> -> defaults -> hardcoded (last resort)
	cid = "x", -- x marks the spot if cb has no identifier
	cfg = "", -- name of config section in doc.meta.stitch.<cfg> (if any)
	arg = "", -- (extra) arguments to pass in to `cmd`-program on the cli (if any)
	dir = ".stitch", -- where to store files (abs or rel path to cwd)
	fmt = "png", -- format for images (if any)
	log = "error", -- debug, error, warn, info, silent
	exe = "maybe", -- yes, no, maybe
	-- include directives, format is "^what:how!format[+extensions]@filter[.func]"
	inc = "cbx:fcb out:fcb art:img err:fcb",
	-- expandable filenames
	cbx = "#dir/cbx/#cid-#sha.cb", -- the codeblock.text as file on disk
	out = "#dir/out/#cid-#sha.out", -- capture of stdout (if any)
	err = "#dir/err/#cid-#sha.err", -- capture of stderr (if any)
	art = "#dir/#cid-#sha.#fmt", -- artifact (output) file (if any)
	-- command must be expanded last
	cmd = "#cbx #arg #art 1>#out 2>#err", -- cmd template string, expanded last
	-- bash: $@ is list of args, ${@: -1} is last argument
}

--[[ helpers ]]

-- local dump = require("dump") -- tmp, delme
local pd = require("pandoc")

function I:log(lvl, action, msg, ...)
	-- [stitch level] (action cb_id) msg ..
	if self.level[I.opts.log] >= self.level[lvl] then
		local logfmt = "[stitch %5s] (%s %7s) " .. tostring(msg) .. "\n"
		local text = string.format(logfmt, lvl, I.opts.cid or "mod", action, ...)
		io.stderr:write(text)
	end
end

--[[ options ]]

-- parse `I.opts.inc` into list: {{what, format, filter, how}, ..}
---@param str string the I.opts.inc string with include directives
---@return table directives list of 4-element lists of strings
function I.parse_inc(str)
	-- what:how!format+extensions@module.function
	local todo = {}
	local part = "([^!@:]+)"
	str = pd.utils.stringify(str) -- just in case
	for p in str:gsub("[,%s]+", " "):gmatch("%S+") do
		todo[#todo + 1] = {
			p:match("^" .. part) or "", -- what to include
			p:match("!" .. part) or "", -- read as type
			p:match("@" .. part) or "", -- filter
			p:match(":" .. part) or "", -- element/how
		}
	end
	I:log("debug", "include", "include found %s inc's in '%s'", #todo, str)
	return todo
end

-- extract specific data from ast elements into lua table(s)
---@param elm any either `doc.blocks`, `doc.meta` or a `CodeBlock`
---@return any regular table holding the metadata as lua values
local function metalua(elm)
	-- note: metalua(doc.blocks) -> list of cb tables.
	local ptype = pd.utils.type(elm)
	if "Meta" == ptype or "table" == ptype or "AttributeList" == ptype then
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
	elseif "attr" == ptype then
		local t = {
			identifier = elm.identifier,
			classes = metalua(elm.classes),
			attributes = {},
		}
		for k, v in pairs(elm.attributes) do
			t.attributes[k] = metalua(v)
		end
		return t
	elseif "CodeBlock" == elm.tag then
		-- a CodeBlock's type is actually 'Block'
		return {
			text = elm.text,
			attr = metalua(elm.attr),
		}
	else
		I:log("error", "meta", "option unknown type '%s'? for %s", ptype, tostring(elm))
		return nil
	end
end

--[[ files ]]

-- sha1 hash of (stitch) option values and codeblock text
---@param cb table a pandoc codeblock
---@return string sha1 hash of option values and codeblock content
local function mksha(cb)
	-- sorting ensures repeatable fingerprints
	local keys = {}
	for key in pairs(I.hardcoded) do
		keys[#keys + 1] = key
	end
	table.sort(keys) -- sorts inplace

	-- fingerprint is hash on option values + cb.text
	local vals = {}
	for _, key in ipairs(keys) do
		vals[#vals + 1] = pd.utils.stringify(I.opts[key]):gsub("%s", "")
	end
	-- eliminate whitespace as well for repeatable fingerprints
	vals[#vals + 1] = cb.text:gsub("%s", "")

	return pd.utils.sha1(table.concat(vals, ""))
end

-- create conditions for codeblock execution and set I.opts.exe
---@param cb table pandoc codeblock
---@return boolean ok success indicator
local function mkcmd(cb)
	-- create dirs for cb's possible output files
	for _, fpath in ipairs({ "cbx", "out", "err", "art" }) do
		-- `normalize` (v2.12) makes dir platform independent
		local dir = pd.path.normalize(pd.path.directory(I.opts[fpath]))
		if not os.execute("mkdir -p " .. dir) then
			I:log("error", "cmd", "cbx could not create dir" .. dir)
			return false
		end
	end

	-- cb.text becomes executable on disk (TODO:
	-- if not flive(fname) then .. else I:log(reuse) end
	local fh = io.open(I.opts.cbx, "w")
	if not fh then
		I:log("error", "cmd", "cbx could not open file: " .. I.opts.cbx)
		return false
	end
	if not fh:write(cb.text) then
		fh:close()
		I:log("error", "cmd", "cbx could not write to: " .. I.opts.cbx)
		return false
	end
	fh:close()

	-- review: not platform independent
	-- * this fails on Windows where I.opts.cbx should be a bat file
	-- * maybe check *.bat and skip?  Or just try & warn if not successful
	-- package.config:sub(1,1) -> \ for windows, / for others
	if not os.execute("chmod u+x " .. I.opts.cbx) then
		I:log("error", "cmd", "cbx could not mark executable: " .. I.opts.cbx)
		return false
	end

	-- review: check expanse complete, no more #<names> left?
	I:log("info", "cmd", "expanding '%s'", I.opts.cmd)
	I.opts.cmd = I.opts.cmd:gsub("%#(%w+)", I.opts)
	I:log("info", "cmd", "expanded as '%s'", I.opts.cmd)
	return true
end

-- says whether given `filename` is real on disk or not
---@param filename string path to a file
---@return boolean exists true or false
local function freal(filename)
	local f = io.open(filename, "r")
	if f then
		f:close()
		return true
	end
	return false
end

-- read file `name` and, possibly, convert to pandoc ast using `format`
---@param name string file to read
---@param format? string convert file data to ast using a pandoc reader ("" to skip)
---@return string|table? data file data, ast or nil (in case of errors)
local function fread(name, format)
	local ok, dta
	local fh, err = io.open(name, "r")

	if nil == fh then
		I:log("error", "read", "%s %s", name, err)
		return nil
	end

	dta = fh:read("*a")
	fh:close()
	I:log("info", "read", "%s, %d bytes", name, #dta)

	if format and #format > 0 then
		ok, dta = pcall(pd.read, dta, format)
		if ok then
			return dta
		else
			I:log("error", "read", "pandoc.read as %s failed: %s", format, dta)
			return nil
		end
	end

	return dta
end

-- save `doc` to given `fname`, except when it's an ast
---@param doc string|table? doc to be saved
---@param fname string filename to save doc with
---@return boolean ok success indicator
local function fsave(doc, fname)
	if "string" ~= type(doc) then
		I:log("info", "write", "%s, skip writing data of type '%s'", fname, type(doc))
		return false
	end

	-- save doc to fname (even if doc is 0 bytes)
	local fh = io.open(fname, "w")
	if nil == fh then
		I:log("error", "write", "%s, unable to open for writing", fname)
		return false
	end

	local ok, err = fh:write(doc)
	fh:close()

	if not ok then
		I:log("error", "write", "%s, error: %s", fname, err)
		return false
	end

	I:log("debug", "write", "%s, %d bytes", fname, #doc)
	return true
end

-- says whether cb-executable file and 1 or more outputs already exist or not
---@return boolean deja_vu true or false
local function deja_vu()
	-- if cbx exist with 1 or more ouputs, we were here before
	-- REVIEW: should take I.opts.inc's what into account and check all of them?
	-- * an output file not included in I.opts.inc is never created(!)
	-- * you want to catch when 1 or more artifacts were removed somehow

	if freal(I.opts.cbx) then
		if freal(I.opts.out) or freal(I.opts.err) or freal(I.opts.art) then
			return true
		end
	end
	return false
end

-- clones `cb`, removes stitch properties, adds a 'stitched' class
---@param cb table a codeblock instance
---@return table clone a new codeblock instance
local function mkfcb(cb)
	local clone = cb:clone()

	clone.classes = cb.classes:map(function(class)
		return class:gsub("^stitch$", "stitched")
	end)

	-- remove attributes present in I.opts
	for k, _ in pairs(cb.attributes) do
		if I.opts[k] then
			clone.attributes[k] = nil
		end
	end

	return clone
end

-- run doc through lua filter(s), count how many were actually applied
---@param doc any file data, pandoc ast or nil
---@param filter string name of lua mod.fun to run (if any)
---@return string|table? doc the, possibly, modified doc
---@return number count the number of filters actually applied
local function xform(doc, filter)
	local count = 0
	local ok, filters, tmp
	if #filter == 0 then
		return doc, count
	end

	local mod, fun = filter:match("(%w+)%.?(%w*)")
	fun = #fun > 0 and fun or "pandoc" -- default to mod.pandoc
	ok, filters = pcall(require, mod)
	if not ok then
		I:log("warn", "xform", "skip @%s: module %s not found", filter, mod)
		return doc, count
	elseif filters == true then
		I:log("warn", "xform", "skip @%s: not a list of filters", filter)
		return doc, count
	end

	if doc and "Pandoc" == pd.utils.type(doc) then
		doc.meta.stitch = pd.metamap(I.ctx)
	end

	for n, f in ipairs(filters) do
		if f[fun] then
			ok, tmp = pcall(f[fun], doc)
			if not ok then
				I:log("warn", "xform", "filter '%s[%s].%s', failed, filter ignored", mod, n, fun)
			else
				doc = tmp
				count = count + 1
			end
		else
			I:log("warn", "xform", "filter '%s[%d].%s', '%s' not found, filter ignored", mod, n, fun)
		end
	end
	return doc, count
end

--[[ ast ]]

-- create doc elements for codeblock
---@param cb table codeblock
---@return table result sequence of pandoc ast elements
local function result(cb)
	local elms, count = {}, 0

	for idx, elm in ipairs(I.parse_inc(I.opts.inc)) do
		local what, format, filter, how = table.unpack(elm)
		local fname = I.opts[what]
		if fname then
			local doc = fread(I.opts[what], format)
			doc, count = xform(doc, filter)
			if count > 0 or true then
				-- a filter could post-process an image so save it, if applicable
				fsave(doc, I.opts[what])
			end

			-- elms[#elsm+1] = mkelm(doc, cb, I.opts, what, how) -- nil is noop
			local ncb = mkfcb(cb)
			local title = ncb.attributes.title or ""
			local caption = ncb.attributes.caption
			local elmid = string.format("%s-%d-%s", I.opts.cid, idx, what)
			ncb.identifier = elmid
			if "fcb" == how and "Pandoc" == pd.utils.type(doc) then
				I:log("debug", "include", "include %s, '%s:%s', data as native ast", elmid, what, how)
				ncb.text = pd.write(doc, "native")
				elms[#elms + 1] = ncb
			elseif "fcb" == how and "cbx" == what then
				I:log("debug", "include", "include %s, '%s:%s', cb in a fenced codeblock", elmid, what, how)
				ncb.text = pd.write(pd.Pandoc({ cb }, {}))
				elms[#elms + 1] = ncb
			elseif "fcb" == how then
				-- everthing else simply goes inside fcb as text
				I:log("debug", "include", "include %s, inc '%s:%s', data in a fcb", elmid, what, how)
				ncb.text = doc
				elms[#elms + 1] = ncb
			elseif "img" == how then
				I:log("debug", "include", "include %s, inc '%s:%s', image %s", elmid, what, how, fname)
				elms[#elms + 1] = pd.Image({ caption }, fname, title, ncb.attr)
			elseif "fig" == how then
				I:log("debug", "include", "include %s, inc '%s:%s', figure", elmid, what, how, fname)
				local img = pd.Image({ caption }, fname, title, ncb.attr)
				elms[#elms + 1] = pd.Figure(img, { caption }, ncb.attr)
			elseif doc and "" == how then
				-- output elements cbx, out, err, art without a how
				if "Pandoc" == pd.utils.type(doc) then
					-- an ast by default has its individual blocks inserted
					I:log("debug", "include", "include %s, inc '%s:%s', ast blocks", elmid, what, how)
					if doc.blocks[1].attr then
						doc.blocks[1].identifier = ncb.identifier -- or blocks[1].attr = ncb.attr
						doc.blocks[1].classes = ncb.classes
					end
					for _, block in ipairs(doc.blocks) do
						elms[#elms + 1] = block
					end
				else
					-- doc is raw data and inserted as a div
					I:log("debug", "include", "include %s, inc '%s:%s', data as div", elmid, what, how)
					elms[#elms + 1] = pd.Div(doc, ncb.attr)
				end
			else
				-- todo: never reached?
				I:log("error", "include", "skip %s, inc '%s:%s' data is '%s'", elmid, what, how, doc)
				elms[#elms + 1] =
					pd.Div(string.format("<stitch> %s, %s:%s: unknown or no output seen", elmid, what, how), ncb.attr)
			end
		else
			I:log("error", "include", "skip %s, invalid directive inc '%s:%s'", I.opts.cid, what, how)
		end
	end

	return elms
end

--[[ context & cb ]]

---sets I.opts for the current codeblock
---@param cb table codeblock with `.stitch` class (or not)
---@return boolean ok success indicator
local function mkopt(cb)
	-- resolution: cb -> meta.stitch[cb.cfg] -> defaults -> hardcoded
	I.opts = metalua(cb.attributes)
	setmetatable(I.opts, { __index = I.ctx[I.opts.cfg] })

	-- additional options ("" is an absent identifier)
	I.opts.cid = #cb.identifier > 0 and cb.identifier or nil
	I.opts.sha = mksha(cb) -- derived only

	-- expand filenames for this codeblock (cmd is expanded as exe later)
	local expandables = { "cbx", "out", "err", "art" }
	for _, k in ipairs(expandables) do
		I.opts[k] = I.opts[k]:gsub("%#(%w+)", I.opts)
	end

	-- check against circular refs
	for k, _ in pairs(I.hardcoded) do
		if "cmd" ~= k and "string" == type(I.opts[k]) and I.opts[k]:match("#%w+") then
			I:log("error", "options", "%s not entirely expanded: %s", k, I.opts[k])
			return false
		end
	end

	return true
end

--- extract `doc.meta.stitch` config from a doc's meta block (if any)
---@param doc table the doc's ast
---@return table config doc.meta.stitch's named configs: option,value-pairs
function I:mkctx(doc)
	-- pickup named cfg sections in meta.stitch, resolution order:
	-- I.opts (cb) -> I.ctx (stitch[cb.cfg]) -> defaults -> hardcoded
	self.ctx = metalua(doc.meta.stitch or {}) or {}

	-- defaults -> hardcoded
	local defaults = self.ctx.defaults or {}
	setmetatable(defaults, { __index = I.hardcoded })
	self.ctx.defaults = nil

	-- sections -> defaults -> hardcoded
	for _, attr in pairs(self.ctx) do
		setmetatable(attr, { __index = defaults })
	end

	-- missing I.ctx.keys also fallback to defaults -> hardcoded
	setmetatable(self.ctx, {
		__index = function()
			return defaults
		end,
	})

	return self.ctx
end

---@poram cb a pandoc.codeblock
---@return any list of nodes in pandoc's ast
function I.codeblock(cb)
	if not cb.classes:find("stitch") then
		return nil
	end

	-- TODO: check I.opts.exe to decide what to do & return (if anything)
	if mkopt(cb) and mkcmd(cb) then
		if deja_vu() then
			I:log("info", "result", "%s, re-using existing files", I.opts.cid)
		else
			local ok, code, nr = os.execute(I.opts.cmd)
			if not ok then
				I:log("error", "result", "fail %s, execute failed with %s(%s): %s", I.opts.cid, code, nr, I.opts.cmd)
				return nil
			end
		end
	end
	return result(cb)
end

--[[ main ]]

I:log("info", "check", "PANDOC_VERSION %s", _ENV.PANDOC_VERSION) -- 3.1.3
I:log("info", "check", string.format("OS is %s", pd.system.os))
-- assert(pandoc_api_version >= {1, 23}, "need at least pandoc x.x.x")
-- pandoc.Figure was introduced in pandoc version 3 (TODO: check)
print("are we good?", _ENV.PANDOC_VERSION >= { 1, 23 })

local Stitch = {
	_ = I, -- make actual implementation available for testing

	Pandoc = function(doc)
		I:mkctx(doc)
		return doc:walk({ CodeBlock = I.codeblock })
	end,
}

-- Lua filters are tables with element names as keys and values
-- consisting of functions acting on those elements.
--
-- Yet: `return Stitch` doesn't work?  Maybe my pandoc version (3.1.3)
-- is too old for that.

return {
	Stitch,
}
