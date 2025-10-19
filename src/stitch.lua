-- stitch turns codeblocks into images, figures, codeblocks and more

local M = {} -- returned by global Stitch() for testing

local ctx = {} -- holds meta.stitch configuration for current document

local hardcoded = {
	-- last resort for cb option resolution: cb -> meta.<cfg> -> defaults -> hardcoded

	cfg = "", -- this codeblock's config in doc.meta.stitch.<cfg> (if any)
	prg = "", -- program name to run, "" means cb itself
	arg = "", -- (extra) arguments to pass in to `cmd`-program on the cli (if any)
	dir = ".stitch", -- where to store files (abs/rel path to cwd)
	fmt = "png", -- format for images (if any)
	log = 0, -- log notification level
	ins = "cb:fcb out:fcb err:fcb art:img", -- "<file>[:type], .." -> ordered list of what to insert
	inc = "cb:fcb out!markdown@filter err:fcb@meta",
	cmd = "#prg #arg 1>#out 2>#err", -- cmd template string, expanded last
}

--[[ helpers ]]

local dump = require("dump") -- tmp, delme
local format = string.format
local F = string.format
local pd = require("pandoc")

-- converts (only) doc.meta to list of lines to complement `pandoc.write(doc, "native")`
---@param elm any doc.meta of one of its elements
---@param indent? number number of indent spaces, defaults to 0
---@param acc? table accumulator for lines, defaults to empty list
---@return table acc the list of lines describing docs.meta
local function meta2lines(elm, indent, acc)
	-- maybe do `doc.meta.hardcoded = hardcoded` before calling meta2lines(doc.meta)
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
	sep = string.format("[%s]+%%s*", sep or ",") --> [sep]+%s*

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

--[[ stitch options ]]

