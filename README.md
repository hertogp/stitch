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
      |                  - a lua-filter -                     |
      |                                                       |
      '-------------------.oooO-------------------------------'
                           (   )   Oooo.
                            \ (    (   )
                             \_)    ) /
                                   (_/
```

  
  
  

# Turn codeblocks into works of art

If you can generate output (be it text or graphics) from the command
line, stitch will help you do the same from within a codeblock and
include its result upon converting the document using
[pandoc](https://pandoc.org/).

Main [features](#features) include:

- run a codeblock as a system command, a lua chunk or read it as-is
- optionally convert `data` by reading it with pandoc using some format
- optionally run `data` (or `doc`) through another lua program or filter
- include 0 or more results (as image, figure, codeblock or doc
  fragment)
- granular control on where to store files, upto codeblock levels
- optionally skip running a codeblock if it hasn’t changed
- shift headers up or down while converting a, possibly included,
  document

## Security

`stitch.lua` is, like any lua-filter that executes codeblocks, totally
*insecure* and any CISO’s nightmare. Before running an externally
supplied document through the `stitch.lua` filter, be sure you have
vetted each and every codeblock that is marked for stitching since it
probably runs a plethora of system commands on your machine, potentially
causing chaos and/or harm.

## Requirements

This lua-filter requires pandoc version \>= 2.19 (or \>= 3.0 if you want
to use `pandoc.Figure` to link to an image). Some of the `lua` chunks in
this readme require version \>= 3.1.1 in order to convert it. Anyway,
some stuff in here is probably not Windows friendly, but any \*nix
should be fine.

## Installation

Installation is straightforward:

- put `stitch.lua` on your `$LUA_PATH` (e.g. in
  `~/.local/share/pandoc/filters`)
- add `~/.local/share/pandoc/filters/?.lua` to `$LUA_PATH`

## Usage

`% pandoc --lua-filter stitch.lua doc.md ..`

The filter will process a codeblock if it has a:

- `stitch=name` attribute, explicitly linking it to a
  `doc.meta.stitch`-section
- class that matches a `doc.meta.stitch`-section (implicit link)
- `.stitch` class (which uses `doc.meta.stitch.defaults` or hardcoded
  defaults)

Processing a codeblock roughly follows these steps:

1.  resolve all options and expand them (once)
2.  save codeblock’s `text` to [`cbx`](#cbx)-file & mark it as
    executable (always)
3.  check if anything has changed [`oid`](#oid) (1+ of the other
    artifacts exist)
4.  conditionally run [`cmd`](#cmd) or \[`lua`\] load [`cbx`](#cbx)-file
    & run, producing artifacts
    1.  an [`art`](#art)-file (usually an image file, depends on
        [`cmd`](#cmd)),
    2.  an [`out`](#out)-file (if [`cmd`](#cmd) redirects `stdout` here)
    3.  an [`err`](#err)-file (if [`cmd`](#cmd) redirects `stderr` here)
5.  check for [`old`](#old) files and conditionally remove them
6.  parse the [`inc`](#inc)-option and include artifacts in order (if
    any)

In the face of errors, the filter just complains and carries on, if
possible, usually skipping the offending codeblock or artifact. If
things don’t pan out, check the logs and perhaps set the codeblock’s
[`log`](#log)-option to `debug`.

## Configuration

Configuration involves setting some options, either in the documents
meta block and/or in a codeblock’s attributes. Options are resolved in
the following (*most to least specific*) order:

1.  codeblock attributes
2.  a codeblock’s `name` section, in stitch’s meta data
3.  the `defaults` section, again in stitch’s meta data
4.  hardcoded option values

| Opt | Value                            | Description                        |
|:----|:---------------------------------|:-----------------------------------|
| arg | `''`                             | extra argument(s) for the cli      |
| cls | `'no'`                           | allow codeblock selection by class |
| dir | `'.stitch'`                      | stitch’s working directory         |
| exe | `'maybe'`                        | execute codeblock, or not          |
| fmt | `'png'`                          | intended `art`-file extension      |
| hdr | `'0'`                            | simple shift of headers            |
| log | `'info'`                         | log verbosity                      |
| run | `'system'`                       | run type for a codeblock           |
| old | `'purge'`                        | what to do with old files          |
| —   |                                  |                                    |
| art | `'#dir/#oid-#sha.#fmt'`          | template for cmd output file       |
| cbx | `'#dir/#oid-#sha.cbx'`           | template for cb’s `cbx`-file       |
| err | `'#dir/#oid-#sha.err'`           | template for stderr file redirect  |
| out | `'#dir/#oid-#sha.out'`           | template for stdout file redirect  |
| —   |                                  |                                    |
| cmd | `'#cbx #arg #art 1>#out 2>#err'` | template for the command line      |
| —   |                                  |                                    |
| inc | `'art:img err'`                  | what to include in which order     |

Available options and their hardcoded values

Note: `sha` and `oid` are provided by stitch, the latter is either the
codeblock’s `identifier` attribute or `anon<nr>` generated by the
filter.

The defaults are basically setup to:

- run the \[`cbx`’\]-file as a system command
- provide no additional [`arg`](#arg)’s
- provide an output filename [`art`](#art) as last argument
- capture stdout and stderr to [`out`](#out), resp. [`err`](#err)-files
- include some artifacts in the current doc:
  - `art:img` a link to an image file given by [`art`](#art)
  - `err`, whatever was captured on stderr in another codeblock

It is then up to the codeblock’s code to actually produce any of the
artifacts to be included. Tweaking a codeblock is then usually done by
specifying an [`arg`](#arg) attribute if needed and possibly changing
its [`dir`](#dir) and or [`inc`](#inc) attribute.

Most options are pretty and straightforward with [`inc`](#inc) being
somewhat more elaborate.

Here is an example, before describing the various options:

```` figlet
``` {#figlet1 .figlet arg="'s t i t c h'"}
#! /usr/bin/env bash
figlet -f script ${1}
```
````

``` figlet
                               _     
            o                 | |    
 ,    _|_        _|_    __    | |    
/ \_   |    |     |    /      |/ \   
 \/    |_/  |_/   |_/  \___/  |   |_/
                                     
                                     
```

The `.figlet` class links to a configuration section with the same name
under `doc.meta.stitch`:

    stitch:
      figlet:
        cmd: "#cbx #arg 1>#out"
        inc: "cbx:fcb out"
        dir: ".stitch/readme/figlet"

The `figlet`-section above basically sets the command line to use, the
directory where to store intermediate files and what to include in the
pandoc document being created. In this case both the codeblock itself
(with its attributes), followed by whatever was captured on `stdout` by
redirection. The `#cbx` and `#out` are expanded using the default
templates which amount to something like:

- `.stitch/readme/figlet/figlet1-<..sha-hash..>.cbx`, and
- `.stitch/readme/figlet/figlet1-<..sha-hash..>.out`

while `#arg` is expanded as per codeblock’s `arg='..'` attribute. The
codeblock’s text is saved in the `cbx-file`, marked executable and then
run as a system command and redirects figlet’s output to the out-file
which is then later on included via the `inc`-option.

The codeblock text could also be run as a lua chunk (`run=chunk`) or
serve as plain input data for an external tool or another pandoc filter.

### `arg`

*arg* is used to optionally supply extra argument(s) on the command
line.

It is a string and may contain spaces and it is simply interpolated in
the [`cmd`](#cmd) expansion which will be executed via an
`os.execute(cmd)`. The hardcoded default is `arg=""`, which won’t show
up on the command line.

The example below shows how a bash script sees its arguments when `arg`
is a multi word string in the codeblock’s attributes. There is no output
on stderr so the redirect does not create a file and the output file
argument is ignored by the script.

````
``` {#arg .stitch arg="two words" inc="cbx:fcb out"}
#!/usr/bin/env bash
echo "--------------"
echo "script name  :  ${0}"
echo "nr of args   :  ${#}"
echo "all args     :  ${@}"
echo "1st arg      :  ${1}"
echo "2nd arg      :  ${2}"
echo "last arg     :  ${@: -1}"
echo "alt last arg :  ${@:$#}"
echo "--------------"
```
````

```
--------------
script name  :  .stitch/readme/defaults/arg-8b59c724b69ca007855bfa62a5a917a9725a2c53.cbx
nr of args   :  2
all args     :  two words
1st arg      :  two
2nd arg      :  words
last arg     :  words
alt last arg :  words
--------------
```

### `art`

Specifies the intended filename for a codeblock’s result.

This is usually some type of graphic, but need not be. The type of file
and the output format of the document, determines how it can be included
by [`inc`](#inc).

If a codeblock stores non-graphical data in the `art`-file, linking to
it as an image or figure during a conversion to PDF, usually trips up
the PDF-engine.

### `cbx`

Specifies the filename where the current codeblock’s body is saved.

Default value:

When stitch touches a codeblock, it always saves its body (content) to
the filename given by `cbx` and marks it as executable. Later on, it
might be:

- run as a system command and use its output, e.g. \[youplot\]
- fed to an external tool and use her output, e.g. \[diagon\]
- loaded as a chunk and called to produce output, e.g. \[lua\]

### `cls`

*cls* specifies whether or not a codeblock can be selected by class.

Valid values: `{yes, no}`

Normally, codeblocks are marked by:

- setting an attribute like `stitch=name`, or
- adding `.stitch` as a class to a codeblock.

Hence, converting an externally acquired markdown document would require
touching all relevant codeblocks in order for them to get processed. The
`cls` option alleviates that need by allowing stitch to select
codeblock’s based on (one of) its classes.

When used as a codeblock attribute `{.. cls=true ..}`, stitch will match
any of the codeblock’s classes to named stitch sections in the doc’s
meta data. The first match is then used to process the codeblock. When
no class matches, the codeblock is ignored. This will happen for this
codeblock specifically.

To enable the same for all codeblocks that have a certain class, set the
`cls=true` in the corresponding stitch name’d section in the doc’s meta
data.

So the main purpose is to allow for processing of markdown documents
that are produced externally and pulled in by a codeblock and that are
not necessarily ‘stitch-aware’.

For example, suppose your main document’s meta data looks something
like:

     ---
     author: abc
     stitch:                     # the stitch meta data section
       gnuplot:                  # a named stitch section
         dir: '.stitch/gnuplot'
         .. : more options
         cls: true               # -> select codeblocks with class .gnuplot
       other:                    # a named stitch section
         dir: ..
     ...

If a codeblock in the main document pulls in another markdown document,
which is to be filtered by stitch as well (see [Nested
doc](#nested-doc)), stitch adds its own configuration to the
subdocument’s meta data before calling itself (or another filter) with
that document. That way all `{#id .gnuplot ..}` codeblocks will also be
processed without touching the subdocument itself.

This feature can also be used when writing a document to further reduce
the noise in the attributes of codeblocks and allows for consistent
processing of said codeblocks.

### `cmd`

Specifies the command line to (optionally) run via `os.execute(cmd)`.

The (hardcoded) default for `cmd` is to:

- run the codeblock as a system command,
- provide the expanded forms of [`arg`](#arg) and [`art`](#art) as
  arguments, and
- redirect stdout & stderr to [`out`](#out) and [`err`](#err)
  respectively.

Ofcourse, it is up to the codeblock code to actually use its argument
and/or the intended output filename.

If the [`cbx`](#cbx)-file itself is to be processed by another tool,
simply change the cmd string to something like
`gnuplot #cbx 1>#art 2>#err` which redirects gnuplot’s graphical output
to the file given by [`art`](#art) (the `#..` are all expanded before
running the command).

### `dir`

*dir* is used in the expansion of the artifact filepaths.

This effectively sets the working directory for stitch relative to the
directory where pandoc was started. Override the hardcoded `.stitch`
default in one or more of:

- the codeblock attributes
- a named stitch section in the doc’s meta data
- a stitch section named `defaults` in the doc’s meta data

Setting `dir` in a codeblock’s attributes is specific for that
codeblock. Mainly useful when debugging a particular defiant codeblock,
since it makes the artifact files easier to find/view.

When set in a named stitch section in the document’s meta data, it
allows to store artifact files per type of tool used. Useful if the
document being processed uses multiple tools for various codeblocks.

For dumping all artifacts in the same directory, just not in `.stitch`,
set dir as desired in the `defaults`-section of stitch in the doc’s meta
data.

### `err`

*err* is a filename template used to capture any output on `stderr`.

It is primarily used in the `cmd` template during the expansion to the
full command to run on the command line. Depending on how the `cmd`
template is set, this may or may not be actually used.

### `exe`

*exe* specifies whether a codeblock should actually run.

Valid values: `{yes, no, maybe}`

If *exe* is `yes` the codeblock is always run. A `no` means just that.
When the value is `maybe` (the default), the codeblock is only executed
when something changed and new or different results are expected. To
detect changes, stitch uses a fingerprint of the codeblock.

A codeblock’s fingerprint is calculated using:

- almost all option values (sorted by key), and
- the codeblock’s contents

All values are combined to a single string with all whitespace removed.
The fingerprint is then the sha1-hash of that string.

Options that do not influence any actual results are omitted (like `exe`
itself or `log` etc.). Sorting and whitespace removal means consistent
fingerprints and makes it useful to detect changes in the codeblock
and/or its options.

However, sometimes a codeblock simply serves to download some
periodically updated file from somewhere. Since nothing changed in the
codeblock itself, a downloaded file seems up-to-date. Setting `exe=yes`
will ensure the download is performed when converting the document.

Set `exe=no` to avoid downloading each time the document is converted or
to avoid heavy computations caused by a codeblock while working on other
parts of the document.

### `fmt`

*fmt* is used as the extension in the `#art` template.

It allows for easily setting the intended graphics format on the
codeblock level without touching the `art` template.

### `hdr`

TODO: explain

### `inc`

*inc* contains 0 or more directives on what to include and how.

It is a single string containing comma or space separated directives. A
directive must start with the `what` and may be followed by three other
types of mechanisms (in any order) which are defined by their leading
character.

    what!read@filter:how
     |    |     |     `- one of {<none>, fcb, img, fig} - optional
     |    |     `------- mod[.func], filter(s) w/ func to call - optional
     |    `------------- one of the pandoc `from` formats - optional
     `------------------ one of {cbx, art, out, err} - mandatory

     * if a part is omitted, so is its leading marker (`!`, `@` or `:`).
     * `what` must start the directive, the other parts can be in any order

Note that the same artifact can be included multiple times. Regardless
of the order of those 3 mechanisms, they are always evaluated in this
order:

1.  `!read` the artifact’s data using `pandoc.read(data, read)` – if
    applicable
2.  `@filter` the data or doc (if re-read)
3.  `:how` include the result in a specific manner in the master
    document

*what*

This part starts the directive and is the only mandatory part and refers
to:

- `cbx`, the codeblock itself
- `art`, usually contains graphical output (depends on `cmd` used)
- `out`, usually contains the output on stdout (depends on `cmd` used)
- `err`, usually contains the output on stderr (depends on `cmd` used)

*!read*

After the `what`’s output file has been read, `!read` says the data must
be re-read by pandoc using `pandoc.read(data, <read>)`. Note:

- `read`’s value should be one of pandoc’s `-f xx` formats
- `!read` converts the data to a Pandoc document

See [pandoc’s options](https://pandoc.org/MANUAL.html#general-options)
or `% pandoc --list-input-formats` for possible values for `read`. So
something like `!markdown`, `!csv` or some other value on that list.

*@filter*

After the `what` has been read (and possibly reread using pandoc.read),
it can be processed further by listing a filter in the form of
`mod.func`. Stitch will require `mod` which could be a regular module
`mod` exporting `func` or another pandoc-lua filter.

If a module could be loaded which is actually named `mod.func`, then it
is supposed to export a `Pandoc` function. Such a module requires the
data to be an actual Pandoc document produced by `!read`.

Before calling, stitch inspects the `data` and if it has type `Pandoc`,
its meta data is augmented with a `stitched` section that contains:

- `opts`, a lua table with all the options of the current codeblock
- `ctx`, a lua table with all the `stitch` related meta data of the
  current doc

However, it could be any module that simply accepts the data as acquired
by reading the `what`-file.

If no module was found an error is logged and processing continues.

TODO: add documentation of cb’s attr `hdr` that will shift header levels
of a pandoc doc to be included.

*:how*

Specifies how to include the final result (i.e. data or doc) after
reading, re-reading and possibly filtering.

- *\<none\>*, means going with the Stitch default for what is being
  included:
  - data is type `Pandoc` then its blocks are inserted, otherwise:
  - `art` is linked to as an pandoc.Image
  - `out` is included as the body of a pandoc.CodeBlock
  - `err` dito
  - `cbx` is included as a pandoc.CodeBlock
- *fcb*, to include the result in a fenced codeblock
  - if data is a pandoc element -\> cb content =
    `pandoc.write(data, native)`
  - otherwise, data is included as-is in the codeblock contents
- *img*, a pandoc.Image link to the file on disk for `what`
- *fig*, same but using pandoc.Figure

### `log`

*log* specifies logging level for stitch(-section) or an individual
codeblock.

Valid values: `{debug, info, note, warn, error, silent}`

Use `meta.stitch.defaults.log=silent` and a `cb.attribute.log=debug` to
turn off all logging except for one codeblock where logging happens on
the debug level.

### `oid`

*oid* is a unique, codeblock identifier, used in file templates.

It is set to either:

- cb.attr.identifier, or
- cb\<nth\>, where it’s the nth codeblock seen by stitch

Each time an artifact is included as per the codeblock’s [`inc`](#inc),
an `id` is generated and assigned to the element to be inserted (if
possible). That id consists of the codeblock’s identifier
([`oid`](#oid)), a counter of the nth artifact being included and the
kind of artifact.

An example of such an element id is: `csv-3-err` where

- the codeblock identifier is `csv`,
- it’s the third [`inc`](#inc)-directive that causes the include, and
  where
- `err` is the artificat to be included

### `old`

*old* specifies whether or not old files can be removed.

Valid values: `{keep, purge}`

Old incarnations of an artifact file are detected when their filenames
match the new filename except for the last `-#sha.<ext>` part. If a
filename template doesn’t end in `-#sha.<ext>` then Stitch cannot detect
old files and manual clean up will be necessary.

### `out`

*out* is a filename (template) used to capture any output on `stdout`.

It is primarily used in the `cmd` template during the expansion to the
full command to run on the command line. Depending on how the `cmd`
template is set, this may or may not be actually used.

# Examples

A few examples, mostly taken from the repo’s of the command line tools
used.

Each work of ‘art’ is followed by the codeblock that generated it. Most
examples use a configuration section `stitch='tool_name'` in order to
minimize the clutter in a codeblock’s attributes and keep its files
organized.

See the other
[examples](https://github.com/hertogp/stitch/tree/main/examples) in
[stitch’s repository](https://github.com/hertogp/stitch), which also
contain some information on installing the command line tools used.

## [Diagon](https://github.com/ArthurSonzogni/Diagon)

If you were there for the dawn of the Internet, you might appreciate the
simplicity of ascii output.

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

## [youplot](https://github.com/red-data-tools/YouPlot)

Or a bit more dynamic: today’s local temperature (well, the last time
the codeblock was changed before compiling this readme anyway). The
codeblock pulls in a csv file from `api.open-meteo.com`, cuts the output
down to what is needed and modifies the first field keeping only the
hours of the day. That output is then processed by
[youplot](https://github.com/red-data-tools/YouPlot)

````
``` {#youplot}
curl -sL 'https://api.open-meteo.com/v1/forecast?'\
'latitude=21.3069&longitude=-157.8583&hourly=temperature_2m&format=csv' \
| head -n 29 | tail -n +5 | sed 's/^[^T]*T//' \
|  uplot bar -d, -t "Temperature (˚C) Today" -o
```
````

```
                  Temperature (˚C) Today
         ┌                                        ┐ 
   00:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 28.4    
   01:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 27.8     
   02:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 26.6      
   03:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 25.8       
   04:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 25.4       
   05:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 25.1        
   06:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 25.0        
   07:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 24.9        
   08:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 24.3         
   09:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 23.6         
   10:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■ 23.2          
   11:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■ 22.8          
   12:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■ 22.0           
   13:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■ 21.4            
   14:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■ 21.0            
   15:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■ 20.7             
   16:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■ 20.6             
   17:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■ 20.4             
   18:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■ 21.9           
   19:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 25.2        
   20:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 26.8      
   21:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 27.9    
   22:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 28.7   
   23:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 29.1   
   00:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 28.0    
         └                                        ┘ 
```

## [Cetz](https://typst.app/universe/package/cetz)

Or go more graphical with
[Cetz](https://typst.app/universe/package/cetz), one of many packages in
the [typst](https://typst.app/universe/search/?kind=packages) universe,
for plotting, charts & tree layout.

<figure id="cb03-1-art"
data-sha="91294077a8daf97ca87f30583c0ee1090cd39f14" data-stitch="cetz"
data-oid="cb03">
<img
src=".stitch/new/cetz/cb03-91294077a8daf97ca87f30583c0ee1090cd39f14.png"
id="cb03-1-art" data-sha="91294077a8daf97ca87f30583c0ee1090cd39f14"
data-stitch="cetz" data-oid="cb03" alt="Karl&#39;s picture" />
<figcaption aria-hidden="true">Karl's picture</figcaption>
</figure>

````
``` {#cb03 stitch="cetz" caption="Karl's picture"}
#import "@preview/cetz:0.4.2"
#set page(width: auto, height: auto, margin: .5cm)
#show math.equation: block.with(fill: white, inset: 1pt)
#cetz.canvas(length: 3cm, {
  import cetz.draw: *
  set-style(
    mark: (fill: black, scale: 2),
    stroke: (thickness: 0.4pt, cap: "round"),
    angle: (
      radius: 0.3,
      label-radius: .22,
      fill: green.lighten(80%),
      stroke: (paint: green.darken(50%))
    ), content: (padding: 1pt)
  )
  grid((-1.5, -1.5), (1.4, 1.4), step: 0.5, stroke: gray + 0.2pt)
  circle((0,0), radius: 1)
  line((-1.5, 0), (1.5, 0), mark: (end: "stealth"))
  content((), $ x $, anchor: "west")
  line((0, -1.5), (0, 1.5), mark: (end: "stealth"))
  content((), $ y $, anchor: "south")
  for (x, ct) in ((-1, $ -1 $), (-0.5, $ -1/2 $), (1, $ 1 $)) {
    line((x, 3pt), (x, -3pt))
    content((), anchor: "north", ct)
  }
  for (y, ct) in ((-1, $ -1 $), (-0.5, $ -1/2 $), (0.5, $ 1/2 $), (1, $ 1 $)) {
    line((3pt, y), (-3pt, y))
    content((), anchor: "east", ct)
  }
  // Draw the green angle
  cetz.angle.angle((0,0), (1,0), (1, calc.tan(30deg)),
    label: text(green, [#sym.alpha]))
  line((0,0), (1, calc.tan(30deg)))
  set-style(stroke: (thickness: 1.2pt))
  line((30deg, 1), ((), "|-", (0,0)), stroke: (paint: red), name: "sin")
  content(("sin.start", 50%, "sin.end"), text(red)[$ sin alpha $])
  line("sin.end", (0,0), stroke: (paint: blue), name: "cos")
  content(("cos.start", 50%, "cos.end"), text(blue)[$ cos alpha $], anchor: "north")
  line((1, 0), (1, calc.tan(30deg)), name: "tan", stroke: (paint: orange))
  content("tan.end", $ text(#orange, tan alpha) = text(#red, sin alpha) / text(#blue, cos alpha) $, anchor: "west")
})
```
````

## [Fletcher](https://typst.app/universe/package/fletcher)

Another package from the [typst](https://typst.app/) universe, for
drawing diagrams and arrows. Revisiting the flowchart shown earlier with
[diagon](#diagon).

<figure id="cb04-1-art"
data-sha="fe6cfe9fbc2b4804645836dd7c1980f10b87b7af" data-stitch="cetz"
data-oid="cb04">
<img
src=".stitch/new/cetz/cb04-fe6cfe9fbc2b4804645836dd7c1980f10b87b7af.svg"
id="cb04-1-art" data-sha="fe6cfe9fbc2b4804645836dd7c1980f10b87b7af"
data-stitch="cetz" data-oid="cb04" alt="Stitch" />
<figcaption aria-hidden="true">Stitch</figcaption>
</figure>

````
``` {#cb04 stitch="cetz" caption="Stitch" fmt="svg"}
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import fletcher.shapes: pill, parallelogram, diamond
#set page(width: auto, height: auto, margin: (x: 8pt, y: 8pt))
#set text(10pt)
#diagram(
  node-stroke: .1em,
  node-fill: gradient.radial(blue.lighten(80%), blue, center: (30%, 20%), radius: 80%),
  spacing: 4em,
  mark-scale: 150%,
  node((-1,-1), "codeblock", name: <cb>, shape: pill),
  node((-1,0), "stitch?", name: <stitch>, shape: diamond),
  edge(<cb>, <stitch>, "-|>"),
  node((0,0), "exe?", name: <exe>, shape: diamond),
  edge(<stitch>, <exe>, "-|>", `yes`),
  node((1,0), "create: cbx art out err", name: <create>, shape: parallelogram, extrude: (-2.5, 0)),
  edge(<exe>, <create>, "->", `yes`),
  node((0,1), "purge?", name: <purge>, shape:diamond),
  edge(<exe>, <purge>, "-|>", `no`),
  edge(<create.south>, (1, 0.5), (0, 0.5),  "-|>"),
  node((1,1), "rm old files", name: <rm>, shape: parallelogram, extrude: (-2.5,0)),
  edge(<purge>, <rm>, "-|>", `yes`),
  node((0,2), "parse `inc`-opt", name: <parse>, shape: parallelogram),
  edge(<purge>, <parse>, "-|>", `no`),
  edge(<rm.south>, (1, 1.5), (0,1.5), "-|>"),
  node((0,3), "`inc:`-parts?", name: <parts>, shape: diamond),
  edge(<parse>, <parts>, "-|>"),
  node((1,3), "include in order parsed", name: <include>, shape: parallelogram),
  edge(<parts>, <include>, "-|>", `yes`),
  node((-1,4), "continue", name: <continue>, shape: pill),
  edge(<stitch>, <continue>, "-|>", `no`),
  edge(<parts>, (0, 3.45), (-1, 3.45), "-|>", `no`),
  edge(<include>, (1, 4), <continue>, "-|>"),
)
```
````

## [Lilaq](https://lilaq.org/)

Yet another [typst](https://typst.app/) package, this time for advanced
data visualization. Unfortunately, typst and its packages currently have
no way of downloading data, so the following codeblock is used for
side-effects only

````
``` {#cb05 stitch="download" arg="../cetz/temperatures.json"}
curl -sL 'https://api.open-meteo.com/v1/forecast?latitude=52.52&longitude=13.41&'\
'hourly=temperature_2m&timezone=Europe%2FLondon&forecast_days=1&format=json'\
| jq .
```
````

This downloads today’s temperature to
`.stitch/readme/cetz/temperatures.json`, which is then used in the
following codeblock to create a graph.

<figure id="cb06-1-art"
data-sha="6f6e58db3c97cb05307bffddda67d136742101c3" data-stitch="cetz"
data-oid="cb06">
<img
src=".stitch/new/cetz/cb06-6f6e58db3c97cb05307bffddda67d136742101c3.svg"
id="cb06-1-art" data-sha="6f6e58db3c97cb05307bffddda67d136742101c3"
data-stitch="cetz" data-oid="cb06"
alt="Temperature (C) today by Lilaq" />
<figcaption aria-hidden="true">Temperature (C) today by
Lilaq</figcaption>
</figure>

````
``` {#cb06 stitch="cetz" caption="Temperature (C) today by Lilaq" fmt="svg" exe="yes"}
#import "@preview/lilaq:0.5.0" as lq
#set page(width: auto, height: auto, margin: (x: 8pt, y: 8pt))
#let dta = json("temperatures.json")
#let hour(str) = { return int(str.slice(11, count: 2))}
#let hours = dta.hourly.time.map(hour)
#lq.diagram(
  title: [GPS (#dta.latitude, #dta.longitude)\ source: api.open-meteo.com],
  xlabel: [hour\ (#dta.timezone)],
  ylabel: [temperature (#dta.hourly_units.temperature_2m)],
  lq.plot(hours, dta.hourly.temperature_2m),
)
```
````

## [Gnuplot](https://gnuplot.sourceforge.net)

Another example using the trusty `gnuplot`.

<figure id="gnuplot-1-art" class="gnuplot"
data-sha="336ac3e2c1a6826f074c228d9e372a8b0c41a010" data-oid="gnuplot">
<img
src=".stitch/new/gnuplot/gnuplot-336ac3e2c1a6826f074c228d9e372a8b0c41a010.png"
id="gnuplot-1-art" class="gnuplot"
data-sha="336ac3e2c1a6826f074c228d9e372a8b0c41a010"
data-oid="gnuplot" />
<figcaption aria-hidden="true"></figcaption>
</figure>

```` gnuplot
``` {#gnuplot .gnuplot log="debug"}
set terminal png
set dummy u,v
set key bmargin center horizontal Right noreverse enhanced autotitles nobox
set parametric
set view 50, 30, 1, 1
set isosamples 50, 20
set hidden3d back offset 1 trianglepattern 3 undefined 1 altdiagonal bentover
set ticslevel 0
set title "Interlocking Tori"
set urange [ -3.14159 : 3.14159 ] noreverse nowriteback
set vrange [ -3.14159 : 3.14159 ] noreverse nowriteback
splot cos(u)+.5*cos(u)*cos(v),sin(u)+.5*sin(u)*cos(v),.5*sin(v) with lines,\
1+cos(u)+.5*cos(u)*cos(v),.5*sin(v),sin(u)+.5*sin(u)*cos(v) with lines
```
````

# Documentation

## Features

Stitch provides a few features for converting codeblocks:

- conditional codeblock execution ([`exe`](#exe))
  - run the codeblock as a system command
  - have it processed by an external tool
  - load it as a chunk and run it with Stitch in its global environment
- organize storage locations for codeblock artifacts ([`dir`](#dir))
- detect old files and (possibly) remove them ([`old`](#old))
- include 0 or more of the artifacts ([`inc`](#inc))
- include the same artifact multiple times in, usually, different ways
- use a codeblock for side-effects only (0 includes)
- log levels, global, per tool or codeblock, to show all gory details
  ([`log`](#log))
- transfer a codeblock’s attributes to its included results, if possible
- a unique id per codeblock and for each of its includes ([`oid`](#oid))
- include after re-read an artifact using a [pandoc
  –read=format](https://pandoc.org/MANUAL.html#general-options)
- run the [`cbx`](#cbx) or other artifact through an external filter
  - any lua program/filter that accepts string data or a pandoc doc
  - stitch itself for codeblocks in an externally acquired markdown doc

Some terminology used:

artifact  
refers to the [`cbx`](#cbx)-file or one of 3 files produced by
processing a codeblock

cbx-file  
the [`cbx`](#cbx)-file where a codeblock’s contents is stored and marked
executable

art-file  
the [`art`](#art)-file where file-based output is to be written to

out-file  
the [`out`](#out)-file where the output on stdout is captured

err-file  
the [`err`](#err)-file where the output on stderr is captured

tool  
an external program used to process the \[cbx\]-file

this usually has its own `stitch section` in the doc’s meta data

stitch section  
a `name`’d table of options under `stitch:` in the doc’s meta data

defaults  
a `defaults` section under `stitch` to fall back on when resolving
options

hardcoded  
the option values hardcoded in stitch and used if option resolution
fails

option resolution  
where stitch looks for options and their values.

order is: codeblock attr -\> stitch\[name\] -\> stitch\[defaults\] -\>
hardcoded

## Configuration

## Logging

Using codeblocks to generate artifacts and include those in the current
document can be confusing at times, especially when small errors lead to
unexpected behaviour and/or no output at all.

That’s where logging might help. Use the [`log`](#log) attribute, either
on an individual codeblock, or on the tool level in a `meta.stitch` tool
section and set it to `debug` to crank up the volume.

Log entries have roughly the following format:

`[stitch:<N> <Level>] <owner> : <action> | <message>`

where:

- `<N>` is the recursion level (max depth is hardcoded to 6)
- `<level>` is one of `error`, `warn`, `info`, `debug`
- `<owner>` is usually the codeblock [`oid`](#oid) or `stitch` itself
- `<action>` denotes what stitch is doing at that moment
- `<msg>` is whatever seemed insightful at the time

As an example, see the
[readme.pdf.log](https://github.com/hertogp/stitch/blob/main/.stitch/readme.pdf.log)
generated last time this readme was converted to PDF. Here is the
beginning of it (at least as it was on one of the conversion runs):

    [stitch:0  info] stitch :   init| STITCH initialized
    [stitch:0  info] stitch : stitch| walking CodeBlocks
    [stitch:0  info] preface:command| expanding template '#cbx 1>#out'
    [stitch:0  info] preface:command| .stitch/readme/preface-<sha>.cbx 1>.stitch/readme/preface-<sha>.out
    [stitch:0  info] preface:execute| skipped, output files exist (exe='maybe')
    [stitch:0  info] preface:  files| looking for old files ..
    [stitch:0  info] preface:  files| 0 old files removed
    [stitch:0  info] preface:include| cb.'#preface-1-out', 'out:fcb', fenced pandoc.CodeBlock
    [stitch:0  info] cb01   :command| expanding template 'diagon #arg <#cbx 1>#out'

where `<sha>` is the (40 chars long) fingerprint of the codeblock being
processed.

The logs show:

- stitch being initialized,
- that is it walking codeblocks only (no shifting headers here) and
- how it processed the fist (`preface`) codeblock of this readme
- that artifiacts are stored in ‘.stitch/readme/’ directory
- the start of processing the second codeblock, aptly named `cb01` ..

## Gotcha’s

If `stitch` isn’t behaving as expected:

| \#  | gotcha        | description                                                            |
|-----|---------------|------------------------------------------------------------------------|
| 1   | no quotes     | most values are strings and without quotes only the first word remains |
| 2   | no section    | remember: stitch falls back to hardcoded options if none are specified |
| 3   | no result     | a 0-byte artifact file may result in an empty element                  |
| 4   | wrong art     | if output is absent check the right \`what\` is in \`inc\`             |
| 5   | cb is skipped | probably because it it not recognized as such: check your markdown     |
| 6   | pdf fails     | image files that are invalid may break your pdf-engine                 |
| 7   | opt:val       | use opt=val to prevent an existential crisis                           |

gotcha's

## Stitch introspection

If a CodeBlock’s attributes include a `lua=chunk`, then stitch will load
it as a chunk, providing a copy of itself as `Stitch` in the chunk’s
global namespace.

# More examples

## Dump a pandoc AST fragment

If you are wondering what the pandoc AST looks like for a snippet the
following codeblock would reveal that when reading some csv-file using
`-f csv`. The attributes say:

- `.stitch` use the defaults for options not specified in these
  attributes
- `exe=no` don’t run the codeblock (`cmd` won’t be executed)
- `inc="cbx:fcb cbx!csv cbx!csv:fcb"`
  - include the codeblock as-is in a new fenced codeblock, including its
    attributes
  - include the codeblock’s data after reading it as pandoc `-f csv`
    format which means the doc’s blocks are inserted
  - same, but put it inside a new fenced codeblock for which the doc is
    first serialized using its `native` output format.

````
``` {#csv .stitch inc="cbx:fcb cbx!csv cbx!csv:fcb" exe="no"}
opt,value,description
arg, "", cli-argument
exe, maybe, execute?
```
````

| opt | value | description  |
|-----|-------|--------------|
| arg |       | cli-argument |
| exe | maybe | execute?     |

```
[ Table
    ( "csv-3-cbx" , [] , [] )
    (Caption Nothing [])
    [ ( AlignDefault , ColWidthDefault )
    , ( AlignDefault , ColWidthDefault )
    , ( AlignDefault , ColWidthDefault )
    ]
    (TableHead
       ( "" , [] , [] )
       [ Row
           ( "" , [] , [] )
           [ Cell
               ( "" , [] , [] )
               AlignDefault
               (RowSpan 1)
               (ColSpan 1)
               [ Plain [ Str "opt" ] ]
           , Cell
               ( "" , [] , [] )
               AlignDefault
               (RowSpan 1)
               (ColSpan 1)
               [ Plain [ Str "value" ] ]
           , Cell
               ( "" , [] , [] )
               AlignDefault
               (RowSpan 1)
               (ColSpan 1)
               [ Plain [ Str "description" ] ]
           ]
       ])
    [ TableBody
        ( "" , [] , [] )
        (RowHeadColumns 0)
        []
        [ Row
            ( "" , [] , [] )
            [ Cell
                ( "" , [] , [] )
                AlignDefault
                (RowSpan 1)
                (ColSpan 1)
                [ Plain [ Str "arg" ] ]
            , Cell
                ( "" , [] , [] ) AlignDefault (RowSpan 1) (ColSpan 1) []
            , Cell
                ( "" , [] , [] )
                AlignDefault
                (RowSpan 1)
                (ColSpan 1)
                [ Plain [ Str "cli-argument" ] ]
            ]
        , Row
            ( "" , [] , [] )
            [ Cell
                ( "" , [] , [] )
                AlignDefault
                (RowSpan 1)
                (ColSpan 1)
                [ Plain [ Str "exe" ] ]
            , Cell
                ( "" , [] , [] )
                AlignDefault
                (RowSpan 1)
                (ColSpan 1)
                [ Plain [ Str "maybe" ] ]
            , Cell
                ( "" , [] , [] )
                AlignDefault
                (RowSpan 1)
                (ColSpan 1)
                [ Plain [ Str "execute?" ] ]
            ]
        ]
    ]
    (TableFoot ( "" , [] , [] ) [])
]
```

# Nested doc

As a final example, here’s how to run a codeblock’s output through a
filter after re-reading it as markdown. In this case, the filter is
stitch itself.

````` lua
```` {#nested .lua .stitch inc="cbx:fcb out!markdown@stitch" log="debug" cls="yes" hdr="1"}
#! /usr/bin/env lua

print [[---
author: nested
stitch:
  defaults:
    dir: ".stitch/readme/nested"
...

\newpage

# Nested report

This could be some report created by a command line tool, producing
a markdown report on some topic.  Here, it's just the text as printed
by lua.  Any (nested) codeblocks can also be processed by stitch.

```{#nd-csv .stitch inc="cbx!csv" log=debug exe=no}
day,count
mon,1
tue,2
```

## The weather today

```{#nd-temps .stitch inc="out"}
curl -sL 'https://api.open-meteo.com/v1/forecast?'\
'latitude=21.3069&longitude=-157.8583&hourly=temperature_2m&format=csv' \
| head -n 29 | tail -n +5 | sed 's/^[^T]*T//' \
|  uplot bar -d, -t "Temperature (˚C) Today" -o
```

\newpage

## Gnuplot again

```{#nd-gnu .gnuplot}
set terminal png
set dummy u,v
set key bmargin center horizontal Right noreverse enhanced autotitles nobox
set parametric
set view 50, 30, 1, 1
set isosamples 50, 20
set hidden3d back offset 1 trianglepattern 3 undefined 1 altdiagonal bentover
set ticslevel 0
set title "Interlocking Tori"
set urange [ -3.14159 : 3.14159 ] noreverse nowriteback
set vrange [ -3.14159 : 3.14159 ] noreverse nowriteback
splot cos(u)+.5*cos(u)*cos(v),sin(u)+.5*sin(u)*cos(v),.5*sin(v) with lines,\
1+cos(u)+.5*cos(u)*cos(v),.5*sin(v),sin(u)+.5*sin(u)*cos(v) with lines
```

## poor man's yaml

```{.lua #nd-yaml .chunk log=debug}
local ccb = Stitch.ccb
local ctx = Stitch.ctx
local fh = io.open(ccb.opt.out, 'w')
Stitch.log(ccb.oid, 'warn', 'logging from a chunk!')

fh:write('\nIn doc.meta\n---\nstitch:\n')
local yaml = Stitch.toyaml(ctx, 2)
fh:write(table.concat(yaml, "\n"))
-- defaults was "promoted" to metatable of ctx
yaml = Stitch.toyaml(ctx.defaults, 4)
if #yaml > 0 then
  fh:write("\n  defaults:\n")
  fh:write(table.concat(yaml, "\n"))
end
-- hardcoded
yaml = Stitch.toyaml(getmetatable(ctx.hard_coded).__index, 4)
if #yaml > 0 then
  fh:write("\n  hardcoded:\n")
  fh:write(table.concat(yaml, "\n"))
end

fh:write("\n...\n\n")
fh:write("codeblock opt:\n")
yaml = Stitch.toyaml(ccb.opt, 2)
fh:write("{\n", table.concat(yaml, "\n"), "\n}\n")

fh:write("\n...\n\n")
fh:write("state.meta\n")
yaml = Stitch.toyaml(Stitch.meta)
fh:write("{\n", table.concat(yaml, "\n"), "\n}\n")

fh:close()
```
]]
````
`````

## Nested report

This could be some report created by a command line tool, producing a
markdown report on some topic. Here, it’s just the text as printed by
lua. Any (nested) codeblocks can also be processed by stitch.

| day | count |
|-----|-------|
| mon | 1     |
| tue | 2     |

### The weather today

```
                  Temperature (˚C) Today
         ┌                                        ┐ 
   00:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 29.3   
   01:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 29.0   
   02:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 28.3    
   03:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 27.1      
   04:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 25.5       
   05:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 24.8        
   06:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 24.6        
   07:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 24.4         
   08:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 24.2         
   09:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 24.0         
   10:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 23.8         
   11:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 23.7         
   12:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 23.7         
   13:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■ 23.6          
   14:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■ 23.5          
   15:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■ 23.4          
   16:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■ 23.3          
   17:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■ 23.2          
   18:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 23.9         
   19:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 25.3        
   20:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 26.7      
   21:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 28.1    
   22:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 28.8    
   23:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 29.3   
   00:00 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 29.0   
         └                                        ┘ 
```

### Gnuplot again

``` gnuplot
set terminal png
set dummy u,v
set key bmargin center horizontal Right noreverse enhanced autotitles nobox
set parametric
set view 50, 30, 1, 1
set isosamples 50, 20
set hidden3d back offset 1 trianglepattern 3 undefined 1 altdiagonal bentover
set ticslevel 0
set title "Interlocking Tori"
set urange [ -3.14159 : 3.14159 ] noreverse nowriteback
set vrange [ -3.14159 : 3.14159 ] noreverse nowriteback
splot cos(u)+.5*cos(u)*cos(v),sin(u)+.5*sin(u)*cos(v),.5*sin(v) with lines,\
1+cos(u)+.5*cos(u)*cos(v),.5*sin(v),sin(u)+.5*sin(u)*cos(v) with lines
```

### poor man’s yaml

``` lua
local ccb = Stitch.ccb
local ctx = Stitch.ctx
local fh = io.open(ccb.opt.out, 'w')
Stitch.log(ccb.oid, 'warn', 'logging from a chunk!')

fh:write('\nIn doc.meta\n---\nstitch:\n')
local yaml = Stitch.toyaml(ctx, 2)
fh:write(table.concat(yaml, "\n"))
-- defaults was "promoted" to metatable of ctx
yaml = Stitch.toyaml(ctx.defaults, 4)
if #yaml > 0 then
  fh:write("\n  defaults:\n")
  fh:write(table.concat(yaml, "\n"))
end
-- hardcoded
yaml = Stitch.toyaml(getmetatable(ctx.hard_coded).__index, 4)
if #yaml > 0 then
  fh:write("\n  hardcoded:\n")
  fh:write(table.concat(yaml, "\n"))
end

fh:write("\n...\n\n")
fh:write("codeblock opt:\n")
yaml = Stitch.toyaml(ccb.opt, 2)
fh:write("{\n", table.concat(yaml, "\n"), "\n}\n")

fh:write("\n...\n\n")
fh:write("state.meta\n")
yaml = Stitch.toyaml(Stitch.meta)
fh:write("{\n", table.concat(yaml, "\n"), "\n}\n")

fh:close()
```
