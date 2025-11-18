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
-- * small functions donutnot log, just yield results
-- * classes that instantiate are Capatalized, otherwise all lower case
-- * large scopes means longer names
-- * keep local var declaration close to their use
-- * log facilities are: stitch, codeblock, filter etc ..

-- initialize only once (load vs require)
if package.loaded.stitch2 then return package.loaded.stitch2 end

--[[----- locals -----------]]
local pd = _ENV.pandoc -- if nil, we're probably not being loaded by pandoc
local sf = string.format
local dump = require 'dump' -- tmp: delme

--- predefined log levels in string or numeric form
local log_level = { 1, 2, 3, 4, 5, 6, silent = 0, fatal = 1, error = 2, warn = 3, note = 4, info = 5, debug = 6 }

--- module level defaults for stitch's options
local hard_coded_opts = {
  -- resolution order: cb->stitch.section->stitch.defaults->hardcoded
  -- cid, sha are calculated and added by stitch fo its own use
  arg = '', -- (extra) arguments to pass in to `cmd`-program on the cli (if any)
  art = '#dir/#cid-#sha.#fmt', -- artifact (output) file (if any)
  cbx = '#dir/#cid-#sha.cbx', -- the codeblock.text as file on disk
  cls = 'no', -- {'yes', 'no'}
  cmd = '#cbx #arg #art 1>#out 2>#err', -- cmd template string, expanded last
  dir = '.stitch', -- where to store files (abs or rel path to cwd)
  err = '#dir/#cid-#sha.err', -- capture of stderr (if any)
  exe = 'maybe', -- {yes, no, maybe}
  fmt = 'png', -- format for images (if any)
  inc = 'cbx:fcb out:fcb art:img err:fcb',
  log = 'info', -- {debug, error, warn, info, silent}
  run = 'cmd', -- {cmd, chunk, noop (ie cbx=data to be used by inc)}
  old = 'purge', -- {keep, purge}
  out = '#dir/#cid-#sha.out', -- capture of stdout (if any)
}

