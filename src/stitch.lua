--[[-- stitch --]]
-- TODO:
-- [o] check utf8 requirements (if any)
-- [o] add mediabag to store files related to cb's
-- [o] add `Code` handler to insert pieces of a CodeBlock from mediabag
-- [?] add `meta` as inc target for troubleshooting meta!read@filter:fcb
-- [ ] check all pd.<f>'s used and establish oldest version possible
-- [x] make stitch also shift headers based on doc.meta.stitch.xxx.hdr
-- [ ] REVIEW: add stitch classes list to treat as stichable
-- [?] REVIEW: option lua=chunk just runs dofile(cbx)()() ?
-- [ ] add I.dump(table) -> list of strings, shallow dump of table

-- ensure we're loaded only once (see notes on module's return statement)
if package.loaded.stitch then return package.loaded.stitch end

local pd = require('pandoc') -- shorthand & no more 'undefined global "pandoc"'

_ENV.PANDOC_VERSION:must_be_at_least('3.0')

--[[-- state --]]

local MAXTAIL = 6 -- max tail length (aka recursion depth)
local tail = {} -- stack of saved states during recursion
local I = {} -- Stitch's Implementation; for testing
I.opts = { log = 'info' } --> for initial logging, is reset for each cb
I.level = {
  silent = 0,
  error = 1,
  warn = 2,
  note = 3,
  info = 4,
  debug = 5,
}
I.cbc = 0 -- codeblock counter
I.hdc = 0 -- header counter
I.ctx = {} -- this doc's context (= meta.stitch)

--[[-- helpers --]]

