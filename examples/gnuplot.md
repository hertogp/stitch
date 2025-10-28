---
author: hertogp
date: today
stitch:
  man:
    inc: out:fcb
  gnuplot:
    fmt: png
    inc: art err cbx
    log: debug
    cmd: "gnuplot #cbx 1>#art 2>#err"
...

```{#id0 .stitch inc=out:fcb}
echo gnuplot | figlet -c -w 55 | boxes -d peek -p h2v1 | sed 's/\/\*/  /;s/\*\//-+/'
echo "                https://gnuplot.sourceforge.net\n\n\n"
gnuplot -h | sed 's/^/           /'
```

\newpage

# Simple Plot

```{#id1 .stitch cfg=gnuplot caption="Created by gnuplot"}
set terminal pngcairo transparent enhanced font \
    "arial,10" fontscale 1.0 size 500, 350
set key inside left top vertical Right noreverse enhanced \
    autotitles box linetype -1 linewidth 1.000
set samples 200, 200
plot [-30:20] besj0(x)*0.12e1 with impulses, \
    (x**besj0(x))-2.5 with points
```

\newpage

# Surface, no hidden lines

```{#id2 .stitch cfg=gnuplot caption="Created by gnuplot"}
set terminal pngcairo  transparent enhanced font "arial,10" fontscale 1.0 \
    size 600, 400
# set output 'gnuplot-02.png'
set samples 20, 20
set isosamples 20, 20
set hidden3d back offset 1 trianglepattern 3 undefined 1 altdiagonal bentover
set style data lines
set title "Hidden line removal of explicit surfaces"
set trange [ * : * ] noreverse nowriteback
set urange [ * : * ] noreverse nowriteback
set vrange [ * : * ] noreverse nowriteback
set xrange [ -3.00000 : 3.00000 ] noreverse nowriteback
set x2range [ * : * ] noreverse writeback
set yrange [ -2.00000 : 2.00000 ] noreverse nowriteback
set y2range [ * : * ] noreverse writeback
set zrange [ * : * ] noreverse writeback
set cbrange [ * : * ] noreverse writeback
set rrange [ * : * ] noreverse writeback
set colorbox vertical origin screen 0.9, 0.2 size screen 0.05, 0.6 front \
    noinvert bdefault
VERSION = "gnuplot version 6.0.3"
NO_ANIMATION = 1
splot 1 / (x*x + y*y + 1)
```

# Documentation

## gnuplot -h

```{#id3 .stitch inc=out:fcb}
#! /usr/bin/env bash
gnuplot -h
```
## man gnuplot

```{#man .stitch cfg=man}
#!/usr/bin/env sh
MANWIDTH=75 man gnuplot | col -bx | iconv -t ascii//TRANSLIT
```
