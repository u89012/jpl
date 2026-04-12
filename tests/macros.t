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

deftags('div', 'span')

fn tag(name, attrs, children, body)
  if body != nil
    children = body()
  end
  if children == nil
    children = []
  end
  if type(children) != 'table'
    children = [children]
  end
  return { tag = name, props = attrs, children = children }
end

fn testMacroExpressionExpansionWorks()
  src = """
macro inc(x) = _q(_u(x) + 1)
export fn probe() = inc(4)
"""
  mod = compileAndLoad(src)
  assertEq(mod.probe(), 5)
end
fn testMacroSpliceWorks()
  src = """
macro pair(*items) = _q([_s(items)])
export fn probe() = pair(1, 2)
"""
  mod = compileAndLoad(src)
  out = mod.probe()
  assertEq(out[1], 1)
  assertEq(out[2], 2)
end
fn testMacroDefinesMultipleForms()
  src = """
macro definePair()
  _q(fn one() = 1)
  _q(fn two() = 2)
end

definePair()

export fn probe()
  return [one(), two()]
end
"""
  mod = compileAndLoad(src)
  out = mod.probe()
  assertEq(out[1], 1)
  assertEq(out[2], 2)
end
fn testMacroDeftagsBuildsHtmlStyleNodes()
  node = div(class='panel', data-id='row-1', aria-label='Main') do
    return 'ok'
  end
  assertEq(node.tag, 'div')
  assertEq(node.props['class'], 'panel')
  assertEq(node.props['data-id'], 'row-1')
  assertEq(node.props['aria-label'], 'Main')
  assertEq(node.children[1], 'ok')
end
