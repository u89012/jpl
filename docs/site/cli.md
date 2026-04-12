---
id: cli
title: CLI
---

# CLI

Jaya currently ships with a compiler, runtime entrypoint, test runner, and REPL.

## REPL

```bash
./jpl
```

## Run a File

```bash
./jpl app.jpl
```

## Load Into the REPL

```bash
./jpl --i app.jpl
```

## Run Tests

```bash
./jpl --t
./jpl --t tests/std/modules.t
```

## Print Generated Lua

```bash
./jpl --lua app.jpl
```

## Print the AST

```bash
./jpl --ast app.jpl
```

## Compile to Lua Bytecode

```bash
./jpl --luac app.jpl
lua luac.out
```
