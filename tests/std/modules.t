fs = require('fs')

fn testStdJsonModuleWorks()
  src = """
json = require('json')

export fn probe()
  text = json.encode({
    first_name = 'Ada',
    age = 9,
    active = true,
    user_info = {display_name = 'Ada Lovelace'},
    tags = ['jaya', 'lua'],
    note = nil
  }, casing=json.camelCase)
  data = json.decode('{"firstName":"Ada","age":9,"active":true,"userInfo":{"displayName":"Ada Lovelace"},"tags":["jaya","lua"],"note":null}')
  return [
    text.includes('"firstName":"Ada"'),
    text.includes('"userInfo":{"displayName":"Ada Lovelace"}'),
    text.includes('"tags":["jaya","lua"]'),
    data.firstName,
    data.age,
    data.active,
    data.userInfo.displayName,
    data.tags[1],
    data.tags[2],
    data.note == nil
  ]
end
"""
  mod = compileAndLoad(src)
  out = mod.probe()
  assertEq(out[1], true)
  assertEq(out[2], true)
  assertEq(out[3], true)
  assertEq(out[4], 'Ada')
  assertEq(out[5], 9)
  assertEq(out[6], true)
  assertEq(out[7], 'Ada Lovelace')
  assertEq(out[8], 'jaya')
  assertEq(out[9], 'lua')
  assertEq(out[10], true)
end
fn testStdSysSleepWorks()
  src = """
export fn probe()
  return sleep(0)
end
"""
  mod = compileAndLoad(src)
  assertEq(mod.probe(), nil)
end
fn testStdMathModuleWorks()
  src = """
math = require('math')

export fn probe()
  return [
    math.pi > 3.14,
    math.abs(-4),
    math.floor(3.9),
    math.ceil(3.1),
    math.round(3.6),
    math.sqrt(81),
    math.pow(2, 5),
    math.min(3, 9),
    math.max(3, 9),
    math.clamp(12, 0, 10),
    math.sin(0),
    math.cos(0)
  ]
end
"""
  mod = compileAndLoad(src)
  out = mod.probe()
  assertEq(out[1], true)
  assertEq(out[2], 4)
  assertEq(out[3], 3)
  assertEq(out[4], 4)
  assertEq(out[5], 4)
  assertEq(out[6], 9)
  assertEq(out[7], 32)
  assertEq(out[8], 3)
  assertEq(out[9], 9)
  assertEq(out[10], 10)
  assertEq(out[11], 0)
  assertEq(out[12], 1)
end
fn testStdMathSeedWorks()
  src = """
math = require('math')

export fn probe()
  math.seed(12345)
  first = math.random()
  math.seed(12345)
  second = math.random()
  return first == second
end
"""
  mod = compileAndLoad(src)
  assertEq(mod.probe(), true)
end
fn testStdHtmlModuleWorks()
  src = """
html = require('html')

export fn probe()
  attrs = {}
  attrs['class'] = 'panel'
  node = html.tag('div', attrs, [
    html.tag('span', {}, ['Ada & Bea'])
  ])
  return html.render(node)
end
"""
  mod = compileAndLoad(src)
  assertEq(mod.probe(), '<div class="panel"><span>Ada &amp; Bea</span></div>')
end
fn testStdHtmlBuilderWorks()
  src = """
html = require('html')

export fn probe()
  b = html.Builder()
  b.div(id=123, class='panel', data-id='row-1', attr1='foo', attr2=true) do
    b.h1('Users', class='title', style='font-size:x-large')
    b.ul() do
      b.li('Ada', class='name')
      b.li('Bea', class='name')
    end
  end
  return b.s()
end
"""
  mod = compileAndLoad(src)
  assertEq(mod.probe(), '<div attr1="foo" attr2 class="panel" data-id="row-1" id="123"><h1 class="title" style="font-size:x-large">Users</h1><ul><li class="name">Ada</li><li class="name">Bea</li></ul></div>')
end
fn testStdHtmlBuilderIncludeWorks()
  src = """
html = require('html')

export fn probe()
  b = html.Builder()
  b.include('/assets/app.css')
  b.include('/assets/app.js?v=2')
  return b.s()
end
"""
  mod = compileAndLoad(src)
  assertEq(mod.probe(), '<link href="/assets/app.css" rel="stylesheet"><script src="/assets/app.js?v=2"></script>')
end
fn testObjectToJsonSkipsPrivateMembersByDefault()
  src = """
class Account(public name, private token, protected status)
  private prop secret = 'hidden'
  protected prop level = 3
  prop role = 'admin'
end

export fn probe()
  account = Account('Ada', 'tok-123', 'active')
  return account.toJson()
end
"""
  mod = compileAndLoad(src)
  out = mod.probe()
  assertEq(out.name, 'Ada')
  assertEq(out.role, 'admin')
  assertNil(out.token)
  assertNil(out.secret)
  assertNil(out.status)
  assertNil(out.level)
