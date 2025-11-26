---@diagnostic disable: undefined-global

local M = require('src/stitch')[1]._bustit

describe('table merging', function()
  it('- forced is nil/false means preserve existing values', function()
    local d = { one = 1, two = 2, three = { one = 11, two = 22 } }
    local s = { one = 11, two = true, three = { one = 111, two = 222, three = 333 }, four = false }

    local m = M.helpers.tmerge(d, s, false)

    -- existing values not overwritten
    assert.equal(m.one, 1)
    assert.equal(m.two, 2)
    assert.equal(m.three.one, 11)
    assert.equal(m.three.two, 22)

    -- new values added
    assert.equal(m.three.three, 333)
    assert.equal(m.four, false)
  end)

  it('- forced is true means overwrite existing values', function()
    local d = { one = 1, two = 2, three = { one = 11, two = 22 } }
    local s = { one = 11, two = true, three = { one = 111, two = 222, three = 333 }, four = false }

    local m = M.helpers.tmerge(d, s, true)

    -- existing values overwritten
    assert.equal(m.one, 11)
    assert.equal(m.two, true)
    assert.equal(m.three.one, 111)
    assert.equal(m.three.two, 222)

    -- new values added
    assert.equal(m.three.three, 333)
    assert.equal(m.four, false)
  end)

  it('- creates destination if its nil', function()
    local d = {}
    local s = { one = 1, two = 'two', three = true, four = { 'a', 'list' } }
    local m = M.helpers.tmerge(d, s)
    local mt = { five = 5, six = 'six', seven = true, eight = false, nine = { ball = 'round' } }

    -- without metatables
    assert.equal('table', type(m))
    assert.are.same(m, s)

    -- with metatable
    setmetatable(s, { __index = mt })
    assert.equal(s.five, 5)
    assert.are.same(s.nine, { ball = 'round' })

    m = {}
    m = M.helpers.tmerge(d, s)

    -- m also has metatable
    assert.equal(rawget(m, 'five'), nil)
    assert.equal(m.five, 5)
  end)

  it('- does deep copy', function() end)
end)
