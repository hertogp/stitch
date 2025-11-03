---
author: hertogp <git.hertogp@gmail.com>
title: stitch
stitch:
  doc:
    cmd: "#cbx 1>#out"
    inc: out
...

# stitch

```{#id stitch=doc}
figlet -w 60 -kcf slant stitch | boxes -d ian_jones -p h6v1
```

# Examples

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




