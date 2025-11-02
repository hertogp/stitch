---
author: hertogp <git.hertogp@gmail.com>
title: stitch
stitch:
  defaults:
    inc: out
  boxes:
...

# stitch

```{#id .stitch cfg=boxes out: ocb,stdout}
figlet stitch | boxes -d ian_jones -p h2v1
```

```
                        doc
                         |
                        cb-------------+
                         |             |
                  +--<exec cb>--+      |
                  |      |      |      |
 .stitch/hash. stdout   file  stderr   cb
                  |      |      |      |
                <cnv>  <cnv>  {fcb}  {ocb}
                  |      |      :      :
                 ins    ins     :      :
                  +------+------+------+
                         |
                        doc
```




