---
id: testing
title: Testing
---

# Testing

Jaya test files use the `.t` suffix.

Run all tests:

```bash
./jpl --t
```

Run one test file:

```bash
./jpl --t tests/std/modules.t
```

Inside `.t` files, the `test` module is auto-bound and common helpers are available without a prefix:

- `assertEq(...)`
- `assertNil(...)`
- `compileAndLoad(...)`

Example:

```jaya
fn testAddsNumbers()
  mod = compileAndLoad("export fn add(x, y) = x + y")
  assertEq(mod.add(2, 3), 5)
end
```
