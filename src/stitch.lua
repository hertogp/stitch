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
-- * pandoc -v -> ~/.local/share/pandoc = pandoc user data directory
--   + filters placed here will be found by pandoc (TODO: test)
--   + at moment ~/.local/share/pandoc/filters/ is being used
-- * pd.system.os () -> for checking OS type
-- * pd.system.list_directory('dir') (v2.19)
-- * pd.system.make_directory('dir/subdir', true) (v2.19)
-- * pd.system.remove_directory('dir) (v2.19)
-- * Pandoc 3.5 2024-10-04
-- `:Open https://github.com/jgm/pandoc/blob/main/changelog.md#pandoc-35-2024-10-04`
--  + pandoc 3.5 allows for single filter (table) to be returned
--  + return { Pandoc = my_func(doc) }
--  + returned filter should not contain numeric indices or it might still be
--    treated as a list of filters.
--
--  OTHER PROJECTS
--  * `:Open https://github.com/jgm/pandoc/blob/main/doc/extras.md`
--  * `:Open https://github.com/LaurentRDC/pandoc-plot/tree/master`
--  * `:Open https://github.com/pandoc/lua-filters` (older repo)

local I = {} -- Stitch's Implementation; a table nables testing

I.ctx = {} -- this doc's context (= meta.stitch)
I.opts = { log = "info" } --> set per cb being processed
I.level = {
	silent = 0,
	error = 1,
	warn = 2,
	info = 3,
	debug = 4,
}

I.optvalues = {
	-- valid option values
	exe = { "yes", "no", "maybe" },
	log = { "silent", "error", "warn", "info", "debug" },
}

I.hardcoded = {
	-- resolution order: cb -> meta.<cfg> -> defaults -> hardcoded
	cid = "x", -- x marks the spot if cb has no identifier
	cfg = "", -- name of config section in doc.meta.stitch.<cfg> (if any)
	arg = "", -- (extra) arguments to pass in to `cmd`-program on the cli (if any)
	dir = ".stitch", -- where to store files (abs or rel path to cwd)
	fmt = "png", -- format for images (if any)
	log = "info", -- debug, error, warn, info, silent
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
	-- [stitch level] (action cb_id) msg .. (need to validate opts.log value)
	if (self.level[I.opts.log] or 1) >= self.level[lvl] then
		local fmt = "[stitch %5s] %s %-7s| " .. tostring(msg) .. "\n"
		local text = string.format(fmt, lvl, I.opts.cid or "mod", action, ...)
		io.stderr:write(text)
	end
end

--[[ options ]]

-- parse `I.opts.inc` into list: {{what, format, filter, how}, ..}
---@param str string the I.opts.inc string with include directives
---@return table directives list of 4-element lists of strings
function I:parse_inc(str)
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
	self:log("debug", "include", "include found %s inc's in '%s'", #todo, str)
	return todo
end

-- extract specific data from ast elements into lua table(s)
---@param elm any either `doc.blocks`, `doc.meta` or a `CodeBlock`
---@return any regular table holding the metadata as lua values
function I:metalua(elm)
	-- note: metalua(doc.blocks) -> list of cb tables.
	local ptype = pd.utils.type(elm)
	if "Meta" == ptype or "table" == ptype or "AttributeList" == ptype then
		local t = {}
		for k, v in pairs(elm) do
			t[k] = self:metalua(v)
		end
		return t
	elseif "List" == ptype or "Blocks" == ptype then
		local l = {}
		for _, v in ipairs(elm) do
			l[#l + 1] = self:metalua(v)
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
			classes = self:metalua(elm.classes),
			attributes = {},
		}
		for k, v in pairs(elm.attributes) do
			t.attributes[k] = self:metalua(v)
		end
		return t
	elseif "CodeBlock" == elm.tag then
		-- a CodeBlock's type is actually 'Block'
		return {
			text = elm.text,
			attr = self:metalua(elm.attr),
		}
	else
		self:log("error", "meta", "option unknown type '%s'? for %s", ptype, tostring(elm))
		return nil
	end
end

--[[ files ]]

-- sha1 hash of (stitch) option values and codeblock text
---@param cb table a pandoc codeblock
---@return string sha1 hash of option values and codeblock content
function I:mksha(cb)
	-- sorting ensures repeatable fingerprints
	local keys = {}
	for key in pairs(self.hardcoded) do
		keys[#keys + 1] = key
	end
	table.sort(keys) -- sorts inplace

	-- fingerprint is hash on option values + cb.text
	local vals = {}
	for _, key in ipairs(keys) do
		vals[#vals + 1] = pd.utils.stringify(self.opts[key]):gsub("%s", "")
	end
	-- eliminate whitespace as well for repeatable fingerprints
	vals[#vals + 1] = cb.text:gsub("%s", "")

	return pd.utils.sha1(table.concat(vals, ""))
end

-- create conditions for codeblock execution and set I.opts.exe
---@param cb table pandoc codeblock
---@return boolean ok success indicator
function I:mkcmd(cb)
	-- create dirs for cb's possible output files
	for _, fpath in ipairs({ "cbx", "out", "err", "art" }) do
		-- `normalize` (v2.12) makes dir platform independent
		local dir = pd.path.normalize(pd.path.directory(self.opts[fpath]))
		if not os.execute("mkdir -p " .. dir) then
			self:log("error", "cmd", "cbx could not create dir" .. dir)
			return false
		end
	end

	-- cb.text becomes executable on disk (TODO:
	-- if not flive(fname) then .. else I:log(reuse) end
	local fh = io.open(self.opts.cbx, "w")
	if not fh then
		self:log("error", "cmd", "cbx could not open file: " .. self.opts.cbx)
		return false
	end
	if not fh:write(cb.text) then
		fh:close()
		self:log("error", "cmd", "cbx could not write to: " .. self.opts.cbx)
		return false
	end
	fh:close()

	-- review: not platform independent
	-- * this fails on Windows where I.opts.cbx should be a bat file
	-- * maybe check *.bat and skip?  Or just try & warn if not successful
	-- package.config:sub(1,1) -> \ for windows, / for others
	if not os.execute("chmod u+x " .. self.opts.cbx) then
		self:log("error", "cmd", "cbx could not mark executable: " .. self.opts.cbx)
		return false
	end

	-- review: check expanse complete, no more #<names> left?
	self:log("info", "cmd", "expanding '%s'", self.opts.cmd)
	self.opts.cmd = I.opts.cmd:gsub("%#(%w+)", self.opts)
	self:log("info", "cmd", "expanded to '%s'", self.opts.cmd)
	return true
end

-- says whether given `filename` is real on disk or not
---@param filename string path to a file
---@return boolean exists true or false
function I:freal(filename)
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
function I:fread(name, format)
	local ok, dta
	local fh, err = io.open(name, "r")

	if nil == fh then
		self:log("error", "read", "%s %s", name, err)
		return nil
	end

	dta = fh:read("*a")
	fh:close()
	self:log("debug", "read", "%s, %d bytes", name, #dta)

	if format and #format > 0 then
		ok, dta = pcall(pd.read, dta, format)
		if ok then
			return dta
		else
			self:log("error", "read", "pandoc.read as %s failed: %s", format, dta)
			return nil
		end
	end

	return dta
end

-- save `doc` to given `fname`, except when it's an ast
---@param doc string|table? doc to be saved
---@param fname string filename to save doc with
---@return boolean ok success indicator
function I:fsave(doc, fname)
	if "string" ~= type(doc) then
		self:log("info", "write", "%s, skip writing data of type '%s'", fname, type(doc))
		return false
	end

	-- save doc to fname (even if doc is 0 bytes)
	local fh = io.open(fname, "w")
	if nil == fh then
		self:log("error", "write", "%s, unable to open for writing", fname)
		return false
	end

	local ok, err = fh:write(doc)
	fh:close()

	if not ok then
		self:log("error", "write", "%s, error: %s", fname, err)
		return false
	end

	self:log("debug", "write", "%s, %d bytes", fname, #doc)
	return true
end

-- says whether cb-executable file and 1 or more outputs already exist or not
---@return boolean deja_vu true or false
function I:deja_vu()
	-- if cbx exist with 1 or more ouputs, we were here before
	-- REVIEW: should take I.opts.inc's what into account and check all of them?
	-- * an output file not included in I.opts.inc is never created(!)
	-- * you want to catch when 1 or more artifacts were removed somehow

	if self:freal(self.opts.cbx) then
		if self:freal(self.opts.out) or self:freal(self.opts.err) or self:freal(self.opts.art) then
			return true
		end
	end
	return false
end

--[[ AST elements ]]

-- clones `cb`, removes stitch properties, adds a 'stitched' class
---@param cb table a codeblock instance
---@return table clone a new codeblock instance
function I:mkfcb(cb)
	local clone = cb:clone()

	clone.classes = cb.classes:map(function(class)
		return class:gsub("^stitch$", "stitched")
	end)

	-- remove attributes present in I.opts
	for k, _ in pairs(cb.attributes) do
		if self.opts[k] then
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
function I:xform(doc, filter)
	local count = 0
	local ok, filters, tmp
	if #filter == 0 then
		return doc, count
	end

	local mod, fun = filter:match("(%w+)%.?(%w*)")
	fun = #fun > 0 and fun or "pandoc" -- default to mod.pandoc
	ok, filters = pcall(require, mod)
	if not ok then
		self:log("warn", "xform", "skip @%s: module %s not found", filter, mod)
		return doc, count
	elseif filters == true then
		self:log("warn", "xform", "skip @%s: not a list of filters", filter)
		return doc, count
	end

	if doc and "Pandoc" == pd.utils.type(doc) then
		doc.meta.stitch = pd.metamap(I.ctx)
	end

	for n, f in ipairs(filters) do
		if f[fun] then
			ok, tmp = pcall(f[fun], doc)
			if not ok then
				self:log("warn", "xform", "filter '%s[%s].%s', failed, filter ignored", mod, n, fun)
			else
				doc = tmp
				count = count + 1
			end
		else
			self:log("warn", "xform", "filter '%s[%d].%s', '%s' not found, filter ignored", mod, n, fun)
		end
	end
	return doc, count
end

-- create doc elements for codeblock
---@param cb table codeblock
---@return table result sequence of pandoc ast elements
function I:result(cb)
	local elms, count = {}, 0

	for idx, elm in ipairs(self:parse_inc(self.opts.inc)) do
		local what, format, filter, how = table.unpack(elm)
		local fname = self.opts[what]
		if fname then
			local doc = self:fread(self.opts[what], format)
			doc, count = self:xform(doc, filter)
			if count > 0 or true then
				-- a filter could post-process an image so save it, if applicable
				self:fsave(doc, self.opts[what])
			end

			-- NOTE:
			-- * when result is Blocks, maybe use pandoc.structure.make_sections(blocks)
			--   to insert numbered sections in AST using options to control numbering?
			-- * pandoc.structure.table_of_contents (?)
			local ncb = self:mkfcb(cb)
			local title = ncb.attributes.title or ""
			local caption = ncb.attributes.caption
			local elmid = string.format("%s-%d-%s", self.opts.cid, idx, what)
			ncb.identifier = elmid
			if "fcb" == how and "Pandoc" == pd.utils.type(doc) then
				self:log("info", "include", "id %s, '%s:%s', data as native ast", elmid, what, how)
				ncb.text = pd.write(doc, "native")
				elms[#elms + 1] = ncb
			elseif "fcb" == how and "cbx" == what then
				self:log("info", "include", "id %s, '%s:%s', cb in a fenced codeblock", elmid, what, how)
				ncb.text = pd.write(pd.Pandoc({ cb }, {}))
				elms[#elms + 1] = ncb
			elseif "fcb" == how then
				-- everthing else simply goes inside fcb as text
				self:log("info", "include", "id %s, inc '%s:%s', data in a fcb", elmid, what, how)
				ncb.text = doc
				elms[#elms + 1] = ncb
			elseif "img" == how then
				-- `:Open https://github.com/pandoc/lua-filters/blob/master/diagram-generator/diagram-generator.lua#L365`
				self:log("info", "include", "id %s, inc '%s:%s', image %s", elmid, what, how, fname)
				elms[#elms + 1] = pd.Image({ caption }, fname, title, ncb.attr)
			elseif "fig" == how then
				self:log("info", "include", "id %s, inc '%s:%s', figure", elmid, what, how, fname)
				local img = pd.Image({ caption }, fname, title, ncb.attr)
				elms[#elms + 1] = pd.Figure(img, { caption }, ncb.attr)
			elseif doc and "" == how then
				-- output elements cbx, out, err, art without a how
				if "Pandoc" == pd.utils.type(doc) then
					-- an ast by default has its individual blocks inserted
					self:log("info", "include", "id %s, inc '%s:%s', ast blocks", elmid, what, how)
					if doc.blocks[1].attr then
						doc.blocks[1].identifier = ncb.identifier -- or blocks[1].attr = ncb.attr
						doc.blocks[1].classes = ncb.classes
					end
					for _, block in ipairs(doc.blocks) do
						elms[#elms + 1] = block
					end
				else
					-- doc is raw data and inserted as a div
					self:log("info", "include", "id %s, inc '%s:%s', data as div", elmid, what, how)
					elms[#elms + 1] = pd.Div(doc, ncb.attr)
				end
			else
				-- todo: never reached?
				self:log("error", "include", "skip id %s, inc '%s:%s' data is '%s'", elmid, what, how, doc)
				elms[#elms + 1] = pd.Div(
					string.format("<stitch> id %s, %s:%s: unknown or no output seen", elmid, what, how),
					ncb.attr
				)
			end
		else
			self:log("error", "include", "skip id %s, invalid directive inc '%s:%s'", self.opts.cid, what, how)
		end
	end

	return elms
end

--[[ context & cb ]]

-- check values for given `opts`, removes those that are illegal
---@param opts table single k,v store of options
---@return table opts same table with illegal options removed
function I:validate(section, opts)
	for k, valid in pairs(self.optvalues) do
		local v = opts[k]
		if v and #v > 0 and not pd.List.includes(valid, v, 1) then
			local need = table.concat(valid, ", ")
			opts[k] = nil
			self:log("error", "meta", "%s.%s='%s' ignored, need one of: %s", section, k, v, need)
		end
	end
	return opts
end

---sets I.opts for the current codeblock
---@param cb table codeblock with `.stitch` class (or not)
---@return boolean ok success indicator
function I:options(cb)
	-- resolution: cb -> meta.stitch[cb.cfg] -> defaults -> hardcoded
	self.opts = self:metalua(cb.attributes)
	self.opts = self:validate("cb.attr", self.opts)
	setmetatable(self.opts, { __index = self.ctx[self.opts.cfg] })

	-- additional options ("" is an absent identifier)
	self.opts.cid = #cb.identifier > 0 and cb.identifier or nil
	self.opts.sha = self:mksha(cb) -- derived only

	-- expand filenames for this codeblock (cmd is expanded as exe later)
	local expandables = { "cbx", "out", "err", "art" }
	for _, k in ipairs(expandables) do
		self.opts[k] = self.opts[k]:gsub("%#(%w+)", self.opts)
	end

	-- check against circular refs
	for k, _ in pairs(self.hardcoded) do
		if "cmd" ~= k and "string" == type(self.opts[k]) and self.opts[k]:match("#%w+") then
			self:log("error", "options", "%s not entirely expanded: %s", k, I.opts[k])
			return false
		end
	end

	print("cb.log", self.opts.log)

	return true
end

--- extract `doc.meta.stitch` config from a doc's meta block (if any)
---@param doc table the doc's ast
---@return table config doc.meta.stitch's named configs: option,value-pairs
function I:setup(doc)
	-- pickup named cfg sections in meta.stitch, resolution order:
	-- I.opts (cb) -> I.ctx (stitch[cb.cfg]) -> defaults -> hardcoded
	self.ctx = self:metalua(doc.meta.stitch or {}) or {} -- REVIEW: last or {} needed?

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

	defaults = self:validate("defaults", defaults)
	for section, map in pairs(self.ctx) do
		self.ctx[section] = self:validate(section, map)
	end

	return self.ctx
end

---@poram cb a pandoc.codeblock
---@return any list of nodes in pandoc's ast
function I.codeblock(cb)
	if not cb.classes:find("stitch") then
		return nil
	end

	-- TODO: also check self.opts.exe
	if I:options(cb) and I:mkcmd(cb) then
		if I:deja_vu() then
			I:log("info", "result", "%s, re-using existing files", I.opts.cid)
		else
			local ok, code, nr = os.execute(I.opts.cmd)
			if not ok then
				I:log("error", "result", "fail %s, execute failed with %s(%s): %s", I.opts.cid, code, nr, I.opts.cmd)
				return nil
			end
		end
	end
	return I:result(cb)
end

--[[ filter ]]

-- pandoc.Figure was introduced in pandoc version 3 (TODO: check)
-- `:Open https://github.com/jgm/pandoc/blob/main/changelog.md#pandoc-30-2023-01-18`
--  + Pandoc 3.0 introduces pandoc.Figure element
I:log("info", "check", "PANDOC_VERSION %s", _ENV.PANDOC_VERSION) -- 3.1.3
I:log("info", "check", string.format("running on %s", pd.system.os))
print("are we good?", _ENV.PANDOC_VERSION >= { 3, 0 })

local Stitch = {
	_ = I, -- Stitch's implementation: for testing only

	Pandoc = function(doc)
		-- alt: if Pandoc" == pd.utils.type(doc) then return .. else return I end
		I:setup(doc)
		return doc:walk({ CodeBlock = I.codeblock })
	end,
}

-- return Stitch --<-- requires pandoc 3.5
return {
	Stitch,
}
