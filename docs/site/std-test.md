---
id: std-test
title: test
---

# `test`

`test` provides helpers used by Jaya test files.

## `test.assertEq(actual, expected)`

Asserts that two values are equal.

Use this for the most common test expectation when you want a direct value comparison.

## `test.assertNil(value)`

Asserts that a value is `nil`.

This is useful when checking missing fields, absent results, or optional values.

## `test.compileAndLoad(source, filename = '<test>')`

Compiles Jaya source text and returns the loaded module.

This is especially useful for compiler, macro, and module-loading tests where the source under test is generated inline.

In `.t` files, common test helpers are also auto-bound without the `test.` prefix.
