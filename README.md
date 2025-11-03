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
