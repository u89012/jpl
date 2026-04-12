---
id: modules
title: Modules, require, and include
---

# Modules, require, and include

Jaya has two related mechanisms:

- `require(...)` for loading a module namespace
- `include(...)` for compile-time splicing into the current module

## require

```jaya
json = require('json')
text = json.encode({name = 'Ada'})
```

## include

`include` is compile-time and behaves like include-once by resolved path.

```jaya
include('./shared')

export fn answer()
  return helper() + 1
end
```

`include` is useful for:

- splitting one logical module across files
- sharing macros
- assembling stdlib modules internally
