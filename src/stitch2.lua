--[[ stich2 oo-reimplementation of stitch ]]
-- https://github.com/luarocks/lua-style-guide (3 spaces, yikes!)
-- * the larger the scope, the more descriptive the name should be
-- * i for numeric index in loops
-- * use better names than k,v unless working with generic tables
-- * Classes use CamelCase
-- * has_, hasnt_, is_, isnt_ for bool funcs
-- * create tables with their population, e.g. hard_coded = { a = 1, b =2 }

-- initiatlize only once (load vs require)
if package.loaded.stitch2 then return package.loaded.stitch2 end

--[[- handles ]]
local pd = _ENV.pandoc -- if nil, we're not being loaded by pandoc
local sf = string.format
local hard_coded = { log = 'info', a = 1, b = 2, c = 3, d = 4, e = 5 }
local dump = require 'dump' -- tmp: delme
--[[- logging -]]
local log_level = { silent = 0, error = 1, warn = 2, note = 3, info = 4, debug = 5 }
local mod_log = { opt = { log = 'warn', id = 'mod' } }

--- Prints formatted message to stdout
--- @param kb table identity sending the log, must have kb.opt.log and kb.opt.id fields
--- @param topic string short description of topic (8 chars or so)
--- @param msg string message format string
local function log(kb, tier, topic, msg, ...)
  -- [stitch:depth] who topic| msg
  local opt = kb.opt or {}
  local show = log_level[opt.log] or 0
  if (log_level[tier] or 0) > show then return end
  local src = opt.cid or 'unknown'
  local entry = sf('[stitch:%s %7s]', 0, tier)
  local reason = sf(' %-7s %8s| ', src, topic)
  io.output():write(entry, reason, sf(msg, ...), '\n')
end

--[[-- pandoc AST helpers --]]
local parse_by = {} -- forward declaration

--- Converts pandoc AST element `elm` to a regular Lua table
--
-- It converts `Inlines` back to string, eliminates `function` fields and
-- ignores any metatables.  Set `detail` to true to also parse `Inlines`,
-- retain function fields and add a map at index `[0]` with the objects' lua
-- and pandoc type, as well as `'%p`' formatted string for the object.  Still
-- ignores metatables though.
--- @param elm table
--- @param detail boolean?
--- @param seen table?
--- @return table
local function elm_to_lua(elm, detail, seen)
  seen = seen or {}
  detail = detail and true or false
  local t = detail and { [0] = { pandoc = pd.utils.type(elm), lua = type(elm), pointer = sf('%p', elm) } } or {}
  for k, v in pairs(elm) do
    if seen[v] then return { [k] = sf('<cyclic: %s>', v) } end
    seen[v] = 'table' == type(v) and v
    seen[v] = v
    local parse = parse_by[pd.utils.type(v)] or parse_by[type(v)]
    t[k] = parse and parse(v, detail, seen) -- or nil -> ignored
  end
  return t
end

parse_by = { -- index by type(elm)
  -- pandoc type(s)
  ['Inlines'] = function(v, d, s)
    return (d and elm_to_lua(v, d, s)) or pd.write(pd.Pandoc({ v }), 'markdown'):sub(1, -2)
  end,

  -- lua types (nil, thread, number are Lua tables are handled as well)
  ['nil'] = function() return nil end,
  thread = function() return nil end,
  table = function(v, d, s) return elm_to_lua(v, d, s) end,
  userdata = function(v, d, s) return elm_to_lua(v, d, s) end,
  ['function'] = function(v, d) return d and v or nil end,
  string = function(v) return v end,
  boolean = function(v) return v end,
  number = function(v) return v end,
}

--[[- State ]]

local state = {
  count_cb = 0,
  count_hdr = 0,
  ctx = nil, -- context of current document
  ccb = nil, -- current codeblock
  his = {}, -- previous codeblock's
}

function state:set_cb(ccb)
  print(self, ccb)
  self.his[ccb.cid or self.count_cb] = ccb
  self.count_cb = self.count_cb + 1
  return ccb
end

--[[-- doc options --]]

