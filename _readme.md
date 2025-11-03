---
author: hertogp <git.hertogp@gmail.com>
title: stitch
monofont: "DejaVu Sans Mono"
stitch:
  doc:
    cmd: "#cbx 1>#out"
    inc: out
  ascii:
    cmd: "diagon #cbx 1>#out"
    inc: "out cbx:fcb"
...

```{#id stitch=doc}
figlet -w 60 -krf slant "S t i t c h" | boxes -d ian_jones -p h6v1
```

## A pandoc lua-filter, turning codeblocks into works of art

If you can generate output, be it text or graphics, stitch will help you
do the same from within a codeblock and include its result upon converting
to another format.

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

```{stitch=ascii}
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




