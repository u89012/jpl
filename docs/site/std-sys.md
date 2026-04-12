---
id: std-sys
title: sys
---

# `sys`

`sys` provides host and runtime boundary helpers. These functions are the lowest-level bridge to the execution environment.

## `sys.host()`

Returns the name of the current host runtime.

At the moment this returns `'lua'`.

## `sys.version()`

Returns the host runtime version string.

This is typically the Lua version reported by `_VERSION`.

## `sys.platform()`

Returns a short platform tag for the current system.

The current implementation returns either `'windows'` or `'posix'`.

## `sys.cwd()`

Returns the current working directory.

Jaya uses the host environment first and falls back to a shell probe if needed.

## `sys.argv()`

Returns the process arguments as a Jaya array.

If no arguments are available, it returns an empty array.

## `sys.getEnv(name, fallback = nil)`

Returns the value of an environment variable.

If the variable is not set, the fallback value is returned instead.

## `sys.sleep(seconds)`

Pauses execution for the given number of seconds.

If `seconds` is `nil` or less than or equal to `0`, it returns immediately.

## `sys.print(...)`

Prints values to standard output.

This is the same basic output helper exposed directly in the prelude as `print(...)`.

## `sys.pp(value)`

Pretty-prints a value and returns it unchanged.

This is useful while debugging arrays, hashes, and nested structures.

## `sys.warn(value)`

Prints a warning-style value to standard error.

It appends a newline after the value.

## `sys.eprint(value)`

Prints a value to standard error.

This is similar to `warn`, but kept available as an explicit stderr-oriented print helper.

## `sys.exit(code = 0)`

Terminates the current process with the given exit code.

Use this when a script or tool needs to stop with a specific success or failure status.

## `sys.panic(message)`

Raises an immediate runtime error.

This is the lowest-level failure helper in the current `sys` surface.
