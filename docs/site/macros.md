---
id: macros
title: Macros
---

# Macros

Macros execute at compile time.

Quoted forms build syntax explicitly:

```jaya
macro inc(x) = _q(_u(x) + 1)
```

Block macros can execute compile-time code and return multiple forms:

```jaya
macro deftags(*names)
  out = []
  for name in names
    out[#out + 1] = _q(
      macro name(*children, **attrs, &body) = _q(
        tag(_u(name), attrs, children, body)
      )
    )
  end
  return out
end
```

Helper forms:

- `quote(...)` / `_q(...)`
- `unquote(...)` / `_u(...)`
- `splice(...)` / `_s(...)`
