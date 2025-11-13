-- see .busted which uses pandoc lua to run the test spec's, so pandoc is a
-- global, but lua_ls doesn't pickup on it. So, howto remove warning about
-- pandoc being 'undefined global' ?  The following is a bit heavy-handed
---@diagnostic disable: undefined-global
local S = require('src/stitch') -- { Stitch }
local I = S[1]._ -- the Implementation
local pd = require 'pandoc'
local dump = require('dump')
local F = string.format

assert(S, 'S should be { Stitch }, got %s', tostring(S))
assert(I, 'I should be the stitch module, got %s', tostring(S))
assert(pd, 'pd should be pandoc module, got %s', tostring(pd))

describe('stitch options handling', function()
  -- don't indent lines otherwise pandoc reads'em as a single anonymous codeblock
  local markup = [[
---
author: Douglas Adams
answer: 42
stitch:
  defaults: {prg: default, dir: defdir}
  sec1: {prg: sec1, fmt: fmt1}
  sec2: {fmt: fmt2}
...

# ex01

```{#id1 stitch=cfg1 prg=ex01}
#!/usr/bin/env echo
echo hello, world!
```
]]

  it('- option resolution: opts->ctx[section]->defaults->hardcoded', function()
    local doc = pd.read(markup, 'markdown')
    local ctx = I.mkctx(doc) -- get context

    -- ctx.section resolves
    assert.equal(ctx.sec1.prg, 'sec1')
    assert.equal(ctx.sec1.fmt, 'fmt1')
    assert.equal(ctx.sec2.fmt, 'fmt2')

    -- ctx.section -> ctx.defaults
    assert.equal(ctx.sec1.dir, 'defdir')
    assert.equal(ctx.sec2.dir, 'defdir')
    assert.equal(ctx.sec2.prg, 'default')

    -- ctx.section -> ctx.defaults -> hardcoded
    assert.equal(ctx.sec3.prg, 'default')
    assert.equal(ctx.sec3.dir, 'defdir')

    -- hardcoded values, opts not in section, nor defaults
    assert.equal(ctx.sec1.exe, 'maybe')
    assert.equal(ctx.sec2.exe, 'maybe')
    assert.equal(ctx.sec3.exe, 'maybe')

    -- options unknown to stitch resolve to nil
    assert.equal(ctx.defaults.xxx, nil)
    assert.equal(ctx.sec1.xxx, nil)
    assert.equal(ctx.sec2.xxx, nil)
  end)
end)
