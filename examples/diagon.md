---
author: pdh
date: today
#monofont: "FreeMono"
monofont: "DejaVu Sans Mono"
stitch:
  defaults:
    dir: .stitch/diagon
    cmd: "diagon #arg < #cbx 1>#out 2>#err"
    inc: out cbx
  intro:
    log: debug
    inc: out
    cmd: "#cbx 1>#out"
...

```{#id0.0 .stitch cfg=intro inc=out}
#!/usr/bin/env bash
figlet -c -w 60 diagon | boxes -d ian_jones -p h6v2
```

*Notes*

- `snap install diagon`
- `sudo apt install texlive-xetex`
- `sudo apt install texlive-fonts-extra`

Added to diagon.md meta:

- `monofont: "Dejavu Sans Mono"`

\newpage

# diagon -h

```{#id0.1 .stitch cfg=intro inc=out}
diagon -h
```

\newpage

# Generators

Examples borrowed from [diagon's github
repo](https://github.com/ArthurSonzogni/Diagon/tree/main).

## Sequence

```{#id1.0 .stitch arg=Sequence}
Renderer -> Browser: BeginNavigation()
Browser -> Network: URLRequest()
Browser <- Network: URLResponse()
Renderer <- Browser: CommitNavigation()
Renderer -> Browser: DidCommitNavigation()
```
\newpage

## Frame

```{#id2.0 .stitch cfg=intro inc="out cbx"}
figlet diagon | diagon Frame
```

```{#id2.1 .stitch cfg=intro inc="out cbx"}
cat ../.stylua.toml | diagon Frame
```

\newpage

## GraphPlanar

```{#id3.0 .stitch arg=GraphPlanar}
if -> "then A" -> end
if -> "then B" -> end
end -> loop -> if
```

\newpage

## GraphDAG

```{#id4.0 .stitch arg=GraphDAG}
chrome -> content
chrome -> blink
chrome -> base

content -> blink
content -> net
content -> base

blink -> v8
blink -> CC
blink -> WTF
blink -> skia
blink -> base
blink -> net

weblayer -> content
weblayer -> chrome
weblayer -> base

net -> base
WTF -> base
```

\newpage

## Flowchart

```{#id5.0 .stitch arg=Flowchart}
if ("DO YOU UNDERSTAND FLOW CHARTS?")
  "GOOD!";
else if ("OKAY, YOU SEE THE LINE LABELED 'YES'?") {
  if ("... AND YOU CAN SEE THE ONES LABELED 'NO'?") {
    "GOOD";
  } else {
    if ("BUT YOU JUST FOLLOWED THEM TWICE?")
      noop;
    else
      noop;
    "(THAT WASN'T A QUESTION)";
    "SCREW IT"
  }
} else {
  if ("BUT YOU SEE THE ONES LABELED 'NO'?") {
    return "WAIT, WHAT?";
  } else {
    "LISTEN.";
    return "I HATE YOU";
  }
}

"LET'S GO DRING";
"HEY, I SHOULD TRY INSTALLING FREEBSD!"
```

\newpage

## Stitch(cb)


```{#id6.0 .stitch arg=Flowchart inc=out}

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
\
Notes:

- an unchanged codeblock with 1+ existing artifacts, is not executed again
- if `exe=no`, the codeblock isn't executed either
- executing usually creates 3 artifacts in addition to the cbx itself
- if `inc=""`, nothing will be included, not even the original codeblock
- `inc=""` allows for side-effects, like downloading data to be used later \
  which probably uses a fixed filename, instead of a generated one.

