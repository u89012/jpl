---
id: stdlib
title: Standard Library
---

# Standard Library

Current standard library modules include:

- `sys`
- `fs`
- `test`
- `string`
- `number`
- `array`
- `hash`
- `bool`
- `object`
- `class`
- `module`
- `function`
- `json`
- `html`
- `math`
- `inflector`

Core prelude-backed types include:

- `String`
- `Number`
- `Array`
- `Hash`
- `Bool`
- `Object`
- `Class`
- `Module`
- `Function`

Examples:

```jaya
'  Ada  '.trim().upcase()
[1, 2, 3].size()
10.s('hex')
```

```jaya
json = require('json')
json.encode({first_name = 'Ada'}, casing=json.camelCase)
```

```jaya
html = require('html')
b = html.Builder()
b.div(class='panel') do
  b.h1('Users')
end
print(b.s())
```

Each stdlib module now has its own reference page in the sidebar under
`Standard Library -> Modules`.
