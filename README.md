```
                                          \\\///
                                         / _  _ \
                                       (| (.)(.) |)
                .--------------------.OOOo--()--oOOO.-------------------.
                |                                                       |
                |         _____    __     _    __             __        |
                |        / ___/   / /_   (_)  / /_   _____   / /_       |
                |        \__ \   / __/  / /  / __/  / ___/  / __ \      |
                |       ___/ /  / /_   / /  / /_   / /__   / / / /      |
                |      /____/   \__/  /_/   \__/   \___/  /_/ /_/       |
                |                                                       |
                |                                                       |
                '-------------------.oooO-------------------------------'
                                     (   )   Oooo.
                                      \ (    (   )
                                       \_)    ) /
                                             (_/
```

## A pandoc lua-filter, turning codeblocks into works of art

If you can generate output (be it text or graphics) from the command
line, stitch will help you do the same from within a codeblock and
include its result upon converting to another format.

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

## Examples

### [Diagon](https://github.com/ArthurSonzogni/Diagon)

If you were there for the dawn of the Internet, you might appreciate the
simplicity of ascii output.

```
┌─────────┐                                           
│CodeBlock│                                           
└────┬────┘                                           
  ___▽___       ____     ┌──────────────┐             
 ╱       ╲     ╱    ╲    │cbx, art, out,│             
╱ stitch? ╲___╱ exe? ╲___│err created   │             
╲         ╱yes╲      ╱yes└───────┬──────┘             
 ╲_______╱     ╲____╱            │                    
     │no         │no             │                    
     │           └───┬───────────┘                    
     │             __▽___                             
     │            ╱      ╲    ┌────────────────┐      
     │           ╱ purge? ╲___│remove old files│      
     │           ╲        ╱yes└────────┬───────┘      
     │            ╲______╱             │              
     │               │no               │              
     │               └────┬────────────┘              
     │           ┌────────▽───────┐                   
     │           │parse inc-option│                   
     │           └────────┬───────┘                   
     │              ______▽______     ┌──────────────┐
     │             ╱             ╲    │include in the│
     │            ╱ inc: part(s)? ╲___│order parsed  │
     │            ╲               ╱yes└───────┬──────┘
     │             ╲_____________╱            │       
     │                    │no                 │       
     └──────────┬─────────┴───────────────────┘       
           ┌────▽───┐                                 
           │CONTINUE│                                 
           └────────┘                                 

```

````
``` {#cb01 stitch="diagon" arg="Flowchart"}
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
````

### [youplot](https://github.com/red-data-tools/YouPlot)

Or a bit more dynamic: today’s local temperature (well, at the time of
writing anyway).

```
                  Temperature (˚C) Today
         ┌                                        ┐ 
   00:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■ 9.5            
   01:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■ 9.4            
   02:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■ 9.6           
   03:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■ 9.5            
   04:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■ 9.5            
   05:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■ 9.1             
   06:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■ 9.3            
   07:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■ 9.6           
   08:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■ 9.9           
   09:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 10.5        
   10:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 10.9       
   11:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 11.4     
   12:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 12.1    
   13:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 12.3   
   14:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 12.3   
   15:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 12.1    
   16:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 11.7     
   17:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 10.9       
   18:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 10.2         
   19:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 10.1         
   20:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■ 9.8           
   21:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 10.0         
   22:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 10.1         
   23:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 10.3         
   00:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 10.2         
         └                                        ┘ 
