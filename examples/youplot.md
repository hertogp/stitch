---
author: pdh
date: today
mainfont: "Latin Modern Mono"
monofont: FreeMono
stitch:
  defaults:
    dir: .stitch/youplot
    inc: "out cbx"
    log: debug
...

```{#id0.0 .stitch inc=out}
#!/usr/bin/env bash
figlet -c -w 40 youplot | boxes -d ian_jones -p h6v2
```

*Notes*

- visit [youplot](https://github.com/red-data-tools/YouPlot)
- `sudo apt-get install ruby-dev`
- `sudo gem install youplot`
- uplot's option *-o* makes output go to stdout (use in cb itself)
- uses `--pdf-engine=xelatex`
- add in meta:
```
    mainfont: "Latin Modern Mono"
    monofont: FreeMono
```

\newpage

# uplot --help

```{#id0.1 .stitch}
uplot --help
```

\newpage

# Examples

Borrowed from [youplot](https://github.com/red-data-tools/YouPlot) repo.

## barplot

```{#id1.0 .stitch}
curl -sL https://git.io/ISLANDScsv \
| sort -nk2 -t, \
| tail -n15 \
| uplot bar -d, -t "Areas of the World's Major Landmasses" -o
```

\newpage

## density

```{#id1.2 .stitch}
curl -sL https://git.io/IRIStsv \
| cut -f1-4 \
| uplot density -H -t IRIS -o
```

\newpage

## lineplot

```{#id1.3 .stitch}
curl -sL https://git.io/AirPassengers \
| cut -f2,3 -d, \
| uplot line -d, -w 50 -h 15 -t AirPassengers \
  --xlim 1950,1960 --ylim 0,600 -o
```

\newpage

## scatter

```{#id1.4 .stitch}
curl -sL https://git.io/IRIStsv \
| cut -f1-4 \
| uplot scatter -H -t IRIS -o
```
