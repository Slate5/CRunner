# CRunner

CRunner is a command for compiling, running, and testing C/C++ and Go files. There is no need for entering `gcc file.c` and then `./a.out` since CRunner does that in one step with `cr`.

## Installation

The program is tested on Ubuntu, Fedora, and Mint with GCC v7.5 or later and Bash v4.4 or later. Instruction:
```
git clone https://github.com/Slate5/CRunner.git
make -f CRunner/Makefile
```

## Usage

Use `cr` without providing source file (the last modified source file will be used), e.g. `cr -m64 -o output-file` or by specifying source file, e.g. `cr file.c -m64 -o output-file`.

For every option/flag, please check out the help text:\
`cr -h`

### Note about tab completion:

Primary CRunner uses tab completion according to the last modified file in the directory (e.g. if <i>file.go</i> is last modified file then `cr --<tab><tab>` will give the same result as `gccgo --<tab><tab>`), unless another type of source file is provided as an option (e.g. `cr file.c --<tab><tab>` is equivalent to `gcc file.c --<tab><tab>`).\
When specifying the source file, the best practice would be to put a file on the list of flags as soon as possible to ensure that the adequate compiler for tab completion is used.\
Everything else is explained in the help text.

Mint (v19.2 Cinnamon) supports only essential tab completion.

## Uninstallation

From CRunner directory: `make remove && cd`