```

````
``` {#cb02 stitch="youplot"}
curl -sL 'https://api.open-meteo.com/v1/forecast?'\
'latitude=52.52&longitude=13.41&hourly=temperature_2m&format=csv' \
| head -n 29 | tail -n +5 | sed 's/^[^T]*T//' \
|  uplot bar -d, -t "Temperature (˚C) Today" -o
```
````

### [Cetz](https://typst.app/universe/package/cetz)

Or go more graphical with
[Cetz](https://typst.app/universe/package/cetz), one of many packages in
the [typst](https://typst.app/universe/search/?kind=packages) universe
for plotting, charts & tree layout.

<figure id="cb03-1-art" data-stitch="cetz"
data-caption="Karl&#39;s picture">
<img
src=".stitch/cetz/cb03-b9bee3b2db9f17c89dd7a5199c939e3cc1298311.png"
id="cb03-1-art-img" />
<figcaption>Karl's picture</figcaption>
</figure>

````
``` {#cb03 stitch="cetz" caption="Karl's picture"}
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
````

### [Fletcher](https://typst.app/universe/package/fletcher)

Another package from the [typst](https://typst.app/) universe, for
drawing diagrams and arrows. Revisiting the flowchart shown earlier with
[diagon](https://github.com/ArthurSonzogni/Diagon).

<figure id="cb04-1-art" data-stitch="cetz" data-caption="Stitch">
<img
src=".stitch/cetz/cb04-6805adf85fea2c717d0f8faab3db0f29fe733458.svg"
id="cb04-1-art-img" />
<figcaption>Stitch</figcaption>
</figure>

````
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
````

### [Lilaq](https://lilaq.org/)

Yet another [typst](https://typst.app/) package, this time for advanced
data visualization. Unfortunately, typst and its packages currently have
no way of downloading data, so the following codeblock is used for
side-effects only (well, its included here to show it’s actually there
and doing something)

````
``` {#cb05 stitch="download" arg="local-temperature.json"}
curl -sL 'https://api.open-meteo.com/v1/forecast?latitude=52.52&longitude=13.41&'\
'hourly=temperature_2m&timezone=Europe%2FLondon&forecast_days=1&format=json'\
| jq .
```
````

This downloads today’s temperature to
`.stitch/cetz/local-temperature.json`, which is then used in the
following codeblock to create a graph.

<figure id="cb06-1-art" data-stitch="cetz"
data-caption="Temperature (C) today by Lilaq">
<img
src=".stitch/cetz/cb06-b60c5a0c6038b345b783a8f514fe52f0a1651b75.svg"
id="cb06-1-art-img" />
<figcaption>Temperature (C) today by Lilaq</figcaption>
</figure>

````
``` {#cb06 stitch="cetz" caption="Temperature (C) today by Lilaq" fmt="svg" exe="yes"}
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
````

### [Gnuplot](https://gnuplot.sourceforge.net)

Another example using the trusty `gnuplot`.

<figure id="cb07-1-art" data-stitch="gnuplot">
<img
src=".stitch/gnuplot/cb07-2d280d4ebabb1f76bba036bca17a97623b6cd92a.png"
id="cb07-1-art-img" />
</figure>

````
``` {#cb07 stitch="gnuplot"}
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
````

## Documentation

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

### Installation

Installation is pretty straightforward:

- put `stitch.lua` on your `$LUA_PATH` (e.g. in
  `~/.local/share/pandoc/filters`)
- add `~/.local/share/pandoc/filters/?.lua` to `$LUA_PATH`

### Usage

`% pandoc --lua-filter stitch.lua doc.md -t doc.pdf`

A doc’s meta section is read by Stitch for options. When converting
multiple documents into one output document, those could go into a yaml
file mentioned last on the command line. Or as the first one, since meta
information is merged, where the ‘last one wins’.

*stitchable codeblock*

A codeblock can be marked for processing by `stitch` by:

- `.stitch` included as a class, and/or
- `stitch=name` included as an attribute

If either one is found, the codeblock will be processed according to the
set of options found for this codeblock. See [Options](#options) below
for the resolution order.

Using `stitch=` or `stitch=""` is the same as included the `.stitch`
class. If the hardcoded defaults are enough, simply add `.stitch` as a
class. If the tool being used requires other settings, create a named
section in the meta section of the document.

Examples:

    ```{#id-x bash .stitch}
    echo "just using the defaults"
    ```

or
`{#id-y bash stitch=download out="#dir/dta/wheather.json"}     curl -sL https://host/v1/forecast/?today&format=json`
and the meta section looks something like this:

    ---
    author: me
    stitch:
      defaults:
        dir: ".stitch"     # work dir for all things stitch
      download:
        inc=""             # no includes, just download
        cmd="#cbx 1>#out"  # redirect stdout to file given by cb's `#out`-attribute
    ...

The `#<opt>`’s are expanded by stitch using the option-set for the
current codeblock.

### Features

Stitch provides a few features that make converting codeblocks easy:

- conditional codeblock execution
- organize file storage locations
- old file detection and (possibly) clean up
- include 0 or more of stdout, stderr, output file and/or codeblock
- include the same output multiple times in different ways
- run codeblock as system command or run it through another command
- use a codeblock for side-effects only (0 includes)
- different log levels to show processing details

### Options

Stitch options are resolved in the following most to least specific
order:

1.  codeblock attributes
2.  a meta `name` section
3.  the meta `defaults` section
4.  hardcoded Stitch defaults

The list of options and default values:

| Opt | Value                               | Description                                      |
|:----|:------------------------------------|:-------------------------------------------------|
| arg | ’’                                  | argument for the command line                    |
| cid | ‘x’                                 | unique codeblock identifier (\*)                 |
| dir | ‘.stitch’                           | Stitch’s working directory, relative to pandoc’s |
| exe | ‘maybe’                             | execute codeblock (or not)                       |
| fmt | ‘png’                               | intended graphic file format                     |
| log | ‘info’                              | log verbosity                                    |
| old | ‘purge’                             | what to do with old residue files                |
| inc | ‘cbx:fcb out art:img err’           | what to include in which order                   |
| cbx | ‘\#dir/#cid-#sha.cbx’               | codeblock file template                          |
| out | ‘\#dir/#cid-#sha.out’               | stdout file capture template                     |
| err | ‘\#dir/#cid-#sha.err’               | stderr file capture template                     |
| art | ‘\#dir/#cid-#sha.#fmt’              | cmd output file template                         |
| cmd | ‘\#cbx \#arg \#art 1\>#out 2\>#err’ | command line template                            |

Table Stitch options (\*) assigned by stitch, unique across all
codeblocks in the current doc

#### `inc`-option specifies include directives

The `inc`-option is a csv/space separated list of directives, each of
the form:

    what!read@filter:how
     |    |     |     `- one of {<none>, fcb, img, fig} - optional
     |    |     `- mod.func, called with AST or data - optional
     |    `- one of the pandoc `from` formats - optional
     `- one of {cbx, art, out, err} - mandatory

     * if a part is omitted, so is its leading marker (`!`, `@` or `:`).
     * `what` should start the directive, the other parts can be in any order

*what*

This part starts the directive and is the only mandatory part and refers
to:

- `cbx`, the codeblock itself
- `art`, usually contains graphical output (depends on `cmd` used)
- `out`, usually contains the output on stdout (depends on `cmd` used)
- `err`, usually contains the output on stderr (depends on `cmd` used)

*read*

The output denoted by `what` is first read and if `read` is specified,
the data is read again using `pandoc.read()` producing a new pandoc doc.
See [pandoc’s options](https://pandoc.org/MANUAL.html#general-options)
for a list of available input formats to interpret the data.

*filter*

After the `what` has been read (and possibly reread using pandoc.read),
it can be processed further by listing a filter in the form of
`mod.func`. If defined, the lua-module `mod` will be required and its
`func` called with the data read. The `mod.func` is passed the data,
which could be image data, plain ascii text or a pandoc doc (if *read*
was used).

*how*

Specifies how to include the result:

- <none>, means going with the Stitch default
- fcb, to include the result in a fenced codeblock
- img, a pandoc.Image link to the file on disk for `what`
- fig, same but using a pandoc.Figure element

```` stitched
``` {.stitch inc="cbx:fcb out!markdown"}
pandoc --list-input-formats | sed 's/^/- /'
```
````

- biblatex
- bibtex
- commonmark
- commonmark_x
- creole
- csljson
- csv
- docbook
- docx
- dokuwiki
- endnotexml
- epub
- fb2
- gfm
- haddock
- html
- ipynb
- jats
- jira
- json
- latex
- man
- markdown
- markdown_github
- markdown_mmd
- markdown_phpextra
- markdown_strict
- mediawiki
- muse
- native
- odt
- opml
- org
- ris
- rst
- rtf
- t2t
- textile
- tikiwiki
- tsv
- twiki
- typst
- vimwiki

<!-- -->

- codeblock is saved on disk as `dir/<cid>-<hash>.cbx`
- exec bit is turned on
- the `cbx` is either run as a system command or processed by another
  command
- that produces one of more of:
  - stdout (text), redir to `#out`
  - stderr (text), redir to `err`
  - artifact (image), to `#art`
- then the cb(x) and/or 1 or more results can be included as per `inc`
  option
- `inc` = `what!reader@filter:how`, `what` is mandatory, the others are
  optional

### Configuration

- associate a cb with stitch: `.stitch` or `stitch=name`
- options are resolved in this order:
  - codeblock attributes
  - meta\[name\] section
  - meta\[defaults\] section (if any)
  - hardcoded
- options are:
  - dir ..
  - cmd .. etc..
