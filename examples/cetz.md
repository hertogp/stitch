---
author: pdh
date: today
stitch:
  defaults:
    log: debug
  download:
    log: debug
    dir: ".stitch/cetz"
    out: ".stitch/cetz/#arg"
    inc: "cbx:fcb"
    exe: "yes"
  typst:
    dir: ".stitch/cetz"
    arg: compile
    cmd: "typst #arg #cbx #art" # don't catch stderr
    inc: cbx:fcb art
...

```{#id0 .stitch inc=out}
#!/usr/bin/env bash
figlet -c -w 60 "typst / cetz" | boxes -d ian_jones -p h2v1
```

Notes:

- `snap install typst`
- `sudo apt-get install librsvg-bin` (for `Lilaq`)
- homepage [typst.app](https://typst.app/)
- cli command `typst compile cb.cbx cb.<fmt>`
- packages are downloaded automagically when `import`'d in a doc.typ
- see [packages universe](https://typst.app/universe/search/?kind=packages)
   - [Cetz](https://typst.app/universe/package/cetz), library for plotting, charts & tree layout
   - [Cetz-plot](https://github.com/cetz-package/cetz-plot), adds plots and charts to CeTZ
   - [Fletcher](https://typst.app/universe/package/fletcher), draw diagrams with nodes and arrows
   - [Lilaq](https://lilaq.org/), advanced data visualization in Typst

\newpage

\newpage

# Examples

## Cetz, from [typst.app](https://typst.app/universe/package/cetz/)

```{#id1 .stitch cfg=typst caption="Karl's picture"}
#import "@preview/cetz:0.4.2"
#set page(width: auto, height: auto, margin: .5cm)
#show math.equation: block.with(fill: white, inset: 1pt)
#cetz.canvas(length: 3cm, {
  import cetz.draw: *
  set-style(
    mark: (fill: black, scale: 2),
    stroke: (thickness: 0.4pt, cap: "round"),
    angle: (
      radius: 0.3,
      label-radius: .22,
      fill: green.lighten(80%),
      stroke: (paint: green.darken(50%))
    ), content: (padding: 1pt)
  )
  grid((-1.5, -1.5), (1.4, 1.4), step: 0.5, stroke: gray + 0.2pt)
  circle((0,0), radius: 1)
  line((-1.5, 0), (1.5, 0), mark: (end: "stealth"))
  content((), $ x $, anchor: "west")
  line((0, -1.5), (0, 1.5), mark: (end: "stealth"))
  content((), $ y $, anchor: "south")
  for (x, ct) in ((-1, $ -1 $), (-0.5, $ -1/2 $), (1, $ 1 $)) {
    line((x, 3pt), (x, -3pt))
    content((), anchor: "north", ct)
  }
  for (y, ct) in ((-1, $ -1 $), (-0.5, $ -1/2 $), (0.5, $ 1/2 $), (1, $ 1 $)) {
    line((3pt, y), (-3pt, y))
    content((), anchor: "east", ct)
  }
  // Draw the green angle
  cetz.angle.angle((0,0), (1,0), (1, calc.tan(30deg)),
    label: text(green, [#sym.alpha]))
  line((0,0), (1, calc.tan(30deg)))
  set-style(stroke: (thickness: 1.2pt))
  line((30deg, 1), ((), "|-", (0,0)), stroke: (paint: red), name: "sin")
  content(("sin.start", 50%, "sin.end"), text(red)[$ sin alpha $])
  line("sin.end", (0,0), stroke: (paint: blue), name: "cos")
  content(("cos.start", 50%, "cos.end"), text(blue)[$ cos alpha $], anchor: "north")
  line((1, 0), (1, calc.tan(30deg)), name: "tan", stroke: (paint: orange))
  content("tan.end", $ text(#orange, tan alpha) = text(#red, sin alpha) / text(#blue, cos alpha) $, anchor: "west")
})
```

\newpage

## Cetz-plot

Example from [cetz-plot](https://github.com/cetz-package/cetz-plot)

```{#id2 .stitch cfg=typst caption="Cetz-plot"}
#import "@preview/cetz:0.4.2": canvas, draw
#import "@preview/cetz-plot:0.1.3": plot
#set text(size: 10pt)
#set page(width: auto, height: auto, margin: .5cm)
#let style = (stroke: black, fill: rgb(0, 0, 200, 75))
#let f1(x) = calc.sin(x)

#let fn = (
  ($ x - x^3"/"3! $, x => x - calc.pow(x, 3)/6),
  ($ x - x^3"/"3! - x^5"/"5! $, x => x - calc.pow(x, 3)/6 + calc.pow(x, 5)/120),
  ($ x - x^3"/"3! - x^5"/"5! - x^7"/"7! $, x => x - calc.pow(x, 3)/6 + calc.pow(x, 5)/120 - calc.pow(x, 7)/5040),
)
#canvas({
  import draw: *

  // Set-up a thin axis style
  set-style(axes: (stroke: .5pt, tick: (stroke: .5pt)),
            legend: (stroke: none, orientation: ttb, item: (spacing: .3), scale: 80%))
  plot.plot(size: (12, 8),
    x-tick-step: calc.pi/2,
    x-format: plot.formats.multiple-of,
    y-tick-step: 2, y-min: -2.5, y-max: 2.5,
    legend: "inner-north",
    {
      let domain = (-1.1 * calc.pi, +1.1 * calc.pi)

      for ((title, f)) in fn {
        plot.add-fill-between(f, f1, domain: domain,
          style: (stroke: none), label: title)
      }
      plot.add(f1, domain: domain, label: $ sin x  $,
        style: (stroke: black))
    })
})
```

\newpage

## Fletcher


```{#id3 .stitch cfg=typst caption="Fletcher" fmt=svg}
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import fletcher.shapes: diamond
#set text(font: "Comic Neue", size: 10pt) // testing: omit
#set page(fill: none, width: auto, height: auto, margin: (x: 6pt, y:3pt))

#diagram(
	node-stroke: .1em,
    spacing: 2em,
	node((0,0), [Start], corner-radius: .2em, extrude: (0, 3)),
	edge("-|>"),
	node((0,1), align(center)[
		Hey, wait,\ this flowchart\ is a trap!
	], shape: diamond),
	edge("d,r,u,l", "-|>", [Yes], label-pos: 0.1)
)
```

\newpage


```{#id4 .stitch cfg=typst caption="Fletcher" fmt=svg}
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#set text(10pt)
#set page(fill: none, width: auto, height: auto, margin: (x: 6pt, y:3pt))
#diagram(
	node-stroke: .1em,
	node-fill: gradient.radial(blue.lighten(80%), blue, center: (30%, 20%), radius: 80%),
	spacing: 4em,
	edge((-1,0), "r", "-|>", `open(path)`, label-pos: 0, label-side: center),
	node((0,0), `reading`, radius: 2em),
	edge(`read()`, "-|>"),
	node((1,0), `eof`, radius: 2em),
	edge(`close()`, "-|>"),
	node((2,0), `closed`, radius: 2em, extrude: (-2.5, 0)),
	edge((0,0), (0,0), `read()`, "--|>", bend: 130deg),
	edge((0,0), (2,0), `close()`, "-|>", bend: -40deg),
)
```

\newpage

## Lilaq

Notes:

- `typst` only has local data loading, so cb `#id5.0` does the downloading
- `#id5.0` downloads csv-data (see `meta.stitch.download`)
- `#id5.0` with `inc=""` would hide it completely while still being executed
- `#id5.1` uses path to the csv-file, relative to dir where pandoc was started

```{#id5.0 .stitch cfg=download arg="dta/local-temperature.csv"}
curl -sL 'https://api.open-meteo.com/v1/forecast?'\
'latitude=52.52&longitude=13.41&hourly=temperature_2m'\
'&format=csv' | tail -n +5 | head -n 24 | sed 's/^[^T]*T//;s/:/./'
```

```{#id5.1 .stitch cfg=typst caption="Temperature (C)\
today by Lilaq" fmt=svg exe=yes}
#import "@preview/lilaq:0.5.0" as lq
#set page( fill: none, width: auto, height: auto, margin: (x: 8pt, y: 8pt))
#let (x, y) = lq.load-txt(read("dta/local-temperature.csv"))

#lq.diagram(
title: [source: api.open-meteo.com],
  xlabel: [hour],
  ylabel: [temperature (C)],
  lq.plot(x, y),
)
```

\newpage

Among the (local) [data loading](https://typst.app/docs/reference/data-loading/)
facilities is `json` which makes downloading a bit easier but the datetime
string, formatted as `YYY-MM-DDTHH:MM`, still needs some manual massaging
to get a typst `datetime` value.  So rather than parse out all fields to
create a [datetime](https://typst.app/docs/reference/foundations/datetime/)
codeblock `#id5.3` simply turns the `HH` part into an `int`.

```{#id5.2 .stitch cfg=download arg="dta/local-temperature.json" inc="cbx:fcb out:fcb"}
curl -sL 'https://api.open-meteo.com/v1/forecast?latitude=52.52&longitude=13.41&'\
'hourly=temperature_2m&timezone=Europe%2FLondon&forecast_days=1&format=json'\
| jq .
```

```{#id5.3 .stitch blah= cfg=typst caption="Temperature (C)\
today by Lilaq" fmt=svg exe=yes}
#import "@preview/lilaq:0.5.0" as lq
#set page( fill: none, width: auto, height: auto, margin: (x: 8pt, y: 8pt))
#let dta = json("dta/local-temperature.json")
#let hour(str) = {
    return int(str.slice(11, count: 2))
}
#let hours = dta.hourly.time.map(hour)

#lq.diagram(
  title: [GPS (#dta.latitude, #dta.longitude)\ source: api.open-meteo.com],
  xlabel: [hour\ (#dta.timezone)],
  ylabel: [temperature (#dta.hourly_units.temperature_2m)],
  lq.plot(hours, dta.hourly.temperature_2m),
)
```
\newpage

## Plotsy-3d

```{#id6.0 .stitch cfg=typst caption="Plotsy-3d" fmt=svg}
#import "@preview/plotsy-3d:0.2.1": plot-3d-parametric-surface
#set page( fill: none, width: auto, height: auto, margin: (x: 8pt, y: 8pt))

#let xfunc(u,v) = u*calc.sin(v)
#let yfunc(u,v) = u*calc.cos(v)
#let zfunc(u,v) = u
#let color-func(x, y, z, x-lo,x-hi,y-lo,y-hi,z-lo,z-hi) = {
  return purple.transparentize(20%).lighten((z/(z-hi - z-lo)) * 80%)
}
#let scale-factor = 0.25
#let (xscale,yscale,zscale) = (0.3,0.2,0.3)
#let scale-dim = (xscale*scale-factor,yscale*scale-factor, zscale*scale-factor)

$ x(u,v) = u sin(v), space y(u,v)= u cos(v), space z(u,v)= u $
#plot-3d-parametric-surface(
  xfunc,
  yfunc,
  zfunc,
  xaxis: (-5,5), // set the minimum axis size, scales with function if needed
  yaxis: (-5,5),
  zaxis: (0,5),
  color-func: color-func,
  subdivisions:5,
  scale-dim: scale-dim,
  udomain:(0, calc.pi+1), // note this gets truncated to an integer
  vdomain:(0, 2*calc.pi+1), // note this gets truncated to an integer
  axis-step: (5,5,5),
  dot-thickness: 0.05em,
  front-axis-thickness: 0.1em,
  front-axis-dot-scale: (0.04, 0.04),
  rear-axis-dot-scale: (0.08,0.08),
  rear-axis-text-size: 0.5em,
  axis-label-size: 1.5em,
  xyz-colors: (red,green,blue),
)
```
\newpage

```{#id6.1 .stitch cfg=typst caption="Plotsy-3d" fmt=svg}
#import "@preview/plotsy-3d:0.2.1": plot-3d-surface
#set page( fill: none, width: auto, height: auto, margin: (x: 8pt, y: 8pt))
#let size = 10
#let scale-factor = 0.11
#let (xscale,yscale,zscale) = (0.3,0.3,0.02)
#let scale-dim = (xscale*scale-factor,yscale*scale-factor, zscale*scale-factor)
#let func(x,y) = x*x + y*y
#let color-func(x, y, z, x-lo,x-hi,y-lo,y-hi,z-lo,z-hi) = {
  return blue.transparentize(20%).darken((y/(y-hi - y-lo))*100%).lighten((x/(x-hi - x-lo)) * 50%)
}

$ z= x^2 + y^2 $
#plot-3d-surface(
  func,
  color-func: color-func,
  subdivisions: 2,
  subdivision-mode: "decrease",
  scale-dim: scale-dim,
  xdomain: (-size,size),
  ydomain:  (-size,size),
  pad-high: (0,0,0), // padding around the domain with no function displayed
  pad-low: (0,0,5),
  axis-step: (3,3,75),
  dot-thickness: 0.05em,
  front-axis-thickness: 0.1em,
  front-axis-dot-scale: (0.05,0.05),
  rear-axis-dot-scale: (0.08,0.08),
  rear-axis-text-size: 0.5em,
  axis-label-size: 1.5em,
  xyz-colors: (red,green,blue),
)
```


\newpage

# Local installation

## typst -h

```{#id0.0 .stitch inc=out}
typst -h
```

## snap info typst

```{#id1 .stitch inc=out}
snap info typst
```


