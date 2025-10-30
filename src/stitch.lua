--[[ stitch ]]
-- TODO:
-- [o] check utf8 requirements (if any)
-- [o] add mediabag to store files related to cb's
-- [o] add Code handler to insert pieces of a CodeBlock
--
--  OTHER PROJECTS:
--  * `:Open https://github.com/jgm/pandoc/blob/main/doc/extras.md`
--  * `:Open https://github.com/LaurentRDC/pandoc-plot/tree/master`
--  * `:Open https://github.com/pandoc/lua-filters` (older repo)

local I = {} -- Stitch's Implementation; for testing
I.input_idx = 0

I.ctx = {} -- this doc's context (= meta.stitch)
I.opts = { log = 'info' } --> set per cb being processed
I.level = {
  silent = 0,
  error = 1,
  warn = 2,
  info = 3,
  debug = 4,
}

I.optvalues = {
  -- valid option values
  exe = { 'yes', 'no', 'maybe' },
  log = { 'silent', 'error', 'warn', 'info', 'debug' },
  old = { 'keep', 'purge' },
}

I.cbc = 0 -- cb counted as they are seen by Stitch.codeblock(cb)
I.hardcoded = {
  -- resolution order: cb -> meta.<cfg> -> defaults -> hardcoded
  cid = 'x', -- TODO: MUST be unique for each cb so old file detectinon is possible
  cfg = '', -- name of config section in doc.meta.stitch.<cfg> (if any)
  arg = '', -- (extra) arguments to pass in to `cmd`-program on the cli (if any)
  dir = '.stitch', -- where to store files (abs or rel path to cwd)
  fmt = 'png', -- format for images (if any)
  log = 'info', -- debug, error, warn, info, silent
  exe = 'maybe', -- yes, no, maybe
  old = 'purge', -- keep, purge
  -- inc = "what:type!format[+extensions]@filter[.func], .." (csv/space separated)
  -- * what (mandatory) {cbx, out, err, art}, type {fcb, img, fig}
  inc = 'cbx:fcb out:fcb art:img err:fcb',
  -- expandable filenames
  cbx = '#dir/#cid-#sha.cbx', -- the codeblock.text as file on disk
  out = '#dir/#cid-#sha.out', -- capture of stdout (if any)
  err = '#dir/#cid-#sha.err', -- capture of stderr (if any)
  art = '#dir/#cid-#sha.#fmt', -- artifact (output) file (if any)
  cmd = '#cbx #arg #art 1>#out 2>#err', -- cmd template string, expanded last
  -- bash: $@ is list of args, ${@: -1} is last argument
}

--[[ helpers ]]

local pd = require('pandoc')

function I.log(lvl, action, msg, ...)
  -- [stitch level] (action cb_id) msg .. (need to validate opts.log value)
  if (I.level[I.opts.log] or 1) >= I.level[lvl] then
    local fmt = '[stitch %5s] %s %-7s| ' .. tostring(msg) .. '\n'
    local text = string.format(fmt, lvl, I.opts.cid or 'mod', action, ...)
    io.stderr:write(text)
  end
end

--[[ options ]]

