---
id: stdlib
title: Standard Library
---

# Standard Library

Current standard library modules include:

- `sys`
- `fs`
- `test`
- `json`
- `html`
- `math`

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
json.encode({first_name = 'Ada'}, casing=json.camel)
```

```jaya
html = require('html')
b = html.Builder()
b.div(class='panel') do
  b.h1('Users')
end
print(b.s())
```