local marshal = {
	-- convert options from pandoc AST -> lua values
	log = tonumber,
	ins = split,
	inc = function(val)
		local str = pd.utils.stringify(val)
		local todo = {}
		local word = "([^!@:]+)"
		for p in str:gsub("[,%s]+", " "):gmatch("%S+") do
			table.insert(todo, {
				what = p:match("^" .. word),
				read = p:match("!" .. word),
				fltr = p:match("@" .. word),
				elem = p:match(":" .. word),
			})
		end
		print("inc decode", val, dump(todo))
		return todo
	end,
}
setmetatable(marshal, {
	__index = function()
		return pd.utils.stringify -- standard conversion
	end,
})

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
	local fp = {}
	for _, key in ipairs(keys) do
		fp[#fp + 1] = pd.utils.stringify(opts[key]):gsub("%s", "")
	end
	-- ignore whitespace in codeblock (only)
	fp[#fp + 1] = cb.text:gsub("%s", "")

	return pd.utils.sha1(table.concat(fp, ""))
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
		fh:close()
		return nil, format("[error] could not write to %s", opts.inp)
	end
	fh:close()

	-- make executable
	if not os.execute("chmod u+x " .. opts.inp) then
		return nil, format("[error] could not make executable %s", opts.inp)
	end

	-- interpolate & finalize the runnable command
	local tmp = opts.cmd:gsub("%#(%w+)", opts)
	print("cmd org", opts.cmd)
	print("cmd exp", tmp)
	return opts.cmd:gsub("%#(%w+)", opts)
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

-- wrap lines so they're less than `maxlen` long
---@param txt string text string whose lines are to be wrapped
---@param maxlen? number maxlen for a line (defaults to 65)
---@return string txt the wrapped text
local function wrap(txt, maxlen)
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
		return pd.Str(format("alas, unknown element '%s'", key))
	end
end
setmetatable(mkins, mkins._mt)

function mkins.cb(cb, _, how)
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
	local title = cb.attributes.title or "no-title"
	local caption = pd.Str(cb.attributes.caption or "no-caption")
	ncb.identifier = opts.cid .. "-stitched-art" or nil
	local img = pd.Image({ caption }, opts.art)
	img = "fig" == how and pd.Figure(img, { caption }, ncb.attr) or img
	return img
end

local function result(cb, opts)
	-- insert document pieces as per opts.ins
	local elms = {}
	print("dump opts", dump(opts))
	for _, v in ipairs(split(opts.ins, ",%s")) do
		local elm, how = table.unpack(split(v, ":"))
		print("result insert", elm, how)
		elms[#elms + 1] = mkins[elm](cb, opts, how)
	end

	print("dump opts.inc", dump(opts.inc))
	for k, v in pairs(opts.inc) do
		print("#" .. (cb.cid or "nil"), k, dump(v))
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
	local cbfiles = {
		-- filename templates, TODO: this is not platform independant (pathsep "/")
		inp = "#dir/#cid-#sha.cb", -- the codeblock.text as file on disk
		out = "#dir/#cid-#sha.stdout", -- capture of stdout
		err = "#dir/#cid-#sha.stderr", -- capture of stderr
		art = "#dir/#cid-#sha.#fmt", -- artifact (output) file (if any)
	}

	-- only known stitch options
	for k, _ in pairs(hardcoded) do
		opts[k] = attr[k] and marshal[k](attr[k]) -- cannot do: or marshal[k](hard)
		print("options added", k, dump(opts[k]))
	end

	-- cb opts falls back to ctx[cfg] or defaults (if cfg not present)
	setmetatable(opts, { __index = ctx[opts.cfg] })

	-- set cb specific, non-hardcoded options (incl. filenames)
	opts.cid = cb.identifier or "x"
	-- opts.cid = #opts.cid > 0 and opts.cid or "x"
	opts.sha = mksha(cb, opts)

	-- add and expand the filenames for this codeblock
	for k, v in pairs(cbfiles) do
		opts[k] = v:gsub("%#(%w+)", opts):gsub("^-", "")
	end

	-- todo: now opts has attr keys + filename keys, but:
	-- * cmd needs expanding too
	-- * hardcoded contains unmarshalled values
	-- * later on, its unclear whether an option value has been expanded
	--   or not -> gives rise to errors, e.g. with inc: "string" vs its
	--   expanded value of a list of table { {what:.., read: .., ..}, .. }
	-- * to resolve this:
	--   1.a. copy attr[k] to options
	--     b. setmetatable to stitch[cfg]
	--   2. copy cbfiles to options
	--   3. run through hardcoded and add key, expanded values
	--   -> that way, options has *all* key, expanded values and no need for
	--      falling back anymore.  Then you don't need

	return opts
end

--- extract `doc.meta.stitch` config from a doc's meta block (if any)
---@param doc table the doc's AST
---@return table config doc.meta.stitch's named configs: option,value-pairs
function M.context(doc)
	-- resolution order: cb -> meta.stitch[cb.cfg] -> defaults -> hardcoded
	-- uses hardcoded keys to only extract stitch options

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

	-- missing -> defaults -> hardcoded
	setmetatable(ctx, {
		__index = function()
			-- ctx.missing_key -> defaults table
			return defaults
		end,
	})

	return ctx -- section|missing -> defaults -> hardcoded
end

--[[ checks ]]
-- `:Open https://pandoc.org/lua-filters.html#global-variables`
-- `:Open https://pandoc.org/lua-filters.html#type-version`
print("PANDOC_VERSION", _ENV.PANDOC_VERSION) -- 3.1.3

---@poram cb pandoc.CodeBlock
function M.codeblock(cb)
	print("CodeBlock id", cb.identifier)
	if not cb.classes:find("stitch") then
		return nil -- keep cb as-is
	end

	local opts = M.options(cb)
	print("codeblock opts", dump(opts))

	local cmd, err = mkcmd(cb, opts)
	if not cmd then
		print(err)
		return nil
	end

	-- execute
	print("execute", cmd)
	local ok, code, nr = os.execute(cmd)
	if not ok then
		print(format("[error] codeblock failed %s(%s): %s", code, nr, cmd))
	end

	return result(cb, opts)
end

function Pandoc(doc)
	ctx = M.context(doc)
	doc:walk({ CodeBlock = M.codeblock })
	return nil
	-- return doc:walk({ CodeBlock = M.codeblock })
end

function Busted()
	-- only meant for testing with busted
	M.hardcoded = hardcoded
	M.ctx = ctx
	return M
end