--- state stores the following:
--- * `log`, logging levels per facility. Predefined are 'stitch, doc, cb'.
---   Others (cb's e.g.) register via `state:logger(id, level)`
--- * `ctx`, the current document's stitch context (options basically)
--- * `ccb`, the current codeblock being processed as created by `kb:new(cb)`
--- * `seen`, a list of codeblocks seen sofar
--- * `stack`, push/pop stack for `state.ctx` when recursing
---
--- Note: `kb:new(cb)` creates the current `ccb` and adds it to `seen`.
local state = {
  log = { doc = 3, cb = 3, CodeBlok = 5 }, -- log level per 'facility'
  ctx = nil, -- context of current document
  ccb = nil, -- current codeblock
  seen = {}, -- previous codeblock's
  stack = {}, -- previous doc's, gets pushed/popped
}

--[[----- logging ----------]]
-- facility, level, mnemonic, msg
-- facilities register their log level w/ state:logger(id, level)
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
  local level = log_level[tier] or 3 -- unknown tier is warning
  if (log_level[tier] or 0) > (state.log[id] or 0) then return end
  local prefix = sf('%%stitch[%s] %s %s: ', #state.stack, tier, id)
  io.output():write(prefix, sf(msg, ...), '\n')
  io.output():flush()
  assert(level ~= 1, sf('fatal error logged by %s', id))
end

--[[----- State ------------]]

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

--[[----- parsers ----------]]

--- table of parsers per pandoc/lua type
local parse_elm_by = {}

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
local function parse_elm(elm, detail, seen)
  seen = seen or {}
  detail = detail and true or false
  local t = detail and { [0] = { pandoc = pd.utils.type(elm), lua = type(elm), pointer = sf('%p', elm) } } or {}
  for k, v in pairs(elm) do
    if seen[v] then return v end --{ [k] = sf('<cyclic: %p> %s', v, v) } end
    if 'table' == type(v) or 'userdata' == type(v) then seen[v] = v end
    local parse = parse_elm_by[pd.utils.type(v)] or parse_elm_by[type(v)]
    -- print(
    --   sf('%10s', k),
    --   'types:',
    --   pd.utils.type(v),
    --   type(v),
    --   'funcs',
    --   parse_elm_by[pd.utils.type(v)],
    --   parse_elm_by[type(v)]
    -- )
    t[k] = parse and parse(v, detail, seen) -- or nil -> ignored
  end
  return t
end

parse_elm_by = {
  -- parsers by pandoc type(s)
  ['Inlines'] = function(v, d, s)
    return (d and parse_elm(v, d, s)) or pd.write(pd.Pandoc({ v }), 'markdown'):sub(1, -2)
  end,

  -- parsers by lua types
  ['nil'] = function() return nil end,
  thread = function() return nil end,
  table = function(v, d, s) return parse_elm(v, d, s) end,
  userdata = function(v, d, s) return parse_elm(v, d, s) end,
  ['function'] = function(v, d) return d and v or nil end,
  string = function(v) return v end,
  boolean = function(v) return v end,
  number = function(v) return v end,
}

-- parsers for stitch options that also validate
local parse_opt_by = {
  arg = function(v) return 'string' == type(v) and v or nil end,
  art = function(v) return 'string' == type(v) and v or nil end,
  cbx = function(v) return 'string' == type(v) and v or nil end,
  cid = function(v) return 'string' == type(v) and v or nil end,
  cls = function(v) return 'string' == type(v) and v:match('yes no') and v or nil end,
  err = function(v) return 'string' == type(v) and v or nil end,
  exe = function(v) return 'string' == type(v) and v:match('yes no maybe') and v or nil end,
  fmt = function(v) return 'string' == type(v) and v or nil end,
  log = function(v) return 'string' == type(v) and v:match('debug error warn info silent') and v or nil end,
  old = function(v) return 'string' == type(v) and v:match('purge keep') and v or nil end,
  out = function(v) return 'string' == type(v) and v or nil end,
  run = function(v) return 'string' == type(v) and v:match('cmd chunk') and v or nil end,

  inc = function(v)
    -- `inc` in cb.attr is always a string, in meta it can be string or a table
    local t = {}
    if 'string' == type(v) then
      for p in v:gsub('[%s,]+', ' '):gmatch('%S+') do
        t[#t + 1] = p
      end
    elseif 'table' == type(v) then
      t = v
    else
      log('cb-opt', 'error', 'invalid value for inc: "%s"', v)
    end
    local pat = '([^!@:]+)'
    local spec = {}
    for k, part in pairs(t) do
      if 'string' == type(part) then
        -- REVIEW: maybe support multiple filters: @m1.f1@m2.f2@.. ?
        spec[#spec + 1] = {
          part:match('^' .. pat) or '', -- what
          part:match('!' .. pat) or '', -- !read-format
          part:match('@' .. pat) or '', -- @filter.func
          part:match(':' .. pat) or '', -- :what
        }
      else
        log('cb-opt', 'error', sf('skipped "inc[%s]=%s", expected a "string" not type %q', k, part, type(part)))
      end
    end
    return spec
  end,
}
setmetatable(parse_opt_by, {
  __index = function(_, k)
    log('cb-opt', 'debug', sf('%q is not a stitch option, kept as-is', k))
    return function(v) return v end
  end,
})

--- Returns a parsed, validated value for given `opt` and `val` or nil.
---
--- Stitch options with illegal values are removed.  Most options are simply
--- string values.  Option `inc` will be parsed into a sequence of directives
--- which themselves are not validated at this point.
---
--- Non-stitch options are kept as-is, they're not used anyway.
---
--- @param opt string
--- @param val string|table
--- @return string|table?
local function parse_opt(opt, val)
  local parsed = parse_opt_by[opt](val)
  if not parsed then log('stitch', 'error', sf('~~~ invalid value for opt %q ("%s")', opt, val)) end
  return parsed
end

--[[----- options ----------]]

--- Returns an options table for given `doc`, based on `doc.meta.stitch`.
---
--- Each section (table) under `doc.meta.stitch` is turned into a stitch
--- configuration section.  The names `stitch`, `defaults` and `meta` are special.
---
--- Top level options that are not tables, are collected in a `stitch` section
--- while `defaults` will be set as metatable for all section tables.  The
--- `defaults` table itself, will have the `hard_coded` option table as metatable.
--- If `doc.meta.stitch.defaults` does not exist, it is created.
---
--- Additionally, a `meta` section is added which holds the doc's `title`, `author`
--- and `date` (if available).
---
--- Option `x` resolution order: cb.x -> section?.x -> defaults.x -> hard_coded.x
--- Note: non-existing sections also fall back to using defaults.
---
--- @param doc table
--- @return table
local function doc_options(doc)
  local meta = parse_elm(doc.meta) --- @cast meta table
  local loglevel = meta.stitch and sf('%s', meta.stitch.log) or 'info'
  local lid = state:logger('doc-opt', loglevel)
  if not doc.meta.stitch then log(lid, 'warn', 'doc has no stitch configs..') end

  local opt = meta.stitch or {} -- toplevel meta.stitch
  opt.stitch = opt.stitch or {} -- ensure stitch's own section
  local defaults = opt.defaults or {}

  setmetatable(defaults, { __index = hard_coded_opts })
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

  -- ensure valid values for stitch options in all sections
  for name, section in pairs(opt) do
    log(lid, 'debug', 'parsing options in section %q', name)
    for option, val in pairs(section) do
      section[option] = parse_opt(option, val)
    end
  end
  -- print('opt dump', dump(opt))

  opt.meta = {
    title = meta.title,
    author = meta.author,
    date = meta.date,
  }
  log(lid, 'info', 'got doc options for doc titled %q', opt.meta.title)

  return opt
end

--[[----- KodeBlock --------]]
local function run_noop(self) print(self, sf('run noop %s', self.opts.exe)) end
local kb = {
  run = setmetatable({}, { __index = function() return run_noop end }),
}

--- Returns a new current codeblock `ccb` for given Pandoc.CodeBlock `cb`.
--
-- A codeblock is explicitly eligible for stitch processing if it has a `stitch=name`
-- attribute or it has `stitch` as one of its classes.  A codeblock also qualifies if a
-- stitch config section exists for its identifier (rare) or when one of its
-- classes matches a section that has `cls=yes` option set.
--
-- Note: use `kb:eligible(ccb)` to check if stitch can process the codeblock.
--
--- @param cb table
--- @return table ccb
function kb:new(cb)
  local ccb = parse_elm(cb)
  local oid = ccb.attr.identifier or '' -- TODO: unique nrs
  oid = #oid == 0 and sf('cb%03d', #state.seen + 1) or oid
  -- get applicable ccb.stitch cfg section
  local cfg = ccb.attr.attributes.stitch -- 1. stitch=name
  cfg = cfg or pd.List.includes(ccb.attr.classes, 'stitch') -- 2. .stitch class
  cfg = cfg or rawget(state.ctx, oid) and oid -- 3. #id has config section
  for _, v in ipairs(ccb.attr.classes) do
    if cfg then break end
    cfg = cfg or rawget(state.ctx, v) and v.cls == 'yes' and v -- 3. class match cfg.cls=yes
  end

  local new = {
    cfg = cfg, -- the config name, if eligible for stitch processing
    cls = ccb.attr.classes, -- the list of classes
    oid = oid, -- cb's identifier or cb<nth>
    opt = setmetatable(ccb.attr.attributes, { __index = state.ctx[cfg] }),
    txt = ccb.text, -- for convenience
    ast = ccb,
    org = cb,
  }

  -- ensure inc is always array of include specs
  local inc = new.opt.inc -- resolves inc
  if 'string' == type(inc) then
    local parts = {}
    for p in inc:gsub('[%s,]+', ' '):gmatch('%S+') do
      parts[#parts + 1] = p
    end
    inc = parts
  end

  local pat = '([^!@:]+)'
  local spec = {}
  for k, part in pairs(inc) do
    if 'string' == type(part) then
      spec[#spec + 1] = {
        part:match('^' .. pat) or '', -- what
        part:match('!' .. pat) or '', -- !read-format
        part:match('@' .. pat) or '', -- @filter.func
        part:match(':' .. pat) or '', -- :what
      }
    else
      log('cb-opt', 'error', sf('%s: skipped inc[%s], expected a "string" not type %q', oid, k, type(part)))
    end
  end
  new.opt.inc = spec

  self.__index = self
  setmetatable(new, self)
  state:save(new)
  return new
end

--- Returns true if `ccb` can be processed by stitch, false otherwise
--- @param ccb table
--- @return boolean
function kb:eligible(ccb) return assert('table' == type(ccb)) and ccb.cfg ~= nil end

--[[----- kb:run -----------]]
function kb.run.yes(self) print(self, 'run yes') end
function kb.run.no(self) print(self, 'run no') end
function kb.run.maybe(self) print(self, 'run maybe') end
function kb.run.chunk(self) print(self, 'run chunk') end
function kb.run.unknown(self) print(self, 'run chunk') end

--[[----- kb:<funcs> ------]]
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

--[[----- STITCH -----------]]

local function CodeBlock(cb)
  local lid = state:logger('CodeBlock', 'info')
  local ccb = kb:new(cb)
  if not kb:eligible(ccb) then
    log(lid, 'warn', 'Skipped codeblock id %q, not eligible', ccb.oid)
    return nil
  end

  log(lid, 'info', 'New codeblock, id %q with config %q', ccb.oid, ccb.cfg)
  -- process here
  -- print('ccb', ccb.cfg, ccb.opt.inc, dump(state.ctx[ccb.cfg]))
  -- print('ccb.opt', type(ccb.opt.bool1), dump(ccb.opt))
  return nil
end

local function Pandoc(doc)
  local lid = state:logger('Pandoc', 'info')
  log(lid, 'info', 'New document, title "%s"', pd.utils.stringify(doc.meta.title))
  state.ctx = doc_options(doc)
  local rv = doc:walk({ CodeBlock = CodeBlock })

  return rv
end

--[[ shenanigens ]]

package.loaded.stitch2 = { { Pandoc = Pandoc } }

if pd then
  if _ENV.PANDOC_VERSION >= { 3, 5 } then
    -- single filters will become the norm
    package.loaded.stitch2 = { Pandoc = Pandoc }
  end
end
return package.loaded.stitch2