-- parse `I.opts.inc` into list: {{what, format, filter, how}, ..}
---@param str string the I.opts.inc string with include directives
---@return table directives list of 4-element lists of strings
function I.parse_inc(str)
  -- str is what:type!format+extensions@module.function, ..
  local inc = {}
  local part = '([^!@:]+)'

  str = pd.utils.stringify(str):gsub('[,%s]+', ' ')
  for p in str:gmatch('%S+') do
    inc[#inc + 1] = {
      p:match('^' .. part) or '', -- what to include
      p:match('!' .. part) or '', -- read as type
      p:match('@' .. part) or '', -- filter
      p:match(':' .. part) or '', -- element/how
    }
  end
  I.log('debug', 'include', "include found %s inc's in '%s'", #inc, str)

  return inc
end

-- extract specific data from ast elements into lua table(s)
---@param elm any either `doc.blocks`, `doc.meta` or a `CodeBlock`
---@return any regular table holding the metadata as lua values
function I.metalua(elm)
  -- note: metalua(doc.blocks) -> list of cb tables.
  local ptype = pd.utils.type(elm)
  if 'Meta' == ptype or 'table' == ptype or 'AttributeList' == ptype then
    local t = {}
    for k, v in pairs(elm) do
      t[k] = I.metalua(v)
    end
    return t
  elseif 'List' == ptype or 'Blocks' == ptype then
    local l = {}
    for _, v in ipairs(elm) do
      l[#l + 1] = I.metalua(v)
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
      classes = I.metalua(elm.classes),
      attributes = {},
    }
    for k, v in pairs(elm.attributes) do
      t.attributes[k] = I.metalua(v)
    end
    return t
  elseif 'CodeBlock' == elm.tag then
    -- a CodeBlock's type is actually 'Block'
    return {
      text = elm.text,
      attr = I.metalua(elm.attr),
    }
  else
    I.log('error', 'meta', "option unknown type '%s'? for %s", ptype, tostring(elm))
    return nil
  end
end

--[[ files ]]

-- sha1 hash of (stitch) option values and codeblock text
---@param cb table a pandoc codeblock
---@return string sha1 hash of option values and codeblock content
function I.mksha(cb)
  -- for repeatable fingerprints: keys are sorted, whitespace removed
  local hardcoded_keys = {}
  for key in pairs(I.hardcoded) do
    -- toggle'ing exe=yes/no should not effect fingerprint
    if 'exe' ~= key then hardcoded_keys[#hardcoded_keys + 1] = key end
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
      I.log('error', 'cmd', 'permission denied when creating ' .. dir)
      return false
    end
  end

  -- cb.text becomes executable on disk (TODO:
  -- if not flive(fname) then .. else I.log(reuse) end
  local fh = io.open(I.opts.cbx, 'w')
  if not fh then
    I.log('error', 'cmd', 'cbx could not open file: ' .. I.opts.cbx)
    return false
  end
  if not fh:write(cb.text) then
    fh:close()
    I.log('error', 'cmd', 'cbx could not write to: ' .. I.opts.cbx)
    return false
  end
  fh:close()

  if not os.execute('chmod u+x ' .. I.opts.cbx) then
    I.log('error', 'cmd', 'cbx could not mark executable: ' .. I.opts.cbx)
    return false
  end

  I.log('info', 'expand', "cmd template '%s'", I.opts.cmd)
  I.opts.cmd = I.opts.cmd:gsub('%#(%w+)', I.opts)
  I.log('info', 'expand', '%s', I.opts.cmd)
  return true
end

-- says whether given `filename` is real on disk or not
---@param filename string path to a file
---@return boolean exists true or false
function I.freal(filename)
  local f = io.open(filename, 'r')
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
      I.log('info', 'read', 'pandoc.read as %s succeeded (type=%s)', format, pd.utils.type(dta))
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
    I.log('info', 'write', "%s, skip writing data of type '%s'", fname, type(doc))
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
          local ok, err = os.remove(fold) -- pd.system.remove >=version 3.7.1 :(
          if not ok then
            I.log('error', 'files', 'unable to remove: %s (%s)', fold, err)
          else
            count = count + 1
            I.log('debug', 'files', '- removed %s', fold)
          end
        end
      end
    else
      I.log('warn', 'files', 'filename template used without sha1 (%s), unable to detect old files', I.opts.sha)
    end
  end

  return count
end

-- says whether cb-executable file and 1 or more outputs already exist or not
---@return boolean deja_vu true or false
function I.deja_vu()
  -- if cbx exist with 1 or more ouputs, we were here before

  if I.freal(I.opts.cbx) then
    if I.freal(I.opts.out) or I.freal(I.opts.err) or I.freal(I.opts.art) then return true end
  end
  return false
end

--[[ AST elements ]]

I.mkelm = {
  -- functions result should be either type Block or type Blocks
  fcb = function(fcb, cb, doc, what)
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
    I.log('info', 'include', '%s, id %s, pandoc.CodeBlock', what, fcb.attr.identifier)

    return fcb
  end,

  img = function(fcb, _, _, what)
    -- pandoc.Para type Block wrapper, since pandoc.Image is type Inline
    local title = fcb.attributes.title or ''
    local caption = fcb.attributes.caption
    I.log('info', 'include', '%s, id %s, pandoc.Image', what, fcb.attr.identifier)
    return pd.Para(pd.Image({ caption }, I.opts[what], title, fcb.attr))
  end,

  fig = function(fcb, _, _, what)
    -- pandoc.Figure (type Block) >=version 3.0
    -- `:Open https://github.com/pandoc/lua-filters/blob/master/diagram-generator/diagram-generator.lua#L360`
    --  * TODO: PD_VERSION < 3 -> title := fig:title, then pandoc treats it as a Figure
    local img = pd.Image({}, I.opts[what], '', {})
    img.attr.identifier = fcb.attr.identifier .. '-img'
    I.log('info', 'include', '%s, is %s, pandoc.Figure', what, fcb.attr.identifier)
    return pd.Figure(img, { fcb.attributes.caption }, fcb.attr)
  end,

  [''] = function(fcb, cb, doc, what)
    -- no type of ast element specified, do default per `what` (except for a Pandoc doc)
    I.log('debug', 'include', 'no type for %s, fallback to default', what)
    if 'Pandoc' == pd.utils.type(doc) then
      if doc and doc.blocks[1].attr then
        doc.blocks[1].attr = fcb.attr -- else wrap in Div w/ fcb.attr?
      end
      I.log('info', 'include', "%s, is %s, merging %d pandoc.Block's", what, fcb.attr.identifier, #doc.blocks)
      return doc.blocks
    elseif 'art' == what then
      return I.mkelm.fig(fcb, cb, doc, what)
    else
      return I.mkelm.fcb(fcb, cb, doc, what) -- for cbx, out or err
    end
  end,
}

-- setmetatable(mkelm, mkelm_mt)

-- clones `cb`, removes stitch properties, adds a 'stitched' class
---@param cb table a codeblock instance
---@return table clone a new codeblock instance
function I.mkfcb(cb)
  local clone = cb:clone()

  clone.classes = cb.classes:map(function(class) return class:gsub('^stitch$', 'stitched') end)

  -- remove attributes present in I.opts
  for k, _ in pairs(cb.attributes) do
    if I.hardcoded[k] then clone.attributes[k] = nil end
  end

  return clone
end

-- run doc through lua filter(s), count how many were actually applied
---@param doc any file data, pandoc ast or nil
---@param filter string name of lua mod.fun to run (if any)
---@return string|table? doc the, possibly, modified doc
---@return number count the number of filters actually applied
function I.xform(doc, filter)
  local count = 0
  local ok, filters, tmp
  if #filter == 0 then return doc, count end

  local mod, fun = filter:match('(%w+)%.?(%w*)') -- module.function
  fun = #fun > 0 and fun or 'Pandoc' -- function default is Pandoc
  ok, filters = pcall(require, mod)
  if not ok then
    I.log('warn', 'xform', 'skip @%s: module %s not found', filter, mod)
    return doc, count
  elseif filters == true then
    I.log('warn', 'xform', 'skip @%s: not a list of filters', filter)
    return doc, count
  end

  if doc and 'Pandoc' == pd.utils.type(doc) then
    -- add stitch context to a Pandoc doc
    doc.meta.stitch = pd.MetaMap(I.ctx)
  end

  for n, f in ipairs(filters) do
    if f[fun] then
      ok, tmp = pcall(f[fun], doc)
      if not ok then
        I.log('warn', 'xform', "filter '%s[%s].%s', failed, filter ignored", mod, n, fun)
      else
        doc = tmp
        count = count + 1
      end
    else
      I.log('warn', 'xform', "filter '%s[%d].%s', '%s' not found, filter ignored", mod, n, fun)
    end
  end
  return doc, count
end

-- create doc element(s) per codeblock's inc-attribute
---@param cb table codeblock
---@return table result sequence of pandoc ast elements
function I.result(cb)
  local elms = {}

  for idx, elm in ipairs(I.parse_inc(I.opts.inc)) do
    local what, format, filter, type_ = table.unpack(elm)
    local fname = I.opts[what]
    if fname then
      local count = 0 -- num of filters actually applied
      local doc = I.fread(fname, format) -- format maybe "" (just reads fname)
      doc, count = I.xform(doc, filter)
      if count > 0 then
        -- a filter was actually applied, so save altered doc
        I.fsave(doc, fname)
      end

      local fcb = I.mkfcb(cb) -- need fcb per inclusion(!)
      fcb.attr.identifier = string.format('%s-%d-%s', I.opts.cid, idx, what)
      local new = I.mkelm[type_](fcb, cb, doc, what)
      -- see `:Open https://pandoc.org/lua-filters.html#type-blocks`
      -- new is either Blocks or Block; pandoc.List:extend (3.0) is shorter..
      new = 'Blocks' == pd.utils.type(new) and new or pd.Blocks(new)
      for _, block in ipairs(new) do
        elms[#elms + 1] = block
      end
    else
      I.log('error', 'include', "skip id %s, invalid directive inc '%s:%s'", I.opts.cid, what, type_)
    end
  end

  return elms
end

--[[ context & cb ]]

-- check values for given `opts`, removes those that are illegal
---@param opts table single k,v store of options
---@return table opts same table with illegal options removed
function I.validate(section, opts)
  for k, valid in pairs(I.optvalues) do
    local v = opts[k]
    if v and #v > 0 and not pd.List.includes(valid, v, 1) then
      local need = table.concat(valid, ', ')
      opts[k] = nil
      I.log('error', 'meta', "%s.%s='%s' ignored, need one of: %s", section, k, v, need)
    end
  end
  return opts
end

---sets I.opts for the current codeblock
---@param cb table codeblock with `.stitch` class (or not)
---@return boolean ok success indicator
function I.options(cb)
  -- resolution: cb -> meta.stitch[cb.cfg] -> defaults -> hardcoded
  I.opts = I.metalua(cb.attributes)
  I.opts = I.validate('cb.attr', I.opts)
  setmetatable(I.opts, { __index = I.ctx[I.opts.cfg] })
  I.opts.cid = #cb.identifier > 0 and cb.identifier or string.format('cb%03d', I.cbc)
  I.opts.sha = I.mksha(cb) -- derived only

  -- expand filenames for this codeblock (cmd is expanded as exe later)
  local expandables = { 'cbx', 'out', 'err', 'art' }
  for _, k in ipairs(expandables) do
    I.opts[k] = I.opts[k]:gsub('%#(%w+)', I.opts)
  end

  -- check against circular refs
  for k, _ in pairs(I.hardcoded) do
    if 'cmd' ~= k and 'string' == type(I.opts[k]) and I.opts[k]:match('#%w+') then
      I.log('error', 'options', '%s not entirely expanded: %s', k, I.opts[k])
      return false
    end
  end

  return true
end

--- extract `doc.meta.stitch` config from a doc's meta block (if any)
---@param doc table the doc's ast
---@return table config doc.meta.stitch's named configs: option,value-pairs
function I.setup(doc)
  -- pickup named cfg sections in meta.stitch, resolution order:
  -- I.opts (cb) -> I.ctx (stitch[cb.cfg]) -> defaults -> hardcoded
  I.ctx = I.metalua(doc.meta.stitch or {}) or {} -- REVIEW: last or {} needed?

  -- defaults -> hardcoded
  local defaults = I.ctx.defaults or {}
  setmetatable(defaults, { __index = I.hardcoded })
  I.ctx.defaults = nil

  -- sections -> defaults -> hardcoded
  for _, attr in pairs(I.ctx) do
    setmetatable(attr, { __index = defaults })
  end

  -- missing I.ctx.keys also fallback to defaults -> hardcoded
  setmetatable(I.ctx, {
    __index = function() return defaults end,
  })

  defaults = I.validate('defaults', defaults)
  for section, map in pairs(I.ctx) do
    I.ctx[section] = I.validate(section, map)
  end

  return I.ctx
end

---@poram cb a pandoc.codeblock
---@return any list of nodes in pandoc's ast
function I.codeblock(cb)
  I.cbc = I.cbc + 1 -- this is the nth cb seen (for generating cid if missing)

  if not cb.classes:find('stitch') then return nil end

  -- TODO: also check I.opts.exe and I.opts.old (keep/purge)
  if I.options(cb) and I.mkcmd(cb) then
    if 'no' == I.opts.exe then
      I.log('info', 'execute', "skipped (exe='%s')", I.opts.exe)
    elseif I.deja_vu() and 'maybe' == I.opts.exe then
      I.log('info', 'execute', "skipped, output files exist (exe='%s')", I.opts.exe)
    else
      I.log('info', 'execute', "running codeblock (exe='%s')", I.opts.exe)
      local ok, code, nr = os.execute(I.opts.cmd)
      if not ok then
        I.log('error', 'execute', 'codeblock failed with %s(%s)', code, nr)
        return nil
      end
      I.log('info', 'execute', '%s, codeblock ran successfully', I.opts.cid)
    end
  end

  -- do not remove old files if exe=no (if that was added, the cb changed and
  -- so did the cb's sha fingerprint(!): TODO: remove exe from fingerprint.
  if 'no' == I.opts.exe then
    I.log('info', 'files', 'not removing any old files (exe=%s)', I.opts.exe)
  else
    local count = I.fkill()
    I.log('info', 'files', '%d old files removed', count)
  end

  return I.result(cb)
end

--[[ filter ]]

-- `:Open https://github.com/jgm/pandoc/blob/main/changelog.md#pandoc-30-2023-01-18`
--  + Pandoc 3.0 introduces pandoc.Figure element
I.log('info', 'check', string.format('running on %s', pd.system.os))
_ENV.PANDOC_VERSION:must_be_at_least('3.0')
--   I.log('info', 'check', 'ok, pandoc version %s', _ENV.PANDOC_VERSION)
-- else
--   I.log('error', 'check', 'pandoc version is %s, need 3.0 or later')
-- end

local Stitch = {
  -- alt: if Pandoc" == pd.utils.type(doc) then return .. else return I end
  _ = I, -- Stitch's implementation: for testing only

  Pandoc = function(doc)
    -- tmp
    local inputs = _ENV.PANDOC_STATE.input_files
    I.input_idx = I.input_idx + 1
    I.log('info', 'filter', 'processing %s', inputs[I.input_idx])
    print('---->', inputs)
    -- /tmp
    I.setup(doc)
    return doc:walk({ CodeBlock = I.codeblock })
  end,
}

-- return Stitch --<-- requires pandoc 3.5
return {
  Stitch,
}
