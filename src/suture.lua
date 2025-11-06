-- Example filter to demonstrate Stitch processing a codeblock

local increase = 0

local function bump(elm)
  elm.level = elm.level + increase
  return elm
end

return {
  header = function(doc)
    increase = math.floor(tonumber(doc.meta.stitched.cb_attr.bump) or 1)
    return doc:walk({ Header = bump })
  end,
}
