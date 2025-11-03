```
                                  \\\///
                                 / _  _ \
                               (| (.)(.) |)
             .---------------.OOOo--()--oOOO.--------------.
             |                                             |
             |                __   _  __         __        |
             |         _____ / /_ (_)/ /_ _____ / /_       |
             |        / ___// __// // __// ___// __ \      |
             |       (__  )/ /_ / // /_ / /__ / / / /      |
             |      /____/ \__//_/ \__/ \___//_/ /_/       |
             |                                             |
             |                                             |
             '--------------.oooO--------------------------'
                             (   )   Oooo.
                              \ (    (   )
                               \_)    ) /
                                     (_/
```

## a lua-filter for pandoc, turning codeblocks into works of art

# Examples

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
