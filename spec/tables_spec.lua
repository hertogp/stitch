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
  it(' - forced is nil/false means preserve existing values', function()
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

  it(' - forced is true means overwrite existing values', function()
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

  it(' - creates destination if its nil', function()
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

  it(' - barfs on invalid, non-table arguments', function()
    assert.has_error(function() I.merge(5, {}) end)
    assert.has_error(function() I.merge(true, {}) end)
    assert.has_error(function() I.merge('oops', {}) end)

    assert.has_error(function() I.merge({}, 5) end)
    assert.has_error(function() I.merge({}, true) end)
    assert.has_error(function() I.merge({}, 'oops') end)
    assert.has_error(function() I.merge({}, nil) end)
  end)

  it(' - does deep copy', function()
    local d = { one = 42 }
    local s = { one = 1, two = 'two', three = true, four = { 'a', 'list' } }
    local m = I.merge(d, s)
    local mt = { five = 5, six = 'six', seven = true, eight = false, nine = { ball = 'round' } }

    assert.equal(42, m.one)

    -- returned merged table m is a new table
    m.one = 99
    assert.equal(99, m.one)
    assert.equal(42, d.one)
  end)
end)
