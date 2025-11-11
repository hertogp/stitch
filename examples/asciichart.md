---
author: pdh
date: today
monofont: "FreeMono"
stitch:
  defaults:
    dir: .stitch/asciichart
    inc: out cbx
...

```{#id0.0 .stitch inc=out}
#!/usr/bin/env bash
figlet -c -w 60 asciichart | boxes -d ian_jones -p h6v2
```

*Notes*

- original: [https://github.com/kroitor/asciichart/](https://github.com/kroitor/asciichart/)
- lua port: [https://github.com/asukaminato0721/lua-asciichart](https://github.com/asukaminato0721/lua-asciichart)
- install:
    * copy the lua file to `~/.local/share/lua`
    * add `${HOME}/.local/share/lua/?.lua` to `LUA_PATH`

\newpage

# Examples

Borrowed from the [lua port repo](https://github.com/asukaminato0721/lua-asciichart)

## line

```{.lua #id1.0 .stitch}
#!/usr/bin/env lua
local asciichart = require("asciichart")
local s0 = {}
for i = 1, 60 + 1 do
  s0[i] = 15 * math.sin(i * ((math.pi * 4) / 60))
end
print(asciichart.plot(s0))
```

\newpage

## series

```{.lua #id2.0 .stitch}
#!/usr/bin/env lua
local asciichart = require('asciichart')
local function getRandomInt(min, max) return math.random(min, max) end
local function generateSeries(length)
  local series = {}
  series[1] = getRandomInt(0, 10)
  for i = 2, length do
    local randomNum = getRandomInt(0, 1) > 0.5 and 1 or -1
    series[i] = series[i - 1] + randomNum
  end
  return series
end
local s2 = generateSeries(50)
local s3 = generateSeries(50)
print(asciichart.plot({ s2, s3 }))
```

\newpage

## colors

```{.lua #id3.0 .stitch}
#!/usr/bin/env lua
local asciichart = require("asciichart")
local function getRandomInt(min, max)
  return math.random(min, max)
end

local function generateSeries(length)
  local series = {}
  series[1] = getRandomInt(0, 15)
  for i = 2, length do
    local randomNum = getRandomInt(0, 1) > 0.5 and 1 or -1
    series[i] = series[i - 1] + randomNum
  end
  return series
end

local arr1 = generateSeries(50)
local arr2 = generateSeries(50)
local arr3 = generateSeries(50)
local arr4 = generateSeries(50)

local config = {
  colors = {
      asciichart.green, -- blue
      asciichart.green,
      asciichart.default, -- default color
      nil, -- equivalent to default (nil in Lua)
  }
}
config = nil -- TODO: PDF blows up on esc sequences for colors

print(asciichart.plot({arr1, arr2, arr3, arr4}, config))
```
