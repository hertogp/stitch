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
local hard_coded = { log = 'info', a = 1, b = 2 }
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
local parse_it = {} -- forward declaration

--- Converts pandoc AST element `elm` to regular Lua table
-- It sets indices `[-1]`, `[0]` to `elm` 's pandoc resp. lua type and
-- ignores any metatables.
--- @param elm table a pandoc AST element
--- @param dbg boolean? if truthy, sets `[0],[-1]` to org lua resp. pandoc type
--- @return table? table a Lua table version of `elm`, nil for unknown elm's
local function elm_to_lua(elm, dbg)
  dbg = dbg or false

  local t = dbg and { [0] = type(elm), [-1] = pd.utils.type(elm) } or {}
  for k, v in pairs(elm) do
    local lua_type = type(v)
    local pandoc_type = pd.utils.type(v)
    local parse = parse_it[lua_type]
    if 'Inlines' == pandoc_type then
      t[k] = pd.utils.stringify(v)
    elseif parse then
      t[k] = parse(v, dbg)
    else
      t[k] = nil
    end
  end
  return t
end

parse_it = {
  ['nil'] = function() return nil end,
  thread = function() return nil end,
  table = function(v, d) return elm_to_lua(v, d) end,
  userdata = function(v, d) return elm_to_lua(v, d) end,
  string = function(v, _) return pd.utils.stringify(v) end,
  number = function(v, _) return pd.utils.stringify(v) end,
  boolean = function(v, _) return pd.utils.stringify(v) end,
  ['function'] = function(v, _) return v end,
}

--[[- State ]]
local his = {} -- history of recursion
local state = {
  ctx = {}, -- context of current document
  ccb = {}, -- current codeblock
}

--[[- Context ]]
-- ctx is stitch's context derived from doc's meta data

local Context = {}
--- Creates a stitch context for given `doc` which contains: `doc`, `meta` &
--- `opt`, which is the original `meta.stitch` section.  Any `opt.defaults`
--- table is also promoted to metatable for all named and unnamed sections in `opt`.
---
--- Hence, option resolution order: opt.section? -> defaults -> hard_coded.
--- @param doc table
--- @return table
function Context:new(doc)
  local obj = {
    doc = doc,
    meta = elm_to_lua(doc.meta) or {},
    opt = elm_to_lua(doc.meta.stitch or {}) or {},
  }
  obj.meta.stitch = nil
  local defaults = obj.opt.defaults or {}
  obj.opt.defaults = nil

  setmetatable(defaults, { __index = hard_coded })
  setmetatable(obj.opt, { __index = function() return defaults end })
  for name, section in pairs(obj.opt) do
    if 'table' == type(section) then
      setmetatable(section, { __index = defaults })
    else
      obj.opt[name] = nil
    end
  end

  return obj
end

--[[- kb ]]
local function run_noop(self) print(self, sf('run noop %s', self.opts.exe)) end
local kb = {
  run = setmetatable({}, { __index = function(_) return run_noop end }),
  elm = {},
}

function kb:new(context)
  local ctx = setmetatable(context, { __index = hard_coded })
  local new = {
    opts = setmetatable({ kopts = true }, { __index = ctx, hidden = true }),
  }

  -- refer to kb when looking up fields on an instance
  self.__index = self
  return setmetatable(new, self)
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
function kb:chain(field, t)
  if nil == field then return t end
  if 'table' ~= type(field) then return t end
  t = t or {}
  t[#t + 1] = field
  return self:chain((getmetatable(field) or {}).__index, t)
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

local function Pandoc(doc)
  print('ICU-C-ME')
  local ctx = Context:new(doc)
  print('ctx', dump(ctx))
  print('ctx.opt.goofy.log', dump(ctx.opt.goofy.log))
  print('ctx.opt.goofy.a', dump(ctx.opt.goofy.a))

  print('ctx.opt.wam', ctx.opt.wam)
  print('ctx.opt.bam', ctx.opt.bam)
  print('ctx.opt.mickey.a', dump(ctx.opt.mickey.a))
  print('ctx.opt.mickey.log', dump(ctx.opt.mickey.log))

  return doc
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
