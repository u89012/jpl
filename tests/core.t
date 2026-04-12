fs = require('fs')

state = nil

class User(name, age) end

fn before()
  state = []
end

fn beforeTest()
  state[#state + 1] = 'before'
end

fn afterTest()
  state[#state + 1] = 'after'
end

fn testCompilerCompilesAndRunsModule()
  mod = compileAndLoad("export fn add(x, y) = x + y")
  assertEq(mod.add(2, 3), 5)
end
fn testExportsAndRequireLoadSiblingModules()
  dir = '/tmp/jpl_feature_modules'
  os.execute('mkdir -p ' + dir)
  fs.writeFile(dir + '/math.jpl', """
export fn add(x, y) = x + y
""")
  fs.writeFile(dir + '/main.jpl', """
math = require('./math')
export answer = math.add(20, 22)
""")
  mod = compileAndLoad(fs.readFile(dir + '/main.jpl'), dir + '/main.jpl')
  assertEq(mod.answer, 42)
end
fn testImplicitRequireBindsCamelizedModuleName()
  dir = '/tmp/jpl_feature_modules_implicit'
  os.execute('mkdir -p ' + dir)
  fs.writeFile(dir + '/math_utils.jpl', """
export fn add(x, y) = x + y
""")
  fs.writeFile(dir + '/main.jpl', """
require('./math_utils')
export answer = mathUtils.add(20, 22)
""")
  mod = compileAndLoad(fs.readFile(dir + '/main.jpl'), dir + '/main.jpl')
  assertEq(mod.answer, 42)
end
fn testIncludeSplicesIntoCurrentModuleAndSkipsDuplicates()
  dir = '/tmp/jpl_feature_includes'
  os.execute('mkdir -p ' + dir)
  fs.writeFile(dir + '/shared.jpl', """
fn helper() = 41
""")
  fs.writeFile(dir + '/main.jpl', """
include('./shared')
include('./shared')
export fn answer() = helper() + 1
""")
  mod = compileAndLoad(fs.readFile(dir + '/main.jpl'), dir + '/main.jpl')
  assertEq(mod.answer(), 42)
end
fn testDefaultArgsAndNamedArgsWorkTogether()
  src = """
export fn greet(name, title = 'Mx') = title + ' ' + name
"""
  mod = compileAndLoad(src)
  assertEq(mod.greet(title='Dr', name='Ada'), 'Dr Ada')
end
fn testConstBindingsWork()
  src = """
export fn probe()
  const answer = 41
  return answer + 1
end
"""
  mod = compileAndLoad(src)
  assertEq(mod.probe(), 42)
end
fn testConstReassignmentFailsAtCompileTime()
  ok, err = pcall(fn()
    compileAndLoad("""
export fn probe()
  const answer = 41
  answer = 42
  return answer
end
""")
  end)
  assert(ok == false)
  assert(string.find(err, 'cannot reassign const: answer') != nil)
end
fn testArrayAndTableLiteralsWork()
  src = """
export fn probe()
  values = [1, 2, 3]
  info = {name = 'Ada', age = 9}
  return [values[2], info.name, info.age]
end
"""
  mod = compileAndLoad(src)
  out = mod.probe()
  assertEq(out[1], 2)
  assertEq(out[2], 'Ada')
  assertEq(out[3], 9)
end
fn testStringInterpolationWorks()
  src = 'export fn probe(name, count)\n' +
    '  return "Hello #{name}: #{count}"\n' +
    'end\n'
  mod = compileAndLoad(src)
  assertEq(mod.probe('Ada', 3), 'Hello Ada: 3')
end
fn testTripleQuotedInterpolationWorks()
  src = 'export fn probe(name)\n' +
    '  return """Hello #{name}\n' +
    'Line 2\n' +
    '"""\n' +
    'end\n'
  mod = compileAndLoad(src)
  assertEq(mod.probe('Ada'), "Hello Ada\nLine 2\n")
end
fn testIfAndUnlessWork()
  src = """
export fn probe(a, b)
  out = []
  if a
    out[#out + 1] = 'if'
  end
  unless b
    out[#out + 1] = 'unless'
  end
  return out
end
"""
  mod = compileAndLoad(src)
  out = mod.probe(true, false)
  assertEq(out[1], 'if')
  assertEq(out[2], 'unless')
end
fn testCaseWhenElseWorks()
  src = """
export fn probe(v)
  case v
  when 1
    return 'one'
  when 2, 3
    return 'many'
  else
    return 'other'
  end
end
"""
  mod = compileAndLoad(src)
  assertEq(mod.probe(1), 'one')
  assertEq(mod.probe(3), 'many')
  assertEq(mod.probe(9), 'other')
end
fn testCaseSingleBranchElseWorks()
  src = """
export fn probe(v)
  case v
  when 1
    return 'one'
  else
    return 'other'
  end
end
"""
  mod = compileAndLoad(src)
  assertEq(mod.probe(1), 'one')
  assertEq(mod.probe(2), 'other')
end
fn testLetAndIfLetBindValues()
  src = """
export fn probe(v)
  let x = 10, y = 20
    total = x + y
    if let item = v
      return total + item
    else
      return total
    end
  end
end
"""
  mod = compileAndLoad(src)
  assertEq(mod.probe(5), 35)
  assertEq(mod.probe(nil), 30)
end
fn testMatchSupportsClassOnlyAndWildcardField()
  value = User('Ada', 9)
  result = nil
  match value
  when User(_, age)
    result = age
  else
    result = 0
  end
  assertEq(result, 9)
end
fn testMatchSupportsClassOnlyForm()
  result = nil
  match User('Ada', 9)
  when User()
    result = 'user'
  else
    result = 'other'
  end
  assertEq(result, 'user')
end
fn testClassesInheritanceAccessorsAndSuperWork()
  src = """
export class Base(name)
  get label() = name
  greet() = 'hi ' + name
end

export class Child(name, age) extends Base
  get years() = age
  set years(value)
    age = value
  end
  greet() = super.greet() + '!'
end
"""
  mod = compileAndLoad(src)
  child = mod.Child('Ada', 9)
  assertEq(child.label, 'Ada')
  assertEq(child.greet(), 'hi Ada!')
  assertEq(child.years, 9)
  child.years = 10
  assertEq(child.years, 10)
end
fn testMultipleInheritanceLooksUpMethodsAcrossBases()
  src = """
class A()
  a() = 'a'
end
class B()
  b() = 'b'
end
export class C() extends A, B
end
export fn probe()
  c = C()
  parents = C.parents()
  return [c.a(), c.b(), parents[1].name(), parents[2].name()]
end
"""
  mod = compileAndLoad(src)
  out = mod.probe()
  assertEq(out[1], 'a')
  assertEq(out[2], 'b')
  assertEq(out[3], 'A')
  assertEq(out[4], 'B')
end
fn testStaticAccessorsWork()
  src = """
export class Counter()
  static get total() = total
  static set total(value)
    total = value
  end
end
"""
  mod = compileAndLoad(src)
  mod.Counter.total = 7
  assertEq(mod.Counter.total, 7)
  mod.Counter.total = 12
  assertEq(mod.Counter.total, 12)
end
fn testSafeNavigationWorks()
  src = """
export fn probe(user)
  return [user?.profile?.name, user?.missing?.name]
end
"""
  mod = compileAndLoad(src)
  out = mod.probe({ profile = { name = 'Ada' } })
  assertEq(out[1], 'Ada')
  assertNil(out[2])
end
fn testTryCatchFinallyAndThrowWork()
  src = """
export fn probe()
  out = []
  try
    throw 'boom'
  catch
    out[#out + 1] = it
  finally
    out[#out + 1] = 'done'
  end
  return out
end
"""
  mod = compileAndLoad(src)
  out = mod.probe()
  assertEq(out[1], 'boom')
  assertEq(out[2], 'done')
end
fn testTypedCatchWithMultipleTypesWorks()
  src = """
class Boom() end
class Bang() end
export fn probe(flag)
  out = nil
  try
    if flag
      throw Boom()
    else
      throw Bang()
    end
  catch Boom, Bang
    out = it.__class.__name
  end
  return out
end
"""
  mod = compileAndLoad(src)
  assertEq(mod.probe(true), 'Boom')
  assertEq(mod.probe(false), 'Bang')
end
fn testGoRunsWork()
  src = """
export fn probe()
  fn push(out)
    out[#out + 1] = 'ran'
  end
  out = []
  go push(out)
  return out[1]
end
"""
  mod = compileAndLoad(src)
  assertEq(mod.probe(), 'ran')
end
fn testWhileBreakAndContinueWork()
  src = """
export fn probe()
  i = 0
  out = []
  while i < 6
    i = i + 1
    continue if i == 2
    break if i == 5
    out[#out + 1] = i
  end
  return out
end
"""
  mod = compileAndLoad(src)
  out = mod.probe()
  assertEq(out[1], 1)
  assertEq(out[2], 3)
  assertEq(out[3], 4)
  assertNil(out[4])
end
fn testContinueWorksInForInLoops()
  src = """
export fn probe()
  out = []
  for item in [1, 2, 3, 4]
    continue if item % 2 == 0
    out[#out + 1] = item
  end
  return out
end
"""
  mod = compileAndLoad(src)
  out = mod.probe()
  assertEq(out[1], 1)
  assertEq(out[2], 3)
  assertNil(out[3])
end
fn testForInAndLengthAppendValues()
  out = []
  for item in ['a', 'b']
    out[#out + 1] = item + '!'
  end
  assertEq(out[1], 'a!')
  assertEq(out[2], 'b!')
end
fn testRangesAndNumericLiteralsCompile()
  src = """
export fn probe()
  return [0xff, 0o10, 0b11, 1_000, 1..3, 1...3]
end
"""
  mod = compileAndLoad(src)
  out = mod.probe()
  assertEq(out[1], 255)
  assertEq(out[2], 8)
  assertEq(out[3], 3)
  assertEq(out[4], 1000)
  assertEq(out[5].first, 1)
  assertEq(out[5].last, 3)
  assert(out[5].inclusive)
  assert(out[6].inclusive == false)
end
fn testBlocksYieldAndExplicitBlockParamWork()
  src = """
export fn each(a, b, &blk)
  return yield(a) + ':' + yield(b)
end

export fn probe()
  return each('x', 'y') do |item|
    return item + '!'
  end
end
"""
  mod = compileAndLoad(src)
  assertEq(mod.probe(), 'x!:y!')
end
fn testYieldReturnsNilWithoutABlock()
  src = """
export fn greet(name, title = 'Mx', **opts, &blk)
  prefix = opts.prefix || ''
  label = prefix + title + ' ' + name
  return yield(label) or label
end
"""
  mod = compileAndLoad(src)
  assertEq(mod.greet(name='Ada', title='Dr', prefix='Hello, '), 'Hello, Dr Ada')
  assertEq(mod.greet(name='Ada') do |label|
    return label + '!'
  end, 'Mx Ada!')
end
fn testSafeCallAndIndexWork()
  src = """
export fn probe(fnValue, items)
  return [fnValue?(2), items?[1], items?[9]]
end
export fn times2(v) = v * 2
"""
  mod = compileAndLoad(src)
  out = mod.probe(mod.times2, ['a', 'b'])
  assertEq(out[1], 4)
  assertEq(out[2], 'a')
  assertNil(out[3])
end
fn testCommentsLexAndCompile()
  src = """
;;; module
;; section
; line
export fn probe() = 1
"""
  mod = compileAndLoad(src)
  assertEq(mod.probe(), 1)
end
fn testOperatorAliasesWork()
  src = """
export fn probe(a, b)
  return [a && b, a || b, !a, ~1, 5 ~ 3, 2 ^ 3, 1 != 2]
end
"""
  mod = compileAndLoad(src)
  out = mod.probe(true, false)
  assertEq(out[1], false)
  assertEq(out[2], true)
  assertEq(out[3], false)
  assertEq(out[4], -2)
  assertEq(out[5], 6)
  assertEq(out[6], 8)
  assertEq(out[7], true)
end
fn testPostfixConditionalsWork()
  src = """
export fn probe(flag)
  out = []
  out[#out + 1] = 'yes' if flag
  out[#out + 1] = 'no' unless flag
  return out
end
"""
  mod = compileAndLoad(src)
  yes = mod.probe(true)
  no = mod.probe(false)
  assertEq(yes[1], 'yes')
  assertEq(no[1], 'no')
end
fn testConditionalExpressionsWork()
  src = """
export fn probe(flag)
  label = 'yes' if flag else 'no'
  return [label, ('big' if 2 > 1 else 'small')]
end
"""
  mod = compileAndLoad(src)
  yes = mod.probe(true)
  no = mod.probe(false)
  assertEq(yes[1], 'yes')
  assertEq(no[1], 'no')
  assertEq(yes[2], 'big')
end
fn testConditionalExpressionsPreserveFalseyThenValues()
  src = """
export fn probe(flag)
  return [false if flag else true, nil if flag else 'fallback']
end
"""
  mod = compileAndLoad(src)
  yes = mod.probe(true)
  no = mod.probe(false)
  assertEq(yes[1], false)
  assertNil(yes[2])
  assertEq(no[1], true)
  assertEq(no[2], 'fallback')
end
fn testOrAssignWorks()
  src = """
export fn probe()
  count ||= 1
  count ||= 2

  flags = {ready = false}
  flags.ready ||= true
  flags.ready ||= false

  items = []
  items[1] ||= 'first'
  items[1] ||= 'second'

  return [count, flags.ready, items[1]]
end
"""
  mod = compileAndLoad(src)
  out = mod.probe()
  assertEq(out[1], 1)
  assertEq(out[2], true)
  assertEq(out[3], 'first')
end
fn testHooksShareModuleState()
  assertEq(state.includes('before'), true)
end
