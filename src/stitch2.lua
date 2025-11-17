--[[ stich2 oo-reimplementation of stitch ]]
-- https://github.com/luarocks/lua-style-guide (3 spaces, yikes!)
-- * the larger the scope, the more descriptive the name should be
-- * i for numeric index in loops
-- * use better names than k,v unless working with generic tables
-- * Classes use CamelCase
-- * has_, hasnt_, is_, isnt_ for bool funcs
-- * create tables with their population, e.g. hard_coded = { a = 1, b =2 }
--
-- Guidelines
-- * function return result -or- result/nil, error
-- * small functions donot log, just yield results
-- * classes that instantiate are Capatalized, otherwise all lower case
-- * large scopes means longer names
-- * keep local var declaration close to their use

-- initiatlize only once (load vs require)
if package.loaded.stitch2 then return package.loaded.stitch2 end

--[[-- locals --]]
local pd = _ENV.pandoc -- if nil, we're not being loaded by pandoc
local sf = string.format
local hard_coded = { log = 'info', a = 1, b = 2, c = 3, d = 4, e = 5 }
local log_level = { 1, 2, 3, 4, 5, 6, silent = 0, fatal = 1, error = 2, warn = 3, note = 4, info = 5, debug = 6 }
local dump = require 'dump' -- tmp: delme
local state = {
  log = { stitch = 3 }, -- stitch starts at warn level
  ctx = nil, -- context of current document
  ccb = nil, -- current codeblock
  seen = {}, -- previous codeblock's
  stack = {}, -- previous doc's, gets pushed/popped
}

--[[- logging -]]
-- facility, level, mnemonic, msg
-- facilites register their log level w/ state:logger(id, level)
-- mnemonic is upto facility to decide and use consistently
-- msg is whatever it wants to say at given level

--- Prints formatted `msg` to stdout for given `id` at `tier`-level.
---
--- Valid tiers include: `1..6` or `fatal`, `error`, `warn`, `note`, `info` and `debug`.
--- Loggers must register their id and loglevel via `state:logger(id, level)` in order
--- to be able to log messages at that level or below.
---
--- Note: logging a message at level `fatal` is killing.
--- @param id string
--- @param tier string
--- @param msg string
local function log(id, tier, msg, ...)
  local level = log_level[tier] or 1 -- unknown tier is fatal
  if (log_level[tier] or 0) > (state.log[id] or 0) then return end
  io.output():write(sf('%%stitch[%s]-%s-%s: ', #state.stack, id, tier))
  io.output():write(sf(msg, ...), '\n')
  io.output():flush()
  assert(level ~= 1, sf('fatal error logged by %s', id))
end

--[[- State ]]

function state:depth() return #self.stack end

--- Registers a logging `identity` at given log `level` and returns `identity`.
---
--- Illegal levels will be set to most noisy!
--- @param id string
--- @param level string
--- @return string identity
--- @return string? error
function state:logger(id, level)
  local n = log_level[level]
  if not n or n < 0 or n > log_level['debug'] then n = 0 end
  self.log[id] = n
  return id
end

--- Saves current codeblock `ccb` on its stack and returns new total count.
--- @param ccb table
--- @return number
function state:save(ccb)
  self.seen[#self.seen + 1] = ccb
  self.ccb = ccb
  return #self.seen
end

--- Pushes current context onto its stack, sets `ctx` as new context and returns
--- current depth.
---
--- @param ctx table
--- @return number
function state:push(ctx)
  self.stack[#self.stack + 1] = self.ctx
  self.ctx = ctx
  return #self.stack
end

--- Pops context from stack and restores it as current context.
---
--- This also clears (TODO) current codeblock being processed ?
function state:pop()
  -- l={[0]=hidden}; l[#l] == l[0] == hidden (i.e. not so hidden)
  local ctx = self.stack[#self.stack]
  self.stack[#self.stack] = nil
  return ctx
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
--- Additionally, the doc's `title`, `author` and `date` (if available) are
--- also stored under `opt.meta` for convenience and keep it all in one table.
---
--- So, resolution order is: opt.section?.x -> defaults.x -> hard_coded.x
--- @param doc table
--- @return table
local function doc_options(doc)
  local meta = elm_to_lua(doc.meta) --- @cast meta table
  local loglevel = meta.stitch and meta.stitch.log or 'info'
  local lid = state:logger('stitch', loglevel)
  if not doc.meta.stitch then log(lid, 'warn', 'doc has no stitch configs..') end

  local opt = meta.stitch or {} -- toplevel meta.stitch
  opt.stitch = opt.stitch or {} -- ensure stitch's own section
  local defaults = opt.defaults or {}

  setmetatable(defaults, { __index = hard_coded })
  setmetatable(opt, { __index = function() return defaults end })
  opt.defaults = nil

  for name, section in pairs(opt) do
    if 'table' == type(section) then
      setmetatable(section, { __index = defaults })
    else
      log(lid, 'debug', 'moved option "%s: %s" into stitch-section', name, section)
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

--- Returns a new `kb` for given Pandoc.CodeBlock `cb`, if eligible, nil otherwise.
--
-- A `cb` is explicitly eligible for stitch processing if it has a `stitch=name`
-- attribute or it has `stitch` as one of its classes.  A `cb` also qualifies if a
-- stitch config section exists for `cb`'s identifier (rare) or when one of its
-- classes matches a section that has `cls=yes` option set.
--
--- @param cb table
--- @return table?
function kb:new(cb)
  local ccb = elm_to_lua(cb)
  local oid = ccb.attr.identifier or '<none>'
  -- get applicable ccb.stitch cfg section
  local cfg = ccb.attr.attributes.stitch -- 1. stitch=name
  cfg = cfg or pd.List.includes(ccb.attr.classes, 'stitch') -- 2. .stitch class
  cfg = cfg or rawget(state.ctx, oid) and oid -- 3. #id has config section
  for _, v in ipairs(ccb.attr.classes) do
    if cfg then break end
    cfg = cfg or rawget(state.ctx, v) and v.cls == 'yes' and v -- 3. class match cfg.cls=yes
  end
  if not cfg then return nil end

  local new = {
    cfg = cfg,
    cls = ccb.attr.classes,
    oid = oid,
    opt = setmetatable(ccb.attr.attributes, { __index = state.ctx[cfg] }),
    txt = ccb.text, -- for convenience
    ccb = ccb,
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

--[[-- STITCH --]]

local function CodeBlock(cb)
  local ccb = kb:new(cb)
  if not ccb then
    log('stitch', 'info', "skipped cb id '%s' (not eligible)", cb.attr.identifier)
    return nil
  end
  local lid = state:logger(ccb.oid, ccb.opt.log)
  log(lid, 'info', 'selected cb id %s, config is "%s"', lid, ccb.cfg)
  state:save(ccb)
  -- process here
  return nil
end

local function Pandoc(doc)
  state.ctx = doc_options(doc)
  local rv = doc:walk({ CodeBlock = CodeBlock })
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
