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

describe('handles tables', function()
  it('- merge tables without forced', function()
    local d = { one = 1, two = 2, three = { one = 11, two = 22 } }
    local s = { three = { one = 111, two = 222, three = 333 }, four = false }

    local m = I.merge(d, s, false)

    -- existing values not overwritten
    assert.equal(m.one, 1)
    assert.equal(m.two, 2)
    assert.equal(m.three.one, 11)
    assert.equal(m.three.two, 22)
    assert.equal(m.four, false)

    -- new values added
    assert.equal(m.three.three, 333)
  end)
end)
