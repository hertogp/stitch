local increase = 0

local bump = function(elm)
  elm.level = elm.level + increase
  return elm
end
local dump = require 'dump'

return {

  header = function(doc)
    print('dump meta', dump(doc.meta))
    increase = math.floor(tonumber(doc.meta.stitched.cb_attr.bump) or 1)
    print('increase = ', increase)
    return doc:walk({ Header = bump })
  end,
}
