# Pasta
> This is why we have high level languages...

This is the x86-64 assembly version of my [other](https://github.com/insomnimus/pasta) project.

## What Does It Do?
It reads data from the stdin  or the clipboard and sends it to notepad.

It will open a new notepad window if none is open; if one is open, it will focus to it and replace its buffer instead.
> The new Win 11 notepad won't work with this; I don't use it so I didn't handle it. However all it needs is small adjustments (the edit window name is no longer simply "Edit".)

## Usage
You can use this 2 ways.

```powershell
# Read from stdin
cat readme.md | pasta
# If you don't pipe, it reads your clipboard instead.
pasta
```

## How to Assemble
The project makes use of [flat-assembler](https://flatassembler.net) syntax and macros, so go get it.

Make sure to set `$INCLUDE` environment variable to the `fasm` include dir.
(flat-assembler comes with an include directory for macros etc...)

Then, assemble it with:

```powershell
fasm pasta.asm -d config=release
```

> It compiles to exactly 6 KiB!
