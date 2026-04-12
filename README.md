# Jaya

Jaya is a class-based programming language with its own compiler, CLI, standard
library, test runner, and documentation site.

The project currently includes:

- a REPL
- file execution
- macros with compile-time execution
- classes, inheritance, and visibility
- pattern matching
- JSON and HTML stdlib modules
- a Docusaurus documentation site under [`docs/`](/Users/a/Downloads/lua-5.4.7/docs)

## Quick Start

Prerequisites:

- Git
- Lua 5.4

Fetch the project:

```bash
git clone https://github.com/example/jaya.git
cd jaya
chmod +x jpl
```

Start the REPL:

```bash
./jpl
```

Run a file:

```bash
./jpl app.jpl
```

Run the test suite:

```bash
./jpl --t
```

## Common Commands

```bash
./jpl                 # start the REPL
./jpl file.jpl        # compile and run a file
./jpl --i file.jpl    # preload a file, then enter the REPL
./jpl --t             # run all tests
./jpl --t tests/std/modules.t
./jpl --lua file.jpl  # print generated output
./jpl --ast file.jpl  # print the parsed AST
./jpl --luac file.jpl # compile to luac.out
```

## Project Layout

- `jpl`
  Executable launcher.
- `src/jpl.lua`
  Compiler, runtime helpers, CLI, and test runner.
- `src/std/`
  Standard library modules and prelude.
- `tests/`
  Language and stdlib test suites.
- `docs/`
  Docusaurus site and documentation source.

## Documentation

The docs site lives in `docs/`.

Start the docs dev server:

```bash
cd docs
npm install
npm run start
```

Build the static docs site:

```bash
cd docs
npm run build
```

The generated static site is written to `docs/build/`.

## Current Status

Jaya is already usable for experimentation and internal tooling, but it is still
an actively evolving language. The implementation, standard library, and
documentation are being built together.
