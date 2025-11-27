--[[--- stitch ------------]]
--
-- TODO:
-- * add stats: codeblocks/headers/errors/ seen/totals
--   * n/N <topic>, m errors, x ignored
-- * move parse functions into parse obj -> easier to export for busted
-- * add ._internals table to exported filter so they can be tested

-- Pandoc load's filters, stitch requires them.  So prevent initializing twice
if package.loaded.stitch then return package.loaded.stitch end

--[[----- locals -----------]]
local pd = _ENV.pandoc -- if nil, we're probably not being loaded by pandoc
local sf = string.format
local log_level = { 1, 2, 3, 4, 5, 6, silent = 0, fatal = 1, error = 2, warn = 3, note = 4, info = 5, debug = 6 }

-- option resolution: cb.opt->ctx.section->ctx.defaults->hardcoded
local hard_coded_opts = {
  arg = '', -- (extra) arguments to pass in to `cmd`-program on the cli (if any)
  cls = 'no', -- {'yes', 'no'}
  dir = '.stitch', -- where to store files (abs or rel path to cwd)
  exe = 'maybe', -- {yes, no, maybe}
  fmt = 'png', -- format for images (if any)
  hdr = '0', -- shift headers by '+/-n'
  log = 'info', -- one of {debug, error, warn, info, silent}
  run = 'system', -- {system, chunk, no, noop, data (ie cbx=data to be used by inc)}
  old = 'purge', -- {keep, purge}
  -- expandables; #sha & #oid are provided by stitch
  art = '#dir/#oid-#sha.#fmt', -- artifact (output) file (if any)
  cbx = '#dir/#oid-#sha.cbx', -- the codeblock.text as file on disk
  out = '#dir/#oid-#sha.out', -- capture of stdout (if any)
  err = '#dir/#oid-#sha.err', -- capture of stderr (if any)
  cmd = '#cbx #arg #art 1>#out 2>#err', -- cmd template string, expanded last
  -- include directive defaults for cbx, art, out and err (what-types)
  inc = { { what = 'cbx', how = 'fcb' }, { what = 'out' }, { what = 'art', how = 'img' }, { what = 'err' } },
}

