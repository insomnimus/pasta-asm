# Pasta
> This is why we have high level languages...

This is the x86-64 assembly version of my [other](https://github.com/insomnimus/pasta) project.

> I've decided to improve the program and couldn't bother adding some of the new features in assembly (all the interesting bits are still in assembly, the rust code only adds config file and cli args parsing) so the later additions add rust to the mix; you can however still compile the pure assembly version with `fasm pasta_basic.asm`.

## What Does It Do?
It reads data from the stdin  or the clipboard and sends it to an editor (by default, Notepad.)

It will open a new editor window if none is open; if one is open, it will focus to it and replace its buffer instead.

## Usage
If you didn't build the new version and went with the pure-assembly program, you can use it 2 ways:

```powershell
# Read from stdin
cat readme.md | pasta
# If you don't pipe, it reads your clipboard instead.
pasta
```

If you've built the improved version, you can also specify a different editor in the config file.
The file is named the same as the executable but with a `.ini` extension instead (put it next to it!)

```
# paste the clipboard to notepad++
pasta -e notepad++
# you can also pipe to it
cat readme.md | pasta -e notepad++
# this will always launch a new instance
pasta -n
```

## How to Assemble (pure-assembly version)
> You probably want the improved version instead; instructions are given after this.

The project makes use of [flat-assembler](https://flatassembler.net) syntax and macros, so go get it.

Make sure that the `$INCLUDE` environment variable contains the `fasm` include dir.
(flat-assembler comes with an include directory for macros etc...)

Then, assemble it with:

```powershell
fasm pasta_basic.asm -d config=release
```

> It compiles to exactly 6 KiB!

## How to Assemble (improved version)
On top of flat-assembler, you'll need to have `rust`, `clang` and a version of Visual Studio (or Visual Studio Build Tools) installed.

You can install `clang` with [scoop](https://github.com/ScoopInstaller/scoop):\
`scoop install llvm`

- Open `X64 Native Tools Powershell for VS<version>`.
- Add flat-assembler's include directory to the `$INCLUDE` env variable; e.g `$env:INCLUDE += ";D:\programs\fasm\include"`
- Run the build script in the root of this project: `./build.ps1`
