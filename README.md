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

If you can generate output, be it text or graphics, stitch will help you
do the same from within a codeblock and include its result upon
converting to another format.

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

<figure id="cb03-1-art" data-stitch="cetz">
<img
src=".stitch/cetz/cb03-b9bee3b2db9f17c89dd7a5199c939e3cc1298311.png"
id="cb03-1-art-img" />
</figure>

````
``` {#cb03 stitch="cetz"}
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
