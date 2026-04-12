---
id: getting-started
title: Getting Started
---

# Getting Started

For now, the easiest way to install Jaya is to install the runtime dependency, fetch the latest source from GitHub, and run the local launcher.

## Prerequisites

Install:

- Git
- Lua 5.4

## Fetch Jaya

```bash
git clone https://github.com/example/jaya.git
cd jaya
chmod +x jpl
```

The current entrypoint is:

```bash
./jpl
```

Useful commands:

```bash
./jpl                 # start the REPL
./jpl file.jpl        # compile and run a file
./jpl --i file.jpl    # load a file, then enter the REPL
./jpl --t             # run tests
./jpl --lua file.jpl  # print generated output
./jpl --ast file.jpl  # print the parsed AST
./jpl --luac file.jpl # compile to luac.out
```

A minimal file:

```jaya
export fn greet(name)
  return "Hello #{name}"
end
```