-- print a formatted log to stderr (if cb's log level permits it)
-- uses `I.opts.cid` or 'stitch' as log entry originator
function I.log(lvl, action, msg, ...)
  -- log format: [stitch:recursLevel logLevel] owner :action | msg
  local level = I.level[I.opts.log or I.ctx.stitch.log] or 0
  if level >= I.level[lvl] then
    local owner = I.opts.cid or 'stitch'
    local fmt = string.format('[stitch:%d %6s] %-7s:%7s| %s\n', #tail, lvl, owner, action, msg)
    io.stderr:write(string.format(fmt, ...))
  end
end

I.log('note', 'stitch', 'module is being loaded/initialized')

-- return a semi-deep copy of table t
-- (used to provide a copy of I to external filters)
function I.dcopy(t, seen)
  seen = seen or {}
  if 'table' ~= type(t) then return t end
  if seen[t] then return seen[t] end

  local tt = {}
  seen[t] = tt
  for k, v in pairs(t) do
    tt[I.dcopy(k, seen)] = I.dcopy(v, seen)
  end
  setmetatable(tt, I.dcopy(getmetatable(t), seen))
  return tt
end

-- poor man's yaml representation of a table as a list of lines
-- (assumes all keys are strings)
function I.yaml(t, n, seen)
  seen = seen or {}
  n = n or 0
  if 'table' ~= type(t) then return string.format("'%s'", t) end
  if seen[t] then return seen[t] end

  local tt = {}
  seen[t] = tt
  for k, v in pairs(t) do
    local indent = string.rep(' ', n)
    local nl = 'table' == type(v) and '\n' or ' '
    local kk = 'string' == type(k) and k or string.format('[%s]', k)
    local vv = I.yaml(v, n + 2, seen)
    if 'table' == type(vv) then vv = table.concat(vv, '\n') end
    tt[#tt + 1] = string.format('%s%s:%s%s', indent, kk, nl, vv)
  end
  return tt
end

--[[-- data --]]

I.optvalues = {
  cls = { true, false, 'true', 'false', 'yes', 'no' },
  exe = { true, false, 'true', 'false', 'yes', 'no', 'maybe' },
  log = { 'silent', 'error', 'warn', 'notify', 'info', 'debug' },
  lua = { 'chunk', '' },
  old = { 'keep', 'purge' },
  inc_what = { 'cbx', 'art', 'out', 'err' },
  inc_how = { "''", 'any', 'fcb', 'img', 'fig' },
}

I.hardcoded = {
  -- resolution order: cb -> meta.<cfg> -> defaults -> hardcoded
  arg = '', -- (extra) arguments to pass in to `cmd`-program on the cli (if any)
  art = '#dir/#cid-#sha.#fmt', -- artifact (output) file (if any)
  cbx = '#dir/#cid-#sha.cbx', -- the codeblock.text as file on disk
  cid = 'x', -- either cb.identifier or set by stitch using I.cbc
  cls = 'no', -- {'true', 'false', 'yes', 'no', '0', '1', '2', '3'}
  cmd = '#cbx #arg #art 1>#out 2>#err', -- cmd template string, expanded last
  dir = '.stitch', -- where to store files (abs or rel path to cwd)
  err = '#dir/#cid-#sha.err', -- capture of stderr (if any)
  exe = 'maybe', -- {yes, no, maybe}
  fmt = 'png', -- format for images (if any)
  inc = 'cbx:fcb out:fcb art:img err:fcb',
  log = 'info', -- {debug, error, warn, info, silent}
  lua = '', -- {chunk, ''}
  old = 'purge', -- {keep, purge}
  out = '#dir/#cid-#sha.out', -- capture of stdout (if any)
}

--[[-- options --]]

-- check pre-defined option,value-pairs, removing those that are not valid
---@param opts table single, flat, k,v store of options (v's are strings)
---@return table opts same table with illegal option,values removed
function I.check(opts)
  for k, _ in pairs(I.optvalues) do
    local val = opts[k]
    local ok, err = I.vouch(k, val)
    if val and not ok then
      opts[k] = nil
      I.log('error', 'check', err)
    end
  end
  return opts
end

-- parse `I.opts.inc` into list: {{what, format, filter, how}, ..}
---@param inc string the I.opts.inc string with include directives
---@return table directives list of 4-element lists of strings
function I.parse(inc)
  -- str is what:type!format+extensions@module.function, ..
  local directives = {}
  local part = '([^!@:]+)'

  inc = pd.utils.stringify(inc):gsub('[,%s]+', ' ')
  for p in inc:gmatch('%S+') do
    directives[#directives + 1] = {
      p:match('^' .. part) or '', -- what to include
      p:match('!' .. part) or '', -- read as type
      p:match('@' .. part) or '', -- filter
      p:match(':' .. part) or 'any', -- how to include (type of element)
    }
  end

  -- no validity checking:
  -- * an invalid what-value will be skipped by I.result
  -- * an invalid how-value will be ignored
  I.log('debug', 'include', "found %s inc's in '%s'", #directives, inc)

  return directives
end

-- checks if `name`,`value` is a valid pair according to `I.optsvalues`
-- (not all options have predefines value ranges)
---@param name string the name of the option
---@param value any the value of the option
---@return boolean ok true if `value` is valid for given, valid, `name`, false otherwise
---@return string? err message in case of invalid `name` or `value`, nil otherwise
function I.vouch(name, value)
  local values = I.optvalues[name]
  if not values then return false, string.format("'%s' is not a known option", name) end
  value = string.format('%s', value) -- valid values listed as strings

  for _, v in ipairs(values) do
    if value == v then return true, nil end
  end

  local err = "option '%s' expects one of {%s}, got %q"
  local valid = {}
  for _, v in ipairs(values) do
    valid[#valid + 1] = string.format('%q', v)
  end

  err = string.format(err, name, table.concat(valid, ', '), value)
  return false, err
end

-- translate metadata-like AST elements into lua table(s)
---@param elm any either `doc.meta`, a `CodeBlock` or lua table
---@return any regular table with lua key,values-pairs
function I.xlate(elm)
  -- note: xlate(doc.blocks) -> list of cb tables.
  -- `:Open https://pandoc.org/MANUAL.html#extension-fenced_code_attributes`
  -- `:Open https://pandoc.org/MANUAL.html#extension-fenced_code_blocks`
  local ptype = pd.utils.type(elm)
  if 'Meta' == ptype or 'table' == ptype or 'AttributeList' == ptype then
    local t = {}
    for k, v in pairs(elm) do
      t[k] = I.xlate(v)
    end
    return t
  elseif 'List' == ptype or 'Blocks' == ptype then
    local l = {}
    for _, v in ipairs(elm) do
      l[#l + 1] = I.xlate(v)
    end
    return l
  elseif 'Inlines' == ptype or 'string' == ptype then
    return pd.utils.stringify(elm)
  elseif 'boolean' == ptype or 'number' == ptype then
    return elm
  elseif 'nil' == ptype then
    return nil
  elseif 'attr' == ptype then
    local t = {
      identifier = elm.identifier,
      classes = I.xlate(elm.classes),
      attributes = {},
    }
    for k, v in pairs(elm.attributes) do
      t.attributes[k] = I.xlate(v)
    end
    return t
  elseif 'CodeBlock' == elm.tag then
    -- a CodeBlock is an instance of type Block, elm.tags differentiate between Block's
    return {
      text = elm.text,
      attr = I.xlate(elm.attr),
    }
  else
    I.log('warn', 'xlate', "skipping unknown type '%s'? for %s", ptype, tostring(elm))
    return nil
  end
end

--[[-- files --]]

-- sha1 hash of (stitch) option values and codeblock text
---@param cb table a pandoc codeblock
---@return string sha1 hash of option values and codeblock content
function I.mksha(cb)
  -- for repeatable fingerprints: keys are sorted, whitespace removed
  local hardcoded_keys = {}
  local skip_keys = 'exe old log' -- these don't change cb-results
  for key in pairs(I.hardcoded) do
    if not skip_keys:match(key) then hardcoded_keys[#hardcoded_keys + 1] = key end
  end
  table.sort(hardcoded_keys) -- sorts inplace

  local vals = {}
  for _, key in ipairs(hardcoded_keys) do
    vals[#vals + 1] = pd.utils.stringify(I.opts[key]):gsub('%s', '')
  end
  vals[#vals + 1] = cb.text:gsub('%s', '') -- also no wspace

  return pd.utils.sha1(table.concat(vals, ''))
end

-- create conditions for codeblock execution and set I.opts.exe
---@param cb table pandoc codeblock
---@return boolean ok success indicator
function I.mkcmd(cb)
  -- create dirs for cb's possible output files
  for _, fpath in ipairs({ 'cbx', 'out', 'err', 'art' }) do
    -- `normalize` (v2.12) makes dir platform independent
    local dir = pd.path.normalize(pd.path.directory(I.opts[fpath]))
    if not os.execute('mkdir -p ' .. dir) then
      I.log('error', 'command', 'permission denied when creating ' .. dir)
      return false
    end
  end

  -- cb.text becomes executable on disk (TODO:
  -- if not flive(fname) then .. else I.log(reuse) end
  local fh = io.open(I.opts.cbx, 'w')
  if not fh then
    I.log('error', 'command', 'cbx could not open file: ' .. I.opts.cbx)
    return false
  end
  if not fh:write(cb.text) then
    fh:close()
    I.log('error', 'command', 'cbx could not write to: ' .. I.opts.cbx)
    return false
  end
  fh:close()

  if not os.execute('chmod u+x ' .. I.opts.cbx) then
    I.log('error', 'command', 'cbx could not mark executable: ' .. I.opts.cbx)
    return false
  end

  I.log('info', 'command', "expanding template '%s'", I.opts.cmd)
  I.opts.cmd = I.opts.cmd:gsub('%#(%w+)', I.opts)
  I.log('info', 'command', '%s', I.opts.cmd)
  return true
end

-- return true if `filename` exists, false otherwise
---@param filename string path to a file
---@return boolean exists true or false
function I.freal(filename) return true == os.rename(filename, filename) end

-- read file `name` and, possibly, convert to pandoc ast using `format`
---@param name string file to read
---@param format? string convert file data to ast using a pandoc reader ("" to skip)
---@return string|table? data file data, ast or nil (in case of errors)
function I.fread(name, format)
  local ok, dta
  local fh, err = io.open(name, 'r')

  if nil == fh then
    I.log('error', 'read', '%s %s', name, err)
    return nil
  end

  dta = fh:read('*a')
  fh:close()
  I.log('debug', 'read', '%s, %d bytes', name, #dta)

  if format and #format > 0 then
    ok, dta = pcall(pd.read, dta, format)
    if ok then
      I.log('info', 'read', 'pandoc.read as %s succeeded (got type %s)', format, pd.utils.type(dta))
      return dta
    else
      I.log('error', 'read', 'pandoc.read as %s failed: %s', format, dta)
      return nil
    end
  end

  return dta
end

-- save `doc` to given `fname`, except when it's an ast
---@param doc string|table? doc to be saved
---@param fname string filename to save doc with
---@return boolean ok success indicator
function I.fsave(doc, fname)
  if 'string' ~= type(doc) then
    I.log('info', 'write', "%s, skipped writing '%s'", fname, type(doc))
    return false
  end

  local fh = io.open(fname, 'w')
  if nil == fh then
    I.log('error', 'write', '%s, unable to open for writing', fname)
    return false
  end

  local ok, err = fh:write(doc)
  fh:close()

  if not ok then
    I.log('error', 'write', '%s, error: %s', fname, err)
    return false
  end

  I.log('debug', 'write', '%s, %d bytes', fname, #doc)
  return true
end

-- remove old files from past runs of current codeblock
---@return number count number of files removed
function I.fkill()
  local count = 0
  if 'purge' ~= I.opts.old then
    I.log('info', 'files', "not purging old files: cb.old='%s'", I.opts.old)
    return count
  end
  I.log('info', 'files', 'looking for old files ..')

  for _, what in ipairs({ 'cbx', 'out', 'err', 'art' }) do
    local fnew = I.opts[what]
    local pat, cnt = fnew, 0 -- since filenames are expanded, pat includes full path
    local dir = pd.path.directory(pat)
    -- nomagic chars
    local magic = '^$()%.[]*+-?'
    for i = 1, #magic do
      local char = '%' .. magic:sub(i, i)
      pat = pat:gsub(char, '%' .. char)
    end

    -- this only works is file template is <other text>-#sha.<ext>
    pat, cnt = pat:gsub(I.opts.sha, '(%%w+)') -- swap sha of un-magic'd fnew with capture pattern
    -- usage of #sha in filename templates is not mandatory, so check pattern
    if cnt == 1 then
      for _, fold in ipairs(pd.system.list_directory(dir)) do
        fold = pd.path.join({ dir, fold })
        if fold:match(pat) and fold ~= fnew then
          local ok, err = os.remove(fold) -- pd.system.remove needs version >=3.7.1
          if not ok then
            I.log('error', 'files', 'unable to remove: %s (%s)', fold, err)
          else
            count = count + 1
            I.log('debug', 'files', '- removed %s', fold)
          end
        end
      end
    else
      I.log('warn', 'files', '`#%s` template without `#sha` (%s), unable to detect old files', what, I.opts.sha)
    end
  end

  return count
end

-- says whether this cb was seen before (2+ artifacts already exist)
---@return boolean deja_vu true iff cb's `cbx` & 1+ artifacts exist, false otherwise
function I.deja_vu()
  -- don't collapse this
  return I.freal(I.opts.cbx) and (I.freal(I.opts.out) or I.freal(I.opts.err) or I.freal(I.opts.art))
end

--[[-- AST --]]

I.mkelm = {}
setmetatable(I.mkelm, {
  __index = function(t, how)
    local keys = {}
    for k, _ in pairs(t) do
      keys[#keys + 1] = string.format('%q', k)
    end
    table.sort(keys)
    local valid = table.concat(keys, ', ')
    local msg = string.format("expected `how` to be one of {%s}, got '%s'", valid, how)
    I.log('error', 'include', msg)
    return function() return {} end
  end,
})

-- functions result should be either type Block or type Blocks
function I.mkelm.fcb(fcb, cb, doc, what)
  -- pandoc.CodeBlock type is Block

  if 'Pandoc' == pd.utils.type(doc) then
    -- doc converted to pandoc native form, attr copied if possible
    if doc and doc.blocks[1].attr then
      doc.blocks[1].attr = fcb.attr -- else wrap in Div w/ fcb.attr?
    end
    fcb.text = pd.write(doc, 'native')
  elseif 'cbx' == what then
    -- doc discarded, org cb included (in markdown format)
    fcb.text = pd.write(pd.Pandoc({ cb }, {}), 'markdown')
  else
    -- doc used as-is for out, err
    fcb.text = doc
  end
  I.log('info', 'include', "'#%s' for '%s:fcb' as fenced pandoc.CodeBlock", fcb.attr.identifier, what)

  return fcb
end

function I.mkelm.img(fcb, _, _, what)
  -- wrap pandoc.Image (type Inline) in a pandoc.Para (type Block)
  -- `:Open https://github.com/pandoc/lua-filters/blob/master/diagram-generator/diagram-generator.lua#L360`
  --  [ ] TODO: if PD_VERSION < 3 -> title := fig:title, then pandoc will treat it as a Figure
  local title = fcb.attributes.title or ''
  local caption = fcb.attributes.caption
  I.log('info', 'include', "'#%s' for '%s:img' as pandoc.Image", fcb.attr.identifier, what)
  return pd.Para(pd.Image({ caption }, I.opts[what], title, fcb.attr))
end

function I.mkelm.fig(fcb, _, _, what)
  --  pandoc.Figure element (type Block), since pandoc version >=3.0
  -- tmp
  -- local fname = I.opts[what]
  -- local mime, contents = pd.mediabag.fetch(fname)
  -- print('fname, mime, #contents', fname, mime, #contents)
  -- /tmp
  local img = pd.Image({}, I.opts[what], '', {})
  img.attr.identifier = fcb.attr.identifier .. '-img'
  I.log('info', 'include', "'#%s' for '%s:fig' as pandoc.Figure", fcb.attr.identifier, what)
  return pd.Figure(img, { fcb.attributes.caption }, fcb.attr)
end

function I.mkelm.any(fcb, cb, doc, what)
  -- no type of ast element specified, do default per `what` (except for a Pandoc doc)
  local cid = fcb.attr.identifier
  I.log('debug', 'include', "'%s' for '%s' -> no type specified (using default)", cid, what)
  if 'Pandoc' == pd.utils.type(doc) then
    if doc and doc.blocks and doc.blocks[1] and doc.blocks[1].attr then
      doc.blocks[1].attr = fcb.attr -- else wrap in Div w/ fcb.attr?
    end
    I.log('info', 'include', "'%s' for '%s' ~> merging %d pandoc.Block's", cid, what, #doc.blocks)
    return doc.blocks
  elseif 'art' == what then
    return I.mkelm.fig(fcb, cb, doc, what)
  elseif 'cbx' == what then
    fcb.text = doc
    I.log('info', 'include', "'%s' for id %s as plain pandoc.CodeBlock", cid, what)
    return fcb
  else
    return I.mkelm.fcb(fcb, cb, doc, what) -- for cbx, out or err
  end
end

-- clones `cb`, removes stitch properties, adds a 'stitched' class
---@param cb table a codeblock instance
---@return table clone a new codeblock instance
function I.mkfcb(cb)
  local clone = cb:clone()

  clone.classes = cb.classes:map(function(class) return class:gsub('^stitch$', 'stitched') end)

  -- remove attributes from codeblock if present in I.opts
  for k, _ in pairs(cb.attributes) do
    if I.hardcoded[k] then clone.attributes[k] = nil end
  end

  return clone
end

-- find and load module given by `m`, dropping labels during search
--- @param m string module name, with or without path and or function labels
--- @param f string? collects labels that are stripped while searching `m`
--- @return any mod the result of requiring a module, or nil otherwise
--- @return string? name the name that was required as a module, nil otherwise
--- @return string? func the stripped labels (on the right) while searching, or nil
function I.xload(m, f)
  -- return module, module_name, function_name (may be nil)
  if nil == m or 0 == #m then return nil, m, f end
  I.log('debug', 'xload', 'trying module %q', m)

  local suc6, mod = pcall(require, m)
  if false == suc6 or true == mod then
    local last_dot = m:find('%.[^%.]+$')
    if not last_dot then return nil, m, f end
    local mm, ff = m:sub(1, last_dot - 1), m:sub(last_dot + 1)
    if ff and f then ff = string.format('%s.%s', ff, f) end
    return I.xload(mm, ff)
  else
    I.log('debug', 'xload', 'found module %q, pkg.loaded=%s', m, package.loaded[m])
    return mod, m, f
  end
end

-- run (a new) doc through lua filter(s), count how many were actually applied
---@param dta any file data, pandoc ast or nil
---@param filter string name of lua mod[.fun] to run (if any)
---@return string|table? doc the, possibly, modified doc
---@return number count the number of filters actually applied
function I.xform(dta, filter)
  local count = 0

  assert('string' == type(filter), 'expected filter to be a string, got "%s"', type(filter))
  assert(nil ~= dta, 'expected dta to be non-nil!')
  if 0 == #filter then return dta, count end -- "" means silent noop

  local mod, name, fun = I.xload(filter)
  if not mod then
    I.log('error', 'xform', '@%s skipped, could not require filter', filter)
    return dta, count
  end

  fun = fun or 'Pandoc' -- in case `filter` was a module itself
  if mod[fun] then
    I.log('debug', 'xform', '@%s, found %s.%s', filter, name, fun)
  else
    I.log('warn', 'xform', '@%s, found mod %s, presumably a list of filters', filter, name)
  end

  -- push (a *copy* of) our current state before calling any filter(s)
  tail[#tail + 1] = { opts = I.dcopy(I.opts), ctx = I.dcopy(I.ctx), meta = I.xlate(dta.meta) }
  if dta and 'Pandoc' == pd.utils.type(dta) then
    dta.meta.stitched = { opts = I.opts, ctx = I.ctx } -- pass in, current cb opts & context
    I.opts = {} -- reset in case we recurse later on
  end

  -- ensure filters is a *list* of filters (as expected by pandoc version <3.5)
  -- see `:Open https://pandoc.org/lua-filters.html#lua-filter-structure`
  local filters = mod[fun] and { mod } or mod
  for n, f in ipairs(filters) do
    if f[fun] then
      local ok, tmp = pcall(f[fun], dta)

      if not ok then
        I.log('error', 'xform', "@%s, skipped, filter '%s[%s].%s' failed", filter, name, n, fun)
      else
        dta = tmp -- assumes pd.utils.type(tmp) is string or Pandoc, not a function, table (e.g.)
        count = count + 1
        I.log('debug', 'xform', '@%s[%d].%s, ok, got a %s (%s)', name, n, fun, type(dta), pd.utils.type(dta))
      end
    else
      I.log('warn', 'xform', "@%s, skipped, filter '%s[%d]' does not export %q", filter, name, n, fun)
    end
  end

  -- restore state after filter(s) are done
  I.opts = tail[#tail].opts
  I.ctx = tail[#tail].ctx
  tail[#tail] = nil

  I.log('info', 'xform', '@%s, applied %d filter(s) to given `dta`', filter, count)
  return dta, count
end

-- create doc element(s) per codeblock's inc-attribute
---@param cb table codeblock
---@return table result sequence of pandoc ast elements
function I.result(cb)
  local elms = {}

  for idx, elm in ipairs(I.parse(I.opts.inc)) do
    local what, format, filter, how = table.unpack(elm)
    local fname = I.opts[what]
    if fname and I.freal(fname) then
      local count = 0 -- num of filters actually applied
      local doc = I.fread(fname, format) -- format maybe "" (just reads fname)
      doc, count = I.xform(doc, filter)
      if count > 0 then
        -- a filter was actually applied, so save altered doc (if applicable)
        I.fsave(doc, fname)
      end

      -- TODO: if count > 0 we cannot assume the filter actually returns
      -- either data or a pandoc doc.  Could be a table, userdata or even
      -- a function (!).  @_G.load -> would load cbx as a chunk

      local fcb = I.mkfcb(cb) -- need fcb per inclusion(!)
      fcb.attr.identifier = string.format('%s-%d-%s', I.opts.cid, idx, what)
      local new = I.mkelm[how](fcb, cb, doc, what)
      -- see `:Open https://pandoc.org/lua-filters.html#type-blocks`
      -- type(new) is either Blocks or Block;
      new = 'Blocks' == pd.utils.type(new) and new or pd.Blocks(new)
      for _, block in ipairs(new) do
        elms[#elms + 1] = block
      end
      if #new == 0 then I.log('warn', 'include', "'#%s', skipping '%s:%s' (came up empty)", I.opts.cid, what, how) end
    else
      if fname then
        I.log('error', 'include', "'#%s', skipping '%s:%s' (no file produced)", I.opts.cid, what, how)
      else
        I.log('error', 'include', "'#%s', skipping '%s:%s' (invalid `what`)", I.opts.cid, what, how)
      end
    end
  end

  I.opts = {} -- codeblock is finished, reset I.opts
  return elms
end

--[[-- setup --]]

---sets I.opts for the current codeblock
---@param cb table codeblock with `.stitch` class (or not)
---@param section string name of section that made cb eligible
---@return boolean ok success indicator
function I.mkopt(cb, section)
  -- resolution: cb -> meta.stitch.section -> defaults -> hardcoded
  I.opts = I.xlate(cb.attributes)
  I.opts.cid = #cb.identifier > 0 and cb.identifier or string.format('cb%02d', I.cbc)
  I.opts = I.check(I.opts)
  local cfg = I.opts.stitch or section -- {.. stitch=cfg .. }, pickup cfg section name
  local x = section == 'defaults' and '' or '> stitch.defaults '
  I.log('note', 'option', "'%s' uses cb attr > stitch.%s %s> hardcoded.", I.opts.cid, cfg, x)
  setmetatable(I.opts, { __index = I.ctx[cfg] })
  I.opts.sha = I.mksha(cb) -- derived only

  -- expand filenames for this codeblock (cmd is expanded as exe later)
  local expandables = { 'cbx', 'out', 'err', 'art' }
  for _, k in ipairs(expandables) do
    I.opts[k] = I.opts[k]:gsub('%#(%w+)', I.opts)
  end

  -- check against circular refs
  local ok = true
  for k, _ in pairs(I.hardcoded) do
    -- TODO: exclude 'arg' as well?
    I.log('debug', 'option', '%s = %q', k, I.opts[k])
    if 'cmd' ~= k and 'string' == type(I.opts[k]) and I.opts[k]:match('#%w+') then
      I.log('error', 'option', '%s not entirely expanded: %s', k, I.opts[k])
      ok = false -- keep checking the rest & log accordingly
    end
  end

  return ok
end

--- extract `doc.meta.stitch` config from a doc's meta block (if any)
---@param doc table the doc's ast
---@return table config doc.meta.stitch's named configs: option,value-pairs
function I.mkctx(doc)
  -- pickup named cfg sections in meta.stitch, resolution order:
  -- I.opts (cb) -> stitch[section] -> defaults -> hardcoded
  I.ctx = I.xlate(doc.meta.stitch or {})

  -- defaults -> hardcoded
  local defaults = I.ctx.defaults or {}
  setmetatable(defaults, { __index = I.hardcoded })
  I.ctx.defaults = nil -- will be metatable, not a section
  I.ctx.stitch = I.ctx.stitch or {}

  -- sections -> defaults -> hardcoded
  for _, options in pairs(I.ctx) do
    setmetatable(options, { __index = defaults })
  end

  -- missing sections (I.ctx keys) also fallback to defaults -> hardcoded
  setmetatable(I.ctx, {
    __index = function() return defaults end,
  })
  setmetatable(I.ctx.stitch, nil) -- no metable for stitch section

  defaults = I.check(defaults)
  for section, map in pairs(I.ctx) do
    I.ctx[section] = I.check(map)
  end

  return I.ctx
end

--[[-- filter --]]

-- return meta section name that makes this cb eligible or nil
function I.eligible(cb)
  -- hi-2-lo: attr.stitch=name, cls=yes, .stitch (defaults)
  if cb.attributes.stitch then return cb.attributes.stitch end
  for _, class in ipairs(cb.classes) do
    local cls = tostring(I.ctx[class].cls)
    if cls == 'true' or cls == 'yes' then return class end
  end
  if cb.classes:find('stitch') then return 'defaults' end
  I.log('note', 'select', '%s is not eligible for stitch processing', cb.identifier)
  return false
end
---@poram cb a pandoc.codeblock
---@return any list of nodes in pandoc's ast
function I.CodeBlock(cb)
  I.cbc = I.cbc + 1 -- this is the nth cb seen (for generating cid if missing)
  local section = I.eligible(cb)
  if not section then return nil end

  -- TODO: also check I.opts.exe and I.opts.old (keep/purge)
  if I.mkopt(cb, section) and I.mkcmd(cb) then
    if 'no' == I.opts.exe then
      I.log('info', 'execute', "skipped (exe='%s')", I.opts.exe)
    elseif I.deja_vu() and 'maybe' == I.opts.exe then
      I.log('info', 'execute', "skipped, output files exist (exe='%s')", I.opts.exe)
    elseif 'chunk' == I.opts.lua then
      I.log('info', 'execute', "codeblock as a chunk (exe='%s')", I.opts.exe)
      _ENV.Stitch = I.dcopy(I) -- enables introspection by the chunk
      local f, err = loadfile(I.opts.cbx, 't', _ENV) -- lexcial scope
      if f == nil or err then
        I.log('error', 'execute', 'skipped, chunk compile error: %s', err)
      else
        I.log('info', 'execute', 'running chunk, fingers crossed ..')
        local ok
        ok, err = pcall(f)
        if not ok or err then
          I.log('error', 'execute', 'error running chunk: %s', tostring(err))
        else
          I.log('info', 'execute', 'chunk ran ok')
        end
      end
    else
      I.log('info', 'execute', "running codeblock (exe='%s')", I.opts.exe)
      local ok, code, nr = os.execute(I.opts.cmd)
      if not ok then
        -- complain and carry on
        I.log('error', 'execute', 'codeblock failed with %s(%s)', code, nr)
        -- return nil
      end
      I.log('info', 'execute', '%s, codeblock ran successfully', I.opts.cid)
    end
  end

  local count = I.fkill()
  I.log('info', 'files', '%d old files removed', count)
  return I.result(cb)
end

-- add a delta to header levels as specified in a caller's codeblock hdr-option
--- @param elm any a header from document being walked
--- @return any elm same header with possibly updated `header.level`
function I.Header(elm)
  I.hdc = I.hdc + 1 -- counter
  local level = elm.level + math.floor(tonumber(I.ctx.stitch.header) or 0)
  if level ~= elm.level then
    level = level > 0 and level or 0
    local hid = elm.identifier
    hid = #hid > 0 and 'id ' .. hid .. ': ' or hid
    I.log('info', 'header', '%sshifting level from %d to %d', hid, elm.level, level)
    elm.level = level
  end
  return elm
end

--[[-- Stitch --]]

local Stitch = {
  _ = I, -- Stitch's implementation, for testing

  Pandoc = function(doc)
    if #tail > MAXTAIL then
      -- if #tail > 0, doc is being included in an outer doc.
      I.log('error', 'stitch', 'recursion level %d too deep, max is %d', #tail, MAXTAIL)
      assert(false, 'maximum recursion level exceeded') -- simply skips doc
    end

    I.mkctx(doc)
    local cbc = I.cbc
    local hdc = I.hdc

    local s = I.ctx.stitch -- shorthand
    if #tail > 0 then
      -- adopt some settings from caller's cb / doc
      s.header = s.header or tail[#tail].opts.hdr
      s.log = s.log or tail[#tail].opts.log
    end

    s.header = math.floor(tonumber(s.header) or 0)
    local header = 0 ~= s.header and I.Header
    I.log('info', 'stitch', 'processing CodeBlocks and %sHeaders', header and '' or 'not ')

    local rv = doc:walk({ CodeBlock = I.CodeBlock, Header = header })
    I.log('info', 'stitch', 'saw %d CodeBlocks and %d Headers', I.cbc - cbc, I.hdc - hdc)

    return rv
  end,
}

-- Notes:
-- * cannot simply return `Stitch` => requires pandoc version >=3.5
-- * pandoc does f = loadfile(..)(), hence no package.loaded['stitch'] entry
-- * when stitch recurses on a codeblock, it requires itself
-- * stitch must be loaded once (I.cbc), so register as a loaded package
package.loaded.stitch = { Stitch }
return package.loaded.stitch
