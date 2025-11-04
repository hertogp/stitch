---
author: hertogp <git.hertogp@gmail.com>
title: stitch
monofont: "DejaVu Sans Mono"
stitch:
  defaults:
    inc: "out cbx:fcb"
  doc:
    dir: ".stitch/readme"
    cmd: "#cbx 1>#out"
    inc: out
  diagon:
    dir: ".stitch/diagon"
    cmd: "diagon #arg <#cbx 1>#out"
  youplot:
    dir: ".stitch/youplot"
    cmd: "#cbx 1>#out"
  cetz:
    dir: ".stitch/cetz"
    arg: compile
    cmd: "typst #arg #cbx #art" # ignore stderr
    inc: "art cbx:fcb"
  download:
    dir: ".stitch/cetz"
    out: ".stitch/cetz/#arg"
    inc: "cbx:fcb"
    exe: "yes"
  gnuplot:
    dir: ".stitch/gnuplot"
    cmd: "gnuplot #cbx 1>#art 2>#err"
    inc: "art:fig cbx:fcb"
...

```{#cb00 stitch=doc}
figlet -w 60 -krf slant "S t i t c h" | boxes -d ian_jones -p h6v1
```

## A pandoc lua-filter, turning codeblocks into works of art

If you can generate output (be it text or graphics) from the command line,
stitch will help you do the same from within a codeblock and include its result
upon converting to another format.

```
                        doc
                         |
                        cb-------------+
                         |             |
                  +--<exec cb>--+      |
                  |      |      |      |
 .stitch/hash. stdout   file  stderr cb.txt
                  :      :      :      :
                <out>  <art>  <err>  <cbx>
                  |      |      |      |
                 inc    inc    inc    inc
                  :      :      :      :
                  +------+------+------+
                         |
                        doc
```

## Examples

### [Diagon](https://github.com/ArthurSonzogni/Diagon)

If you were there for the dawn of the Internet, you might appreciate the
simplicity of ascii output.

```{#cb01 stitch=diagon arg=Flowchart}
"CodeBlock"

if ("stitch?") {
  if ("exe?") {
    "cbx, art, out, err created"
  }
  if ("purge?") {
    "remove old files"
  }
  "parse inc-option"
  if("inc: part(s)?") {
    "include in the order parsed"
  }
}

"CONTINUE"
```

### [youplot](https://github.com/red-data-tools/YouPlot)

Or a bit more dynamic: today's local temperature  (well, at the time of writing
anyway).

```{#cb02 stitch=youplot}
curl -sL 'https://api.open-meteo.com/v1/forecast?'\
'latitude=52.52&longitude=13.41&hourly=temperature_2m&format=csv' \
| head -n 29 | tail -n +5 | sed 's/^[^T]*T//' \
|  uplot bar -d, -t "Temperature (˚C) Today" -o
```

### [Cetz](https://typst.app/universe/package/cetz)

