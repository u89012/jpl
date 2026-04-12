---
id: std-json
title: json
---

# `json`

`json` provides JSON encoding and decoding for the most common Jaya data shapes.

## `json.encode(value, casing = nil)`

Encodes a Jaya value as JSON text.

Arrays, hashes, strings, numbers, booleans, and `nil` are supported. If `casing` is provided, object keys are transformed recursively during encoding.

```jaya
json = require('json')
json.encode({first_name = 'Ada'}, casing=json.camelCase)
```

## `json.decode(text)`

Decodes JSON text into Jaya values.

Objects become hashes, arrays become arrays, and `null` becomes `nil`.

Requiring `json` also adds:
- `object.toJson()`
- `SomeClass.fromJson(value)`

Those helpers are loaded with the module rather than being present in the prelude by default.

## `json.snakeCase`

Key-transform option for `json.encode`.

Use this to convert object keys to `snake_case` during encoding.

## `json.camelCase`

Key-transform option for `json.encode`.

Use this to convert object keys to `camelCase` during encoding.

## `json.pascalCase`

Key-transform option for `json.encode`.

Use this to convert object keys to `PascalCase` during encoding.
