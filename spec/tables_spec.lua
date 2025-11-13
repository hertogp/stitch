---@diagnostic disable: undefined-global

local S = require('src/stitch') -- { Stitch }
local I = S[1]._ -- the Implementation
local pd = require 'pandoc'
local dump = require('dump')
local F = string.format

assert(S, 'S should be { Stitch }, got %s', tostring(S))
assert(I, 'I should be the stitch module, got %s', tostring(S))
assert(pd, 'pd should be pandoc module, got %s', tostring(pd))

describe('table merging', function()
  it('- merging without forced keeps org values', function()
    local d = { one = 1, two = 2, three = { one = 11, two = 22 } }
    local s = { one = 11, two = true, three = { one = 111, two = 222, three = 333 }, four = false }

    local m = I.merge(d, s, false)

    -- existing values not overwritten
    assert.equal(m.one, 1)
    assert.equal(m.two, 2)
    assert.equal(m.three.one, 11)
    assert.equal(m.three.two, 22)

    -- new values added
    assert.equal(m.three.three, 333)
    assert.equal(m.four, false)
  end)

  it('- merging with forced overrides org values', function()
    local d = { one = 1, two = 2, three = { one = 11, two = 22 } }
    local s = { one = 11, two = true, three = { one = 111, two = 222, three = 333 }, four = false }

    local m = I.merge(d, s, true)

    -- existing values not overwritten
    assert.equal(m.one, 11)
    assert.equal(m.two, true)
    assert.equal(m.three.one, 111)
    assert.equal(m.three.two, 222)

    -- new values added
    assert.equal(m.three.three, 333)
    assert.equal(m.four, false)
  end)

  it('- autovivifaction of nil receiver', function()
    local d = nil
    local s = { one = 1, two = 'two', three = true, four = { 'a', 'list' } }
    local m = I.merge(d, s)
    local mt = { five = 5, six = 'six', seven = true, eight = false, nine = { ball = 'round' } }

    -- without metatables
    assert.equal('table', type(m))
    assert.are.same(m, s)

    -- with metatable
    setmetatable(s, { __index = mt })
    assert.equal(s.five, 5)
    assert.are.same(s.nine, { ball = 'round' })

    m = nil
    m = I.merge(d, s)

    -- m also has metatable
    assert.equal(rawget(m, 'five'), nil)
    assert.equal(m.five, 5)
  end)
end)