end
fn testClassFromJsonUsesPublicFieldsByDefault()
  src = """
class Account(public name, private token, protected status)
  private prop secret = 'hidden'
  protected prop level = 3
  prop role = 'member'
end

export fn probe()
  account = Account.fromJson({
    name = 'Ada',
    token = 'tok-123',
    status = 'active',
    secret = 'hidden',
    level = 7,
    role = 'admin'
  })
  return [
    account.name,
    account.role,
    account.token,
    account.status,
    account.secret,
    account.level
  ]
end
"""
  mod = compileAndLoad(src)
  out = mod.probe()
  assertEq(out[1], 'Ada')
  assertEq(out[2], 'admin')
  assertNil(out[3])
  assertNil(out[4])
  assertEq(out[5], 'hidden')
  assertEq(out[6], 3)
end
fn testObjectVisibilityFieldHelpersWork()
  src = """
class Account(public name, private token, protected status)
  private prop secret = 'hidden'
  protected prop level = 3
  prop role = 'admin'
end

export fn probe()
  account = Account('Ada', 'tok-123', 'active')
  return [account.publicFields(), account.privateFields(), account.protectedFields()]
end
"""
  mod = compileAndLoad(src)
  out = mod.probe()
  publicFields = out[1]
  privateFields = out[2]
  protectedFields = out[3]
  assertEq(publicFields.name, 'Ada')
  assertEq(publicFields.role, 'admin')
  assertNil(publicFields.token)
  assertNil(publicFields.status)
  assertEq(privateFields.token, 'tok-123')
  assertEq(privateFields.secret, 'hidden')
  assertNil(privateFields.name)
  assertEq(protectedFields.status, 'active')
  assertEq(protectedFields.level, 3)
  assertNil(protectedFields.role)
end
fn testPrimitiveTypeTokensCannotBeRedeclared()
  ok, err = pcall(fn()
    compileAndLoad("""
export fn probe()
  const String = {}
  return String
end
""")
  end)
  assert(ok == false)
  assert(string.find(err, 'cannot redeclare const: String') != nil)
end
fn testPrimitiveTypeTokensCannotBeShadowedByParams()
  ok, err = pcall(fn()
    compileAndLoad("""
export fn probe(String)
  return String
end
""")
  end)
  assert(ok == false)
  assert(string.find(err, 'cannot shadow builtin: String') != nil)
end
fn testClassMethodsWork()
  src = """
class Person(name)
  greet() = 'hi'
end

class LoudPerson(name) extends Person
end

export fn probe()
  fns = Person.functions()
  loc = Person.location()
  parents = LoudPerson.parents()
  instance = Person('Ada')
  roundTrip = Person.fromJson(instance.toJson())
  shown = instance.s()
  return [Person.name(), Person.fields()[1], fns[1], fns[2] == nil, loc.source, loc.line, parents[1].name(), roundTrip.name, shown.includes('Person@'), shown.includes('{'), shown.includes('name = "Ada"')]
end
"""
  mod = compileAndLoad(src)
  out = mod.probe()
  assertEq(out[1], 'Person')
  assertEq(out[2], 'name')
  assertEq(out[3], 'greet')
  assertEq(out[4], true)
  assertEq(out[5], '<test>')
  assertEq(out[6], 2)
  assertEq(out[7], 'Person')
  assertEq(out[8], 'Ada')
  assertEq(out[9], true)
  assertEq(out[10], true)
  assertEq(out[11], true)
end
fn testModuleMethodsWork()
  dir = '/tmp/jpl_feature_module_methods'
  os.execute('mkdir -p ' + dir)
  fs.writeFile(dir + '/math_tools.jpl', """
export fn add(x, y) = x + y
export fn sub(x, y) = x - y
""")
  fs.writeFile(dir + '/main.jpl', """
mathTools = require('./math_tools')

export fn probe()
  fns = mathTools.functions()
  loc = mathTools.location()
  return [mathTools.name(), fns[1], fns[2], loc.source, loc.line]
end
""")
  mod = compileAndLoad(fs.readFile(dir + '/main.jpl'), dir + '/main.jpl')
  out = mod.probe()
  assertEq(out[1], 'math_tools')
  assertEq(out[2], 'add')
  assertEq(out[3], 'sub')
  assertEq(out[4], dir + '/math_tools.jpl')
  assertEq(out[5], 1)
end
fn testFunctionMethodsWork()
  src = """
export fn greet(name, title = 'Mx')
  return title + ' ' + name
end

export fn probe()
  anon = fn(value) = value + 1
  greetParams = greet.params()
  anonParams = anon.params()
  namedLoc = greet.location()
  anonLoc = anon.location()
  return [greet.name(), greetParams[1], greetParams[2], anon.name() == nil, anonParams[1], namedLoc.source, namedLoc.line, anonLoc.source, anonLoc.line]
end
"""
  mod = compileAndLoad(src)
  out = mod.probe()
  assertEq(out[1], 'greet')
  assertEq(out[2], 'name')
  assertEq(out[3], 'title')
  assertEq(out[4], true)
  assertEq(out[5], 'value')
  assertEq(out[6], '<test>')
  assertEq(out[7], 2)
  assertEq(out[8], '<test>')
  assertEq(out[9], 7)
end