--- state stores the following:
--- * `log`, log levels per facility which register via `state:logger(id, 'level')
--- * `ctx`, the current document doc.meta.stitch part (i.e. doc config for stitch)
--- * `ccb`, the current codeblock being processed (created by `kb:new(cb)`)
--- * `seen`, a list of codeblocks seen sofar (directly or during recursion)
--- * `stack`, use `state:push/pop` to save/restore state.{ctx, ccb} in filter()
--- * `meta`, a copy of `doc.meta` inserted into doc's to be filtered (providing context)
--- Note: `kb:new(cb)` creates the current `ccb` and adds it to `seen`.
local state = {
  log = { stitch = 6 }, -- initial log level, overrididen by doc.meta.stitch
  ctx = nil, -- context of current document
  ccb = nil, -- current codeblock
  seen = {}, -- list of *all* codeblocks seen
  stack = {}, -- previous {ctx, ccb}'s when filters are called
  meta = {}, -- copy of doc.meta to be used in chunks or handed to filters
}

--[[----- logging ----------]]

--- Prints formatted `msg` to stdout for given `id` at `tier`-level.
-- nb: using `log(id, 'fatal', ..) is killing.
--- @param id string
--- @param tier string
--- @param msg string
local function log(id, tier, msg, ...)
  local level = log_level[tier] or 3 -- unknown tier is warning
  if (log_level[tier] or 0) > (state.log[id] or 0) then return end
  local prefix = sf('stitch[%s] %-5s %8s| ', #state.stack, tier, id)
  io.output():write(prefix, sf(msg, ...), '\n')
  io.output():flush()
  assert(level ~= 1, sf('fatal error logged by %s', id))
end

--[[----- helpers ----------]]

--- Returns a list of lines representing given `t` in yaml(-ish)
--- TODO: howto better represent a list, { [1] = .., [2] = ..} -> [.., ..]
--- @param t any
--- @return table yaml
local function toyaml(t, n, seen, acc)
  seen = seen or {}
  acc = acc or {} -- list of lines (strings)
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

-- Returns a printable string representing given `t`
local function tostr(t, seen, first, acc)
  seen = seen or {}
  acc = acc or ''
  first = nil == first

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
local function exists(filename) return true == os.rename(filename, filename) end

-- Read file, possibly convert its data using `pandoc.read(data,format)`
-- Returns `data` on success, `nil` on failure
--- @param filename string
--- @param format string?
--- @return any?
--- @return string? error
local function read(filename, format)
  log('stitch', 'debug', 'read file %s, format %s', filename, format or '<n/a>')
  if nil == filename then return nil, 'no filename given' end
  local fh, err = io.open(filename, 'r')
  if nil == fh then return nil, err end

  local dta = fh:read('*a')
  fh:close()

  if format and #format > 0 then
    local ok, data = pcall(pd.read, dta, format)
    if not ok then return nil, data end
    dta = data
    log('stitch', 'debug', 'data converted to %s', format)
  end

  return dta
end

--- Returns required `mod` and `name`,`func` on success or `nil` on failure.
-- nb: mod is the result of a succesful rquire, labels dropped while
-- searching are returned as `func`.
--- @param name string
--- @param acc string?
--- @return any mod, string? name, string? func
local function need(name, acc)
  if nil == name or 0 == #name then return nil end

  local ok, mod = pcall(require, name)
  if false == ok or true == mod then
    local last_dot = name:find('%.[^%.]+$')
    if not last_dot then return nil end
    local mm, ff = name:sub(1, last_dot - 1), name:sub(last_dot + 1)
    if ff and acc then ff = sf('%s.%s', ff, acc) end
    return need(mm, ff)
  else
    return mod, name, acc
  end
end

-- Returns a semi-deep copy of `t` (table, userdata, etc..)
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

--- Returns `dst` with values merged in from `src`, use `forced` to overwrite existing values
---@param dst table
---@param src table
---@param forced boolean?
---@return table
local function tmerge(dst, src, forced)
  assert('table' == type(dst), 'expected d to be a table, got ' .. type(dst))
  assert('table' == type(src), 'expected s to be a table, got ' .. type(src))
  if not dst then return tcopy(src) end
  forced = forced or false

  for k, v in pairs(src) do
    if not dst[k] then
      dst[k] = tcopy(v)
    elseif 'table' == type(dst[k]) and 'table' == type(v) then
      dst[k] = tmerge(dst[k], v, forced)
      if not getmetatable(dst[k]) then setmetatable(dst[k], tcopy(getmetatable(v))) end
    elseif forced then
      dst[k] = tcopy(v)
    end
  end
  if not getmetatable(dst) then setmetatable(dst, tcopy(getmetatable(src))) end
  return dst
end

--- Sets `ccb.sha` for given codeblock `ccb` and returns the sha1 fingerprint
--- @param ccb table
--- @return string sha
local function tosha(ccb)
  local keys = {}
  for k, _ in pairs(hard_coded_opts) do
    -- exclude options that donot affect actual output
    if not ('exe log old'):match(k) then keys[#keys + 1] = k end
  end
  table.sort(keys)

  local vals = {}
  for _, k in pairs(keys) do
    vals[#vals + 1] = tostr(ccb.opt[k])
  end
  vals[#vals + 1] = ccb.txt

  local str = table.concat(vals, ''):gsub('%s+', '')
  ccb.sha = pd.sha1(str)
  return ccb.sha
end

--[[----- parse ------------]]

local parse = {} -- forward declaration

parse.elm = {
  -- by pandoc type
  ['Inlines'] = function(v, d, s) return (d and parse:ast(v, d, s)) or pd.write(pd.Pandoc({ v }), 'plain'):sub(1, -2) end,
  -- by lua types
  ['nil'] = function() return nil end,
  thread = function() return nil end,
  table = function(v, d, s) return parse:ast(v, d, s) end,
  userdata = function(v, d, s) return parse:ast(v, d, s) end,
  ['function'] = function(v, d) return d and v or nil end,
  string = function(v) return v end,
  -- insist on 'yes'/'no' for consistency
  boolean = function(v) return v and 'yes' or 'no' end,
  number = function(v) return v end,
}

--- Returns doc element as regular lua table
function parse:ast(elm, detail, seen)
  seen = seen or {}
  detail = detail and true or false

  local t = detail and { [0] = { pandoc = pd.utils.type(elm), lua = type(elm), pointer = sf('%p', elm) } } or {}
  for k, v in pairs(elm) do
    if seen[v] then return v end --{ [k] = sf('<cyclic: %p> %s', v, v) } end
    if 'table' == type(v) or 'userdata' == type(v) then seen[v] = v end
    local parser = self.elm[pd.utils.type(v)] or self.elm[type(v)]
    t[k] = parser and parser(v, detail, seen)
  end
  return t
end

local function w(v) return sf('|%s|', v) end
parse.opt = setmetatable({
  -- check value type
  arg = function(v) return 'string' == type(v) and v or nil end,
  art = function(v) return 'string' == type(v) and v or nil end,
  cbx = function(v) return 'string' == type(v) and v or nil end,
  cmd = function(v) return 'string' == type(v) and v or nil end,
  dir = function(v) return 'string' == type(v) and v or nil end,
  err = function(v) return 'string' == type(v) and v or nil end,
  fmt = function(v) return 'string' == type(v) and v or nil end,
  oid = function(v) return 'string' == type(v) and v or nil end,
  out = function(v) return 'string' == type(v) and v or nil end,
  hdr = function(v) return tonumber(v) end,
  -- check actual values
  cls = function(v) return 'string' == type(v) and ('|no|yes|'):match(w(v)) and v or nil end,
  exe = function(v) return 'string' == type(v) and ('|yes|maybe|no|'):match(w(v)) and v or nil end,
  log = function(v) return 'string' == type(v) and ('|debug|error|warn|note|info|silent|'):match(w(v)) and v or nil end,
  old = function(v) return 'string' == type(v) and ('|purge|keep|'):match(w(v)) and v or nil end,
  run = function(v) return 'string' == type(v) and ('|system|chunk|noop|'):match(w(v)) and v or nil end,
  -- parse inc option value
  inc = function(v)
    -- `inc` is 1) 'cbx:fcb, ..', 2) {'cbx:out', ..} of 3) {{cbx='out', ..}, ..}
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
        spec[#spec + 1] = {
          what = part:match('^' .. pat),
          read = part:match('!' .. pat),
          filter = part:match('@' .. pat),
          how = part:match(':' .. pat),
        }
      elseif 'table' == type(part) and tonumber(k) then
        spec[#spec + 1] = {
          what = part.what,
          read = part.read,
          filter = part.filter,
          how = part.how,
        }
      else
        log('stitch', 'error', sf('ignoring inc[%s]=%s, illegal value', k, tostr(part)))
      end
    end
    return spec
  end,
}, {
  __index = function(_, k)
    log('stitch', 'debug', sf('%q is not a stitch option, kept as-is', k))
    return function(v) return v end
  end,
})

function parse:option(opt, val) return self.opt[opt](val) end

--[[----- State ------------]]

--- Returns the current recursion depth
function state:depth() return #self.stack end

--- Sets max log `level` for given `id`, unknown levels are set as debug level.
--- @param id string
--- @param level string
--- @return string identity
function state:logger(id, level)
  self.log[id] = log_level[level] or log_level.debug
  return id
end

--- Sets `state.ccb` to given `ccb` while adding it to `state.seen`
--- @param ccb table
--- @return number
function state:saw(ccb)
  self.seen[#self.seen + 1] = ccb
  self.ccb = ccb
  return #self.seen
end

--- Pushes a copy of `state.ctx` and `state.ccb` on the stack
function state:push() self.stack[#self.stack + 1] = { ctx = tcopy(self.ctx), ccb = tcopy(self.ccb) } end

--- Pops `state.ctx` & `state.ccb` from the stack, popping an empty stack is fatal
function state:pop()
  local idx = #self.stack
  if 0 == idx then
    log('stitch', 'fatal', '*** Cannot pop from empty stack ***')
  else
    local previous = self.stack[idx]
    self.ctx = previous.ctx
    self.ccb = previous.ccb
    self.stack[idx] = nil
  end
end

--- Sets `state.ctx` and `state.meta` from given Pandoc document `doc`
function state:context(doc)
  local meta = parse:ast(doc.meta)
  -- no `doc.meta.stitch` means empty context ctx
  local loglevel = sf('%s', ((meta.stitch or {}).stitch or {}).log or 'info')
  local lid = state:logger('stitch', loglevel)
  if not doc.meta.stitch then log(lid, 'warn', 'doc.meta has no stitch config') end

  local ctx = meta.stitch or {} -- toplevel `doc.meta.stitch`
  ctx.stitch = ctx.stitch or {} -- ensure stitch's own section in ctx
  for k, v in pairs(ctx) do
    if 'table' ~= type(v) then
      ctx[k] = nil -- remove toplevel ctx.option (not a table)
      if ctx.stitch[k] then
        local msg = 'stitch top level "%s=%s" overruled by section stitch: "%s=%s"'
        log('stitch', 'warn', msg, k, tostr(v), k, tostr(ctx.stitch[k]))
      else
        ctx.stitch[k] = v -- move toplevel ctx.option into ctx.stitch table
      end
    end
  end

  -- check option values, if invalid the codeblock will be skipped later on
  local bad = false
  for name, section in pairs(ctx) do
    log(lid, 'debug', '%q', name)
    for option, value in pairs(section) do
      -- local val = parse_opt(option, value)
      local val = parse:option(option, value)
      if nil == val then
        bad = true
      else
        section[option] = val
      end
      log(lid, 'debug', '- %s.%s = %s (= %s)', name, option, tostr(section[option]), bad and 'invalid!' or 'ok')
    end
    section.bad = bad
  end

  -- setup log levels for all sections
  for name, section in pairs(ctx) do
    local level = section.log or 'info'
    state:logger(name, level)
    log('stitch', 'debug', '%s log level set to %s', name, level)
  end

  -- option resolution order: ctx -> defaults -> hardcoded
  local defaults = ctx.defaults or {}
  setmetatable(defaults, { __index = hard_coded_opts })
  setmetatable(ctx, { __index = function() return defaults end })
  ctx.defaults = nil
  for name, section in pairs(ctx) do
    if 'table' == type(section) then
      setmetatable(section, { __index = defaults })
    else
      log(lid, 'debug', 'stitch.%s=%s', name, section)
      ctx.stitch[name] = section -- aka ctx[name] is a value, not table
      ctx[name] = nil
    end
  end

  log(lid, 'info', 'doc (%s) options done', meta.title or "''")
  self.ctx = ctx
  self.meta = meta
end

--[[----- kodeblock --------]]

--- Class to represent current codeblock instances (`ccb`'s)
---
--- - `ccb:run()` to actually setup and run a codeblock
--- - `ccb:inc()` to build list of elements to include
--- - ccb instance fields:
---   * `oid` ccb's object identifier
---   * `opt` ccb's attributes
---   * `cls` ccb's classes
---   * `txt` ccb's text (content)
---   * `ast` parsed ast for `cb`
---   * `org` the original `cb`
---   * `cfg` ccb's config `ctx.stitch.section` name (nil = not eligible)
---   * `bad` flags codeblock has errors (if any)
local kb = {

  -- function jump-table for the `run`-option attribute of codeblock
  -- * run types include `system`, `chunk` or `noop`
  run = setmetatable({}, {
    __index = function(_, key)
      -- kb.run[run=method](ccb) -> _ is kb.run table, k is absent key being looked up
      return function(self)
        self.bad = true
        log(self.oid, 'error', 'codeblock unknown run type %q', key)
      end
    end,

    __call = function(run, ccb)
      local oid = ccb.oid
      ccb:setup() -- required for cbx creation, also sets bad on errors

      if ccb.bad or ccb.opt.bad then
        log(oid, 'warn', 'codeblock run skipped due to errors')
        return nil
      elseif 'no' == ccb.opt.exe then
        log(oid, 'warn', 'codeblock run skipped (exe = no)')
        return nil
      elseif 'maybe' == ccb.opt.exe and ccb:total_recall() then
        log(oid, 'info', 'codeblock run skipped, results already exist')
        return nil
      end
      log(oid, 'debug', 'codeblock cmd is %s', ccb.opt.cmd)

      run[ccb.opt.run](ccb)
    end,
  }),

  --- function jump-table for `how`-to part of an directive
  --- * `how` includes `fcb`, `img`, `fig`, absent `how` means `any`-how
  inc = setmetatable({}, {
    __index = function(inc, how)
      -- nil means do default, otherwise how is unknown and an error
      return nil == how and inc.any or inc.err
    end,

    --- handles `how` to include an artifact
    __call = function(inc, ccb)
      -- inc is this table, ccb is self from ccb:inc()
      local elms = {} -- accumulator for the includes
      local opt, oid = ccb.opt, ccb.oid

      for idx, todo in pairs(opt.inc) do
        log(oid, 'debug', 'include processing inc[%d] = %s', idx, tostr(todo))
        local dta, elm, msg, err
        dta, err = read(opt[todo.what], todo.read)
        if err then
          log(oid, 'error', 'include failed for inc[%d] = %s (%s)', idx, tostr(todo), err)
          break
        end

        dta, msg = ccb:filter(dta, todo.filter)
        if nil == dta then
          log(oid, 'debug', 'include filter failed %s (%s)', todo.filter, msg)
          break
        end

        elm = inc[todo.how](ccb, idx, dta)
        if nil == elm then
          log(oid, 'debug', 'include inc[%d] = %s failed to produce a result', idx, tostr(todo))
        elseif 'Block' == pd.utils.type(elm) then
          elms[#elms + 1] = elm
          log(oid, 'debug', 'include inc[%d] = %s succeeded', idx, tostr(todo))
        elseif 'Blocks' == pd.utils.type(elm) then
          for _, block in pairs(elm) do
            elms[#elms + 1] = block
          end
          log(oid, 'debug', 'include inc[%d] = %s doc fragment succeeded', idx, tostr(todo))
        else
          msg = 'include inc[%d] = %s cannot include pandoc type %s'
          log(oid, 'debug', msg, idx, tostr(todo), pd.utils.type(elm))
        end
      end
      return elms -- passed back to pandoc as result of CodeBlock(cb)
    end,
  }),
}

--[[----- kb.run:<as> ------]]

-- run=<kind> - function for each kind of run
-- ccb:run() -> __call does the setup and runs kb.run[<kind>](self)

-- ccb run as noop, just logs it is not really running
function kb.run:noop() log('stitch', 'info', '(%s) codeblock not run, run = noop', self.oid) end

-- run ccb as system command
function kb.run:system()
  local oid = self.oid
  local ok, code, nr = os.execute(self.opt.cmd)
  if ok then
    log(oid, 'info', 'codeblock system command succeeded')
  else
    log(oid, 'error', 'codeblock system command failed with %s(%s)', code, nr)
    self.bad = true
  end
end

-- run ccb as lua chunk with _ENV.Stitch set
function kb.run:chunk()
  local oid = self.oid

  _ENV.Stitch = {
    -- provide some state & utils to chunk
    ctx = tcopy(state.ctx),
    ccb = tcopy(state.ccb),
    seen = tcopy(state.seen),
    meta = tcopy(state.meta),
    log = log,
    tostr = tostr,
    toyaml = toyaml,
  }

  local func, error = loadfile(self.opt.cbx, 't', _ENV)
  if func == nil or error then
    log(oid, 'error', 'codeblock chunk failed: %s', error)
  else
    local ok, err = pcall(func)
    if ok then
      log(oid, 'info', 'codeblock chunk succeeded')
    else
      log(oid, 'error', 'codeblock chunk failed wih: %s', err)
    end
  end
end

--[[----- kb.inc:<what> ----]]

--- Returns a default pandoc element for `inc[idx]` directive without a `how`.
function kb.inc:any(idx, dta)
  local todo = self.opt.inc[idx]
  log(self.oid, 'debug', 'include any for %s', tostr(todo))
  local opt = self.opt
  local what = opt.inc[idx].what
  local oid = sf('%s-%d-%s', self.oid, idx, opt.inc[idx].what)
  local fcb = self:clone(oid)

  if 'Pandoc' == pd.utils.type(dta) then
    -- try to transfer some attributes to dta.blocks[1]
    log(self.oid, 'debug', 'include pandoc fragement for %s', tostr(opt.inc[idx]))
    if dta.blocks[1].attr then
      dta.blocks[1].attributes = fcb.attributes
      dta.blocks[1].classes = fcb.classes
      dta.blocks[1].identifier = fcb.identifier
    end
    if dta.blocks[1].caption then dta.blocks[1].caption = { fcb.caption or fcb.attributes.caption } end
    return dta.blocks
  elseif 'art' == what then
    return kb.inc.fig(self, idx)
  elseif 'cbx' == what then
    fcb.text = dta
    return fcb
  else
    return kb.inc.fcb(self, idx, dta)
  end
end

--- Returns a Plain element (error message) for `inc[idx]`'s directive.
---
--- When this function gets called, `kb.inc` was indexed with an unknown `how` to
--- include, i.e. not an `fcb`, `fig`, `img` or `any` which figures out a default for
--- the `what` being included.  In other words, the `inc`-option contains an illegal
--- 'how' either in the codeblock attributes or the meta section of the document.
--- @param idx number
--- @return table
function kb.inc:err(idx, _)
  local todo = self.opt.inc[idx]
  local err = sf('stitch: include error, unknown how "%s" in %s', todo.how, tostr(todo))
  return pd.Plain(sf('<stitch error> %s', err))
end

--- Wraps `dta` in a new fenced codeblock
---
--- A `Pandoc` document to be included, is converted to `native` format.
--- A codeblock to included, is converted to markdown (including its attributes).
--- Otherwise, `dta` is assumed to be text and included as-is as `fcb.text`.
--- @param idx number
--- @return table
function kb.inc:fcb(idx, dta)
  local todo = self.opt.inc[idx]
  local id = sf('%s-%d-%s', self.oid, idx, todo.what)
  dta = dta or '<nil>'
  local fcb = self:clone(id)
  if 'Pandoc' == pd.utils.type(dta) then
    (dta.blocks[1] or {}).attr = fcb.attr
    fcb.text = pd.write(dta, 'native')
  elseif 'cbx' == todo.what then
    -- NOTE: this discards dta
    fcb.text = pd.write(pd.Pandoc(self.org, {}), 'markdown')
  else
    fcb.text = dta
  end
  return fcb
end

--- Returns a Figure link for `inc[idx]`
function kb.inc:fig(idx, _)
  -- img.identifier set correctly thanks to idx being passed on
  local img = kb.inc.img(self, idx).content[1]
  return pd.Figure(img, { img.caption }, img.attr)
end

--- Returns an Image link for `inc[idx]`.
function kb.inc:img(idx, _)
  local what = self.opt.inc[idx].what
  local src = self.opt[what]
  local img = pd.Image({}, src)
  -- img fields: caption, src, title, attr, identifier, classes, attributes, tag
  for k, v in pairs(self.opt) do
    if not hard_coded_opts[k] then img.attributes[k] = tostr(v) end
  end
  for _, class in ipairs(self.cls) do
    if 'stitch' ~= class then img.classes[#img.classes + 1] = class end
  end
  img.attributes.title = nil -- no longer needed
  img.attributes.caption = nil -- dito
  img.title = self.opt.title
  img.caption = { self.opt.caption }
  img.identifier = sf('%s-%d-%s', self.oid, idx, what)
  return pd.Para(img)
end

--[[----- kb:<others> ------]]

--- Returns filtered `data`,`info` or nil,`error` on failure.
--
-- Searches to require `name`, which may be `mod.func`.  If `func` is
-- not defined after a search it is assumed to be `Pandoc`.
--
-- If the `mod` found does not export `func` (`Pandoc` or as found), then
-- `mod` is assumed to be a list of filters each exporting `func` and they
-- are called in the order listed.  So a pandoc filter needs to export `Pandoc`.
--- @param data any
--- @param name string
--- @return any data, string msg
function kb:filter(data, name)
  if nil == data then return nil, 'no data supplied to filter' end
  if nil == name or 0 == #name then return data, 'no filter supplied' end

  local count = 0
  local mod, _, fun = need(name)
  if nil == mod then return nil, sf('unable to require %q', name) end

  fun = fun or 'Pandoc'
  local filters = mod.fun and { mod } or mod

  if 'Pandoc' == pd.utils.type(data) then
    data.meta = tmerge(data.meta, state.meta)
    -- NOTE: this overrides (or adds?) shift in headers (doc.meta.stitch.hdr)
    local hdr = self.opt.hdr or 0
    -- data.meta = tmerge(data.meta, { stitch = { hdr = hdr } }, true)
    data.meta = pd.MetaMap(tmerge(data.meta, { stitch = { hdr = hdr } }, true))
  end

  state:push()
  for _, filter in ipairs(filters) do
    if filter[fun] then
      local ok, tmp = pcall(filter[fun], data)
      data = ok and tmp or data
      count = ok and count + 1 or count
    end
  end
  state:pop()

  return data, sf('%d/%d applied', count, #filters)
end

--- Returns a new current codeblock `ccb` for given Pandoc.CodeBlock `cb`.
--
-- A codeblock is explicitly eligible for stitch processing if it has a `stitch=name`
-- attribute or it has `stitch` as one of its classes.  A codeblock also qualifies if a
-- stitch config section exists for its identifier (rare) or when one of its
-- classes matches a section that has `cls=yes` option set.
--
-- Note: use `kb:is_eligible(ccb)` to check if stitch can process the codeblock
-- after `kb:new(cb)`
--
--- @param cb table
--- @return table ccb
function kb:new(cb)
  local oid = sf('%s', cb.attr.identifier)
  oid = #oid == 0 and sf('anon%02d', #state.seen + 1) or oid
  state:logger(oid, cb.attr.attributes.log or 'debug') -- if unknown, becomes debug
  local ccb = parse:ast(cb)
  local cfg = self:config(oid, ccb) -- link to config section
  local bad = cfg == nil

  -- check option values
  local opt = setmetatable({}, { __index = state.ctx[cfg] })
  for option, value in pairs(ccb.attr.attributes) do
    -- local val = parse_opt(option, value)
    local val = parse:option(option, value)
    if nil == val then
      bad = true
      log(oid, 'error', '(#%s) %s=%s (illegal value)', oid, option, tostr(value))
    end
    opt[option] = val
  end

  local new = {
    cfg = cfg, -- if nil, cb is not eligible for stitch processing
    cls = ccb.attr.classes,
    opt = opt, -- cb's options with valid values
    txt = ccb.text, -- for convenience
    ast = ccb, -- parsed ast for cb (for debugging)
    oid = oid, -- object identifier
    org = cb, -- original cb (for debugging)
    sha = '', -- calculated later using new itself
    bad = bad, -- if true, codeblock skipped, all operations check this flag
  }
  new.sha = tosha(new)

  -- expand #var's used in option values
  local kvmap = tmerge(opt, { sha = new.sha, oid = new.oid })
  local expandables = { 'cbx', 'art', 'out', 'err', 'cmd' }
  for _, expandable in ipairs(expandables) do
    opt[expandable] = pd.path.normalize(opt[expandable]:gsub('%#(%w+)', kvmap))
    kvmap[expandable] = opt[expandable] -- tricky: needed for cmd to expand fully
  end

  -- check all are expanded
  for k, v in pairs(expandables) do
    if 'string' == type(v) and v:match('%#' .. k) then
      log(oid, 'error', 'option %s not fully expanded: %s', k, v)
      new.bad = true
    end
  end

  self.__index = self
  setmetatable(new, self)
  state:saw(new) -- save to state.seen
  return new
end

--- Returns section config name for given `ccb`, nil when no config was found
--- @param oid string
--- @param ccb table
--- @return string? config
function kb:config(oid, ccb)
  -- ccb is not a kb-instance yet, just freshly parsed cb (parse_elm(cb))
  local cfg = ccb.attr.attributes.stitch -- 1. stitch=name
  if cfg and nil == rawget(state.ctx, cfg) then
    log(oid, 'debug', 'config stitch=%s (non-existent) using defaults instead', cfg)
    return 'defaults'
  elseif cfg then
    log(oid, 'debug', 'config stitch=%s', cfg)
    return cfg
  end

  -- 2. cb id has section in ctx.stitch
  cfg = rawget(state.ctx, oid)
  if cfg then
    log(oid, 'debug', 'config %s found by cb id', oid)
    return oid
  end

  -- 3. a ccb class matches with a section & ccb.cls allows matching
  if 'no' ~= ccb.attr.attributes.cls then
    for _, class in ipairs(ccb.attr.classes) do
      local section = rawget(state.ctx, class) -- don't fallback to defaults
      cfg = section and 'no' ~= section.cls and class or nil
      if cfg then break end
    end

    if cfg then
      log(oid, 'debug', 'config %s found by link to section', cfg)
      return cfg
    end
  end

  cfg = pd.List.find(ccb.attr.classes, 'stitch') -- 4. .stitch class
  if cfg then
    log(oid, 'debug', 'config by .stitch class, so using defaults')
    return 'defaults'
  end

  log(oid, 'warn', 'config not found')
  return nil
end

--- Returns a codeblock clone with, a possibly, new `id` and stitch stuff removed.
--- @param id string?
--- @return table
function kb:clone(id)
  local rv = self.org:clone()

  rv.classes = pd.List.filter(rv.classes, function(c) return c ~= 'stitch' end)
  for k, _ in pairs(hard_coded_opts) do
    rv.attributes[k] = nil
  end
  rv.identifier = id and id or rv.identifier

  return rv
end

--- Returns true if cbx-file and one or more of art,out,err-files exist
function kb:total_recall()
  local artifacts = exists(self.opt.art) or exists(self.opt.out) or exists(self.opt.err)
  return exists(self.opt.cbx) and artifacts
end

--- Removes old files, returns the number of files removed
--- @return number count
function kb:purge()
  local oid = self.oid
  local count = 0

  if self.bad then return count end

  if 'purge' ~= self.opt.old then
    log(oid, 'info', 'purge skipped (old=%s)', self.opt.old)
    return count
  end

  for _, ftype in ipairs({ 'cbx', 'out', 'err', 'art' }) do
    local fnew = self.opt[ftype]
    local pat = fnew:gsub('[][()%.*+^$?-]', '%%%1') -- literal magic
    local n = 0
    pat, n = pat:gsub(self.sha, '(%%w+)')
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

--- Returns true if setup succeeded, false otherwise
--- Creates the necessary directories as well as the cbx-file
function kb:setup()
  local oid = self.oid
  for _, path in ipairs({ 'cbx', 'art', 'out', 'err' }) do
    local dir = pd.path.normalize(pd.path.directory(self.opt[path]))
    if exists(dir) then
      log(oid, 'debug', 'using directory %s for %s-file', dir, path)
    else
      log(oid, 'debug', 'creating directory %s for %s-file', dir, path)
      if not os.execute(sf('mkdir -p %s', dir)) then
        log(oid, 'error', 'permission denied when creating ', dir)
        self.bad = true
        return false
      end
    end
  end

  log(oid, 'debug', 'writing out %d chars to %s', #self.txt, self.opt.cbx)
  local fh = io.open(self.opt.cbx, 'w')
  if not (fh and fh:write(self.txt)) then
    log(oid, 'error', 'error writing out cbx-file %s', self.opt.cbx)
    self.bad = true
    return false
  end
  fh:close()

  if not os.execute(sf('chmod u+x %s', self.opt.cbx)) then
    log(oid, 'error', 'could not mark cbx as executable: %s', self.opt.cbx)
    self.bad = true
    return false
  end
  return true
end

--[[---- STITCH -----------]]

local function CodeBlock(cb)
  local ccb = kb:new(cb) -- also registers oid as logger
  local oid = ccb.oid

  if not ccb:is_eligible() then
    log(oid, 'warn', '(%s) skipped, codeblock not eligible', oid)
    return nil
  elseif ccb.bad then
    log(oid, 'error', '(%s) skipped, codeblock contains errors', oid)
    return nil
  end

  log(oid, 'info', 'processing codeblock using config %q', ccb.cfg)
  ccb:run()
  ccb:purge()
  return ccb:inc()
end

local function Header(elm)
  local level = elm.level + math.floor(tonumber(state.ctx.stitch.hdr) or 0)
  if level ~= elm.level then
    level = level > 0 and level or 0
    local hid = elm.identifier
    hid = #hid > 0 and sf('%s: ', hid) or hid
    log('stitch', 'note', 'header %slevel shifted from %d to %d', hid, elm.level, level)
    elm.level = level
  end
  return elm
end

local function Pandoc(doc)
  local lid = state:logger('stitch', 'info')
  -- log(lid, 'info', "new document ('%s')", tostr(parse_elm_by['Inlines'](doc.meta.title)))
  log(lid, 'info', "new document ('%s')", tostr(parse.elm['Inlines'](doc.meta.title)))

  state:context(doc)
  local hdr = 0 ~= tonumber(state.ctx.stitch.hdr)
  local rv = doc:walk({ CodeBlock = CodeBlock, Header = hdr and Header })

  log(lid, 'info', 'done .. saw %s codeblocks', #state.seen)

  return rv
end

--[[ shenanigans ]]
local M = {
  Pandoc = Pandoc,
  _bustit = package.loaded.busted and {
    kb = kb,
    state = state,
    parse = parse,
    helpers = { tostr = tostr, toyaml = toyaml, tcopy = tcopy, tmerge = tmerge, tosha = tosha },
  },
}
M = pd and _ENV.PANDOC_VERSION >= '3.5' and M or { M }
package.loaded.stitch = M
return package.loaded.stitch
