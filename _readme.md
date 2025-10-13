---
author: hertogp <git.hertogp@gmail.com>
title: stitch
stitch:
  defaults:
    out: stdout
    mix: ast
  boxes:
    cli: 'boxes'
    arg: [-d, peek, -p, h2v1}
ins: cb:ocb,stdout:fcb,stderr:fcb
...
```
Examples from imagine

'asy -o <fname>.{im_fmt} {im_opt} <fname>.asy'

'boxes {im_opt} <fname>.boxes'

'{im_prg} {im_opt} -T {im_fmt} <fname>.{im_fmt} -o <fname>.{im_prg}' -- blockdiag

'ctioga2 {im_opt} -f <fname>.ctioga2'

'ditaa <fname>.ditaa <fname>.{im_fmt} {im_opt}'

'figlet {im_opt} < code-text'

'flydraw {im_opt} < code-text' -->> graphical data on stdout

'gle {im_opt} -verbosity 0 -output <fname>.{im_fmt} <fname>.gle'

'gnuplot {im_opt} <fname>.gnuplot > <fname>.{im_fmt}'

'graph -T png {im_opt} <fname>.graph'

'gri {im_opt} -c 0 -b <fname>.gri'

'mmdc -i <fname>.mermaid -o <fname>.<fmt> {im_opt}'

'mscgen -T {im_fmt} -o <fname>.{im_fmt} <fname>.mscgen'

'octave --no-gui -q {im_opt} <fname>.octave <fname>.{im_fmt}'

'pic2plot -T png {im_opt} <fname>.pic2plot'

'plantuml -t{im_fmt} <fname>.plantuml {im_opt}'

'plot -T {im_fmt} {im_opt} <code-text-as-filename>'

'ploticus -{im_fmt} -o <fname>.{im_fmt} {im_opt} <fname>.ploticus'

'protocol {im_opt} code-text'

'pyxplot {im_opt} <fname>.pyxplot'

'<fname>.shebang {im_opt} <fname>.{im_fmt}'

'{im_prg} {im_opt} -T{im_fmt} <fname>.{im_prg} <fname>.{im_fmt}'

-- params are available in cmd template string:

cmd=boxes -d peek -h2v1 {cb} // added if available: 1>{out} 2>{err}
   * out available -> included in doc
   * err available -> included in doc

cmd={prg} .. {arg} 2>{stderr} -T{fmt} 1>{stdout} .. etc ..

cmd={prg} .. {arg} 2>{err} 1>{out} ...
   * ""==prg -> replaced by stitch to dir/id-hash.cb
   * stderr/stdout = dir/id-hash.std{err, out}
   * always read stdout, if needed replaced by reading {stdout}
   * read {stderr} is needed
   * {outfile} when an output file is required
   - these are used in ins (or doc?)

ins = {file}:{mimetype}:{inclusion}
   * mimetype is fromtype to convert to pandoc's AST
   * inclusion can be:
     - para,
     - {f,v,i}cb, fenced, verbatim, indented code block
     - bq block quotation
     - img, ...?


-- static
   * opts keys

-- dynamic:
   * cb = dir/id-hash.fmt (codeblock on disk)








```

```lua
-- hardcoded
 cfg = "" -- this codeblock's config in doc.meta.stitch.<cfg> (if any)
 cmd = "" -- program name to process cb, "" means execute cb itself
 arg = {} -- arguments to pass in to `cmd`-program on the cli (if any)
 dir = ".stitch" -- where to store files (abs/rel path to cwd)
 fmt = "png" -- format for images (if any)
 inp = "" -- input file to process (if any)
 log = 0 -- log notification level
 ins = { "img", "fcb" } -- what to output to new document

--- dynamic
 sha1 = "sha1 hash of option values + cb.text (w/o wspace)"
 exec = "command as handed to popen" -- cmd + args + inp? +out?
 inpf = "inp file" -- if any
 outf = "out file" -- if any, is dir/sha.fmt
 msgs = {} -- stack of error msgs (if any)

-- how to enable filenames in command string to execute?
-- *
-- cmd = {exe} 1>{dir}/{id}-{sha}.stdout 2>{err} -i {inp} -o {out}
-- out = {dir}/{id}-{hash}.{fmt}
-- inp = {dir}/{id}-{hash}.cb
```

# stitch

```{#id .stitch cfg=boxes out: ocb,stdout}
figlet stitch | boxes -d ian_jones -p h2v1
```

A codeblock is processed by:
- executing it as a script, or
- running it through an external tool

whose arguments may:
- point to stdin to read from (only cb.text)
- point to a file on disk/url (e.g. the cb.text saved on disk)
- or simply specify options to the program (e.g. -d peek)

and signal success or failure through it's exit code

and may produce output on one or more of:
- stdout: binary or text in some format (e.g. markdown, png, etc..)
- stderr: binary or text in some format (e.g. json, svg, etc..)
- file  : file on disk in some format (e.g. markdown, png etc..)

and those outputs can be included into pandoc's AST:
- as an image link to a file produced
- as text, possibly converted from some format to pandoc's AST)
- as text in a qouted block or in a (fenced) codeblock

either as a new Para or inserted in its containing Para.

and the original codeblock can be either replaced or retained
(if retained, stitch class & attributes are removed)

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
* lua can't read stderr directly
  you'll need to redirect it to a file (dir/hash.err.txt)
* io.popen("cmd 1><hash>.stdout 2>dir/<hash>.stderr") -> filehandle
  - redir stderr to file (only way to capture that)
  - redir stdout to file (for debugging, reading the filehandle is pointless)
  - convert file from -f ...
    * parse possibly formatted text into pandoc AST and include that in the document, or
    * output to some format and link to it (e.g. using an include)


  Examples
  > io.popen("ls asfasf 2>err.txt"):read('a') -- reads stdout
  > io.open("err.txt"):read("a") -> err text  -- reads stderr, redirected "" == ok
  >
  > io.popen("{cmd} dir/{hash}.cb dir/{hash}.{fmt} 1>dir/hash.stdout 2>dir/hash.stderr")
  > call cmd and:
  > * feed it the cb (may not need it)
  > * feed it a target output file
  > * redir stdout
  > * redir stderr
  > => now you can process the relevant files
  >
  > io.popen("{cmd} dir/{hash}.cb dir/{hash}.{fmt} 2>dir/hash.stderr"):read('a')
  > * same but read stdout directly instead of redir

* os.execute
  - os.execute() -- returns true if a shell is available
  - runs the command, returns true/fail (exit <exit-status> | signal <signal-nr>)

* pandoc.mediabag.fetch(..) -> mt, contents = mediatype, contents
  - mediatype is guessed/taken from the file's extension
  - mediabag module can also create image links


doc: "stdout:markdown, stderr:txt, link:png"
stdout: text/markdown
cb:


stdout:md,para
file:md:,para



