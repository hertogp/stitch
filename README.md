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
