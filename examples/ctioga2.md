---
author: pdh
date: today
monofont: "DejaVu Sans Mono"
stitch:
  defaults:
    dir: .stitch/ctioga
    inc: art cbx
...

```{#id0.0 .stitch inc=out}
#!/usr/bin/env bash
figlet -c -w 60 ctioga2 | boxes -d ian_jones -p h6v2
```

*Notes*

- `sudo apt install ctioga2`
- appears to be broken


\newpage

# ctioga -h

```{#id0.1 .stitch inc=out}
ctioga2 -h
```

\newpage

```{.lua #id1.0 .stitch inc=out}
#!/usr/bin/env lua

local asciichart = require("asciichart")
local s0 = {}

for i = 1, 120 + 1 do
    s0[i] = 15 * math.sin(i * ((math.pi * 4) / 120))
end
print(asciichart.plot(s0))
```
