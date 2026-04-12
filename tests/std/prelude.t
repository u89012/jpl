fn testPreludeStringMethodsWork()
  src = """
export fn probe()
  return [
    '  Ada  '.trim(),
    'hello'.startsWith('he'),
    'hello'.startsWith('zz'),
    'Ada'.upcase(),
    'ADA'.downcase(),
    ''.empty(),
    'Ada'.size(),
    'hello'.includes('ell'),
    'hello'.endsWith('lo'),
    'user_name'.camel(),
    'userName'.snake(),
    'user_name'.pascal(),
    '  MiXeD  '.trim().upcase().downcase(),
    'Ada'[-1],
    'Jaya'[2..-2],
    'Jaya'[1...-1]
  ]
end
"""
  mod = compileAndLoad(src)
  out = mod.probe()
  assertEq(out[1], 'Ada')
  assertEq(out[2], true)
  assertEq(out[3], false)
  assertEq(out[4], 'ADA')
  assertEq(out[5], 'ada')
  assertEq(out[6], true)
  assertEq(out[7], 3)
  assertEq(out[8], true)
  assertEq(out[9], true)
  assertEq(out[10], 'userName')
  assertEq(out[11], 'user_name')
  assertEq(out[12], 'UserName')
  assertEq(out[13], 'mixed')
  assertEq(out[14], 'a')
  assertEq(out[15], 'ay')
  assertEq(out[16], 'Jay')
end
fn testPreludeNumberMethodsWork()
  src = """
export fn probe()
  seen = []
  count = 3
  count.times() do |i|
    seen[#seen + 1] = i
  end
  rangeSeen = []
  for i in 1..3
    rangeSeen[#rangeSeen + 1] = i
  end
  return [
    (-7).abs(),
    10.clamp(1, 5),
    1.2.floor(),
    1.2.ceil(),
    1.6.round(),
    (-1.6).i(),
    4.f(),
    10.s(),
    10.s('octal'),
    10.s('hex'),
    10.s('binary'),
    0.zero(),
    4.positive(),
    (-2).negative(),
    4.between(1, 5),
    4.incr(),
    4.incr(3),
    4.decr(),
    4.decr(2),
    seen[1],
    seen[2],
    seen[3],
    rangeSeen[1],
    rangeSeen[2],
    rangeSeen[3]
  ]
end
"""
  mod = compileAndLoad(src)
  out = mod.probe()
  assertEq(out[1], 7)
  assertEq(out[2], 5)
  assertEq(out[3], 1)
  assertEq(out[4], 2)
  assertEq(out[5], 2)
  assertEq(out[6], -1)
  assertEq(out[7], 4.0)
  assertEq(out[8], '10')
  assertEq(out[9], '12')
  assertEq(out[10], 'a')
  assertEq(out[11], '1010')
  assertEq(out[12], true)
  assertEq(out[13], true)
  assertEq(out[14], true)
  assertEq(out[15], true)
  assertEq(out[16], 5)
  assertEq(out[17], 7)
  assertEq(out[18], 3)
  assertEq(out[19], 2)
  assertEq(out[20], 0)
  assertEq(out[21], 1)
  assertEq(out[22], 2)
  assertEq(out[23], 1)
  assertEq(out[24], 2)
  assertEq(out[25], 3)
end
fn testArrayIndexingSlicingAndHelpersWork()
  src = """
export fn probe()
  values = [10, 20, 30, 40]
  pushed = []
  pushed.push(1).push(2).push(3)
  mapped = values.map(fn(x) = x + 1)
  filtered = values.filter(fn(x) = x >= 30)
  popped = pushed.pop()
  return [
    values.first(),
    values.last(),
    values[-1],
    values[2..-2].join(','),
    values[1...-1].join(','),
    values.size(),
    values.empty(),
    values.includes(30),
    mapped.join(','),
    filtered.join(','),
    popped,
    pushed.join(','),
    values.slice(2, -2).join(',')
  ]
end
"""
  mod = compileAndLoad(src)
  out = mod.probe()
  assertEq(out[1], 10)
  assertEq(out[2], 40)
  assertEq(out[3], 40)
  assertEq(out[4], '20,30')
  assertEq(out[5], '10,20,30')
  assertEq(out[6], 4)
  assertEq(out[7], false)
  assertEq(out[8], true)
  assertEq(out[9], '11,21,31,41')
  assertEq(out[10], '30,40')
  assertEq(out[11], 3)
  assertEq(out[12], '1,2')
  assertEq(out[13], '20,30')
