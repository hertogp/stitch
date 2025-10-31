---
author: pdh
date: today
monofont: "DejaVu Sans Mono"
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

- original: [asciichart](https://github.com/kroitor/asciichart/)
- lua port: [lua-asciichart](https://github.com/asukaminato0721/lua-asciichart)
- copy the lua file to `~/.local/share/lua`
- add `${HOME}/.local/share/lua/?.lua` to `LUA_PATH`


\newpage

# line

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

# series

```{.lua #id2.0 .stitch}
#!/usr/bin/env lua
local asciichart = require('asciichart')
local function getRandomInt(min, max) return math.random(min, max) end
local function generateSeries(length)
  local series = {}
  series[1] = getRandomInt(0, 15)
  for i = 2, length do
    local randomNum = getRandomInt(0, 1) > 0.5 and 2 or -2
    series[i] = series[i - 1] + randomNum
  end
  return series
end
local s2 = generateSeries(60)
local s3 = generateSeries(50)
print(asciichart.plot({ s2, s3 }))
```