--- Returns an options table for given `doc`, based on `doc.meta.stitch`.
---
--- Options can be listed in `doc.meta.stitch` under some name, respresenting
--- external tools used in, or a class of, codeblocks.  A `defaults` section
--- will be promoted to metatable for all named section tables.  If one is
--- not defined, it will be created.  In both cases, the default table itself
--- has the hardcoded option table as its own metatable.
---
--- The name `stitch` is for stitch itself.  These options can either be
--- listed directly under `doc.meta.stitch` or under their own `stitch`
--- subsection.  In both cases they'll end up in the `stitch`-subsection.
---
--- Additionally, the doc's `title`, `author` and `date` are also stored under
--- `opt.meta` for convenience and keep it all in one table.
---
--- So, resolution order is: opt.section?.x -> defaults.x -> hard_coded.x
--- @param doc table
--- @return table
local function doc_options(doc)
  local meta = elm_to_lua(doc.meta) --- @cast meta table
  local opt = meta.stitch or {} -- toplevel meta.stitch
  opt.stitch = opt.stitch or {} -- ensure meta.stitch.stitch collector
  local defaults = opt.defaults or {} -- no defaults means hardcoded will provide

  setmetatable(defaults, { __index = hard_coded })
  setmetatable(opt, { __index = function() return defaults end })

  opt.defaults = nil
  for name, section in pairs(opt) do
    if 'table' == type(section) then
      setmetatable(section, { __index = defaults })
    else
      print('moving opt', name, section)
      opt.stitch[name] = section -- aka opt[name] is a value, not table
      opt[name] = nil
    end
  end

  opt.meta = {
    title = meta.title,
    author = meta.author,
    date = meta.date,
  }

  return opt
end

--[[- KodeBlock ]]
local function run_noop(self) print(self, sf('run noop %s', self.opts.exe)) end
local kb = {
  run = setmetatable({}, { __index = function() return run_noop end }),
}

function kb:new(cb)
  -- TODO:
  -- [ ] get config section name -> that's your metatable
  -- [ ] res. order new.opt.x -> ctx[id].x -> ctx[class ..].x -> defaults -> hardcoded?
  local ccb = elm_to_lua(cb)
  local oid = ccb.attr.identifier
  local cfg = ccb.attr.attributes.stitch -- 1. stitch=name
  cfg = cfg or rawget(state.ctx, oid) and oid -- 2. or #id -> a ctx.name
  for _, v in ipairs(ccb.attr.classes) do
    cfg = cfg or rawget(state.ctx, v) and v -- 3. or first class to match
  end
  cfg = cfg or 'defaults' -- 4. alas it's going to be defaults
  local new = {
    cfg = cfg,
    cls = ccb.attr.classes,
    ocb = cb,
    oid = ccb.attr.identifier,
    opt = setmetatable(ccb.attr.attributes, { __index = state.ctx[cfg] }),
    txt = ccb.text,
  }

  self.__index = self
  setmetatable(new, self)
  return new
end

--[[- kb:run ]]
function kb.run.yes(self) print(self, 'run yes') end
function kb.run.no(self) print(self, 'run no') end
function kb.run.maybe(self) print(self, 'run maybe') end
function kb.run.chunk(self) print(self, 'run chunk') end
function kb.run.unknown(self) print(self, 'run chunk') end

--[[- kb:<funcs> ]]
function kb:execute() return self.run[self.opts.exe](self) end

-- return list of table t and its subsequent metatables (if any)
function kb:chain(tbl, acc)
  if nil == tbl then return acc end
  if 'table' ~= type(tbl) then return acc end
  acc = acc or {}
  acc[#acc + 1] = tbl
  return self:chain((getmetatable(tbl) or {}).__index, acc)
end

-- return all option keys
function kb:options()
  local keys = {}
  for _, tbl in ipairs(self:chain(self.opts)) do
    for k, _ in pairs(tbl) do
      keys[#keys + 1] = k
    end
  end
  return keys
end

--[[- STITCH ]]

local function CodeBlock(cb)
  local ccb = kb:new(cb)
  print('kb', cb, ccb)
  state:set_cb(ccb)
  -- print('cb', dump(elm_to_lua(cb, true)))
  for k, v in pairs(hard_coded) do
    print(k, ccb.opt[k], 'ctx is', state.ctx[ccb.cfg][k], 'hard is', v)
  end
  return nil
end

local function Pandoc(doc)
  print('ICU-C-ME')
  state.ctx = doc_options(doc)

  local rv = doc:walk({ CodeBlock = CodeBlock })
  print('state', dump(state))
  return rv
end

--[[- shenanigens ]]

package.loaded.stitch2 = { { Pandoc = Pandoc } }

if pd then
  if _ENV.PANDOC_VERSION >= { 3, 5 } then
    -- single filters will become the norm
    package.loaded.stitch2 = { Pandoc = Pandoc }
  end
end
return package.loaded.stitch2
