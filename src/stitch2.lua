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

--- hard coded defaults for stitch's options
-- opt resolution: cb.opt->ctx.section->ctx.defaults->hardcoded
-- reserved names: sha, oid
local hard_coded_opts = {
  -- `cid`, `sha` are calculated and added by stitch for its own use
  arg = '', -- (extra) arguments to pass in to `cmd`-program on the cli (if any)
  art = '#dir/#oid-#sha.#fmt', -- artifact (output) file (if any)
  cbx = '#dir/#oid-#sha.cbx', -- the codeblock.text as file on disk
  cls = 'no', -- {'yes', 'no'}
  cmd = '#cbx #arg #art 1>#out 2>#err', -- cmd template string, expanded last
  dir = '.stitch', -- where to store files (abs or rel path to cwd)
  err = '#dir/#oid-#sha.err', -- capture of stderr (if any)
  exe = 'maybe', -- {yes, no, maybe}
  fmt = 'png', -- format for images (if any)
  -- inc: {what=.., how=.., read=.., filter=..}, default how for out,err is fcb
  inc = { { what = 'cbx', how = 'fcb' }, { what = 'out' }, { what = 'art', how = 'img' }, { what = 'err' } },
  log = 'info', -- {debug, error, warn, info, silent}
  run = 'system', -- {system, chunk, no, noop, data (ie cbx=data to be used by inc)}
  old = 'purge', -- {keep, purge}
  out = '#dir/#oid-#sha.out', -- capture of stdout (if any)
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
  log = { stitch = 5, run = 5, doc = 5, docopt = 5, cbopt = 5, CodeBlock = 5 }, -- log level per 'facility'
  ctx = nil, -- context of current document
  ccb = nil, -- current codeblock
  seen = {}, -- previous codeblock's
  stack = {}, -- previous doc's, gets pushed/popped
  doc = nil, -- ref to doc so it can be used in codeblock chunks
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
  local prefix = sf('stitch[%s] %s (%s) ', #state.stack, tier, id)
  io.output():write(prefix, sf(msg, ...), '\n')
  io.output():flush()
  assert(level ~= 1, sf('fatal error logged by %s', id))
end

--[[----- helpers ----------]]

local function exists(filename) return true == os.rename(filename, filename) end

-- Poor man's semi-deep copy of t (table, userdata, etc..)
--- @return any
local function tcopy(t, seen)
  seen = seen or {}

  if seen[t] then return seen[t] end
  -- most pandoc type are clone()'able (except for CommonState ..)
  if 'userdata' == type(t) and t.clone then return t:clone() end
  if 'table' ~= type(t) then return t end

  local tt = {}
  seen[t] = tt
  for k, v in next, t, nil do
    tt[tcopy(k, seen)] = tcopy(v, seen)
  end
  setmetatable(tt, tcopy(getmetatable(t), seen))
  return tt
end

--- poor man's yaml converter
--- Returns a list of lines representing `t` as yaml.
--- Usage: `toyaml(some_var)`.
--- @param t any
--- @return table yaml
local function toyaml(t, n, seen, acc)
  seen = seen or {}
  acc = acc or {}
  n = n or 0
  local indent = string.rep(' ', n)

  if 'table' ~= type(t) or seen[t] then
    acc[#acc + 1] = sf('%s%s', indent, t)
    return acc
  end

  seen[t] = true
  for k, v in pairs(t) do
    local kk = 'string' == type(k) and k or sf('[%s]', k)
    if 'table' == type(v) then
      acc[#acc + 1] = sf('%s%s:', indent, kk)
      acc = toyaml(v, n + 2, seen, acc)
    else
      acc[#acc + 1] = sf('%s%s: %s', indent, kk, v)
    end
  end
  return acc
end

-- poor man's `tostr(data)`
-- best used for small data since it's string ops intensive
local function tostr(t, seen, first, acc)
  seen = seen or {}
  acc = acc or ''
  first = nil == first or false -- first call or not

  local comma = #acc > 0 and ', ' or ''
  if seen[t] then return sf('%s%s<%s>', acc, comma, t) end
  if 'table' ~= type(t) then return sf('%s%s%s', acc, comma, t) end

  seen[t] = true
  for k, v in pairs(t) do
    local kk = 'string' == type(k) and sf('%s: ', k) or ''
    comma = #acc > 0 and ', ' or ''
    if 'table' == type(v) then
      local vv = tostr(v, seen, false)
      local fmt = vv:match('^%<.-%>$') and '%s%s%s%s' or '%s%s%s{%s}'
      acc = sf(fmt, acc, comma, kk, vv)
    else
      acc = sf('%s%s%s%s', acc, comma, kk, v)
    end
  end
  acc = first and sf('{%s}', acc) or acc
  return acc
end

-- Returns the sha fingerprint for given (parsed) `ccb`.
--
-- The fingerprint is the sha1 hash of all relevant option values
-- sorted by key plus the codeblock's content.  The sha1 hash is
-- calculated using the combined values with all whitespace removed.
--- @param ccb table
--- @return string sha
local function tosha(ccb)
  local keys = {}
  for k, _ in pairs(hard_coded_opts) do
    if not ('exe log old'):match(k) then keys[#keys + 1] = k end
  end
  table.sort(keys)

  local vals = {}
  for _, k in pairs(keys) do
    vals[#vals + 1] = tostr(ccb.opt[k])
  end
  vals[#vals + 1] = ccb.txt

  local str = table.concat(vals, ''):gsub('%s+', '')
  return pd.sha1(str)
end

--[[----- State ------------]]

function state:depth() return #self.stack end

--- Registers a logging `id` at given log `level` and returns `id`.
---
--- Unknown levels are set as debug level.
--- @param id string
--- @param level string
--- @return string identity
--- @return string? error
function state:logger(id, level)
  self.log[id] = log_level[level] or log_level.debug
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
    t[k] = parse and parse(v, detail, seen)
  end
  return t
end

parse_elm_by = {
  -- parsers by pandoc type(s)
  ['Inlines'] = function(v, d, s)
    return (d and parse_elm(v, d, s)) or pd.write(pd.Pandoc({ v }), 'markdown'):sub(1, -2)
  end,

  -- parsers by lua types
  -- nb: exe=yes/no/maybe, where yes/no comes out as true/false -> all booleans := yes/no strings
  ['nil'] = function() return nil end,
  thread = function() return nil end,
  table = function(v, d, s) return parse_elm(v, d, s) end,
  userdata = function(v, d, s) return parse_elm(v, d, s) end,
  ['function'] = function(v, d) return d and v or nil end,
  string = function(v) return v end,
  boolean = function(v) return v and 'yes' or 'no' end,
  number = function(v) return v end,
}

-- validating parsers for stitch options
-- nb: nil means option value error, only inc can skip parts with illegal values
local parse_opt_by = {
  arg = function(v) return 'string' == type(v) and v or nil end,
  art = function(v) return 'string' == type(v) and v or nil end,
  cbx = function(v) return 'string' == type(v) and v or nil end,
  cid = function(v) return 'string' == type(v) and v or nil end,
  cls = function(v) return 'string' == type(v) and ('no yes'):match(v) and v or nil end,
  err = function(v) return 'string' == type(v) and v or nil end,
  exe = function(v) return 'string' == type(v) and ('yes maybe no'):match(v) and v or nil end,
  fmt = function(v) return 'string' == type(v) and v or nil end,
  log = function(v) return 'string' == type(v) and ('debug error warn info silent'):match(v) and v or nil end,
  old = function(v) return 'string' == type(v) and ('purge keep'):match(v) and v or nil end,
  out = function(v) return 'string' == type(v) and v or nil end,
  run = function(v) return 'string' == type(v) and ('system chunk noop'):match(v) and v or nil end,

  inc = function(v)
    -- `inc` in cb.attr is always a string, in meta it can be string or a table
    local t = {}
    if 'string' == type(v) then
      for p in v:gsub('[%s,]+', ' '):gmatch('%S+') do
        t[#t + 1] = p
      end
    elseif 'table' == type(v) then
      t = v
    end
    local pat = '([^!@:]+)'
    local spec = {}
    for k, part in pairs(t) do
      if 'string' == type(part) then
        -- REVIEW: maybe support multiple filters: @m1.f1@m2.f2@.. ?
        -- note: validation is handled by ccb:inc() & friends
        spec[#spec + 1] = {
          what = part:match('^' .. pat),
          read = part:match('!' .. pat),
          filter = part:match('@' .. pat),
          how = part:match(':' .. pat),
        }
      else
        log('opt', 'error', sf('ignoring inc[%s]=%s, illegal value', k, tostr(part)))
      end
    end
    return spec
  end,
}
setmetatable(parse_opt_by, {
  __index = function(_, k)
    log('opt', 'debug', sf('%q is not a stitch option, kept as-is', k))
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
  local lid = state:logger('docopt', loglevel)
  if not doc.meta.stitch then log(lid, 'warn', 'doc has no stitch configs..') end

  local opt = meta.stitch or {} -- toplevel meta.stitch
  opt.stitch = opt.stitch or {} -- ensure stitch's own section

  -- ensure valid values for stitch options in all sections
  -- TODO: set err-flag on section level, codeblocks that associate with a
  --       section with errors will have to be skipped!
  local flawed = false
  for name, section in pairs(opt) do
    log(lid, 'debug', '%q-options', name)
    for option, value in pairs(section) do
      local val = parse_opt(option, value)
      if nil == val then log(lid, 'error', '(%s) ignoring %s=%s, illegal value', name, option, tostr(value)) end
      flawed = flawed or val == nil
      section[option] = val
      log(lid, 'debug', '- %s.%s = %s', name, option, tostr(section[option], {}, true, ''))
    end
    section.flawed = flawed
  end

  -- setup metatable chain for option resolution order
  local defaults = opt.defaults or {}
  setmetatable(defaults, { __index = hard_coded_opts })
  setmetatable(opt, { __index = function() return defaults end })
  opt.defaults = nil
  for name, section in pairs(opt) do
    if 'table' == type(section) then
      setmetatable(section, { __index = defaults })
    else
      log(lid, 'debug', 'stitch.%s=%s', name, section)
      opt.stitch[name] = section -- aka opt[name] is a value, not table
      opt[name] = nil
    end
  end

  opt.meta = {
    title = meta.title,
    author = meta.author,
    date = meta.date,
  }
  log(lid, 'info', 'got doc options for doc titled %q', opt.meta.title)

  return opt
end

--[[----- kodeblock --------]]

--- Class to represent codeblock instances (`ccb`'s) within stitch.
---
--- Class fields:
--- `run` function table for running the codeblock via `ccb:run()`
---
--- Instance fields:
--- `opt` ccb's attributes, includes `oid` used for logging
--- `cls` ccb's classes
--- `txt` ccb's text (content)
--- `ast` parsed ast for `cb`
--- `org` the original `cb`
--- `cfg` ccb's configuration name (nil = not eligible)
--- `flawed` flags that codeblock has errors or not
local kb = {
  -- run methods per type of codeblock (system, chunk or noop)
  run = setmetatable({}, {
    __index = function(_, k)
      -- kb.run[run=method](ccb) -> _ is kb.run table, k is absent key being looked up
      return function(self)
        self.flawed = true
        log(self.opt.oid, 'error', 'codeblock unknown run type %q', k)
      end
    end,
    __call = function(run, self)
      -- ccb:run() -> run is table kb.run, self is the ccb instance
      local oid = self.opt.oid
      if self.flawed or self.opt.flawed then
        log(oid, 'warn', 'codeblock not running due to errors')
        return nil
      elseif 'no' == self.opt.exe then
        log(oid, 'warn', 'codeblock skipping skip run (exe = no)')
        return nil
      elseif 'maybe' == self.opt.exe and self:total_recall() then
        log(oid, 'info', 'codeblock run skipped, results already exist')
        return nil
      end
      -- TODO: also check self.opt.run != noop ?
      if self:setup() then run[self.opt.run](self) end
    end,
  }),

  inc = setmetatable({}, {
    __index = function(_, k)
      return function(self)
        log(self.opt.iod, 'error', 'include skip type %q (unknown)', k)
        return {}
      end
    end,

    __call = function(inc, self)
      local oid = self.opt.oid
      local includes = self.opt.inc
      for idx, directive in pairs(includes) do
        log(oid, 'debug', 'inc[%d] = %s', idx, tostr(directive))
      end
    end,
  }),
}

--[[----- kb.run:<as> ------]]

-- run=<kind> - function for each kind of run
-- ccb:run() -> __call does the setup and runs kb.run[<kind>](self)

-- ccb run as noop, just logs it is not really running
function kb.run:noop() log('run', 'info', '(%s) no run, codeblock is a noop', self.opt.oid) end

-- run ccb as system command
function kb.run:system()
  --
  local oid = self.opt.oid
  local ok, code, nr = os.execute(self.opt.cmd)
  if ok then
    log(oid, 'info', 'codeblock succeeded as system command')
  else
    -- TODO: make this self.lid
    log(oid, 'error', 'codeblock system command failed with %s(%s)', code, nr)
    self.flawed = true
  end
end

-- run ccb as lua chunk with _ENV.Stitch set
function kb.run:chunk()
  -- TODO: use clone() instead of references to internal tables
  _ENV.Stitch = {
    state = tcopy(state),
    tostr = tostr,
    toyaml = toyaml,
  }
  local oid = self.opt.oid

  local f, lferr = loadfile(self.opt.cbx, 't', _ENV)
  if f == nil or lferr then
    log(oid, 'error', 'codeblock chunk failed: %s', lferr)
  else
    local ok, err = pcall(f)
    if ok then
      log(oid, 'info', 'codeblock succeeded as chunk', oid)
    else
      log(oid, 'error', 'codeblock chunk failed wih: %s', err)
    end
  end
end

--[[----- kb.inc:<what> ----]]

function kb.inc:fcb()
  -- tja wat dan?
end

--[[----- kb:<others> ------]]

--- Returns a new current codeblock `ccb` for given Pandoc.CodeBlock `cb`.
--
-- A codeblock is explicitly eligible for stitch processing if it has a `stitch=name`
-- attribute or it has `stitch` as one of its classes.  A codeblock also qualifies if a
-- stitch config section exists for its identifier (rare) or when one of its
-- classes matches a section that has `cls=yes` option set.
--
-- Note: use `kb:is_eligible(ccb)` to check if stitch can process the codeblock.
--
--- @param cb table
--- @return table ccb
function kb:new(cb)
  local oid = sf('%s', cb.attr.identifier)
  oid = #oid == 0 and sf('cb%03d', #state.seen + 1) or oid
  state:logger(oid, cb.attr.attributes.log or 'debug') -- if unknown, becomes debug
  local ccb = parse_elm(cb)

  local cfg = ccb.attr.attributes.stitch -- 1. stitch=name
  cfg = cfg or pd.List.includes(ccb.attr.classes, 'stitch') -- 2. .stitch class
  cfg = cfg or rawget(state.ctx, oid) and oid -- 3. #id has config section
  if 'no' ~= cb.attr.attributes.cls and not cfg then
    -- 4. cb class matches with a section, disable search on cb-level w/ cls=no
    for _, class in ipairs(ccb.attr.classes) do
      if cfg then break end
      local section = rawget(state.ctx, class)
      -- nb: resolution is section->defaults->hard_coded_opts
      -- * require for the section to actually exists (hence rawget)
      -- * disable class matching on on section-level or defaults level
      cfg = section and 'no' ~= section.cls and class or nil
    end
  end
  cfg = cfg or nil -- ensure nil as failure value (i.e. false := nil)

  -- ensure cb options have valid values, set err for any mistakes found
  local flawed = false --> later ops will check err and skip codeblock entirely
  local opt = setmetatable({}, { __index = state.ctx[cfg] })
  for option, value in pairs(ccb.attr.attributes) do
    local val = parse_opt(option, value)
    if nil == val then log(oid, 'error', '(#%s) %s=%s (illegal value)', oid, option, tostr(value)) end
    flawed = flawed or val == nil
    opt[option] = val
  end

  local new = {
    cfg = cfg, -- if nil, cb is not eligible for stitch processing
    cls = ccb.attr.classes,
    opt = opt, -- cb's options with valid values
    txt = ccb.text, -- for convenience
    ast = ccb, -- parsed ast for cb (for debugging)
    org = cb, -- original cb (for debugging)
    flawed = flawed, -- if true, codeblock skipped, all operations check this flag
  }

  -- calculate sha & expand filenames (cmd must be last as it uses filenames)
  opt.oid = oid
  opt.sha = tosha(new)
  for _, tpl in ipairs({ 'cbx', 'art', 'out', 'err', 'cmd' }) do
    opt[tpl] = pd.path.normalize(opt[tpl]:gsub('%#(%w+)', opt))
  end

  self.__index = self
  setmetatable(new, self)
  state:save(new)
  return new
end

--- Returns true if cbx-file and one or more of art,out,err-files exist
---
--- If true, there is no real need to run codeblock again. Returns false when no
--- such files exist or could not be determined due to lack of fingerprints.
function kb:total_recall()
  local artifacts = exists(self.opt.art) or exists(self.opt.out) or exists(self.opt.err)
  return exists(self.opt.cbx) and artifacts
end

--- Returns the number of old files removed that were previously generated
--- by this codeblock.  If codeblock is flawed, purge is skipped.
--- @return number count
function kb:purge()
  local oid = self.opt.oid
  local count = 0

  if self.flawed then return count end

  if 'purge' ~= self.opt.old then
    log(oid, 'info', 'purge skipped (old=%s)', self.opt.old)
    return count
  end

  for _, ftype in ipairs({ 'cbx', 'out', 'err', 'art' }) do
    local fnew = self.opt[ftype]
    local pat = fnew:gsub('[][()%.*+^$?-]', '%%%1') -- literal magic
    local n = 0
    pat, n = pat:gsub(self.opt.sha, '(%%w+)')
    if n ~= 1 then
      log(oid, 'warn', 'purge skipped, %s-file has no sha fingerprint', ftype)
      break
    end

    local dir = pd.path.directory(fnew)
    for _, fold in ipairs(pd.system.list_directory(dir)) do
      fold = pd.path.join({ dir, fold })
      if fold:match(pat) and fold ~= fnew then
        local ok, err = os.remove(fold) -- pd.system.remove is version >=3.7.1
        if not ok then
          log(oid, 'error', 'purge failed to remove old file %s (%s)', fold, err)
        else
          count = count + 1
          log(oid, 'debug', 'purge removed old file %s', fold)
        end
      end
    end
  end
  log(oid, 'debug', 'purge removed %d old files', count)
  return count
end

--- Returns true if `ccb` can be processed by stitch, false otherwise
function kb:is_eligible() return self.cfg ~= nil end

--- Setup creates the necessary directories and sets up the cbx-file
---
--- Return true if setup succeeded, false otherwise
function kb:setup()
  local oid = self.opt.oid
  for _, path in ipairs({ 'cbx', 'art', 'out', 'err' }) do
    local dir = pd.path.normalize(pd.path.directory(self.opt[path]))
    if not os.execute(sf('mkdir -p %s', dir)) then
      log(oid, 'error', 'permission denied when creating ', dir)
      self.flawed = true
      return false
    end
  end

  local fh = io.open(self.opt.cbx, 'w')
  if not (fh and fh:write(self.txt)) then
    log(oid, 'error', 'error writing out cbx-file %s', self.opt.cbx)
    self.flawed = true
    return false
  end
  fh:close()

  if not os.execute(sf('chmod u+x %s', self.opt.cbx)) then
    log(oid, 'error', 'could not mark cbx as executable: %s', self.opt.cbx)
    self.flawed = true
    return false
  end
  return true
end

--[[----- STITCH -----------]]

local function CodeBlock(cb)
  local ccb = kb:new(cb) -- also registers oid as logger
  local oid = ccb.opt.oid
  if not ccb:is_eligible() then
    log(oid, 'warn', '(%s) skip, codeblock not eligible', oid)
    return nil
  end
  if ccb.flawed then
    log(oid, 'error', '(%s) skip, codeblock contains errors', oid)
    return nil
  end

  log(oid, 'info', 'codeblock selected using config %q', ccb.cfg)

  -- process here
  -- ccb:run()
  -- 2. kb:purge(ccb)
  -- 3. return kb:result(ccb)
  -- print(ccb:total_recall())
  ccb:run()
  ccb:purge()

  ccb:inc()
  -- return ccb:inc()
  return nil
end

local function Pandoc(doc)
  local lid = state:logger('doc', 'info')
  -- log(lid, 'info', 'new document, title "%s"', pd.utils.stringify(doc.meta.title))
  log(lid, 'info', 'new document, title %q', tostr(parse_elm_by['Inlines'](doc.meta.title)))
  state.ctx = doc_options(doc) -- TODO: should simply set state.ctx ?
  state.doc = doc
  local rv = doc:walk({ CodeBlock = CodeBlock })
  log(lid, 'info', 'done .. saw %s codeblocks', #state.seen)

  -- tmp
  -- tmp

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
