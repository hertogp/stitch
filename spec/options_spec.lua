-- see .busted which uses pandoc lua to run the test spec's, so pandoc is a
-- global, but lua_ls doesn't pickup on it. So, howto remove warning about
-- pandoc being 'undefined global' ?  The following is a bit heavy-handed
--@diagnostic disable: undefined-global

local M = require('src/stitch')[1]._bustit -- [1] due to pandoc version < 3.5
local pd = require 'pandoc'
local sf = string.format
local tostr = M.helpers.tostr

describe('options handling #options', function()
  -- don't indent lines otherwise pandoc reads'em as a single anonymous codeblock
  local markup = [[---
title: "test option handling"
author: "Douglas Adams"
answer: 42
stitch:
  defaults:
    prg: prg_default
    dir: dir_default
  cfg1:
    prg: prg_cfg1
    fmt: fmt_cfg1
  cfg2:
    fmt: fmt_cfg2
...

# ex01

```{#id1 stitch=cfg1 prg=ex01}
#!/usr/bin/env echo
echo hello, world!
```
]]

  it('- state.ctx resolves options via ctx.section->defaults->hardcoded', function()
    local doc = pd.read(markup, 'markdown')
    M.state:context(doc)
    local ctx = M.state.ctx

    -- ctx.defaults exists
    assert(ctx ~= nil)
    assert(ctx.defaults ~= nil)
    assert.equal('prg_default', ctx.defaults.prg)
    assert.equal('dir_default', ctx.defaults.dir)

    -- cfg1 exists, has its own opts and defaults for dir, hardcodec for the rest
    assert.equal('table', type(ctx.cfg1))
    assert.equal('prg_cfg1', ctx.cfg1.prg) -- explicit value
    assert.equal('fmt_cfg1', ctx.cfg1.fmt)
    assert.equal('dir_default', ctx.cfg1.dir) -- default value
    assert.equal('info', ctx.cfg1.log) -- hard coded value

    -- cfg2 exists
    assert.equal('table', type(ctx.cfg2))
    assert.equal('fmt_cfg2', ctx.cfg2.fmt) -- explicit
    assert.equal('dir_default', ctx.cfg2.dir) -- default value
    assert.equal('system', ctx.cfg2.run) -- hard coded value

    -- unknown section yields defaults
    local unknown = ctx.unknown
    assert.equal(nil, rawget(ctx, 'unknown')) -- ctx.unknown does not exist
    assert.equal(unknown, ctx.defaults) -- metatable magic!
    assert.equal('prg_default', ctx.unknown.prg) -- defaults
    assert.equal('dir_default', ctx.unknown.dir) -- defaults
    assert.equal('purge', ctx.unknown.old) -- hard coded
  end)

  it('- state:context parses entire doc.meta', function()
    local doc = pd.read(markup, 'markdown')
    M.state:context(doc)
    local meta = M.state.meta

    assert(meta)
    assert.equal('test option handling', meta.title)
    assert.equal('Douglas Adams', meta.author)
    assert.equal('42', meta.answer)
  end)

  it('- parses 3 versions of the inc option value', function()
    -- 3 versions of the same inc-option value
    -- incv1 is comma and/or space separated
    local incv1 = 'cbx out!markdown@foobar:fcb err:fcb, art:img,art:fig'
    local incv2 = { 'cbx', 'out!markdown@foobar:fcb', 'err:fcb', 'art:img', 'art:fig' }
    local incv3 = {
      { what = 'cbx' },
      { what = 'out', read = 'markdown', filter = 'foobar', how = 'fcb' },
      { what = 'err', how = 'fcb' },
      { what = 'art', how = 'img' },
      { what = 'art', how = 'fig' },
    }

    for _, inc in ipairs({ incv1, incv2, incv3 }) do
      local v = M.parse:option('inc', inc)
      assert(v) -- parsed option value is same as incv3

      -- 'cbx'
      assert.equal('cbx', v[1].what, sf('inc[1] in "%s"', tostr(inc)))
      assert.equal(nil, v[1].read, sf('inc[1] in = "%s" ', tostr(inc)))
      assert.equal(nil, v[1].filter, sf('inc[1] in "%s"', tostr(inc)))
      assert.equal(nil, v[1].how, sf('inc[1] in "%s"', tostr(inc)))

      -- out!markdown@foobar:fcb
      assert.equal('out', v[2].what, sf('inc[1] in "%s"', tostr(inc)))
      assert.equal('markdown', v[2].read, sf('inc[1] in = "%s" ', tostr(inc)))
      assert.equal('foobar', v[2].filter, sf('inc[1] in "%s"', tostr(inc)))
      assert.equal('fcb', v[2].how, sf('inc[1] in "%s"', tostr(inc)))

      -- err:fcb
      assert.equal('err', v[3].what, sf('inc[1] in "%s"', tostr(inc)))
      assert.equal(nil, v[3].read, sf('inc[1] in = "%s" ', tostr(inc)))
      assert.equal(nil, v[3].filter, sf('inc[1] in "%s"', tostr(inc)))
      assert.equal('fcb', v[3].how, sf('inc[1] in "%s"', tostr(inc)))

      -- art:img
      assert.equal('art', v[4].what, sf('inc[1] in "%s"', tostr(inc)))
      assert.equal(nil, v[4].read, sf('inc[1] in = "%s" ', tostr(inc)))
      assert.equal(nil, v[4].filter, sf('inc[1] in "%s"', tostr(inc)))
      assert.equal('img', v[4].how, sf('inc[1] in "%s"', tostr(inc)))

      -- art:fig
      assert.equal('art', v[5].what, sf('inc[1] in "%s"', tostr(inc)))
      assert.equal(nil, v[5].read, sf('inc[1] in = "%s" ', tostr(inc)))
      assert.equal(nil, v[5].filter, sf('inc[1] in "%s"', tostr(inc)))
      assert.equal('fig', v[5].how, sf('inc[1] in "%s"', tostr(inc)))
    end
  end)

  it('- validates values for some options', function()
    -- hdr
    assert.equal(1, M.parse:option('hdr', '+1'))
    assert.equal(1, M.parse:option('hdr', '1'))
    assert.equal(-1, M.parse:option('hdr', '-1'))
    assert.equal(-1, M.parse:option('hdr', -1))
    assert.equal(1, M.parse:option('hdr', 1))
    assert.equal(nil, M.parse:option('hdr', 'abc'))
    assert.equal(nil, M.parse:option('hdr', 'ten'))
    assert.equal(nil, M.parse:option('hdr', {}))
    assert.equal(nil, M.parse:option('hdr', false))

    -- cls
    assert.equal('yes', M.parse:option('cls', 'yes'))
    assert.equal('no', M.parse:option('cls', 'no'))
    assert.equal(nil, M.parse:option('cls', 'maybe'))
    assert.equal(nil, M.parse:option('cls', true))
    assert.equal(nil, M.parse:option('cls', false))
    assert.equal(nil, M.parse:option('cls', 'Yes'))
    assert.equal(nil, M.parse:option('cls', 'NO'))

    -- exe
    assert.equal('yes', M.parse:option('exe', 'yes'))
    assert.equal('no', M.parse:option('exe', 'no'))
    assert.equal('maybe', M.parse:option('exe', 'maybe'))
    assert.equal(nil, M.parse:option('exe', true))
    assert.equal(nil, M.parse:option('exe', false))
    assert.equal(nil, M.parse:option('exe', 'Yes'))

    -- log
    assert.equal('debug', M.parse:option('log', 'debug'))
    assert.equal('error', M.parse:option('log', 'error'))
    assert.equal('warn', M.parse:option('log', 'warn'))
    assert.equal('note', M.parse:option('log', 'note'))
    assert.equal('info', M.parse:option('log', 'info'))
    assert.equal('silent', M.parse:option('log', 'silent'))
    assert.equal(nil, M.parse:option('log', 'Silent'))
    assert.equal(nil, M.parse:option('log', true))
    assert.equal(nil, M.parse:option('log', false))

    -- old
    assert.equal('purge', M.parse:option('old', 'purge'))
    assert.equal('keep', M.parse:option('old', 'keep'))
    assert.equal(nil, M.parse:option('old', 'delete'))

    -- run
    assert.equal('system', M.parse:option('run', 'system'))
    assert.equal('chunk', M.parse:option('run', 'chunk'))
    assert.equal('noop', M.parse:option('run', 'noop'))
    assert.equal(nil, M.parse:option('run', 'poop'))
    assert.equal(nil, M.parse:option('run', true))
    assert.equal(nil, M.parse:option('run', false))
    assert.equal(nil, M.parse:option('run', 'yes'))
    assert.equal(nil, M.parse:option('run', 'no'))
  end)
end)