Or go more graphical with [Cetz](https://typst.app/universe/package/cetz), one
of many packages in the [typst](https://typst.app/universe/search/?kind=packages)
universe for plotting, charts & tree layout.

```{#cb03 stitch=cetz caption="Karl's picture"}
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

### [Fletcher](https://typst.app/universe/package/fletcher)

Another package from the [typst](https://typst.app/) universe, for drawing
diagrams and arrows. Revisiting the flowchart shown earlier with
[diagon](https://github.com/ArthurSonzogni/Diagon).

``` {#cb04 stitch="cetz" caption="Stitch" fmt="svg"}
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import fletcher.shapes: pill, parallelogram, diamond
#set page(width: auto, height: auto, margin: (x: 8pt, y: 8pt))
#set text(10pt)
#diagram(
  node-stroke: .1em,
  node-fill: gradient.radial(blue.lighten(80%), blue, center: (30%, 20%), radius: 80%),
  spacing: 4em,
  mark-scale: 150%,
  node((-1,-1), "codeblock", name: <cb>, shape: pill),
  node((-1,0), "stitch?", name: <stitch>, shape: diamond),
  edge(<cb>, <stitch>, "-|>"),
  node((0,0), "exe?", name: <exe>, shape: diamond),
  edge(<stitch>, <exe>, "-|>", `yes`),
  node((1,0), "create: cbx art out err", name: <create>, shape: parallelogram, extrude: (-2.5, 0)),
  edge(<exe>, <create>, "->", `yes`),
  node((0,1), "purge?", name: <purge>, shape:diamond),
  edge(<exe>, <purge>, "-|>", `no`),
  edge(<create.south>, (1, 0.5), (0, 0.5),  "-|>"),
  node((1,1), "rm old files", name: <rm>, shape: parallelogram, extrude: (-2.5,0)),
  edge(<purge>, <rm>, "-|>", `yes`),
  node((0,2), "parse `inc`-opt", name: <parse>, shape: parallelogram),
  edge(<purge>, <parse>, "-|>", `no`),
  edge(<rm.south>, (1, 1.5), (0,1.5), "-|>"),
  node((0,3), "`inc:`-parts?", name: <parts>, shape: diamond),
  edge(<parse>, <parts>, "-|>"),
  node((1,3), "include in order parsed", name: <include>, shape: parallelogram),
  edge(<parts>, <include>, "-|>", `yes`),
  node((-1,4), "continue", name: <continue>, shape: pill),
  edge(<stitch>, <continue>, "-|>", `no`),
  edge(<parts>, (0, 3.45), (-1, 3.45), "-|>", `no`),
  edge(<include>, (1, 4), <continue>, "-|>"),
)

```

### [Lilaq](https://lilaq.org/)

Yet another [typst](https://typst.app/) package, this time for advanced data
visualization.  Unfortunately, typst and its packages currently have no way of
downloading data, so the following codeblock is used for side-effects only
(well, its included here to show it's actually there and doing something)

``` {#cb05 stitch="download" arg="local-temperature.json"}
curl -sL 'https://api.open-meteo.com/v1/forecast?latitude=52.52&longitude=13.41&'\
'hourly=temperature_2m&timezone=Europe%2FLondon&forecast_days=1&format=json'\
| jq .
```

This downloads today's temperature to `.stitch/cetz/local-temperature.json`,
which is then used in the following codeblock to create a graph.

```{#cb06 stitch=cetz caption="Temperature (C) today by Lilaq" fmt=svg exe=yes}
#import "@preview/lilaq:0.5.0" as lq
#set page(width: auto, height: auto, margin: (x: 8pt, y: 8pt))
#let dta = json("local-temperature.json")
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

### [Gnuplot](https://gnuplot.sourceforge.net)

Another example using the trusty `gnuplot`.

```{#cb07 stitch=gnuplot}
set terminal png
set dummy u,v
set key bmargin center horizontal Right noreverse enhanced autotitles nobox
set parametric
set view 50, 30, 1, 1
set isosamples 50, 20
set hidden3d back offset 1 trianglepattern 3 undefined 1 altdiagonal bentover
set ticslevel 0
set title "Interlocking Tori"
set urange [ -3.14159 : 3.14159 ] noreverse nowriteback
set vrange [ -3.14159 : 3.14159 ] noreverse nowriteback
splot cos(u)+.5*cos(u)*cos(v),sin(u)+.5*sin(u)*cos(v),.5*sin(v) with lines,\
1+cos(u)+.5*cos(u)*cos(v),.5*sin(v),sin(u)+.5*sin(u)*cos(v) with lines
```

## Documentation

```
Outline
- installation
  * put stitch.lua somewhere on LUA_PATH (e.g. `~/.local/share/pandoc/filters`)

- usage
  * `% pandoc --lua-filter stitch.lua doc.md -o doc.pdf`
  * link a codeblock to stitch via attribute or class:
    + `stitch=name`, attribute, points to a section in doc's meta
    + `.stitch`, as one of the cb classes
  * stitch options resolution order:
    1. cb attributes
    2. meta named section (if any)
    3. meta defaults section (if any)
    4. hardcoded

- features
  * conditional codeblock execution
  * organize file storage locations
  * old file detection and (possibly) clean up
  * include 0 or more of stdout, stderr, image and/or codeblock
  * run codeblock as system command or run it through another command
  * codeblock can be used for side-effects only (0 includes)
  * different log levels to show processing details

```

### Installation

Installation is pretty straightforward:

* put `stitch.lua` on your `$LUA_PATH` (e.g. in `~/.local/share/pandoc/filters`)
* add `~/.local/share/pandoc/filters/?.lua` to `$LUA_PATH`


### Usage

`% pandoc --lua-filter stitch.lua doc.md -t doc.pdf`

A doc's meta section is read by Stitch for options.  When converting
multiple documents into one output document, those could go into
a yaml file mentioned last on the command line.  Or as the first one,
since meta information is merged, where the 'last one wins'.


### Features

Stitch provides a few features that make converting codeblocks easy:

  * conditional codeblock execution
  * organize file storage locations
  * old file detection and (possibly) clean up
  * include 0 or more of stdout, stderr, output file and/or codeblock
  * include the same output multiple times in different ways
  * run codeblock as system command or run it through another command
  * use a codeblock for side-effects only (0 includes)
  * different log levels to show processing details

### Options

Stitch options are resolved in the following order (most to least specific):

  1. codeblock attributes
  2. a meta `name` section
  3. the meta `defaults` section
  4. hardcoded Stitch defaults

The list of options:

Option | Default                        | Description
:------|:-------------------------------|:--------------------------------
cid    | 'x'                            | unique codeblock identifier
arg    | ''                             | argument for the command line
dir    | '.stitch'                      | Stitch's working directory, relative to pandoc's
fmt    | 'png'                          | intended graphic file format
log    | 'info'                         | log verbosity
exe    | 'maybe'                        | execute codeblock (or not)
old    | 'purge'                        | what to do with old residue files
inc    | 'cbx:fcb out art:img err'      | what to include in which order
cbx    | '#dir/#cid-#sha.cbx'           | codeblock file template
out    | '#dir/#cid-#sha.out'           | stdout file capture template
err    | '#dir/#cid-#sha.err'           | stderr file capture template
art    | '#dir/#cid-#sha.#fmt'          | cmd output file template
cmd    | '#cbx #arg #art 1>#out 2>#err' | command line template


- codeblock is saved on disk as `dir/<cid>-<hash>.cbx`
- exec bit is turned on
- the `cbx` is either run as a system command or processed by another command
- that produces one of more of:
   + stdout (text), redir to `#out`
   + stderr (text), redir to `err`
   + artifact (image), to `#art`
- then the cb(x) and/or 1 or more results can be included as per `inc` option
- `inc` = `what!reader@filter:how`, `what` is mandatory, the others are optional

### Configuration

- associate a cb with stitch: `.stitch` or `stitch=name`
- options are resolved in this order:
    + codeblock attributes
    + meta[name] section
    + meta[defaults] section (if any)
    + hardcoded
- options are:
    + dir ..
    + cmd ..
    etc..

