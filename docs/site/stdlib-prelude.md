---
id: stdlib-prelude
title: Prelude
---

# Prelude

The prelude is auto-included for normal programs.

Directly available helpers currently include:

- `print`
- `pp`
- `warn`
- `exit`
- `cwd`
- `argv`
- `getEnv`
- `sleep`

It also exposes the core type tokens and primitive method namespaces:

- `String`
- `Number`
- `Array`
- `Hash`
- `Bool`
- `Object`
- `Class`
- `Module`
- `Function`

Example:

```jaya
print(cwd())
sleep(1)
'hello'.startsWith('he')
```
