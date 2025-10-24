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

local function dbg(level, fmt, ...)
	local text = F("[stitch](%s) " .. fmt .. "\n", level, ...)
	io.stderr:write(text)
	return text
end

--[[ stitch options ]]

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

local hardcoded = {
	-- resolution order: cb -> meta.<cfg> -> defaults -> hardcoded (last resort)
	cid = "x", -- x marks the spot if cb has no identifier
	cfg = "", -- name of config section in doc.meta.stitch.<cfg> (if any)
	arg = "", -- (extra) arguments to pass in to `cmd`-program on the cli (if any)
	dir = ".stitch", -- where to store files (abs or rel path to cwd)
	fmt = "png", -- format for images (if any)
	log = "error", -- debug, info, warn[ing], error
	-- include directives, format is "^what:how!format[+extensions]@filter[.func]"
	inc = "cbx:fcb out:fcb art:img err:fcb",
	-- expandable filenames
	cbx = "#dir/#cid-#sha.cb", -- the codeblock.text as file on disk
	out = "#dir/#cid-#sha.out", -- capture of stdout (if any)
	err = "#dir/#cid-#sha.err", -- capture of stderr (if any)
	art = "#dir/#cid-#sha.#fmt", -- artifact (output) file (if any)
	-- command must be expanded last
	cmd = "#cbx #arg #art 1>#out 2>#err", -- cmd template string, expanded last
	-- bash: $@ is list of args, ${@: -1} is last argument
}

-- Extract specific data from AST elements into lua table(s)
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
	elseif "Attr" == ptype then
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
		-- a CodeBlock's type is actually 'Block' (and it's not the only one)
		return {
			text = elm.text,
			attr = metalua(elm.attr),
		}
	else
		print("metalua", F("%s, todo: %s", ptype, tostring(elm)))
		return nil
	end
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
			msg("error", F("pandoc reader: %s", dta))
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
				msg("warn", F("ignoring filter '%s[%s].%s' since it failed", mod, n, fun))
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

-- clones `cb`, removes its stitch properties, adds a 'stitched' class
---@param cb table a CodeBlock instance
---@param opts table the cb's stitch options
---@return table clone a new CodeBlock instance
local function mkfcb(cb, opts)
	local clone = cb:clone()

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

-- create doc elements for codeblock
---@param cb table codeblock
---@param opts table codeblock options
---@return table result sequence of pandoc AST elements
local function result(cb, opts)
	local elms, count = {}, 0

	for idx, elm in ipairs(parse_inc(opts.inc)) do
		local what, format, filter, how = table.unpack(elm)
		local fname = opts[what]
		if fname then
			local doc = fread(opts[what], format)
			doc, count = fluaf(doc, filter)
			if count > 0 or true then
				-- a filter could post-process an image so save it, if applicable
				fsave(doc, opts[what])
			end

			-- elms[#elsm+1] = mkelm(doc, cb, opts, what, how) -- nil is noop
			local ncb = mkfcb(cb, opts)
			local title = ncb.attributes.title or ""
			local caption = ncb.attributes.caption
			local elmid = F("%s-%d-%s", opts.cid, idx, what)
			ncb.identifier = elmid
			if "fcb" == how and "Pandoc" == pd.utils.type(doc) then
				msg("debug", F("%s, '%s:%s': include doc as AST (native)", elmid, what, how))
				ncb.text = pd.write(doc, "native")
				elms[#elms + 1] = ncb
			elseif "fcb" == how and "cbx" == what then
				msg("debug", F("%s, '%s:%s': include cb as fenced codeblock", elmid, what, how))
				ncb.text = pd.write(pd.Pandoc({ cb }, {}))
				elms[#elms + 1] = ncb
			elseif "fcb" == how then
				-- everthing else simply goes inside fcb as text
				msg("debug", F("%s, '%s:%s': include doc as-is in fcb", elmid, what, how))
				ncb.text = doc
				elms[#elms + 1] = ncb
			elseif "img" == how then
				msg("debug", F("%s, '%s:%s': include doc as Image", elmid, what, how))
				elms[#elms + 1] = pd.Image({ caption }, fname, title, ncb.attr)
			elseif "fig" == how then
				msg("debug", F("%s, '%s:%s': include doc as Figure", elmid, what, how))
				local img = pd.Image({ caption }, fname, title, ncb.attr)
				elms[#elms + 1] = pd.Figure(img, { caption }, ncb.attr)
			elseif doc and "" == how then
				-- output elements cbx, out, err, art without a how
				if "Pandoc" == pd.utils.type(doc) then
					-- an AST by default has its individual blocks inserted
					msg("debug", F("%s, '%s:%s': include doc's AST blocks as-is", elmid, what, how))
					if doc.blocks[1].attr then
						doc.blocks[1].identifier = ncb.identifier -- or blocks[1].attr = ncb.attr
						doc.blocks[1].classes = ncb.classes
					end
					for _, block in ipairs(doc.blocks) do
						elms[#elms + 1] = block
					end
				else
					-- doc is raw data and inserted as a Div
					msg("debug", F("%s, '%s:%s': include doc as Div", elmid, what, how))
					msg("info", F("include '%s': doc included Div (default)", what))
					elms[#elms + 1] = pd.Div(doc, ncb.attr)
				end
			else
				-- TODO: never reached?
				msg("error", F("%s, '%s:%s', include skipped: doc is %s", elmid, what, how, doc))
				elms[#elms + 1] = pd.Div(F("directive '%s': unknown or no output seen", what), ncb.attr)
			end
		else
			msg("error", F("skipping '%s': not a valid codeblock output (in: %s)", what, opts.inc))
		end
	end

	return elms
end

--[[ option handling ]]

---@param cb table codeblock with `.stitch` class
---@return table|nil opts the `cb`-specific options, nil on errors
function M.options(cb)
	-- resolution: cb -> meta.stitch[cb.cfg] -> defaults -> hardcoded
	local expandables = { "cbx", "out", "err", "art", "cmd" } -- cmd must be last
	local opts = metalua(cb.attributes)
	setmetatable(opts, { __index = ctx[opts.cfg] })

	-- additional options ("" is an absent identifier)
	opts.cid = #cb.identifier > 0 and cb.identifier or nil -- fallback to hardcoded
	opts.sha = mksha(cb, opts) -- derived only

	-- expand filenames and then cmd for this codeblock
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
	ctx = metalua(doc.meta.stitch or {}) or {}

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
	return doc:walk({ CodeBlock = M.codeblock })
end

-- TODO: for testing
-- * create local S = {} w/ all stitch func/data in it
-- * return { {Pandoc = pandoc}, 0 = S } }

return {
	-- a filter is a list of filters
	-- traverse = "topdown" -- could be used to direct order of filters to run
	{ Pandoc = pandoc },
}
