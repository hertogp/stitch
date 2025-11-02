---
author: pdh
date: today
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

- see [youplot](https://github.com/red-data-tools/YouPlot)
- `sudo apt-get install ruby-dev`
- `sudo gem install youplot`
- uplot's option *-o* makes output go to stdout
- uses `--pdf-engine=xelatex`
- add in meta: `monofont: FreeMono`

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

```{#id2.1 .stitch}
curl -sL https://git.io/IRIStsv \
| cut -f1-4 \
| uplot density -H -t IRIS -o
```

\newpage

## lineplot

```{#id3.1 .stitch}
curl -sL https://git.io/AirPassengers \
| cut -f2,3 -d, \
| uplot line -d, -w 50 -h 15 -t AirPassengers \
  --xlim 1950,1960 --ylim 0,600 -o
```

\newpage

The local temperature for the next 7 days (168 hrs) (at the time of writing).

```{#id3.2 .stitch}
curl -sL 'https://api.open-meteo.com/v1/forecast?'\
'latitude=52.52&longitude=13.41&hourly=temperature_2m&format=csv' \
| tail -n +5 | cut -f2 -d, \
| uplot line -d, -w 60 -h 15 -t "Temperature (˚C)" --ylim 0,25 -o
```

\newpage

Or the temperature, on the day of compiling this document, in a bar plot:

```{#id3.3 .stitch}
curl -sL 'https://api.open-meteo.com/v1/forecast?'\
'latitude=52.52&longitude=13.41&hourly=temperature_2m&format=csv' \
| head -n 29 | tail -n +5 | sed 's/^[^T]*T//' \
|  uplot bar -d, -t "Temperature (˚C) Today" -o
```


\newpage

## scatter

```{#id4.1 .stitch}
curl -sL https://git.io/IRIStsv \
| cut -f1-4 \
| uplot scatter -H -t IRIS -o
```
