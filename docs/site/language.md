---
id: language
title: Language Basics
---

# Language Basics

## Functions

```jaya
export fn add(x, y) = x + y
```

```jaya
export fn greet(name, title = 'Mx')
  return "#{title} #{name}"
end
```

Functions can accept blocks with `&blk` and invoke them with `yield(...)`.

If no block is given, `yield(...)` returns `nil` instead of raising an error. That makes fallback patterns like this work cleanly:

```jaya
export fn greet(name, title = 'Mx', **opts, &blk)
  prefix = opts.prefix || ''
  label = prefix + title + ' ' + name
  return yield(label) or label
end

greet(name='Ada')
greet(name='Ada') do |label|
  return label + '!'
end
```

## Classes

```jaya
export class User(name, age)
  greet() = "hi #{self.name}"
end
```

## Control Flow

```jaya
if ready
  print('go')
elsif fallback
  print('fallback')
else
  print('wait')
end
```

```jaya
unless failed
  print('ok')
end
```

```jaya
case value
when 1
  return 'one'
when 2, 3
  return 'many'
else
  return 'other'
end
```

## Pattern Matching

```jaya
match value
when User(_, age)
  return age
when User()
  return 'user'
else
  return 'other'
end
```

## Strings

```jaya
name = 'Ada'
line = "Hello #{name}"
text = """
Hello #{name}
Line 2
"""
```

## Arrays and Hashes

```jaya
items = [1, 2, 3]
user = {name = 'Ada', age = 9}
```

Jaya supports negative indexing and slicing for arrays and strings:

```jaya
items[-1]
items[2..-1]
'Jaya'[1...-1]
```