end
fn testForKeyValueInHashWorks()
  src = """
export fn probe()
  items = {name = 'Ada', age = 9}
  seen = {}
  for key, value in items
    seen[key] = value
  end
  return [seen.name, seen.age]
end
"""
  mod = compileAndLoad(src)
  out = mod.probe()
  assertEq(out[1], 'Ada')
  assertEq(out[2], 9)
end
fn testPreludeHashMethodsWork()
  src = """
export fn probe()
  data = {name = 'Ada', age = 9}
  keys = data.keys()
  values = data.values()
  merged = data.merge({age = 10, lang = 'Jaya'})
  return [
    data.size(),
    data.empty(),
    data.has('name'),
    data.fetch('name'),
    data.fetch('missing', 'fallback'),
    keys.includes('name') && keys.includes('age'),
    values.includes('Ada') && values.includes(9),
    merged.age,
    merged.lang
  ]
end
"""
  mod = compileAndLoad(src)
  out = mod.probe()
  assertEq(out[1], 2)
  assertEq(out[2], false)
  assertEq(out[3], true)
  assertEq(out[4], 'Ada')
  assertEq(out[5], 'fallback')
  assertEq(out[6], true)
  assertEq(out[7], true)
  assertEq(out[8], 10)
  assertEq(out[9], 'Jaya')
end
fn testPreludeBoolMethodsWork()
  src = """
export fn probe()
  yes = true
  no = false
  return [
    yes.s(),
    no.s(),
    yes.negate(),
    no.negate(),
    yes.andAlso(no),
    no.orElse(yes),
    yes.xor(no),
    no.xor(no)
  ]
end
"""
  mod = compileAndLoad(src)
  out = mod.probe()
  assertEq(out[1], 'true')
  assertEq(out[2], 'false')
  assertEq(out[3], false)
  assertEq(out[4], true)
  assertEq(out[5], false)
  assertEq(out[6], true)
  assertEq(out[7], true)
  assertEq(out[8], false)
end
fn testPreludePrimitiveTypeTokensExist()
  src = """
export fn probe()
  return [sys != nil, Object != nil, String != nil, Number != nil, Bool != nil, Array != nil, Hash != nil, Class != nil, Module != nil, Function != nil]
end
"""
  mod = compileAndLoad(src)
  out = mod.probe()
  assertEq(out[1], true)
  assertEq(out[2], true)
  assertEq(out[3], true)
  assertEq(out[4], true)
  assertEq(out[5], true)
  assertEq(out[6], true)
  assertEq(out[7], true)
  assertEq(out[8], true)
  assertEq(out[9], true)
  assertEq(out[10], true)
end
fn testPreludeSysModuleAndAliasesWork()
  src = """
export fn probe()
  args = argv()
  shown = pp([1, {name = 'Ada'}])
  return [
    sys.host(),
    sys.version().startsWith('Lua'),
    sys.platform() != nil,
    sys.cwd().size() > 0,
    getEnv('PWD') != nil,
    args != nil,
    print == sys.print,
    pp == sys.pp,
    warn == sys.warn,
    exit == sys.exit,
    cwd == sys.cwd,
    shown[1],
    shown[2].name
  ]
end
"""
  mod = compileAndLoad(src)
  out = mod.probe()
  assertEq(out[1], 'lua')
  assertEq(out[2], true)
  assertEq(out[3], true)
  assertEq(out[4], true)
  assertEq(out[5], true)
  assertEq(out[6], true)
  assertEq(out[7], true)
  assertEq(out[8], true)
  assertEq(out[9], true)
  assertEq(out[10], true)
  assertEq(out[11], true)
  assertEq(out[12], 1)
  assertEq(out[13], 'Ada')
end
