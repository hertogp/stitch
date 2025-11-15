--[[ stich2 oo-reimplementation of stitch ]]

-- initiatlize only once (load vs require)
if package.loaded.stitch2 then return package.loaded.stitch2 end

--[[- locals]]
--

local hard = { khard = true, x = 11, y = 12, z = 99 }
local function run_noop(self) print(self, 'run noop ' .. self.opts.exe) end
local kb = {
  run = setmetatable({}, { __index = function(_) return run_noop end }),
  -- __index = function(t, k)
  --   return function() print(t, 'run unknown ' .. k) end
  -- end,
  -- }),
  elm = {},
}
function kb:new(context)
  local ctx = setmetatable(context, { __index = hard })
  local new = {
    opts = setmetatable({ kopts = true }, { __index = ctx, hidden = true }),
  }

  -- refer to kb when looking up fields on an instance
  self.__index = self
  return setmetatable(new, self)
end

function kb.run.yes(self) print(self, 'run yes') end
function kb.run.no(self) print(self, 'run no') end
function kb.run.maybe(self) print(self, 'run maybe') end
function kb.run.chunk(self) print(self, 'run chunk') end
function kb.run.unknown(self) print(self, 'run chunk') end
function kb:execute() return self.run[self.opts.exe](self) end

-- return list of table t and its subsequent metatables (if any)
function kb:chain(field, t)
  if nil == field then return t end
  if 'table' ~= type(field) then return t end
  t = t or {}
  t[#t + 1] = field
  return self:chain((getmetatable(field) or {}).__index, t)
end

-- return all option keys
function kb:options()
  local keys = {}
  for _, tbl in ipairs(self:chain(self.opts)) do
    for k, _ in pairs(tbl) do
      keys[#keys + 1] = k
    end
  end
  return keys
end

-- local ctx = { kctx = true, a = 1, b = 2 }
-- local ccb = kb:new(ctx) -- new current codeblock
--
-- print('ctx.a', ctx.a)
-- print('ctx.z', ctx.z)
-- print('ccb.opts', ccb.opts)
-- print('ccb.opts.a', ccb.opts.a)
-- print('ccb.opts.x', ccb.opts.x)
--
-- print('{ ' .. table.concat(ccb:options(), ', ') .. ' }')
--
-- -- how to store :method in var and call it
-- local m = kb.options
-- local c = m(ccb)
-- print('{ ' .. table.concat(c, ';') .. ' }')
--
-- -- indirect execution
-- ccb.opts.exe = 'chunk'
-- ccb:execute()
-- ccb.opts.exe = 'yes'
-- ccb:execute()
-- ccb.opts.exe = 'abracadabra'
-- ccb:execute()
--
-- os.exit(0)

-- conditional module returns ?
-- local marker = os.getenv('STITCH')
-- print('modmode', marker)
-- marker = os.getenv('HOME')
-- print('where the hart is', marker)
--
-- os.exit(0)

--[[-- /kb (tmp) --]]

--[[- STITCH ]]

package.loaded.stitch2 = { {

  Pandoc = function(doc)
    print('ICU-C-ME')
    return doc
  end,
} }

return package.loaded.stitch
