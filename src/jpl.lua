local JPL = {}
local SELF_PATH = debug.getinfo(1, "S").source:match("^@(.+)$") or "src/jpl.lua"
local SELF_DIR = SELF_PATH:match("^(.*)/[^/]*$") or "."

local KEYWORDS = {
  ["and"] = true,
  ["break"] = true,
  ["case"] = true,
  ["class"] = true,
  ["const"] = true,
  ["do"] = true,
  ["else"] = true,
  ["elsif"] = true,
  ["end"] = true,
  ["export"] = true,
  ["false"] = true,
  ["fn"] = true,
  ["for"] = true,
  ["get"] = true,
  ["go"] = true,
  ["if"] = true,
  ["in"] = true,
  ["let"] = true,
  ["local"] = true,
  ["match"] = true,
  ["macro"] = true,
  ["nil"] = true,
  ["not"] = true,
  ["or"] = true,
  ["private"] = true,
  ["protected"] = true,
  ["prop"] = true,
  ["public"] = true,
  ["repeat"] = true,
  ["return"] = true,
  ["set"] = true,
  ["static"] = true,
  ["super"] = true,
  ["then"] = true,
  ["throw"] = true,
  ["true"] = true,
  ["try"] = true,
  ["unless"] = true,
  ["until"] = true,
  ["extends"] = true,
  ["catch"] = true,
  ["finally"] = true,
  ["when"] = true,
  ["while"] = true,
  ["yield"] = true,
}

local MULTI = {
  ["..."] = true,
  [".."] = true,
  ["**"] = true,
  ["&&"] = true,
  ["||"] = true,
  ["=>"] = true,
  ["!="] = true,
  ["=="] = true,
  ["~="] = true,
  ["<="] = true,
  [">="] = true,
  ["//"] = true,
  ["<<"] = true,
  [">>"] = true,
  ["::"] = true,
}

local RIGHT_ASSOC = {
  ["^"] = true,
}

local PRECEDENCE = {
  ["or"] = 1,
  ["||"] = 1,
  ["and"] = 2,
  ["&&"] = 2,
  ["=="] = 3, ["~="] = 3, ["!="] = 3, ["<"] = 3, ["<="] = 3, [">"] = 3, [">="] = 3,
  ["~"] = 4,
  ["+"] = 5, ["-"] = 5,
  ["*"] = 6, ["/"] = 6, ["//"] = 6, ["%"] = 6,
  ["^"] = 7,
}

local RESERVED_BUILTINS = {
  sys = true,
  Object = true,
  String = true,
  Number = true,
  Bool = true,
  Array = true,
  Hash = true,
  Class = true,
  Module = true,
  Function = true,
}

local LUA_BARE_KEYS = {
  ["and"] = false,
  ["break"] = false,
  ["do"] = false,
  ["else"] = false,
  ["elseif"] = false,
  ["end"] = false,
  ["false"] = false,
  ["for"] = false,
  ["function"] = false,
  ["goto"] = false,
  ["if"] = false,
  ["in"] = false,
  ["local"] = false,
  ["nil"] = false,
  ["not"] = false,
  ["or"] = false,
  ["repeat"] = false,
  ["return"] = false,
  ["then"] = false,
  ["true"] = false,
  ["until"] = false,
  ["while"] = false,
}

local function can_emit_bare_key(name)
  return type(name) == "string"
    and name:match("^[A-Za-z_][A-Za-z0-9_]*$")
    and LUA_BARE_KEYS[name] == nil
end

local function syntax_error(source, line, col, msg)
  error(string.format("Jaya syntax error at %s:%d:%d: %s", source or "<input>", line or 1, col or 1, msg), 0)
end

local Lexer = {}
Lexer.__index = Lexer

function Lexer.new(input, source)
  return setmetatable({
    input = input,
    source = source or "<input>",
    pos = 1,
    line = 1,
    col = 1,
    len = #input,
    comments = {},
  }, Lexer)
end

function Lexer:peek(offset)
  offset = offset or 0
  local p = self.pos + offset
  if p > self.len then
    return nil
  end
  return self.input:sub(p, p)
end

function Lexer:advance(n)
  n = n or 1
  for _ = 1, n do
    local ch = self:peek()
    if not ch then
      return
    end
    self.pos = self.pos + 1
    if ch == "\n" then
      self.line = self.line + 1
      self.col = 1
    else
      self.col = self.col + 1
    end
  end
end

function Lexer:read_line_comment(prefix)
  local line, col = self.line, self.col
  self:advance(#prefix)
  local start = self.pos
  while self:peek() and self:peek() ~= "\n" do
    self:advance()
  end
  self.comments[#self.comments + 1] = {
    kind = "comment",
    prefix = prefix,
    level = #prefix,
    value = self.input:sub(start, self.pos - 1),
    line = line,
    col = col,
  }
end

function Lexer:skip_space()
  while true do
    local ch = self:peek()
    if not ch then
      return
    end
    if ch:match("%s") then
      self:advance()
    elseif ch == ";" then
      local prefix = ";"
      if self:peek(1) == ";" and self:peek(2) == ";" then
        prefix = ";;;"
      elseif self:peek(1) == ";" then
        prefix = ";;"
      end
      self:read_line_comment(prefix)
    elseif ch == "-" and self:peek(1) == "-" then
      self:read_line_comment("--")
    else
      return
    end
  end
end

function Lexer:read_name()
  local start = self.pos
  while true do
    local ch = self:peek()
    if ch and ch:match("[%w_]") then
      self:advance()
    else
      break
    end
  end
  local value = self.input:sub(start, self.pos - 1)
  if KEYWORDS[value] then
    return "keyword", value
  end
  return "name", value
end

function Lexer:read_number()
  local start = self.pos
  if self:peek() == "0" then
    local marker = self:peek(1)
    if marker == "x" or marker == "X" then
      self:advance(2)
      while self:peek() and self:peek():match("[%da-fA-F_]") do
        self:advance()
      end
      local raw = self.input:sub(start, self.pos - 1):gsub("_", "")
      return "number", raw
    elseif marker == "b" or marker == "B" then
      self:advance(2)
      while self:peek() and self:peek():match("[01_]") do
        self:advance()
      end
      local raw = self.input:sub(start + 2, self.pos - 1):gsub("_", "")
      return "number", tostring(tonumber(raw, 2))
    elseif marker == "o" or marker == "O" then
      self:advance(2)
      while self:peek() and self:peek():match("[0-7_]") do
        self:advance()
      end
      local raw = self.input:sub(start + 2, self.pos - 1):gsub("_", "")
      return "number", tostring(tonumber(raw, 8))
    end
  end
  while self:peek() and self:peek():match("[%d_]") do
    self:advance()
  end
  if self:peek() == "." and self:peek(1) and self:peek(1):match("%d") then
    self:advance()
    while self:peek() and self:peek():match("[%d_]") do
      self:advance()
    end
  end
  local value = self.input:sub(start, self.pos - 1)
  return "number", value:gsub("_", "")
end

function Lexer:read_interpolation_source(start_line, start_col)
  local depth = 1
  local start = self.pos
  while true do
    local ch = self:peek()
    if not ch then
      syntax_error(self.source, start_line, start_col, "unterminated interpolation")
    elseif ch == "'" or ch == '"' then
      local quote = ch
      self:advance()
      while true do
        local inner = self:peek()
        if not inner then
          syntax_error(self.source, start_line, start_col, "unterminated interpolation string")
        elseif inner == "\\" then
          self:advance(2)
        elseif inner == quote then
          self:advance()
          break
        else
          self:advance()
        end
      end
    elseif ch == "{" then
      depth = depth + 1
      self:advance()
    elseif ch == "}" then
      depth = depth - 1
      if depth == 0 then
        local value = self.input:sub(start, self.pos - 1)
        self:advance()
        return value
      end
      self:advance()
    else
      self:advance()
    end
  end
end

function Lexer:read_string_part(quote)
  local start_line, start_col = self.line, self.col
  self:advance()
  local parts = {}
  local has_interp = false
  while true do
    local ch = self:peek()
    if not ch then
      syntax_error(self.source, start_line, start_col, "unterminated string")
    elseif ch == quote then
      self:advance()
      break
    elseif ch == "\\" then
      self:advance()
      local esc = self:peek()
      if not esc then
        syntax_error(self.source, start_line, start_col, "unterminated escape")
      end
      local map = { n = "\n", r = "\r", t = "\t", ["\\"] = "\\", ['"'] = '"', ["'"] = "'" }
      parts[#parts + 1] = map[esc] or esc
      self:advance()
    elseif quote == '"' and ch == "#" and self:peek(1) == "{" then
      has_interp = true
      self:advance(2)
      local expr_source = self:read_interpolation_source(start_line, start_col)
      parts[#parts + 1] = { kind = "interp", source = expr_source }
    else
      parts[#parts + 1] = ch
      self:advance()
    end
  end
  if not has_interp then
    local flat = {}
    for _, part in ipairs(parts) do
      flat[#flat + 1] = part
    end
    return "string", table.concat(flat)
  end
  local normalized = {}
  local buffer = {}
  local function flush_buffer()
    if #buffer > 0 then
      normalized[#normalized + 1] = table.concat(buffer)
      buffer = {}
    end
  end
  for _, part in ipairs(parts) do
    if type(part) == "string" then
      buffer[#buffer + 1] = part
    else
      flush_buffer()
      normalized[#normalized + 1] = part
    end
  end
  flush_buffer()
  return "interp_string", normalized
end

function Lexer:read_string(quote)
  if quote == "'" then
    local start_line, start_col = self.line, self.col
    self:advance()
    local parts = {}
    while true do
      local ch = self:peek()
      if not ch then
        syntax_error(self.source, start_line, start_col, "unterminated string")
      elseif ch == quote then
        self:advance()
        break
      elseif ch == "\\" then
        self:advance()
        local esc = self:peek()
        if not esc then
          syntax_error(self.source, start_line, start_col, "unterminated escape")
        end
        local map = { n = "\n", r = "\r", t = "\t", ["\\"] = "\\", ['"'] = '"', ["'"] = "'" }
        parts[#parts + 1] = map[esc] or esc
        self:advance()
      else
        parts[#parts + 1] = ch
        self:advance()
      end
    end
    return "string", table.concat(parts)
  end
  return self:read_string_part(quote)
end

function Lexer:read_triple_string()
  local start_line, start_col = self.line, self.col
  self:advance(3)
  local parts = {}
  local has_interp = false
  while true do
    local ch = self:peek()
    if not ch then
      syntax_error(self.source, start_line, start_col, "unterminated triple-quoted string")
    elseif ch == '"' and self:peek(1) == '"' and self:peek(2) == '"' then
      self:advance(3)
      break
    elseif ch == "#" and self:peek(1) == "{" then
      has_interp = true
      self:advance(2)
      local expr_source = self:read_interpolation_source(start_line, start_col)
      parts[#parts + 1] = { kind = "interp", source = expr_source }
    else
      parts[#parts + 1] = ch
      self:advance()
    end
  end
  if not has_interp then
    local flat = {}
    for _, part in ipairs(parts) do
      flat[#flat + 1] = part
    end
    return { kind = "string", value = table.concat(flat) }
  end
  local normalized = {}
  local buffer = {}
  local function flush_buffer()
    if #buffer > 0 then
      normalized[#normalized + 1] = table.concat(buffer)
      buffer = {}
    end
  end
  for _, part in ipairs(parts) do
    if type(part) == "string" then
      buffer[#buffer + 1] = part
    else
      flush_buffer()
      normalized[#normalized + 1] = part
    end
  end
  flush_buffer()
  return { kind = "interp_string", value = normalized }
end

function Lexer:next_token()
  self:skip_space()
  local line, col = self.line, self.col
  local ch = self:peek()
  if not ch then
    return { kind = "eof", value = "<eof>", line = line, col = col }
  end
  if ch:match("[%a_]") then
    local kind, value = self:read_name()
    return { kind = kind, value = value, line = line, col = col }
  end
  if ch:match("%d") then
    local kind, value = self:read_number()
    return { kind = kind, value = value, line = line, col = col }
  end
  if ch == '"' and self:peek(1) == '"' and self:peek(2) == '"' then
    local triple = self:read_triple_string()
    return { kind = triple.kind, value = triple.value, line = line, col = col }
  end
  if ch == "'" or ch == '"' then
    local kind, value = self:read_string(ch)
    return { kind = kind, value = value, line = line, col = col }
  end

  local three = (self:peek() or "") .. (self:peek(1) or "") .. (self:peek(2) or "")
  if MULTI[three] then
    self:advance(3)
    return { kind = "symbol", value = three, line = line, col = col }
  end

  local two = (self:peek() or "") .. (self:peek(1) or "")
  if MULTI[two] then
    self:advance(2)
    return { kind = "symbol", value = two, line = line, col = col }
  end

  self:advance()
  return { kind = "symbol", value = ch, line = line, col = col }
end

function JPL.lex(input, source)
  local lx = Lexer.new(input, source)
  local tokens = {}
  while true do
    local tok = lx:next_token()
    tokens[#tokens + 1] = tok
    if tok.kind == "eof" then
      break
    end
  end
  tokens.comments = lx.comments
  return tokens
end

local Parser = {}
Parser.__index = Parser

function Parser.new(tokens, source)
  return setmetatable({
    tokens = tokens,
    index = 1,
    source = source or "<input>",
    fn_depth = 0,
    class_names = {},
    last_token = nil,
  }, Parser)
end

function Parser:current()
  return self.tokens[self.index]
end

function Parser:peek(offset)
  return self.tokens[self.index + (offset or 0)] or self.tokens[#self.tokens]
end

function Parser:advance()
  local tok = self:current()
  self.index = self.index + 1
  self.last_token = tok
  return tok
end

function Parser:error(tok, msg)
  syntax_error(self.source, tok.line, tok.col, msg)
end

function Parser:match(kind, value)
  local tok = self:current()
  if tok.kind == kind and (value == nil or tok.value == value) then
    self:advance()
    return tok
  end
  return nil
end

function Parser:expect(kind, value, msg)
  local tok = self:current()
  if tok.kind ~= kind or (value ~= nil and tok.value ~= value) then
    self:error(tok, msg or ("expected " .. (value or kind)))
  end
  return self:advance()
end

function Parser:at_block_end(extra)
  local tok = self:current()
  if tok.kind == "eof" then
    return true
  end
  if tok.kind == "keyword" then
    if tok.value == "end" or tok.value == "else" or tok.value == "elsif" or tok.value == "when" then
      return true
    end
    if extra and extra[tok.value] then
      return true
    end
  end
  return false
end

function Parser:parse_program()
  local body = self:parse_block()
  self:expect("eof")
  return { kind = "Program", body = body, source = self.source }
end

function Parser:parse_block(extra_terminators)
  local body = {}
  while not self:at_block_end(extra_terminators) do
    body[#body + 1] = self:parse_statement()
    self:match("symbol", ";")
  end
  return body
end

function Parser:parse_statement()
  local tok = self:current()
  if tok.kind == "symbol" and (tok.value == "," or tok.value == "@" or tok.value == "`") then
    return self:with_postfix_condition({ kind = "ExprStmt", expression = self:parse_expression() })
  end
  if tok.kind == "keyword" then
    local kw = tok.value
    if kw == "export" then
      return self:parse_export()
    elseif kw == "class" then
      return self:parse_class(false)
    elseif kw == "fn" then
      return self:parse_fn_statement()
    elseif kw == "macro" then
      return self:parse_macro_statement()
    elseif kw == "if" then
      return self:parse_if()
    elseif kw == "unless" then
      return self:parse_unless()
    elseif kw == "case" then
      return self:parse_case()
    elseif kw == "let" then
      return self:parse_let()
    elseif kw == "const" then
      return self:parse_const(false)
    elseif kw == "for" then
      return self:parse_for()
    elseif kw == "match" then
      return self:parse_match()
    elseif kw == "try" then
      return self:parse_try()
    elseif kw == "return" then
      return self:parse_return()
    elseif kw == "break" then
      return self:parse_break()
    elseif kw == "go" then
      return self:parse_go()
    elseif kw == "throw" then
      return self:parse_throw()
    elseif kw == "local" then
      return self:parse_local()
    end
  end
  return self:parse_assignment_or_expr()
end

function Parser:parse_for()
  self:expect("keyword", "for")
  local names = { self:expect("name", nil, "expected loop variable name").value }
  if self:match("symbol", ",") then
    names[#names + 1] = self:expect("name", nil, "expected second loop variable name").value
  end
  self:expect("keyword", "in", "expected 'in' after loop variable")
  local iterable = self:parse_expression()
  local body = self:parse_block()
  self:expect("keyword", "end", "expected 'end' to close for")
  return {
    kind = "ForIn",
    names = names,
    iterable = iterable,
    body = body,
  }
end

function Parser:parse_export()
  local export_tok = self:expect("keyword", "export")
  if self.fn_depth > 0 then
    self:error(export_tok, "'export' allowed only at top level")
  end
  if self:current().kind == "keyword" and self:current().value == "class" then
    return self:parse_class(true)
  end
  if self:match("keyword", "fn") then
    local fn = self:parse_fn(true)
    fn.exported = true
    fn.local_default = false
    return fn
  end
  if self:match("keyword", "macro") then
    local macro = self:parse_macro(true)
    macro.exported = true
    macro.local_default = false
    return macro
  end
  if self:match("keyword", "const") then
    return self:parse_const(true)
  end
  local names = self:parse_name_list()
  self:expect("symbol", "=", "expected '=' after export names")
  local values = self:parse_expr_list()
  return { kind = "ExportAssign", names = names, values = values, top_level_only = true }
end

function Parser:parse_local()
  self:expect("keyword", "local")
  local names = self:parse_binding_pattern_list()
  local values = nil
  if self:match("symbol", "=") then
    values = self:parse_expr_list()
  end
  return self:with_postfix_condition({ kind = "LocalAssign", names = names, values = values })
end

function Parser:parse_const(exported)
  if not exported then
    self:expect("keyword", "const")
  end
  local names = self:parse_name_list()
  self:expect("symbol", "=", "expected '=' after const names")
  local values = self:parse_expr_list()
  return {
    kind = exported and "ExportConstAssign" or "ConstAssign",
    names = names,
    values = values,
    exported = exported or false,
    top_level_only = exported or false,
  }
end

function Parser:parse_let()
  self:expect("keyword", "let")
  local bindings = {}
  repeat
    local pattern = self:parse_binding_pattern()
    self:expect("symbol", "=", "expected '=' in let binding")
    bindings[#bindings + 1] = {
      kind = "LetBinding",
      pattern = pattern,
      value = self:parse_expression(),
    }
  until not self:match("symbol", ",")
  local body = self:parse_block()
  self:expect("keyword", "end", "expected 'end' to close let")
  return {
    kind = "Let",
    bindings = bindings,
    body = body,
  }
end

function Parser:parse_binding_pattern()
  local tok = self:current()
  if tok.kind == "name" then
    return { kind = "PatternName", name = self:advance().value }
  elseif tok.kind == "symbol" and tok.value == "[" then
    return self:parse_array_pattern()
  elseif tok.kind == "symbol" and tok.value == "{" then
    return self:parse_table_pattern()
  end
  self:error(tok, "expected binding pattern")
end

function Parser:parse_binding_pattern_list()
  local patterns = {}
  repeat
    patterns[#patterns + 1] = self:parse_binding_pattern()
  until not self:match("symbol", ",")
  return patterns
end

function Parser:parse_array_pattern()
  local items = {}
  self:expect("symbol", "[")
  if not self:match("symbol", "]") then
    repeat
      items[#items + 1] = self:parse_binding_pattern()
    until not self:match("symbol", ",")
    self:expect("symbol", "]", "expected ']' after array pattern")
  end
  return { kind = "ArrayPattern", items = items }
end

function Parser:parse_table_pattern()
  local fields = {}
  self:expect("symbol", "{")
  if not self:match("symbol", "}") then
    repeat
      local key = self:expect("name", nil, "expected field name in table pattern").value
      local pattern
      if self:match("symbol", "=") then
        pattern = self:parse_binding_pattern()
      else
        pattern = { kind = "PatternName", name = key }
      end
      fields[#fields + 1] = { kind = "PatternField", key = key, pattern = pattern }
    until not self:match("symbol", ",")
    self:expect("symbol", "}", "expected '}' after table pattern")
  end
  return { kind = "TablePattern", fields = fields }
end

function Parser:parse_match_pattern()
  local tok = self:current()
  if tok.kind == "name" then
    local name = self:advance().value
    if name == "_" then
      return { kind = "PatternWildcard" }
    elseif name == "t" then
      return { kind = "PatternLiteral", value = { kind = "Boolean", value = true } }
    elseif self:current().kind == "symbol" and self:current().value == "(" then
      self:advance()
      local args = {}
      if not self:match("symbol", ")") then
        repeat
          args[#args + 1] = self:parse_match_pattern()
        until not self:match("symbol", ",")
        self:expect("symbol", ")", "expected ')' after class pattern")
      end
      return { kind = "ClassPattern", name = name, args = args }
    end
    return { kind = "PatternName", name = name }
  elseif tok.kind == "number" then
    self:advance()
    return { kind = "PatternLiteral", value = { kind = "Number", value = tonumber(tok.value) } }
  elseif tok.kind == "string" then
    self:advance()
    return { kind = "PatternLiteral", value = { kind = "String", value = tok.value } }
  elseif tok.kind == "keyword" then
    if tok.value == "true" or tok.value == "false" then
      self:advance()
      return { kind = "PatternLiteral", value = { kind = "Boolean", value = tok.value == "true" } }
    elseif tok.value == "nil" then
      self:advance()
      return { kind = "PatternLiteral", value = { kind = "Nil" } }
    end
  elseif tok.kind == "symbol" and tok.value == "[" then
    return self:parse_match_array_pattern()
  elseif tok.kind == "symbol" and tok.value == "{" then
    return self:parse_match_table_pattern()
  end
  self:error(tok, "expected match pattern")
end

function Parser:parse_match_array_pattern()
  local items = {}
  self:expect("symbol", "[")
  if not self:match("symbol", "]") then
    repeat
      items[#items + 1] = self:parse_match_pattern()
    until not self:match("symbol", ",")
    self:expect("symbol", "]", "expected ']' after array pattern")
  end
  return { kind = "ArrayPattern", items = items }
end

function Parser:parse_match_table_pattern()
  local fields = {}
  self:expect("symbol", "{")
  if not self:match("symbol", "}") then
    repeat
      local key = self:expect("name", nil, "expected field name in table pattern").value
      local pattern
      if self:match("symbol", "=") then
        pattern = self:parse_match_pattern()
      else
        pattern = { kind = "PatternName", name = key }
      end
      fields[#fields + 1] = { kind = "PatternField", key = key, pattern = pattern }
    until not self:match("symbol", ",")
    self:expect("symbol", "}", "expected '}' after table pattern")
  end
  return { kind = "TablePattern", fields = fields }
end

function Parser:parse_name_list()
  local names = {}
  repeat
    names[#names + 1] = self:expect("name").value
  until not self:match("symbol", ",")
  return names
end

function Parser:parse_return()
  self:expect("keyword", "return")
  local values = nil
  if not self:at_block_end() and not self:match("symbol", ";") then
    values = self:parse_expr_list()
  end
  local cond = self:parse_postfix_condition()
  return { kind = "Return", values = values, condition = cond }
end

function Parser:parse_break()
  self:expect("keyword", "break")
  local cond = self:parse_postfix_condition()
  return { kind = "Break", condition = cond }
end

function Parser:parse_throw()
  self:expect("keyword", "throw")
  return { kind = "Throw", value = self:parse_expression() }
end

function Parser:parse_go()
  self:expect("keyword", "go")
  return { kind = "Go", value = self:parse_expression() }
end

function Parser:parse_postfix_condition()
  local tok = self:current()
  if self.last_token == nil or tok.line ~= self.last_token.line then
    return nil
  end
  if tok.kind == "keyword" and (tok.value == "if" or tok.value == "unless") then
    self:advance()
    return { kind = tok.value == "if" and "IfCond" or "UnlessCond", expr = self:parse_expression() }
  end
  return nil
end

function Parser:with_postfix_condition(stmt)
  local cond = self:parse_postfix_condition()
  if not cond then
    return stmt
  end
  return { kind = "ConditionalStmt", statement = stmt, condition = cond }
end

function Parser:parse_binding_condition()
  self:expect("keyword", "let")
  local pattern = self:parse_binding_pattern()
  self:expect("symbol", "=", "expected '=' in binding condition")
  return {
    kind = "LetCond",
    pattern = pattern,
    value = self:parse_expression(),
  }
end

function Parser:parse_if()
  self:expect("keyword", "if")
  local branches = {}
  local condition
  if self:current().kind == "keyword" and self:current().value == "let" then
    condition = self:parse_binding_condition()
  else
    condition = self:parse_expression()
  end
  self:match("keyword", "then")
  branches[#branches + 1] = { condition = condition, body = self:parse_block() }
  while self:match("keyword", "elsif") do
    local cond
    if self:current().kind == "keyword" and self:current().value == "let" then
      cond = self:parse_binding_condition()
    else
      cond = self:parse_expression()
    end
    self:match("keyword", "then")
    branches[#branches + 1] = { condition = cond, body = self:parse_block() }
  end
  local else_body = nil
  if self:match("keyword", "else") then
    else_body = self:parse_block()
  end
  self:expect("keyword", "end", "expected 'end' to close if")
  return { kind = "If", branches = branches, else_body = else_body }
end

function Parser:parse_unless()
  self:expect("keyword", "unless")
  local condition
  if self:current().kind == "keyword" and self:current().value == "let" then
    condition = self:parse_binding_condition()
  else
    condition = self:parse_expression()
  end
  self:match("keyword", "then")
  local body = self:parse_block()
  local else_body = nil
  if self:match("keyword", "else") then
    else_body = self:parse_block()
  end
  self:expect("keyword", "end", "expected 'end' to close unless")
  return { kind = "Unless", condition = condition, body = body, else_body = else_body }
end

function Parser:parse_try()
  self:expect("keyword", "try")
  local body = self:parse_block({ catch = true, finally = true })
  local catches = {}
  while true do
    local catch_tok = self:match("keyword", "catch")
    if not catch_tok then
      break
    end
    local catch_types = nil
    if self:current().line == catch_tok.line and
        not (self:current().kind == "keyword" and (self:current().value == "catch" or self:current().value == "finally" or self:current().value == "end")) then
      catch_types = { self:parse_expression() }
      while self:match("symbol", ",") do
        catch_types[#catch_types + 1] = self:parse_expression()
      end
    end
    catches[#catches + 1] = {
      kind = "CatchClause",
      types = catch_types,
      body = self:parse_block({ catch = true, finally = true }),
    }
  end
  if #catches == 0 then
    self:error(self:current(), "expected at least one 'catch' in try")
  end
  local finally_body = nil
  if self:match("keyword", "finally") then
    finally_body = self:parse_block()
  end
  self:expect("keyword", "end", "expected 'end' to close try")
  return {
    kind = "Try",
    body = body,
    catches = catches,
    finally_body = finally_body,
  }
end

function Parser:parse_case()
  self:expect("keyword", "case")
  local subject = self:parse_expression()
  local whens = {}
  while self:match("keyword", "when") do
    local values = self:parse_expr_list()
    whens[#whens + 1] = { values = values, body = self:parse_block({ when = true, ["else"] = true }) }
  end
  local else_body = nil
  if self:match("keyword", "else") then
    else_body = self:parse_block()
  end
  self:expect("keyword", "end", "expected 'end' to close case")
  return { kind = "Case", subject = subject, whens = whens, else_body = else_body }
end

function Parser:parse_match()
  self:expect("keyword", "match")
  local subject = self:parse_expression()
  local whens = {}
  while self:match("keyword", "when") do
    local pattern = self:parse_match_pattern()
    if pattern.kind == "PatternWildcard" then
      self:error(self:current(), "use 'else' for match fallback instead of 'when _'")
    end
    whens[#whens + 1] = {
      pattern = pattern,
      body = self:parse_block({ when = true, ["else"] = true }),
    }
  end
  if #whens == 0 then
    self:error(self:current(), "expected at least one 'when' in match")
  end
  local else_body = nil
  if self:match("keyword", "else") then
    else_body = self:parse_block()
  end
  self:expect("keyword", "end", "expected 'end' to close match")
  return { kind = "Match", subject = subject, whens = whens, else_body = else_body }
end

function Parser:parse_fn_statement()
  self:expect("keyword", "fn")
  return self:parse_fn(true)
end

function Parser:parse_macro_statement()
  self:expect("keyword", "macro")
  return self:parse_macro(true)
end

function Parser:parse_macro(is_statement)
  local name = nil
  if is_statement and self:current().kind == "name" then
    name = self:advance().value
  elseif is_statement then
    self:error(self:current(), "expected macro name")
  end
  self:expect("symbol", "(", "expected '(' after macro")
  local params = self:parse_params()
  self:expect("symbol", ")", "expected ')' after parameters")
  self.fn_depth = self.fn_depth + 1
  local body
  if self:match("symbol", "=") then
    body = { kind = "ExprBody", value = self:parse_expression() }
  else
    body = { kind = "BlockBody", body = self:parse_block() }
    self:expect("keyword", "end", "expected 'end' to close macro")
  end
  self.fn_depth = self.fn_depth - 1
  return {
    kind = name and "MacroDecl" or "MacroExpr",
    name = name,
    params = params,
    body = body,
    exported = name and false or nil,
    local_default = name and true or nil,
  }
end

function Parser:parse_class(exported)
  local class_tok = self:expect("keyword", "class")
  local name = self:expect("name", nil, "expected class name").value
  self.class_names[name] = true
  local params = {}
  if self:match("symbol", "(") then
    params = self:parse_class_params()
    self:expect("symbol", ")", "expected ')' after class parameters")
  end
  local bases = {}
  if self:match("keyword", "extends") then
    repeat
      bases[#bases + 1] = self:parse_suffixed_expression()
    until not self:match("symbol", ",")
  end
  local members = {}
  if self:is_class_member_start(self:current()) then
    while not (self:current().kind == "keyword" and self:current().value == "end") do
      members[#members + 1] = self:parse_class_member()
      self:match("symbol", ";")
    end
  end
  self:expect("keyword", "end", "expected 'end' to close class")
  return {
    kind = "ClassDecl",
    name = name,
    source = self.source,
    decl_line = class_tok.line,
    decl_col = class_tok.col,
    params = params,
    bases = bases,
    members = members,
    exported = exported or false,
    local_default = not exported,
  }
end

function Parser:parse_class_params()
  local params = {}
  if self:current().kind == "symbol" and self:current().value == ")" then
    return params
  end
  repeat
    local visibility = "public"
    if self:current().kind == "keyword" then
      local kw = self:current().value
      if kw == "public" or kw == "private" or kw == "protected" then
        visibility = kw
        self:advance()
      end
    end
    local name = self:expect("name", nil, "expected class parameter name").value
    local default = nil
    if self:match("symbol", "=") then
      default = self:parse_expression()
    end
    params[#params + 1] = {
      kind = "ClassParam",
      name = name,
      default = default,
      visibility = visibility,
    }
  until not self:match("symbol", ",")
  return params
end

function Parser:parse_class_modifiers()
  local visibility = "public"
  local is_static = false
  local seen_visibility = false
  while self:current().kind == "keyword" do
    local kw = self:current().value
    if kw == "public" or kw == "private" or kw == "protected" then
      if seen_visibility then
        self:error(self:current(), "duplicate visibility modifier")
      end
      visibility = kw
      seen_visibility = true
      self:advance()
    elseif kw == "static" then
      if is_static then
        self:error(self:current(), "duplicate 'static' modifier")
      end
      is_static = true
      self:advance()
    else
      break
    end
  end
  return visibility, is_static
end

function Parser:is_class_member_start(tok)
  if tok.kind == "keyword" then
    local kw = tok.value
    return kw == "public"
      or kw == "private"
      or kw == "protected"
      or kw == "static"
      or kw == "prop"
      or kw == "fn"
      or kw == "get"
      or kw == "set"
  end
  return tok.kind == "name" and self:peek(1).kind == "symbol" and self:peek(1).value == "("
end

function Parser:parse_method_member(name, visibility, is_static, kind)
  self:expect("symbol", "(", "expected '(' after method name")
  local params = self:parse_params()
  self:expect("symbol", ")", "expected ')' after parameters")
  self.fn_depth = self.fn_depth + 1
  local body
  if self:match("symbol", "=") then
    body = { kind = "ExprBody", value = self:parse_expression() }
  else
    body = { kind = "BlockBody", body = self:parse_block() }
    self:expect("keyword", "end", "expected 'end' to close method")
  end
  self.fn_depth = self.fn_depth - 1
  return {
    kind = kind,
    name = name,
    params = params,
    body = body,
    visibility = visibility,
    static = is_static,
  }
end

function Parser:parse_class_member()
  local visibility, is_static = self:parse_class_modifiers()
  local tok = self:current()
  if tok.kind == "name" and self:peek(1).kind == "symbol" and self:peek(1).value == "(" then
    local name = self:advance().value
    local kind = name == "init" and "Constructor" or "Method"
    return self:parse_method_member(name, visibility, is_static, kind)
  end
  if tok.kind ~= "keyword" then
    self:error(tok, "expected class member")
  end
  if tok.value == "prop" then
    self:advance()
    local name = self:expect("name", nil, "expected property name").value
    local value = nil
    if self:match("symbol", "=") then
      value = self:parse_expression()
    end
    return {
      kind = "Property",
      name = name,
      value = value,
      visibility = visibility,
      static = is_static,
    }
  elseif tok.value == "fn" then
    self:advance()
    local member = self:parse_fn(true)
    member.kind = "Method"
    member.exported = nil
    member.local_default = nil
    member.visibility = visibility
    member.static = is_static
    return member
  elseif tok.value == "get" or tok.value == "set" then
    local accessor_kind = tok.value
    self:advance()
    return self:parse_accessor(accessor_kind, visibility, is_static)
  end
  self:error(tok, "expected property, method, or accessor")
end

function Parser:parse_accessor(accessor_kind, visibility, is_static)
  local name = self:expect("name", nil, "expected accessor name").value
  self:expect("symbol", "(", "expected '(' after accessor name")
  local params = self:parse_params()
  self:expect("symbol", ")", "expected ')' after accessor parameters")

  if accessor_kind == "get" and #params > 0 then
    self:error(self:current(), "getter cannot declare parameters")
  end
  if accessor_kind == "set" and (#params ~= 1 or params[1].kind ~= "Param") then
    self:error(self:current(), "setter must declare exactly one parameter")
  end

  self.fn_depth = self.fn_depth + 1
  local body
  if self:match("symbol", "=") then
    body = { kind = "ExprBody", value = self:parse_expression() }
  else
    body = { kind = "BlockBody", body = self:parse_block() }
    self:expect("keyword", "end", "expected 'end' to close accessor")
  end
  self.fn_depth = self.fn_depth - 1

  return {
    kind = accessor_kind == "get" and "Getter" or "Setter",
    name = name,
    params = params,
    body = body,
    visibility = visibility,
    static = is_static,
  }
end

function Parser:parse_fn(is_statement)
  local start_tok = self.last_token or self:current()
  local name = nil
  if is_statement and self:current().kind == "name" then
    name = self:advance().value
  elseif is_statement then
    self:error(self:current(), "expected function name")
  end
  self:expect("symbol", "(", "expected '(' after fn")
  local params = self:parse_params()
  self:expect("symbol", ")", "expected ')' after parameters")
  self.fn_depth = self.fn_depth + 1
  local body
  if self:match("symbol", "=") then
    body = { kind = "ExprBody", value = self:parse_expression() }
  else
    body = { kind = "BlockBody", body = self:parse_block() }
    self:expect("keyword", "end", "expected 'end' to close fn")
  end
  self.fn_depth = self.fn_depth - 1
  return {
    kind = name and "FnDecl" or "FnExpr",
    name = name,
    source = self.source,
    decl_line = start_tok.line,
    decl_col = start_tok.col,
    params = params,
    body = body,
    exported = name and false or nil,
    local_default = name and true or nil,
  }
end

function Parser:parse_param_list(terminator)
  local params = {}
  local seen_rest = false
  local seen_kwrest = false
  local seen_block = false
  local seen_vararg = false
  if self:current().kind == "symbol" and self:current().value == terminator then
    return params
  end
  repeat
    if self:match("symbol", "&") then
      if seen_block then
        self:error(self:current(), "duplicate block parameter")
      end
      if seen_vararg then
        self:error(self:current(), "no parameters allowed after vararg parameter")
      end
      params[#params + 1] = { kind = "BlockParam", name = self:expect("name", nil, "expected block parameter name").value }
      seen_block = true
      break
    elseif self:match("symbol", "...") then
      if seen_rest or seen_kwrest then
        self:error(self:current(), "duplicate vararg parameter")
      end
      params[#params + 1] = { kind = "VarargParam" }
      seen_rest = true
      seen_vararg = true
      break
    elseif self:match("symbol", "**") then
      if seen_kwrest then
        self:error(self:current(), "duplicate keyword-rest parameter")
      end
      if seen_block then
        self:error(self:current(), "no parameters allowed after block parameter")
      end
      if seen_vararg then
        self:error(self:current(), "no parameters allowed after vararg parameter")
      end
      params[#params + 1] = { kind = "KwrestParam", name = self:expect("name", nil, "expected parameter name").value }
      seen_kwrest = true
    elseif self:match("symbol", "*") then
      if seen_rest or seen_kwrest then
        self:error(self:current(), "duplicate rest parameter")
      end
      if seen_block then
        self:error(self:current(), "no parameters allowed after block parameter")
      end
      if seen_vararg then
        self:error(self:current(), "no parameters allowed after vararg parameter")
      end
      params[#params + 1] = { kind = "RestParam", name = self:expect("name", nil, "expected parameter name").value }
      seen_rest = true
    else
      if seen_kwrest then
        self:error(self:current(), "no parameters allowed after keyword-rest parameter")
      end
      if seen_block then
        self:error(self:current(), "no parameters allowed after block parameter")
      end
      if seen_vararg then
        self:error(self:current(), "no parameters allowed after vararg parameter")
      end
      local name = self:expect("name", nil, "expected parameter name").value
      local default = nil
      if self:match("symbol", "=") then
        default = self:parse_expression()
      end
      params[#params + 1] = { kind = "Param", name = name, default = default }
    end
  until not self:match("symbol", ",")
  return params
end

function Parser:parse_params()
  return self:parse_param_list(")")
end

function Parser:parse_assignment_or_expr()
  if self:current().kind == "symbol" and (self:current().value == "[" or self:current().value == "{") then
    local pattern = self:parse_binding_pattern()
    self:expect("symbol", "=", "expected '=' in destructuring assignment")
    local values = self:parse_expr_list()
    return self:with_postfix_condition({
      kind = "DestructureAssign",
      pattern = pattern,
      values = values,
      local_default = true,
    })
  end
  local expr = self:parse_suffixed_expression()
  if self:is_assignable(expr) and ((self:current().kind == "symbol" and self:current().value == "=") or (self:current().kind == "symbol" and self:current().value == ",")) then
    local targets = { expr }
    while self:match("symbol", ",") do
      local target = self:parse_suffixed_expression()
      if not self:is_assignable(target) then
        self:error(self:current(), "expected assignable target")
      end
      targets[#targets + 1] = target
    end
    self:expect("symbol", "=", "expected '=' in assignment")
    local values = self:parse_expr_list()
    return self:with_postfix_condition({ kind = "Assign", targets = targets, values = values, local_default = true })
  end
  if self:is_require_call(expr) then
    local path = expr.args[1].value.value
    local bind = self:implicit_require_name(path)
    if not bind then
      self:error(expr.args[1].value, "require path needs explicit assignment because it does not map to a valid identifier")
    end
    return self:with_postfix_condition({
      kind = "ImplicitRequire",
      module = path,
      bind = bind,
    })
  end
  return self:with_postfix_condition({ kind = "ExprStmt", expression = expr })
end

function Parser:is_assignable(expr)
  return expr.kind == "Name" or expr.kind == "Member" or expr.kind == "Index"
end

function Parser:is_require_call(expr)
  if expr.kind ~= "Call" then
    return false
  end
  if expr.callee.kind ~= "Name" or expr.callee.value ~= "require" then
    return false
  end
  if #expr.args ~= 1 or expr.args[1].kind ~= "PosArg" then
    return false
  end
  return expr.args[1].value.kind == "String"
end

function Parser:implicit_require_name(path)
  local leaf = path:match("([^/]+)$") or path
  leaf = leaf:gsub("%.jpl$", ""):gsub("%.lua$", "")
  leaf = leaf:gsub("[-_]+([A-Za-z0-9])", function(ch)
    return ch:upper()
  end)
  if leaf:match("^[A-Za-z_][A-Za-z0-9_]*$") then
    return leaf
  end
  return nil
end

function Parser:parse_expr_list()
  local list = { self:parse_expression() }
  while self:match("symbol", ",") do
    list[#list + 1] = self:parse_expression()
  end
  return list
end

function Parser:parse_expression(min_prec)
  min_prec = min_prec or 0
  local expr = self:parse_prefix()
  while true do
    local tok = self:current()
    local op = tok.value
    local prec = (tok.kind == "keyword" or tok.kind == "symbol") and PRECEDENCE[op] or nil
    if not prec or prec < min_prec then
      break
    end
    self:advance()
    if op == "&&" then
      op = "and"
    elseif op == "||" then
      op = "or"
    elseif op == "!=" then
      op = "~="
    end
    local next_min = RIGHT_ASSOC[op] and prec or (prec + 1)
    local rhs = self:parse_expression(next_min)
    expr = { kind = "Binary", op = op, left = expr, right = rhs }
  end
  if min_prec == 0 and self:current().kind == "symbol" and (self:current().value == ".." or self:current().value == "...") then
    local inclusive = self:advance().value == ".."
    expr = {
      kind = "Range",
      start = expr,
      ["end"] = self:parse_expression(1),
      inclusive = inclusive,
    }
  end
  return expr
end

function Parser:is_statement_quote_start(tok)
  if tok.kind == "keyword" then
    local kw = tok.value
    return kw == "break"
      or kw == "case"
      or kw == "class"
      or kw == "export"
      or kw == "fn"
      or kw == "if"
      or kw == "local"
      or kw == "macro"
      or kw == "return"
      or kw == "unless"
  end
  if tok.kind == "name" then
    local next_tok = self:peek(1)
    return next_tok.kind == "symbol" and (next_tok.value == "=" or next_tok.value == ",")
  end
  return false
end

function Parser:parse_quasiquote()
  local next_tok = self:current()
  if self:is_statement_quote_start(next_tok) then
    return { kind = "QuasiQuote", value = self:parse_statement() }
  end
  return { kind = "QuasiQuote", value = self:parse_expression(8) }
end

function Parser:parse_quote_call()
  self:expect("symbol", "(", "expected '(' after quote")
  local next_tok = self:current()
  local value
  if self:is_statement_quote_start(next_tok) then
    value = self:parse_statement()
  else
    value = self:parse_expression()
  end
  self:expect("symbol", ")", "expected ')' after quote")
  return { kind = "QuasiQuote", value = value }
end

function Parser:parse_unquote_call(kind_name)
  self:expect("symbol", "(", "expected '(' after " .. kind_name)
  local value = self:parse_expression()
  self:expect("symbol", ")", "expected ')' after " .. kind_name)
  return { kind = (kind_name == "splice" or kind_name == "_s") and "UnquoteSplice" or "Unquote", value = value }
end

function Parser:parse_prefix()
  local tok = self:current()
  if tok.kind == "keyword" and tok.value == "not" then
    self:advance()
    return { kind = "Unary", op = "not", value = self:parse_expression(8) }
  elseif tok.kind == "symbol" and tok.value == "!" then
    self:advance()
    return { kind = "Unary", op = "not", value = self:parse_expression(8) }
  elseif tok.kind == "symbol" and tok.value == "~" then
    self:advance()
    return { kind = "Unary", op = "~", value = self:parse_expression(8) }
  elseif tok.kind == "symbol" and tok.value == "#" then
    self:advance()
    return { kind = "Unary", op = "#", value = self:parse_expression(8) }
  elseif tok.kind == "symbol" and tok.value == "-" then
    self:advance()
    return { kind = "Unary", op = "-", value = self:parse_expression(8) }
  elseif tok.kind == "symbol" and tok.value == "`" then
    self:advance()
    return self:parse_quasiquote()
  elseif tok.kind == "symbol" and tok.value == "," then
    self:advance()
    if self:match("symbol", "@") then
      return { kind = "UnquoteSplice", value = self:parse_expression(8) }
    end
    return { kind = "Unquote", value = self:parse_expression(8) }
  elseif tok.kind == "symbol" and tok.value == "@" then
    self:advance()
    return { kind = "UnquoteSplice", value = self:parse_expression(8) }
  end
  return self:parse_suffixed_expression()
end

function Parser:parse_suffixed_expression()
  local expr = self:parse_primary()
  while true do
    if self:match("symbol", ".") then
      expr = { kind = "Member", object = expr, name = self:expect("name", nil, "expected member name").value }
    elseif self:match("symbol", "?") then
      if self:match("symbol", ".") then
        expr = { kind = "SafeMember", object = expr, name = self:expect("name", nil, "expected member name").value }
      elseif self:match("symbol", "[") then
        local index = self:parse_expression()
        self:expect("symbol", "]", "expected ']'")
        expr = { kind = "SafeIndex", object = expr, index = index }
      elseif self:current().kind == "symbol" and self:current().value == "(" then
        expr = { kind = "SafeCall", callee = expr, args = self:parse_call_args() }
      elseif self:match("symbol", ":") then
        local method = self:expect("name", nil, "expected method name").value
        local args = self:parse_call_args()
        expr = { kind = "SafeMethodCall", callee = expr, method = method, args = args }
      else
        self:error(self:current(), "expected '.', '[', ':', or '(' after '?'")
      end
    elseif self:match("symbol", "[") then
      local index = self:parse_expression()
      self:expect("symbol", "]", "expected ']'")
      expr = { kind = "Index", object = expr, index = index }
    elseif self:match("symbol", ":") then
      local method = self:expect("name", nil, "expected method name").value
      local args = self:parse_call_args()
      expr = { kind = "MethodCall", callee = expr, method = method, args = args }
    elseif self:current().kind == "symbol" and self:current().value == "(" then
      local args = self:parse_call_args()
      if expr.kind == "Name" and self.class_names[expr.value] then
        expr = { kind = "NewExpr", class = expr, args = args }
      elseif expr.kind == "SafeMember" or expr.kind == "SafeIndex" then
        expr = { kind = "SafeCall", callee = expr, args = args }
      else
        expr = { kind = "Call", callee = expr, args = args }
      end
    else
      break
    end
  end
  if self:current().kind == "keyword" and self:current().value == "do" then
    if expr.kind ~= "Call" and expr.kind ~= "MethodCall" and expr.kind ~= "SafeCall" and expr.kind ~= "SafeMethodCall" then
      self:error(self:current(), "do-block must follow a call")
    end
    if expr.block then
      self:error(self:current(), "call already has a trailing block")
    end
    expr.block = self:parse_do_block()
  end
  return expr
end

function Parser:parse_do_block()
  self:expect("keyword", "do")
  local params = nil
  if self:match("symbol", "|") then
    params = self:parse_param_list("|")
    self:expect("symbol", "|", "expected '|' after block parameters")
  end
  local body = self:parse_block()
  self:expect("keyword", "end", "expected 'end' to close block")
  return {
    kind = "BlockArg",
    params = params or {},
    body = { kind = "BlockBody", body = body },
  }
end

function Parser:parse_named_arg_label()
  local first = self:current()
  if first.kind ~= "name" and first.kind ~= "keyword" then
    return nil
  end

  local parts = { first.value }
  local offset = 1
  while self:peek(offset).kind == "symbol" and self:peek(offset).value == "-" do
    local part = self:peek(offset + 1)
    if part.kind ~= "name" and part.kind ~= "keyword" then
      return nil
    end
    parts[#parts + 1] = part.value
    offset = offset + 2
  end

  local eq = self:peek(offset)
  if eq.kind ~= "symbol" or eq.value ~= "=" then
    return nil
  end

  parts = { self:advance().value }
  while self:match("symbol", "-") do
    local segment = self:current()
    if segment.kind ~= "name" and segment.kind ~= "keyword" then
      self:error(segment, "expected attribute name segment")
    end
    parts[#parts + 1] = self:advance().value
  end
  self:expect("symbol", "=", "expected '=' after named argument label")
  return table.concat(parts, "-")
end

function Parser:parse_call_args()
  local args = {}
  self:expect("symbol", "(", "expected '(' for call")
  if not self:match("symbol", ")") then
    repeat
      local name = self:parse_named_arg_label()
      if name then
        args[#args + 1] = { kind = "NamedArg", name = name, value = self:parse_expression() }
      else
        args[#args + 1] = { kind = "PosArg", value = self:parse_expression() }
      end
    until not self:match("symbol", ",")
    self:expect("symbol", ")", "expected ')'")
  end
  return args
end

function Parser:parse_primary()
  local tok = self:current()
  if tok.kind == "number" then
    self:advance()
    return { kind = "Number", value = tonumber(tok.value) }
  elseif tok.kind == "string" then
    self:advance()
    return { kind = "String", value = tok.value }
  elseif tok.kind == "interp_string" then
    self:advance()
    local parts = {}
    for _, part in ipairs(tok.value or {}) do
      if type(part) == "string" then
        parts[#parts + 1] = { kind = "String", value = part }
      else
        parts[#parts + 1] = JPL.parse_interpolation_expr(part.source, self.source)
      end
    end
    return { kind = "InterpolatedString", parts = parts }
  elseif tok.kind == "name" then
    if (tok.value == "quote" or tok.value == "_q") and self:peek(1).kind == "symbol" and self:peek(1).value == "(" then
      self:advance()
      return self:parse_quote_call()
    elseif (tok.value == "unquote" or tok.value == "_u" or tok.value == "splice" or tok.value == "_s")
        and self:peek(1).kind == "symbol" and self:peek(1).value == "(" then
      local kind_name = self:advance().value
      return self:parse_unquote_call(kind_name)
    end
    self:advance()
    if tok.value == "t" then
      return { kind = "Boolean", value = true }
    end
    return { kind = "Name", value = tok.value }
  elseif tok.kind == "keyword" then
    if tok.value == "true" or tok.value == "false" then
      self:advance()
      return { kind = "Boolean", value = tok.value == "true" }
    elseif tok.value == "nil" then
      self:advance()
      return { kind = "Nil" }
    elseif tok.value == "super" then
      self:advance()
      return { kind = "Super" }
    elseif tok.value == "fn" then
      self:advance()
      return self:parse_fn(false)
    elseif tok.value == "macro" then
      self:advance()
      return self:parse_macro(false)
    elseif tok.value == "yield" then
      return self:parse_yield()
    end
  elseif tok.kind == "symbol" and tok.value == "(" then
    self:advance()
    local expr = self:parse_expression()
    self:expect("symbol", ")", "expected ')'")
    return expr
  elseif tok.kind == "symbol" and tok.value == "[" then
    return self:parse_array()
  elseif tok.kind == "symbol" and tok.value == "{" then
    return self:parse_brace_literal()
  end
  self:error(tok, "unexpected token " .. tok.value)
end

function Parser:parse_yield()
  self:expect("keyword", "yield")
  local args = {}
  local tok = self:current()
  local stops = {
    [")"] = true,
    ["]"] = true,
    ["}"] = true,
    [";"] = true,
    [","] = true,
  }
  local stop_keywords = {
    ["do"] = true,
    ["else"] = true,
    ["elsif"] = true,
    ["end"] = true,
    ["if"] = true,
    ["then"] = true,
    ["unless"] = true,
    ["when"] = true,
  }
  if tok.kind == "symbol" and tok.value == "(" then
    args = self:parse_call_args()
  elseif not (tok.kind == "eof"
      or (tok.kind == "symbol" and stops[tok.value])
      or (tok.kind == "keyword" and stop_keywords[tok.value])) then
    args = self:parse_expr_list()
  end
  return { kind = "Yield", args = args }
end

function Parser:parse_array()
  local elements = {}
  self:expect("symbol", "[")
  if not self:match("symbol", "]") then
    repeat
      elements[#elements + 1] = self:parse_expression()
    until not self:match("symbol", ",")
    self:expect("symbol", "]", "expected ']'")
  end
  return { kind = "Array", elements = elements }
end

function Parser:parse_brace_literal()
  local fields = {}
  self:expect("symbol", "{")
  while not self:match("symbol", "}") do
    if self:current().kind == "name" and self:peek(1).kind == "symbol" and self:peek(1).value == "=" then
      local name = self:advance().value
      self:advance()
      fields[#fields + 1] = { kind = "Field", name = name, value = self:parse_expression() }
    elseif self:current().kind == "name" and self:peek(1).kind == "symbol" and self:peek(1).value == ":" then
      self:error(self:peek(1), "use '=' for hash entries; ':' hash syntax is not supported")
    else
      fields[#fields + 1] = { kind = "Value", value = self:parse_expression() }
    end
    self:match("symbol", ",")
    self:match("symbol", ";")
  end
  return { kind = "Table", fields = fields }
end

function JPL.parse(input, source)
  local tokens = JPL.lex(input, source)
  local parser = Parser.new(tokens, source)
  return parser:parse_program()
end

function JPL.parse_interpolation_expr(input, source)
  local tokens = JPL.lex(input, source)
  local parser = Parser.new(tokens, source)
  local expr = parser:parse_expression()
  parser:expect("eof")
  return expr
end

local function clone_node(node)
  if type(node) ~= "table" then
    return node
  end
  local out = {}
  for key, value in pairs(node) do
    out[key] = clone_node(value)
  end
  return out
end

local function macro_value_to_ast(value)
  if type(value) == "table" and value.kind then
    return clone_node(value)
  elseif value == nil then
    return { kind = "Nil" }
  elseif type(value) == "boolean" then
    return { kind = "Boolean", value = value }
  elseif type(value) == "number" then
    return { kind = "Number", value = value }
  elseif type(value) == "string" then
    return { kind = "String", value = value }
  elseif type(value) == "table" then
    local is_array = true
    local max_index = 0
    for key in pairs(value) do
      if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
        is_array = false
        break
      end
      if key > max_index then
        max_index = key
      end
    end
    if is_array then
      local elements = {}
      for i = 1, max_index do
        elements[i] = macro_value_to_ast(value[i])
      end
      return { kind = "Array", elements = elements }
    end
    local fields = {}
    for key, item in pairs(value) do
      fields[#fields + 1] = {
        kind = "Field",
        name = tostring(key),
        value = macro_value_to_ast(item),
      }
    end
    table.sort(fields, function(a, b) return a.name < b.name end)
    return { kind = "Table", fields = fields }
  end
  error("cannot convert macro value to AST: " .. type(value), 0)
end

local function splice_values(value)
  if type(value) == "table" and value.kind == "Array" then
    local out = {}
    for i, item in ipairs(value.elements or {}) do
      out[i] = clone_node(item)
    end
    return out
  elseif type(value) == "table" and value.kind == nil then
    local out = {}
    for i, item in ipairs(value) do
      out[i] = macro_value_to_ast(item)
    end
    return out
  end
  error("macro splice expects an array of AST nodes", 0)
end

local macro_value_to_name

local function qq_visit(node, env, list_mode)
  if type(node) ~= "table" then
    return clone_node(node)
  end
  if (node.kind == "MacroDecl" or node.kind == "FnDecl" or node.kind == "ClassDecl")
      and type(node.name) == "string" and env[node.name] ~= nil then
    local out = clone_node(node)
    out.name = macro_value_to_name(env[node.name])
    if out.body then
      out.body = qq_visit(out.body, env, false)
    end
    if out.params then
      out.params = qq_visit(out.params, env, true)
    end
    return out
  end
  if node.kind == "Name" and env[node.value] ~= nil then
    return macro_value_to_ast(env[node.value])
  end
  if node.kind == "Unquote" then
    if node.value.kind ~= "Name" then
      error("macro unquote expects a parameter name", 0)
    end
    local value = env[node.value.value]
    if value == nil then
      error("unknown macro parameter: " .. node.value.value, 0)
    end
    return macro_value_to_ast(value)
  elseif node.kind == "UnquoteSplice" then
    if not list_mode then
      error("macro splice is only allowed in list positions", 0)
    end
    if node.value.kind ~= "Name" then
      error("macro splice expects a parameter name", 0)
    end
    local value = env[node.value.value]
    if value == nil then
      error("unknown macro parameter: " .. node.value.value, 0)
    end
    return { __splice = true, values = splice_values(value) }
  end

  local out = {}
  for key, value in pairs(node) do
    if type(value) == "table" and value[1] ~= nil then
      local items = {}
      for _, item in ipairs(value) do
        local expanded = qq_visit(item, env, true)
        if type(expanded) == "table" and expanded.__splice then
          for _, spliced in ipairs(expanded.values) do
            items[#items + 1] = spliced
          end
        else
          items[#items + 1] = expanded
        end
      end
      out[key] = items
    else
      out[key] = qq_visit(value, env, false)
    end
  end
  return out
end

local function macro_expand_quote(node, env)
  if node.kind ~= "QuasiQuote" then
    return qq_visit(node, env, false)
  end
  return qq_visit(node.value, env, false)
end

macro_value_to_name = function(value)
  if type(value) == "string" then
    return value
  elseif type(value) == "table" and value.kind == "String" then
    return value.value
  elseif type(value) == "table" and value.kind == "Name" then
    return value.value
  end
  error("macro name interpolation expects a string-like value", 0)
end

local MacroRuntime = {}
MacroRuntime.__index = MacroRuntime

function MacroRuntime.new(env)
  return setmetatable({
    scopes = { env or {} },
  }, MacroRuntime)
end

function MacroRuntime:error(msg)
  error("Jaya macro error: " .. msg, 0)
end

function MacroRuntime:push_scope(bindings)
  self.scopes[#self.scopes + 1] = bindings or {}
end

function MacroRuntime:pop_scope()
  self.scopes[#self.scopes] = nil
end

function MacroRuntime:snapshot_env()
  local env = {}
  for i = 1, #self.scopes do
    for key, value in pairs(self.scopes[i]) do
      env[key] = value
    end
  end
  return env
end

function MacroRuntime:lookup(name)
  for i = #self.scopes, 1, -1 do
    local scope = self.scopes[i]
    if scope[name] ~= nil then
      return scope[name]
    end
  end
  self:error("unknown macro variable: " .. tostring(name))
end

function MacroRuntime:assign(name, value)
  for i = #self.scopes, 1, -1 do
    local scope = self.scopes[i]
    if scope[name] ~= nil then
      scope[name] = value
      return
    end
  end
  self.scopes[#self.scopes][name] = value
end

function MacroRuntime:declare(name, value)
  self.scopes[#self.scopes][name] = value
end

function MacroRuntime:is_truthy(value)
  return value ~= nil and value ~= false
end

function MacroRuntime:eval_expr(node)
  if type(node) ~= "table" or not node.kind then
    return node
  end
  if node.kind == "Number" or node.kind == "String" or node.kind == "Boolean" then
    return node.value
  elseif node.kind == "InterpolatedString" then
    local out = ""
    for _, part in ipairs(node.parts or {}) do
      out = out .. tostring(self:eval_expr(part))
    end
    return out
  elseif node.kind == "Nil" then
    return nil
  elseif node.kind == "Name" then
    return self:lookup(node.value)
  elseif node.kind == "Unary" then
    local value = self:eval_expr(node.value)
    if node.op == "not" then
      return not self:is_truthy(value)
    elseif node.op == "-" then
      return -value
    elseif node.op == "~" then
      return ~value
    elseif node.op == "#" then
      return #value
    end
    self:error("unsupported macro unary operator: " .. tostring(node.op))
  elseif node.kind == "Binary" then
    if node.op == "and" then
      local left = self:eval_expr(node.left)
      if not self:is_truthy(left) then
        return left
      end
      return self:eval_expr(node.right)
    elseif node.op == "or" then
      local left = self:eval_expr(node.left)
      if self:is_truthy(left) then
        return left
      end
      return self:eval_expr(node.right)
    end
    local left = self:eval_expr(node.left)
    local right = self:eval_expr(node.right)
    if node.op == "+" then
      if type(left) == "string" or type(right) == "string" then
        return tostring(left) .. tostring(right)
      end
      return left + right
    elseif node.op == "-" then
      return left - right
    elseif node.op == "*" then
      return left * right
    elseif node.op == "/" then
      return left / right
    elseif node.op == "//" then
      return left // right
    elseif node.op == "%" then
      return left % right
    elseif node.op == "^" then
      return left ^ right
    elseif node.op == "~" then
      return left ~ right
    elseif node.op == "==" then
      return left == right
    elseif node.op == "~=" then
      return left ~= right
    elseif node.op == "<" then
      return left < right
    elseif node.op == "<=" then
      return left <= right
    elseif node.op == ">" then
      return left > right
    elseif node.op == ">=" then
      return left >= right
    end
    self:error("unsupported macro binary operator: " .. tostring(node.op))
  elseif node.kind == "Array" then
    local out = {}
    for i, item in ipairs(node.elements or {}) do
      out[i] = self:eval_expr(item)
    end
    return out
  elseif node.kind == "Table" then
    local out = {}
    local index = 1
    for _, field in ipairs(node.fields or {}) do
      if field.kind == "Field" then
        out[field.name] = self:eval_expr(field.value)
      else
        out[index] = self:eval_expr(field.value)
        index = index + 1
      end
    end
    return out
  elseif node.kind == "Index" then
    local value = self:eval_expr(node.object)
    local index = self:eval_expr(node.index)
    if type(index) == "table" and index.first ~= nil and index.last ~= nil and index.inclusive ~= nil then
      if type(value) == "string" then
        local len = #value
        local start_idx = index.first < 0 and (len + index.first + 1) or index.first
        local end_idx = index.last < 0 and (len + index.last + 1) or index.last
        if not index.inclusive then
          end_idx = end_idx - 1
        end
        if start_idx > end_idx then
          return ""
        end
        return string.sub(value, start_idx, end_idx)
      elseif type(value) == "table" then
        local is_array_value = true
        local n = 0
        for k in pairs(value) do
          if type(k) ~= "number" then
            is_array_value = false
            break
          end
          if k > n then
            n = k
          end
        end
        if is_array_value then
          for i = 1, n do
            if value[i] == nil then
              is_array_value = false
              break
            end
          end
        end
        if is_array_value then
          local start_idx = index.first < 0 and (n + index.first + 1) or index.first
          local end_idx = index.last < 0 and (n + index.last + 1) or index.last
          if not index.inclusive then
            end_idx = end_idx - 1
          end
          local out = {}
          local next_i = 1
          for i = start_idx, end_idx do
            out[next_i] = value[i]
            next_i = next_i + 1
          end
          return out
        end
      end
    end
    if type(value) == "string" and type(index) == "number" and index % 1 == 0 then
      local idx = index < 0 and (#value + index + 1) or index
      return string.sub(value, idx, idx)
    elseif type(value) == "table" and type(index) == "number" and index % 1 == 0 then
      local is_array_value = true
      local n = 0
      for k in pairs(value) do
        if type(k) ~= "number" then
          is_array_value = false
          break
        end
        if k > n then
          n = k
        end
      end
      if is_array_value then
        for i = 1, n do
          if value[i] == nil then
            is_array_value = false
            break
          end
        end
      end
      if is_array_value and index < 0 then
        return value[n + index + 1]
      end
    end
    return value[index]
  elseif node.kind == "Member" then
    return self:eval_expr(node.object)[node.name]
  elseif node.kind == "QuasiQuote" then
    return macro_expand_quote(node, self:snapshot_env())
  end
  self:error("unsupported macro expression: " .. tostring(node.kind))
end

function MacroRuntime:assign_target(target, value)
  if target.kind == "Name" then
    self:assign(target.value, value)
  elseif target.kind == "Index" then
    self:eval_expr(target.object)[self:eval_expr(target.index)] = value
  elseif target.kind == "Member" then
    self:eval_expr(target.object)[target.name] = value
  else
    self:error("unsupported macro assignment target: " .. tostring(target.kind))
  end
end

function MacroRuntime:eval_stmt(node)
  if node.kind == "ExprStmt" then
    self:eval_expr(node.expression)
  elseif node.kind == "Assign" then
    local values = {}
    for i, value in ipairs(node.values or {}) do
      values[i] = self:eval_expr(value)
    end
    for i, target in ipairs(node.targets or {}) do
      self:assign_target(target, values[i])
    end
  elseif node.kind == "LocalAssign" then
    local values = {}
    for i, value in ipairs(node.values or {}) do
      values[i] = self:eval_expr(value)
    end
    for i, pattern in ipairs(node.names or {}) do
      if pattern.kind ~= "PatternName" then
        self:error("unsupported macro local binding pattern: " .. tostring(pattern.kind))
      end
      self:declare(pattern.name, values[i])
    end
  elseif node.kind == "Return" then
    local values = {}
    for i, value in ipairs(node.values or {}) do
      values[i] = self:eval_expr(value)
    end
    error({ __macro_return = true, values = values }, 0)
  elseif node.kind == "If" then
    for _, branch in ipairs(node.branches or {}) do
      if self:is_truthy(self:eval_expr(branch.condition)) then
        self:push_scope({})
        self:eval_block(branch.body or {})
        self:pop_scope()
        return
      end
    end
    if node.else_body then
      self:push_scope({})
      self:eval_block(node.else_body)
      self:pop_scope()
    end
  elseif node.kind == "Unless" then
    if not self:is_truthy(self:eval_expr(node.condition)) then
      self:push_scope({})
      self:eval_block(node.body or {})
      self:pop_scope()
    elseif node.else_body then
      self:push_scope({})
      self:eval_block(node.else_body)
      self:pop_scope()
    end
  elseif node.kind == "ForIn" then
    local iterable = self:eval_expr(node.iterable)
    if type(iterable) ~= "table" then
      self:error("macro for-in expects an iterable table")
    end
    local names = node.names or { node.name }
    if #names == 1 then
      local iterator, state, seed
      if iterable.first ~= nil and iterable.last ~= nil and iterable.inclusive ~= nil then
        local first = iterable.first
        local last = iterable.last
        local inclusive = iterable.inclusive
        local step = first <= last and 1 or -1
        iterator = function(_, current)
          local next_value = current + step
          if inclusive then
            if (step > 0 and next_value > last) or (step < 0 and next_value < last) then
              return nil
            end
          else
            if (step > 0 and next_value >= last) or (step < 0 and next_value <= last) then
              return nil
            end
          end
          return next_value, next_value
        end
        state = iterable
        seed = first - step
      elseif (function(value)
        local n = 0
        for k in pairs(value) do
          if type(k) ~= "number" then
            return false
          end
          if k > n then
            n = k
          end
        end
        for i = 1, n do
          if value[i] == nil then
            return false
          end
        end
        return true
      end)(iterable) then
        iterator, state, seed = ipairs(iterable)
      else
        iterator, state, seed = next, iterable, nil
      end
      while true do
        local key, value = iterator(state, seed)
        if key == nil then
          break
        end
        seed = key
        self:push_scope({ [names[1]] = value })
        self:eval_block(node.body or {})
        self:pop_scope()
      end
    else
      for key, value in pairs(iterable) do
        self:push_scope({ [names[1]] = key, [names[2]] = value })
        self:eval_block(node.body or {})
        self:pop_scope()
      end
    end
  elseif node.kind == "ConditionalStmt" then
    local ok = node.condition.kind == "IfCond"
      and self:is_truthy(self:eval_expr(node.condition.expr))
      or (node.condition.kind == "UnlessCond" and not self:is_truthy(self:eval_expr(node.condition.expr)))
    if ok then
      self:eval_stmt(node.statement)
    end
  else
    self:error("unsupported macro statement: " .. tostring(node.kind))
  end
end

function MacroRuntime:eval_block(body)
  for _, stmt in ipairs(body or {}) do
    self:eval_stmt(stmt)
  end
  return nil
end

local Expander = {}
Expander.__index = Expander

function Expander.new(macros)
  return setmetatable({ macros = macros or {} }, Expander)
end

function Expander:error(msg)
  error("Jaya macro error: " .. msg, 0)
end

function Expander:macro_params(params)
  local info = {
    positional = {},
    rest = nil,
    kwrest = nil,
    block = nil,
  }
  for _, param in ipairs(params or {}) do
    if param.kind == "Param" then
      info.positional[#info.positional + 1] = param.name
    elseif param.kind == "RestParam" then
      info.rest = param.name
    elseif param.kind == "KwrestParam" then
      info.kwrest = param.name
    elseif param.kind == "BlockParam" then
      info.block = param.name
    else
      self:error("unsupported macro parameter kind: " .. tostring(param.kind))
    end
  end
  return info
end

function Expander:expand_macro_call(macro, args)
  local env = {}
  local runtime_env = {}
  local params = self:macro_params(macro.params)
  local positional = {}
  local named = {}
  for _, arg in ipairs(args or {}) do
    if arg.kind == "PosArg" then
      positional[#positional + 1] = clone_node(arg.value)
    elseif arg.kind == "NamedArg" then
      named[arg.name] = clone_node(arg.value)
    else
      self:error("unsupported macro argument kind: " .. tostring(arg.kind))
    end
  end
  for i, name in ipairs(params.positional) do
    env[name] = positional[i]
    runtime_env[name] = clone_node(positional[i])
  end
  if #positional > #params.positional and not params.rest then
    self:error("too many macro arguments for " .. tostring(macro.name))
  end
  if params.rest then
    local rest = {}
    for i = #params.positional + 1, #positional do
      rest[#rest + 1] = positional[i]
    end
    env[params.rest] = { kind = "Array", elements = rest }
    runtime_env[params.rest] = clone_node(rest)
  end
  if params.kwrest then
    local fields = {}
    local table_value = {}
    for key, value in pairs(named) do
      fields[#fields + 1] = { kind = "Field", name = key, value = value }
      table_value[key] = clone_node(value)
    end
    table.sort(fields, function(a, b) return a.name < b.name end)
    env[params.kwrest] = { kind = "Table", fields = fields }
    runtime_env[params.kwrest] = table_value
  elseif next(named) ~= nil then
    local first = next(named)
    self:error("unknown named macro argument: " .. tostring(first))
  end
  if params.block then
    if args and args.block then
      env[params.block] = {
        kind = "FnExpr",
        params = clone_node(args.block.params or {}),
        body = clone_node(args.block.body),
      }
      runtime_env[params.block] = clone_node(env[params.block])
    else
      env[params.block] = { kind = "Nil" }
      runtime_env[params.block] = nil
    end
  elseif args and args.block then
    self:error("macro does not accept a trailing block: " .. tostring(macro.name))
  end
  local function normalize_macro_result(values)
    local count = values and #values or 0
    if count == 0 then
      return { kind = "Nil" }
    elseif count == 1 then
      return values[1]
    end
    return values
  end
  local runtime = MacroRuntime.new(runtime_env)
  if macro.body.kind == "ExprBody" then
    return normalize_macro_result({ runtime:eval_expr(macro.body.value) })
  end
  local explicit = {}
  local saw_explicit = false
  for _, stmt in ipairs(macro.body.body or {}) do
    if stmt.kind == "ExprStmt" and stmt.expression and stmt.expression.kind == "QuasiQuote" then
      saw_explicit = true
      explicit[#explicit + 1] = macro_expand_quote(stmt.expression, env)
    elseif stmt.kind == "Return" and #stmt.values == 1 and stmt.values[1].kind == "QuasiQuote" then
      saw_explicit = true
      explicit[#explicit + 1] = macro_expand_quote(stmt.values[1], env)
    else
      saw_explicit = false
      explicit = nil
      break
    end
  end
  if saw_explicit and explicit then
    return self:expand_block(explicit)
  end
  local ok, result = pcall(function()
    return runtime:eval_block(macro.body.body or {})
  end)
  if not ok then
    if type(result) == "table" and result.__macro_return then
      return normalize_macro_result(result.values or {})
    end
    error(result, 0)
  end
  return { kind = "Nil" }
end

function Expander:expand_expr(node)
  if type(node) ~= "table" or not node.kind then
    return node
  end
  if node.kind == "Call" and node.callee.kind == "Name" and self.macros[node.callee.value] then
    local args = clone_node(node.args or {})
    args.block = node.block and clone_node(node.block) or nil
    local expanded = self:expand_macro_call(self.macros[node.callee.value], args)
    if type(expanded) ~= "table" then
      self:error("macro " .. node.callee.value .. " did not expand to an AST node")
    end
    if expanded[1] ~= nil then
      self:error("statement macro " .. node.callee.value .. " cannot be used in expression position")
    end
    if not expanded.kind then
      self:error("macro " .. node.callee.value .. " did not expand to an AST node")
    end
    if expanded.kind == "ExprStmt" then
      expanded = expanded.expression
    end
    return self:expand_expr(expanded)
  end

  local out = clone_node(node)
  if out.kind == "Unary" then
    out.value = self:expand_expr(out.value)
  elseif out.kind == "Binary" then
    out.left = self:expand_expr(out.left)
    out.right = self:expand_expr(out.right)
  elseif out.kind == "Call" or out.kind == "SafeCall" then
    out.callee = self:expand_expr(out.callee)
    for i, arg in ipairs(out.args or {}) do
      if arg.kind == "PosArg" or arg.kind == "NamedArg" then
        out.args[i].value = self:expand_expr(arg.value)
      end
    end
  elseif out.kind == "MethodCall" or out.kind == "SafeMethodCall" then
    out.callee = self:expand_expr(out.callee)
    for i, arg in ipairs(out.args or {}) do
      if arg.kind == "PosArg" or arg.kind == "NamedArg" then
        out.args[i].value = self:expand_expr(arg.value)
      end
    end
  elseif out.kind == "Member" then
    out.object = self:expand_expr(out.object)
  elseif out.kind == "Index" or out.kind == "SafeIndex" then
    out.object = self:expand_expr(out.object)
    out.index = self:expand_expr(out.index)
  elseif out.kind == "Array" then
    for i, item in ipairs(out.elements or {}) do
      out.elements[i] = self:expand_expr(item)
    end
  elseif out.kind == "Table" then
    for i, field in ipairs(out.fields or {}) do
      if field.value then
        out.fields[i].value = self:expand_expr(field.value)
      end
    end
  elseif out.kind == "FnExpr" then
    out.body = self:expand_body(out.body)
  elseif out.kind == "Range" then
    out.start = self:expand_expr(out.start)
    out["end"] = self:expand_expr(out["end"])
  elseif out.kind == "Yield" then
    for i, arg in ipairs(out.args or {}) do
      if arg.kind == "PosArg" or arg.kind == "NamedArg" then
        out.args[i].value = self:expand_expr(arg.value)
      else
        out.args[i] = self:expand_expr(arg)
      end
    end
  end
  return out
end

function Expander:expand_body(body)
  if body.kind == "ExprBody" then
    return { kind = "ExprBody", value = self:expand_expr(body.value) }
  end
  return { kind = "BlockBody", body = self:expand_block(body.body or {}) }
end

function Expander:expand_stmt(node)
  if type(node) ~= "table" or not node.kind then
    return { node }
  end
  if node.kind == "ExprStmt" and node.expression.kind == "Call" and node.expression.callee.kind == "Name" and self.macros[node.expression.callee.value] then
    local call = node.expression
    local args = clone_node(call.args or {})
    args.block = call.block and clone_node(call.block) or nil
    local expanded = self:expand_macro_call(self.macros[call.callee.value], args)
    if type(expanded) ~= "table" then
      self:error("macro " .. node.expression.callee.value .. " did not expand to AST")
    end
    if expanded[1] ~= nil then
      return self:expand_block(expanded)
    end
    if not expanded.kind then
      self:error("macro " .. node.expression.callee.value .. " did not expand to an AST node")
    end
    if expanded.kind ~= "ExprStmt" and expanded.kind ~= "Assign" and expanded.kind ~= "LocalAssign" and expanded.kind ~= "ExportAssign"
        and expanded.kind ~= "Return" and expanded.kind ~= "If" and expanded.kind ~= "Unless"
        and expanded.kind ~= "Case" and expanded.kind ~= "Let" and expanded.kind ~= "Match" and expanded.kind ~= "Try"
        and expanded.kind ~= "Throw" and expanded.kind ~= "Break" and expanded.kind ~= "Go" and expanded.kind ~= "FnDecl"
        and expanded.kind ~= "ClassDecl" and expanded.kind ~= "MacroDecl" then
      expanded = { kind = "ExprStmt", expression = expanded }
    end
    return self:expand_stmt(expanded)
  end

  local out = clone_node(node)
  if out.kind == "Assign" or out.kind == "DestructureAssign" then
    for i, value in ipairs(out.values or {}) do
      out.values[i] = self:expand_expr(value)
    end
  elseif out.kind == "LocalAssign" then
    for i, value in ipairs(out.values or {}) do
      out.values[i] = self:expand_expr(value)
    end
  elseif out.kind == "ExportAssign" or out.kind == "ConstAssign" or out.kind == "ExportConstAssign" then
    for i, value in ipairs(out.values or {}) do
      out.values[i] = self:expand_expr(value)
    end
  elseif out.kind == "FnDecl" then
    out.body = self:expand_body(out.body)
  elseif out.kind == "ExprStmt" then
    out.expression = self:expand_expr(out.expression)
  elseif out.kind == "Return" then
    for i, value in ipairs(out.values or {}) do
      out.values[i] = self:expand_expr(value)
    end
    if out.condition then
      out.condition.expr = self:expand_expr(out.condition.expr)
    end
  elseif out.kind == "Break" then
    if out.condition then
      out.condition.expr = self:expand_expr(out.condition.expr)
    end
  elseif out.kind == "If" then
    for i, branch in ipairs(out.branches or {}) do
      if branch.condition.kind == "LetCond" then
        branch.condition.value = self:expand_expr(branch.condition.value)
      else
        branch.condition = self:expand_expr(branch.condition)
      end
      branch.body = self:expand_block(branch.body)
      out.branches[i] = branch
    end
    out.else_body = self:expand_block(out.else_body)
  elseif out.kind == "Unless" then
    if out.condition.kind == "LetCond" then
      out.condition.value = self:expand_expr(out.condition.value)
    else
      out.condition = self:expand_expr(out.condition)
    end
    out.body = self:expand_block(out.body)
    out.else_body = self:expand_block(out.else_body)
  elseif out.kind == "Case" then
    out.subject = self:expand_expr(out.subject)
    for i, clause in ipairs(out.whens or {}) do
      for j, value in ipairs(clause.values or {}) do
        clause.values[j] = self:expand_expr(value)
      end
      clause.body = self:expand_block(clause.body)
      out.whens[i] = clause
    end
    out.else_body = self:expand_block(out.else_body)
  elseif out.kind == "Match" then
    out.subject = self:expand_expr(out.subject)
    for i, clause in ipairs(out.whens or {}) do
      clause.body = self:expand_block(clause.body)
      out.whens[i] = clause
    end
    out.else_body = self:expand_block(out.else_body)
  elseif out.kind == "Let" then
    for i, binding in ipairs(out.bindings or {}) do
      binding.value = self:expand_expr(binding.value)
      out.bindings[i] = binding
    end
    out.body = self:expand_block(out.body)
  elseif out.kind == "Try" then
    out.body = self:expand_block(out.body)
    for i, clause in ipairs(out.catches or {}) do
      if clause.types then
        for j, value in ipairs(clause.types) do
          clause.types[j] = self:expand_expr(value)
        end
      end
      clause.body = self:expand_block(clause.body)
      out.catches[i] = clause
    end
    out.finally_body = self:expand_block(out.finally_body)
  elseif out.kind == "Throw" or out.kind == "Go" then
    out.value = self:expand_expr(out.value)
  elseif out.kind == "ConditionalStmt" then
    out.statement = self:expand_stmt(out.statement)[1]
    out.condition.expr = self:expand_expr(out.condition.expr)
  elseif out.kind == "ClassDecl" then
    for i, param in ipairs(out.params or {}) do
      if param.default then
        param.default = self:expand_expr(param.default)
      end
      out.params[i] = param
    end
    for i, base in ipairs(out.bases or {}) do
      out.bases[i] = self:expand_expr(base)
    end
    for i, member in ipairs(out.members or {}) do
      if member.value then
        member.value = self:expand_expr(member.value)
      end
      if member.body then
        member.body = self:expand_body(member.body)
      end
      out.members[i] = member
    end
  end
  return { out }
end

function Expander:expand_block(body)
  local out = {}
  for _, stmt in ipairs(body or {}) do
    local expanded = self:expand_stmt(stmt)
    for _, item in ipairs(expanded) do
      out[#out + 1] = item
    end
  end
  return out
end

function JPL.expand(ast)
  local macros = {}
  local pending = {}
  for _, stmt in ipairs(ast.body or {}) do
    if stmt.kind == "MacroDecl" then
      macros[stmt.name] = stmt
    else
      pending[#pending + 1] = stmt
    end
  end
  local expander = Expander.new(macros)
  local body = {}
  local index = 1
  while index <= #pending do
    local stmt = pending[index]
    local expanded = expander:expand_stmt(stmt)
    for _, item in ipairs(expanded) do
      if item.kind == "MacroDecl" then
        macros[item.name] = item
        expander.macros = macros
      else
        body[#body + 1] = item
      end
    end
    index = index + 1
  end
  return {
    kind = ast.kind,
    body = body,
  }
end

local LUA_PREAMBLE = [[
local __jaya_exports = rawget(_ENV, "__jaya_exports") or {}
rawset(__jaya_exports, "__jaya_kind", "module")
local __jaya_object_methods = rawget(_G, "__jaya_object_methods")
if __jaya_object_methods == nil then
  __jaya_object_methods = {}
  _G.__jaya_object_methods = __jaya_object_methods
end
local __jaya_module_cache = rawget(_G, "__jaya_module_cache")
if __jaya_module_cache == nil then
  __jaya_module_cache = {}
  _G.__jaya_module_cache = __jaya_module_cache
end
local __jaya_fn_meta = rawget(_G, "__jaya_fn_meta")
if __jaya_fn_meta == nil then
  __jaya_fn_meta = setmetatable({}, { __mode = "k" })
  _G.__jaya_fn_meta = __jaya_fn_meta
end
local __jaya_primitive_methods = rawget(_G, "__jaya_primitive_methods")
if __jaya_primitive_methods == nil then
  __jaya_primitive_methods = {
    string = {},
    number = {},
    array = {},
    table = {},
    boolean = {},
    ["function"] = {},
    class = {},
    module = {},
  }
  _G.__jaya_primitive_methods = __jaya_primitive_methods
end
local __jaya_new
local __jaya_pack_named_call
local __jaya_is_array
local __jaya_is_range
local __jaya_call_with_block
local __jaya_call_named_with_block
local __jaya_pack_block_call
local function __jaya_add(left, right)
  if type(left) == "string" or type(right) == "string" then
    return tostring(left) .. tostring(right)
  end
  return left + right
end
local function __jaya_range(first, last, inclusive)
  return { first = first, last = last, inclusive = inclusive }
end
local function __jaya_len(value)
  return #value
end
__jaya_is_range = function(value)
  return type(value) == "table"
    and rawget(value, "first") ~= nil
    and rawget(value, "last") ~= nil
    and rawget(value, "inclusive") ~= nil
end
local function __jaya_normalize_index(length, index)
  if type(index) ~= "number" or index % 1 ~= 0 then
    return index
  end
  if index < 0 then
    return length + index + 1
  end
  return index
end
local function __jaya_slice(value, range)
  local first = range.first
  local last = range.last
  local inclusive = range.inclusive
  if type(value) == "string" then
    local len = #value
    local start_idx = __jaya_normalize_index(len, first)
    local end_idx = __jaya_normalize_index(len, last)
    if type(start_idx) ~= "number" or type(end_idx) ~= "number" then
      return nil
    end
    if not inclusive then
      end_idx = end_idx - 1
    end
    if start_idx > end_idx then
      return ""
    end
    return string.sub(value, start_idx, end_idx)
  elseif __jaya_is_array(value) then
    local len = #value
    local start_idx = __jaya_normalize_index(len, first)
    local end_idx = __jaya_normalize_index(len, last)
    if type(start_idx) ~= "number" or type(end_idx) ~= "number" then
      return nil
    end
    if not inclusive then
      end_idx = end_idx - 1
    end
    local out = {}
    if start_idx > end_idx then
      return out
    end
    local next_i = 1
    for i = start_idx, end_idx do
      out[next_i] = value[i]
      next_i = next_i + 1
    end
    return out
  end
  return nil
end
local function __jaya_get_index(value, index)
  if __jaya_is_range(index) then
    local sliced = __jaya_slice(value, index)
    if sliced ~= nil then
      return sliced
    end
  end
  if type(value) == "string" then
    local idx = __jaya_normalize_index(#value, index)
    if type(idx) ~= "number" then
      return nil
    end
    return string.sub(value, idx, idx)
  elseif __jaya_is_array(value) then
    local idx = __jaya_normalize_index(#value, index)
    return value[idx]
  elseif value ~= nil then
    return value[index]
  end
  return nil
end
local function __jaya_iter(value)
  if __jaya_is_range(value) then
    local first = value.first
    local last = value.last
    local inclusive = value.inclusive
    local step = first <= last and 1 or -1
    local function iter(_, current)
      local next_value = current + step
      if inclusive then
        if (step > 0 and next_value > last) or (step < 0 and next_value < last) then
          return nil
        end
      else
        if (step > 0 and next_value >= last) or (step < 0 and next_value <= last) then
          return nil
        end
      end
      return next_value, next_value
    end
    return iter, value, first - step
  end
  if type(value) ~= "table" then
    error("for-in expects an iterable table or range", 0)
  end
  if __jaya_is_array(value) then
    return ipairs(value)
  end
  return next, value, nil
end
__jaya_is_array = function(value)
  if type(value) ~= "table" then
    return false
  end
  local max = 0
  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      return false
    end
    if key > max then
      max = key
    end
  end
  for i = 1, max do
    if rawget(value, i) == nil then
      return false
    end
  end
  return true
end
local function __jaya_define_primitive(kind, methods)
  __jaya_primitive_methods[kind] = methods or {}
  return __jaya_primitive_methods[kind]
end
local function __jaya_collect_callable_names(value, inherited)
  local names = {}
  local seen = {}
  local function add_name(name)
    if type(name) ~= "string" then
      return
    end
    if name:match("^__jaya_") then
      return
    end
    if not seen[name] then
      seen[name] = true
      names[#names + 1] = name
    end
  end
  local function walk_class(cls)
    if type(cls) ~= "table" then
      return
    end
    for key, item in pairs(cls) do
      if type(item) == "function" then
        add_name(key)
      end
    end
    if inherited then
      local bases = rawget(cls, "__bases") or {}
      for i = 1, #bases do
        walk_class(bases[i])
      end
    end
  end
  if type(value) == "table" and rawget(value, "__jaya_kind") == "module" then
    for key, item in pairs(value) do
      if type(item) == "function" then
        add_name(key)
      end
    end
  else
    walk_class(value)
  end
  table.sort(names)
  return names
end
local function __jaya_module_basename(path)
  if type(path) ~= "string" then
    return nil
  end
  local stem = path:match("([^/]+)$") or path
  stem = stem:gsub("%.jpl$", "")
  stem = stem:gsub("%.lua$", "")
  stem = stem:gsub("/init$", "")
  return stem
end
local function __jaya_location(source, line, col)
  return {
    source = source,
    line = line,
    col = col,
  }
end
local function __jaya_safe_member(obj, key)
  if obj == nil then
    return nil
  end
  return obj[key]
end
local function __jaya_safe_index(obj, key)
  if obj == nil then
    return nil
  end
  return __jaya_get_index(obj, key)
end
local function __jaya_safe_call(fn, ...)
  if fn == nil then
    return nil
  end
  return fn(...)
end
local __jaya_lookup_method
local function __jaya_call_member(obj, method, ...)
  if obj == nil then
    error("cannot call member on nil", 0)
  end
  local ok, direct = pcall(function()
    return obj[method]
  end)
  if ok and direct ~= nil then
    return direct(...)
  end
  local fn = __jaya_lookup_method(obj, method)
  if fn ~= nil then
    return fn(obj, ...)
  end
  error("unknown member: " .. tostring(method), 0)
end
local function __jaya_call_member_with_block(obj, method, positional, block)
  if obj == nil then
    error("cannot call member on nil", 0)
  end
  local ok, direct = pcall(function()
    return obj[method]
  end)
  if ok and direct ~= nil then
    return __jaya_call_with_block(direct, positional, block)
  end
  local fn = __jaya_lookup_method(obj, method)
  if fn ~= nil then
    local final = __jaya_pack_block_call(fn, positional, block)
    return fn(obj, table.unpack(final, 1, final.n or #final))
  end
  error("unknown member: " .. tostring(method), 0)
end
local function __jaya_call_member_named(obj, method, positional, named, block)
  if obj == nil then
    error("cannot call member on nil", 0)
  end
  local ok, direct = pcall(function()
    return obj[method]
  end)
  if ok and direct ~= nil then
    local final = __jaya_pack_named_call(direct, positional, named)
    if block ~= nil then
      final.n = (final.n or #final) + 1
      final[final.n] = block
    end
    return direct(table.unpack(final, 1, final.n or #final))
  end
  local fn = __jaya_lookup_method(obj, method)
  if fn ~= nil then
    local final = __jaya_pack_named_call(fn, positional, named)
    if block ~= nil then
      final.n = (final.n or #final) + 1
      final[final.n] = block
    end
    return fn(obj, table.unpack(final, 1, final.n or #final))
  end
  error("unknown member: " .. tostring(method), 0)
end
__jaya_lookup_method = function(obj, method)
  if obj == nil then
    return nil
  end
  local ok, direct = pcall(function()
    return obj[method]
  end)
  if ok and direct ~= nil then
    return direct
  end
  local kind = type(obj)
  if kind == "string" or kind == "number" or kind == "boolean" then
    local methods = __jaya_primitive_methods[kind]
    return methods and methods[method] or nil
  elseif kind == "function" then
    local methods = __jaya_primitive_methods["function"]
    return methods and methods[method] or nil
  elseif kind == "table" then
    local dispatch_kind
    if rawget(obj, "__name") ~= nil and rawget(obj, "__bases") ~= nil then
      dispatch_kind = "class"
    elseif rawget(obj, "__jaya_kind") == "module" then
      dispatch_kind = "module"
    else
      dispatch_kind = __jaya_is_array(obj) and "array" or "table"
    end
    local methods = __jaya_primitive_methods[dispatch_kind]
    return methods and methods[method] or nil
  end
  return nil
end
local function __jaya_safe_method(obj, method, ...)
  if obj == nil then
    return nil
  end
  local fn = __jaya_lookup_method(obj, method)
  if fn == nil then
    return nil
  end
  return fn(obj, ...)
end
local function __jaya_lookup_class(cls, key)
  local value = rawget(cls, key)
  if value ~= nil then
    return value
  end
  local bases = rawget(cls, "__bases") or {}
  for i = 1, #bases do
    local found = __jaya_lookup_class(bases[i], key)
    if found ~= nil then
      return found
    end
  end
  return nil
end
local function __jaya_lookup_table_chain(cls, slot, key)
  if cls == nil then
    return nil
  end
  local store = rawget(cls, slot)
  if type(store) == "table" then
    local value = rawget(store, key)
    if value ~= nil then
      return value
    end
  end
  local bases = rawget(cls, "__bases") or {}
  for i = 1, #bases do
    local found = __jaya_lookup_table_chain(bases[i], slot, key)
    if found ~= nil then
      return found
    end
  end
  return nil
end
local function __jaya_instance_to_json(self)
  if type(self) ~= "table" then
    return self
  end
  local cls = rawget(self, "__class")
  local fields = type(cls) == "table" and (rawget(cls, "__jaya_json_fields") or rawget(cls, "__jaya_fields")) or {}
  local out = {}
  for i = 1, #fields do
    local field = fields[i]
    out[field] = self[field]
  end
  return out
end
local function __jaya_instance_fields_by_visibility(self, visibility)
  if type(self) ~= "table" then
    return {}
  end
  local cls = rawget(self, "__class")
  if type(cls) ~= "table" then
    return {}
  end
  local field_key = "__jaya_" .. tostring(visibility) .. "_fields"
  local fields = rawget(cls, field_key) or {}
  local out = {}
  for i = 1, #fields do
    local field = fields[i]
    out[field] = self[field]
  end
  return out
end
local function __jaya_define_object_methods(methods)
  __jaya_object_methods = methods or {}
  _G.__jaya_object_methods = __jaya_object_methods
  return __jaya_object_methods
end
local function __jaya_class_from_json(cls, value)
  if type(value) ~= "table" then
    return value
  end
  local params = rawget(cls, "__jaya_param_names") or {}
  local param_vis = rawget(cls, "__jaya_param_visibilities") or {}
  local args = {}
  for i = 1, #params do
    if (param_vis[i] or "public") == "public" then
      args[i] = rawget(value, params[i])
    end
  end
  local instance = __jaya_new(cls, table.unpack(args))
  local fields = rawget(cls, "__jaya_json_fields") or rawget(cls, "__jaya_fields") or {}
  for i = 1, #fields do
    local field = fields[i]
    if value[field] ~= nil then
      instance[field] = value[field]
    end
  end
  return instance
end
local function __jaya_class(name, bases)
  local cls = {
    __name = name,
    __bases = bases or {},
    __jaya_getters = {},
    __jaya_setters = {},
    __jaya_static_getters = {},
    __jaya_static_setters = {},
    __jaya_static_values = {},
  }
  return setmetatable(cls, {
    __call = function(cls, ...)
      return __jaya_new(cls, ...)
    end,
    __index = function(tbl, key)
      local getter = __jaya_lookup_table_chain(tbl, "__jaya_static_getters", key)
      if getter ~= nil then
        return getter()
      end
      local values = rawget(tbl, "__jaya_static_values") or {}
      local value = rawget(values, key)
      if value ~= nil then
        return value
      end
      if key == "fromJson" then
        return function(value)
          return __jaya_class_from_json(tbl, value)
        end
      end
      return __jaya_lookup_class(tbl, key)
    end,
    __newindex = function(tbl, key, value)
      if type(value) == "function" or tostring(key):match("^__jaya_") then
        rawset(tbl, key, value)
        return
      end
      local setter = __jaya_lookup_table_chain(tbl, "__jaya_static_setters", key)
      if setter ~= nil then
        return setter(value)
      end
      local values = rawget(tbl, "__jaya_static_values")
      values[key] = value
    end,
  })
end
local function __jaya_class_name(cls)
  return type(cls) == "table" and rawget(cls, "__name") or nil
end
local function __jaya_class_location(cls)
  if type(cls) ~= "table" then
    return nil
  end
  return __jaya_location(rawget(cls, "__jaya_source"), rawget(cls, "__jaya_line"), rawget(cls, "__jaya_col"))
end
local function __jaya_class_fields(cls)
  local fields = type(cls) == "table" and rawget(cls, "__jaya_fields") or nil
  if type(fields) ~= "table" then
    return {}
  end
  local out = {}
  for i = 1, #fields do
    out[i] = fields[i]
  end
  return out
end
local function __jaya_class_functions(cls)
  return __jaya_collect_callable_names(cls, true)
end
local function __jaya_class_parents(cls)
  local bases = type(cls) == "table" and rawget(cls, "__bases") or nil
  if type(bases) ~= "table" then
    return {}
  end
  local out = {}
  for i = 1, #bases do
    out[i] = bases[i]
  end
  return out
end
local function __jaya_module_name(mod)
  if type(mod) ~= "table" then
    return nil
  end
  local name = rawget(mod, "__jaya_name")
  if name ~= nil then
    return name
  end
  return __jaya_module_basename(rawget(mod, "__jaya_source"))
end
local function __jaya_module_location(mod)
  if type(mod) ~= "table" then
    return nil
  end
  return __jaya_location(rawget(mod, "__jaya_source"), rawget(mod, "__jaya_line"), rawget(mod, "__jaya_col"))
end
local function __jaya_module_functions(mod)
  return __jaya_collect_callable_names(mod, false)
end
rawset(__jaya_exports, "__jaya_source", __jaya_source)
rawset(__jaya_exports, "__jaya_name", __jaya_module_basename(__jaya_source))
rawset(__jaya_exports, "__jaya_line", 1)
rawset(__jaya_exports, "__jaya_col", 1)
local function __jaya_bind_method(self, value)
  if type(value) ~= "function" then
    return value
  end
  local bound = function(...)
    return value(self, ...)
  end
  local meta = __jaya_fn_meta[value]
  if meta ~= nil then
    if type(meta.params) == "table" and meta.params[1] == "self" then
      local params = {}
      for i = 2, #meta.params do
        params[#params + 1] = meta.params[i]
      end
      __jaya_fn_meta[bound] = {
        params = params,
        kwrest = meta.kwrest,
        name = meta.name,
        source = meta.source,
        line = meta.line,
        col = meta.col,
      }
    else
      __jaya_fn_meta[bound] = meta
    end
  end
  return bound
end
__jaya_new = function(cls, ...)
  local self
  self = setmetatable({ __class = cls, __jaya_values = {} }, {
    __index = function(_, key)
      local getter = __jaya_lookup_table_chain(cls, "__jaya_getters", key)
      if getter ~= nil then
        return getter(self)
      end
      local values = rawget(self, "__jaya_values") or {}
      local value = rawget(values, key)
      if value ~= nil then
        return value
      end
      local class_method = __jaya_lookup_class(cls, key)
      if class_method ~= nil then
        return __jaya_bind_method(self, class_method)
      end
      local object_method = __jaya_object_methods[key]
      if object_method ~= nil then
        return __jaya_bind_method(self, object_method)
      end
      return nil
    end,
    __newindex = function(_, key, value)
      local setter = __jaya_lookup_table_chain(cls, "__jaya_setters", key)
      if setter ~= nil then
        return setter(self, value)
      end
      local values = rawget(self, "__jaya_values")
      values[key] = value
    end,
  })
  local ctor = rawget(cls, "__jaya_construct")
  if ctor ~= nil then
    ctor(self, ...)
  else
    local init = __jaya_lookup_class(cls, "init")
    if init ~= nil then
      init(self, ...)
    end
  end
  return self
end
local function __jaya_make_super(self, cls)
  local base = (rawget(cls, "__bases") or {})[1]
  return setmetatable({}, {
    __call = function(_, ...)
      if base == nil then
        return nil
      end
      local ctor = rawget(base, "__jaya_construct")
      if ctor ~= nil then
        return ctor(self, ...)
      end
      local init = __jaya_lookup_class(base, "init")
      if init ~= nil then
        return init(self, ...)
      end
      return nil
    end,
    __index = function(_, key)
      if base == nil then
        return nil
      end
      local getter = __jaya_lookup_table_chain(base, "__jaya_getters", key)
      if getter ~= nil then
        return getter(self)
      end
      local value = __jaya_lookup_class(base, key)
      if value ~= nil then
        return __jaya_bind_method(self, value)
      end
      return self[key]
    end,
  })
end
local function __jaya_instance_of(obj, class_name)
  local cls = type(obj) == "table" and rawget(obj, "__class") or nil
  local function walk(current)
    if current == nil then
      return false
    end
    if rawget(current, "__name") == class_name then
      return true
    end
    local bases = rawget(current, "__bases") or {}
    for i = 1, #bases do
      if walk(bases[i]) then
        return true
      end
    end
    return false
  end
  return walk(cls)
end
local function __jaya_class_is_a(current, target)
  if current == nil or target == nil then
    return false
  end
  if current == target then
    return true
  end
  local bases = rawget(current, "__bases") or {}
  for i = 1, #bases do
    if __jaya_class_is_a(bases[i], target) then
      return true
    end
  end
  return false
end
local function __jaya_catch_matches(err, catch_type)
  if catch_type == nil then
    return false
  end
  if type(catch_type) == "table" and rawget(catch_type, "__name") ~= nil then
    local err_class = type(err) == "table" and rawget(err, "__class") or nil
    return __jaya_class_is_a(err_class, catch_type)
  end
  if type(catch_type) == "string" then
    if err == catch_type then
      return true
    end
    local err_class = type(err) == "table" and rawget(err, "__class") or nil
    return err_class ~= nil and rawget(err_class, "__name") == catch_type
  end
  return err == catch_type
end
local function __jaya_go(fn)
  local thread = coroutine.create(fn)
  local ok, result = coroutine.resume(thread)
  if not ok then
    error(result, 0)
  end
  return thread
end
local function __jaya_error_message(err)
  if type(err) == "string" then
    return err:gsub("\nstack traceback:.*", "")
  elseif type(err) == "table" and err.message ~= nil then
    return tostring(err.message)
  end
  return tostring(err)
end
local function __jaya_compact_require_error(module_name, err)
  local msg = __jaya_error_message(err)
  if msg:match("^module .- not found:") then
    return "standard module not found: " .. tostring(module_name)
  end
  return msg
end
local function __jaya_lookup_fn_meta(target)
  if type(target) ~= "function" then
    return nil
  end
  local meta = __jaya_fn_meta[target]
  if meta == nil then
    return nil
  end
  if meta.params ~= nil or meta.name ~= nil then
    return meta
  end
  return { params = meta }
end
local function __jaya_function_name(target)
  local meta = __jaya_lookup_fn_meta(target)
  return meta and meta.name or nil
end
local function __jaya_function_location(target)
  local meta = __jaya_lookup_fn_meta(target)
  if meta == nil then
    return nil
  end
  return __jaya_location(meta.source, meta.line, meta.col)
end
local function __jaya_function_params(target)
  local meta = __jaya_lookup_fn_meta(target)
  if meta == nil or type(meta.params) ~= "table" then
    return {}
  end
  local out = {}
  for i = 1, #meta.params do
    out[i] = meta.params[i]
  end
  return out
end
local function __jaya_param_meta(spec)
  if type(spec) == "table" and (spec.params ~= nil or spec.kwrest ~= nil) then
    return {
      params = spec.params or {},
      kwrest = spec.kwrest,
    }
  end
  return {
    params = spec or {},
    kwrest = nil,
  }
end
local function __jaya_register_params(target, names, name, source, line, col)
  local spec = __jaya_param_meta(names)
  if type(target) == "function" then
    __jaya_fn_meta[target] = {
      params = spec.params,
      kwrest = spec.kwrest,
      name = name,
      source = source,
      line = line,
      col = col,
    }
  elseif type(target) == "table" then
    rawset(target, "__jaya_param_names", spec.params)
    rawset(target, "__jaya_kwrest_name", spec.kwrest)
  end
  return target
end
local function __jaya_lookup_param_meta(target)
  if type(target) == "function" then
    return __jaya_lookup_fn_meta(target)
  elseif type(target) == "table" then
    local params = rawget(target, "__jaya_param_names")
    local kwrest = rawget(target, "__jaya_kwrest_name")
    if params == nil and kwrest == nil then
      return nil
    end
    return {
      params = params or {},
      kwrest = kwrest,
    }
  end
  return nil
end
__jaya_pack_named_call = function(target, positional, named)
  local meta = __jaya_lookup_param_meta(target)
  if meta == nil then
    error("named arguments are not supported for this callee", 0)
  end
  local names = meta.params or {}
  local final = {}
  for i = 1, #positional do
    final[i] = positional[i]
  end
  local next_pos = #positional + 1
  local seen = {}
  for i = 1, #positional do
    local param_name = names[i]
    if param_name ~= nil then
      seen[param_name] = true
    end
  end
  for i = 1, #names do
    local name = names[i]
    if seen[name] then
    elseif named[name] ~= nil then
      final[i] = named[name]
      seen[name] = true
    end
  end
  for name in pairs(named) do
    if not seen[name] then
      if meta.kwrest == nil then
        error("unknown named argument: " .. tostring(name), 0)
      end
    end
  end
  if meta.kwrest ~= nil then
    local kw = {}
    for name, value in pairs(named) do
      if not seen[name] then
        kw[name] = value
      end
    end
    final[#names + 1] = kw
  end
  final.n = #names + (meta.kwrest ~= nil and 1 or 0)
  return final
end
local function __jaya_call_named(target, positional, named)
  local final = __jaya_pack_named_call(target, positional, named)
  return target(table.unpack(final, 1, final.n or #final))
end
__jaya_pack_block_call = function(target, positional, block)
  local meta = __jaya_lookup_param_meta(target)
  if meta ~= nil and meta.kwrest ~= nil then
    local names = meta.params or {}
    local final = {}
    for i = 1, #positional do
      final[i] = positional[i]
    end
    final[#names + 1] = {}
    final.n = #names + 1
    if block ~= nil then
      final.n = final.n + 1
      final[final.n] = block
    end
    return final
  end
  local final = {}
  for i = 1, #positional do
    final[i] = positional[i]
  end
  final.n = #positional
  if block ~= nil then
    final.n = final.n + 1
    final[final.n] = block
  end
  return final
end
__jaya_call_with_block = function(target, positional, block)
  local final = __jaya_pack_block_call(target, positional, block)
  return target(table.unpack(final, 1, final.n or #final))
end
__jaya_call_named_with_block = function(target, positional, named, block)
  local final = __jaya_pack_named_call(target, positional, named)
  if block ~= nil then
    final.n = (final.n or #final) + 1
    final[final.n] = block
  end
  return target(table.unpack(final, 1, final.n or #final))
end
local function __jaya_call_method_named(obj, method, positional, named)
  if obj == nil then
    error("cannot call named method on nil", 0)
  end
  local fn = __jaya_lookup_method(obj, method)
  if fn == nil then
    error("unknown method: " .. tostring(method), 0)
  end
  local final = __jaya_pack_named_call(fn, positional, named)
  return fn(obj, table.unpack(final, 1, final.n or #final))
end
local function __jaya_call_method(obj, method, ...)
  if obj == nil then
    error("cannot call method on nil", 0)
  end
  local fn = __jaya_lookup_method(obj, method)
  if fn == nil then
    error("unknown method: " .. tostring(method), 0)
  end
  return fn(obj, ...)
end
local function __jaya_call_method_with_block(obj, method, positional, block)
  if obj == nil then
    error("cannot call method on nil", 0)
  end
  local fn = __jaya_lookup_method(obj, method)
  if fn == nil then
    error("unknown method: " .. tostring(method), 0)
  end
  local final = __jaya_pack_block_call(fn, positional, block)
  return fn(obj, table.unpack(final, 1, final.n or #final))
end
local function __jaya_call_method_named_with_block(obj, method, positional, named, block)
  if obj == nil then
    error("cannot call named method on nil", 0)
  end
  local fn = __jaya_lookup_method(obj, method)
  if fn == nil then
    error("unknown method: " .. tostring(method), 0)
  end
  local final = __jaya_pack_named_call(fn, positional, named)
  if block ~= nil then
    final.n = (final.n or #final) + 1
    final[final.n] = block
  end
  return fn(obj, table.unpack(final, 1, final.n or #final))
end
local function __jaya_call_safe_method_named(obj, method, positional, named)
  if obj == nil then
    return nil
  end
  return __jaya_call_method_named(obj, method, positional, named)
end
local function __jaya_call_safe_method_named_with_block(obj, method, positional, named, block)
  if obj == nil then
    return nil
  end
  return __jaya_call_method_named_with_block(obj, method, positional, named, block)
end
local function __jaya_call_safe_with_block(fn, positional, block)
  if fn == nil then
    return nil
  end
  return __jaya_call_with_block(fn, positional, block)
end
local function __jaya_yield(block, ...)
  if block == nil then
    error("yield used without a block", 0)
  end
  return block(...)
end
local function __jaya_yield_named(block, positional, named)
  if block == nil then
    error("yield used without a block", 0)
  end
  return __jaya_call_named(block, positional, named)
end
local function __jaya_raise(kind, module_name, path, cause)
  local location = path or module_name or "<input>"
  local pieces = {
    "Jaya " .. kind .. " error",
    "  module: " .. tostring(module_name or "<input>"),
    "  at: " .. tostring(location),
    "  cause: " .. __jaya_error_message(cause),
  }
  error(table.concat(pieces, "\n"), 0)
end
local function __jaya_dirname(path)
  if type(path) ~= "string" then
    return "."
  end
  local dir = path:match("^(.*)/[^/]*$")
  if dir == nil or dir == "" then
    return "."
  end
  return dir
end
local function __jaya_join_path(base, piece)
  if base == "." or base == "" then
    return piece
  end
  return base .. "/" .. piece
end
local function __jaya_normalize_path(path)
  local absolute = path:sub(1, 1) == "/"
  local parts = {}
  for piece in path:gmatch("[^/]+") do
    if piece == "." then
    elseif piece == ".." then
      if #parts > 0 and parts[#parts] ~= ".." then
        parts[#parts] = nil
      elseif not absolute then
        parts[#parts + 1] = piece
      end
    else
      parts[#parts + 1] = piece
    end
  end
  local joined = table.concat(parts, "/")
  if absolute then
    return "/" .. joined
  end
  return joined ~= "" and joined or "."
end
local function __jaya_file_exists(path)
  local fh = io.open(path, "rb")
  if fh == nil then
    return false
  end
  fh:close()
  return true
end
local function __jaya_read_file(path)
  local fh, err = io.open(path, "rb")
  if fh == nil then
    error(err, 0)
  end
  local data = fh:read("*a")
  fh:close()
  return data
end
local function __jaya_stem_name(path)
  local stem = path:gsub("\\", "/"):match("([^/]+)$") or path
  stem = stem:gsub("%.jpl$", ""):gsub("%.lua$", "")
  return stem
end
local function __jaya_load_compiler(compiler_path)
  if rawget(_G, "JPL") ~= nil then
    return rawget(_G, "JPL")
  end
  local loader, err = loadfile(compiler_path)
  if loader == nil then
    error(err, 0)
  end
  local compiler = loader()
  _G.JPL = compiler
  return compiler
end
local function __jaya_load_jpl_module(resolved_path, compiler_path)
  local cached = __jaya_module_cache[resolved_path]
  if cached ~= nil then
    if type(cached) == "table" and rawget(cached, "__jaya_state") == "loading" then
      return cached.exports
    end
    return cached
  end
  local compiler_ok, compiler_or_err = pcall(__jaya_load_compiler, compiler_path)
  if not compiler_ok then
    __jaya_raise("compiler", resolved_path, compiler_path, compiler_or_err)
  end
  local compiler = compiler_or_err
  local read_ok, source_or_err = pcall(__jaya_read_file, resolved_path)
  if not read_ok then
    __jaya_raise("module", resolved_path, resolved_path, source_or_err)
  end
  local compile_ok, lua_code_or_err = pcall(compiler.compile, source_or_err, resolved_path)
  if not compile_ok then
    __jaya_raise("compile", resolved_path, resolved_path, lua_code_or_err)
  end
  local placeholder = {}
  __jaya_module_cache[resolved_path] = {
    __jaya_state = "loading",
    exports = placeholder,
  }
  local module_env = setmetatable({
    __jaya_exports = placeholder,
  }, {
    __index = _ENV,
  })
  local chunk, err = load(lua_code_or_err, "@" .. resolved_path, "t", module_env)
  if chunk == nil then
    __jaya_module_cache[resolved_path] = nil
    __jaya_raise("compile", resolved_path, resolved_path, err)
  end
  local run_ok, exports_or_err = pcall(chunk)
  if not run_ok then
    __jaya_module_cache[resolved_path] = nil
    __jaya_raise("runtime", resolved_path, resolved_path, exports_or_err)
  end
  local exports = exports_or_err
  __jaya_module_cache[resolved_path] = exports
  return exports
end
local function __jaya_native_require_available(module_name)
  if package == nil then
    return false
  end
  if package.loaded and package.loaded[module_name] ~= nil then
    return true
  end
  if package.searchpath then
    if package.path and package.searchpath(module_name, package.path) then
      return true
    end
    if package.cpath and package.searchpath(module_name, package.cpath) then
      return true
    end
  end
  return false
end
local function __jaya_local_candidates(module_name, source_path)
  local base_dir = __jaya_dirname(source_path)
  local raw_name = module_name
  if raw_name:sub(1, 1) == "/" then
    raw_name = raw_name
  else
    raw_name = __jaya_normalize_path(__jaya_join_path(base_dir, raw_name))
  end
  local candidates = {}
  local function push(path)
    candidates[#candidates + 1] = __jaya_normalize_path(path)
  end
  if raw_name:match("%.jpl$") or raw_name:match("%.lua$") then
    push(raw_name)
  else
    push(raw_name .. ".jpl")
    push(raw_name .. "/init.jpl")
    push(raw_name .. ".lua")
    push(raw_name .. "/init.lua")
  end
  return candidates
end
local function __jaya_std_candidates(module_name, compiler_path)
  local std_root = __jaya_join_path(__jaya_dirname(compiler_path), "std")
  local raw_name = __jaya_join_path(std_root, module_name)
  local candidates = {}
  local function push(path)
    candidates[#candidates + 1] = __jaya_normalize_path(path)
  end
  if raw_name:match("%.jpl$") or raw_name:match("%.lua$") then
    push(raw_name)
  else
    push(raw_name .. ".jpl")
    push(raw_name .. "/init.jpl")
    push(raw_name .. ".lua")
    push(raw_name .. "/init.lua")
  end
  return candidates
end
local function __jaya_require(module_name, source_path, compiler_path)
  if type(module_name) ~= "string" then
    error("require expects a string module name", 0)
  end
  local is_relative = module_name:sub(1, 2) == "./" or module_name:sub(1, 3) == "../"
  local is_absolute = module_name:sub(1, 1) == "/"
  local is_local = is_relative or is_absolute
  if not is_local then
    for _, candidate in ipairs(__jaya_std_candidates(module_name, compiler_path)) do
      if __jaya_file_exists(candidate) then
        if __jaya_module_cache[candidate] ~= nil then
          local cached = __jaya_module_cache[candidate]
          if type(cached) == "table" and rawget(cached, "__jaya_state") == "loading" then
            return cached.exports
          end
          return cached
        end
        if candidate:match("%.jpl$") then
          return __jaya_load_jpl_module(candidate, compiler_path)
        end
        local loader, err = loadfile(candidate)
        if loader == nil then
          __jaya_raise("module", module_name, candidate, err)
        end
        local ok, exports_or_err = pcall(loader)
        if not ok then
          __jaya_raise("runtime", module_name, candidate, exports_or_err)
        end
        local exports = exports_or_err
        __jaya_module_cache[candidate] = exports
        return exports
      end
    end
    local ok, result = pcall(require, module_name)
    if not ok then
      __jaya_raise("module", module_name, module_name, __jaya_compact_require_error(module_name, result))
    end
    return result
  end
  for _, candidate in ipairs(__jaya_local_candidates(module_name, source_path)) do
    if __jaya_file_exists(candidate) then
      if __jaya_module_cache[candidate] ~= nil then
        local cached = __jaya_module_cache[candidate]
        if type(cached) == "table" and rawget(cached, "__jaya_state") == "loading" then
          return cached.exports
        end
        return cached
      end
      if candidate:match("%.jpl$") then
        return __jaya_load_jpl_module(candidate, compiler_path)
      end
      local loader, err = loadfile(candidate)
      if loader == nil then
        __jaya_raise("module", module_name, candidate, err)
      end
      local ok, exports_or_err = pcall(loader)
      if not ok then
        __jaya_raise("runtime", module_name, candidate, exports_or_err)
      end
      local exports = exports_or_err
      __jaya_module_cache[candidate] = exports
      return exports
    end
  end
  __jaya_raise("module", module_name, source_path, "module not found")
end
local function __jaya_match(value, pattern, bindings)
  local kind = pattern.kind
  if kind == "wildcard" then
    return true
  elseif kind == "name" then
    bindings[pattern.name] = value
    return true
  elseif kind == "literal" then
    return value == pattern.value
  elseif kind == "array" then
    if type(value) ~= "table" then
      return false
    end
    for i = 1, #pattern.items do
      if rawget(value, i) == nil then
        return false
      end
      if not __jaya_match(value[i], pattern.items[i], bindings) then
        return false
      end
    end
    return true
  elseif kind == "table" then
    if type(value) ~= "table" then
      return false
    end
    for i = 1, #pattern.fields do
      local field = pattern.fields[i]
      if rawget(value, field.key) == nil then
        return false
      end
      if not __jaya_match(value[field.key], field.pattern, bindings) then
        return false
      end
    end
    return true
  elseif kind == "class" then
    if not __jaya_instance_of(value, pattern.name) then
      return false
    end
    local cls = rawget(value, "__class")
    local fields = cls and rawget(cls, "__jaya_fields") or {}
    for i = 1, #pattern.args do
      local key = fields[i]
      if key == nil then
        return false
      end
      if value[key] == nil then
        return false
      end
      if not __jaya_match(value[key], pattern.args[i], bindings) then
        return false
      end
    end
    return true
  end
  error("unknown match pattern kind: " .. tostring(kind), 0)
end
]]

local Codegen = {}
Codegen.__index = Codegen

function Codegen.new(opts)
  opts = opts or {}
  return setmetatable({
    lines = {},
    indent = 0,
    scope_stack = { {} },
    temp_id = 0,
    source_name = opts.source_name,
    compiler_path = opts.compiler_path,
    known_named_params = opts.known_named_params or {},
  }, Codegen)
end

function Codegen:error(msg)
  error(msg, 0)
end

function Codegen:push_scope()
  self.scope_stack[#self.scope_stack + 1] = {}
end

function Codegen:pop_scope()
  self.scope_stack[#self.scope_stack] = nil
end

function Codegen:declare(name, opts)
  opts = opts or {}
  if RESERVED_BUILTINS[name] and not opts.allow_reserved then
    self:error("cannot shadow builtin: " .. name)
  end
  self.scope_stack[#self.scope_stack][name] = {
    declared = true,
    const = opts.const or false,
  }
end

function Codegen:is_declared(name)
  for i = #self.scope_stack, 1, -1 do
    if self.scope_stack[i][name] then
      return true
    end
  end
  return false
end

function Codegen:is_const(name)
  for i = #self.scope_stack, 1, -1 do
    local entry = self.scope_stack[i][name]
    if entry then
      return entry.const == true
    end
  end
  return false
end

function Codegen:line(text)
  self.lines[#self.lines + 1] = string.rep("  ", self.indent) .. text
end

function Codegen:with_block(fn)
  self.indent = self.indent + 1
  self:push_scope()
  fn()
  self:pop_scope()
  self.indent = self.indent - 1
end

function Codegen:new_temp()
  self.temp_id = self.temp_id + 1
  return "__jaya_tmp_" .. self.temp_id
end

function Codegen:emit_pattern_local(pattern, value_expr)
  if pattern.kind == "PatternName" then
    if self:is_const(pattern.name) then
      self:error("cannot reassign const: " .. pattern.name)
    end
    self:declare(pattern.name)
    self:line("local " .. pattern.name .. " = " .. value_expr)
    return
  elseif pattern.kind == "PatternWildcard" then
    return
  elseif pattern.kind == "ArrayPattern" then
    local temp = self:new_temp()
    self:line("local " .. temp .. " = " .. value_expr)
    for i, item in ipairs(pattern.items) do
      self:emit_pattern_local(item, temp .. "[" .. i .. "]")
    end
    return
  elseif pattern.kind == "TablePattern" then
    local temp = self:new_temp()
    self:line("local " .. temp .. " = " .. value_expr)
    for _, field in ipairs(pattern.fields) do
      self:emit_pattern_local(field.pattern, temp .. "." .. field.key)
    end
    return
  end
  self:error("unsupported binding pattern " .. tostring(pattern.kind))
end

function Codegen:block_has_nonlocal_control(stmts)
  for _, stmt in ipairs(stmts or {}) do
    if stmt.kind == "Return" or stmt.kind == "Break" then
      return true
    elseif stmt.kind == "If" then
      for _, branch in ipairs(stmt.branches or {}) do
        if self:block_has_nonlocal_control(branch.body) then
          return true
        end
      end
      if self:block_has_nonlocal_control(stmt.else_body) then
        return true
      end
    elseif stmt.kind == "Unless" then
      if self:block_has_nonlocal_control(stmt.body) or self:block_has_nonlocal_control(stmt.else_body) then
        return true
      end
    elseif stmt.kind == "Case" then
      for _, branch in ipairs(stmt.whens or {}) do
        if self:block_has_nonlocal_control(branch.body) then
          return true
        end
      end
      if self:block_has_nonlocal_control(stmt.else_body) then
        return true
      end
    elseif stmt.kind == "Match" then
      for _, clause in ipairs(stmt.whens or {}) do
        if self:block_has_nonlocal_control(clause.body) then
          return true
        end
      end
      if self:block_has_nonlocal_control(stmt.else_body) then
        return true
      end
    elseif stmt.kind == "Let" then
      if self:block_has_nonlocal_control(stmt.body) then
        return true
      end
    elseif stmt.kind == "Try" then
      return true
    end
  end
  return false
end

function Codegen:clone_scope_stack()
  local out = {}
  for i, scope in ipairs(self.scope_stack) do
    local copy = {}
    for name, value in pairs(scope) do
      copy[name] = value
    end
    out[i] = copy
  end
  return out
end

function Codegen:compile_block_lines(stmts, setup, inherit_scopes)
  local child = Codegen.new({ known_named_params = self.known_named_params })
  child.temp_id = self.temp_id
  child.scope_stack = inherit_scopes and self:clone_scope_stack() or { {} }
  if setup then
    setup(child)
  end
  for _, stmt in ipairs(stmts or {}) do
    child:emit_stmt(stmt)
  end
  self.temp_id = child.temp_id
  return child.lines
end

function Codegen:emit_stmt(node)
  if node.kind == "Assign" then
    self:emit_assign(node)
  elseif node.kind == "DestructureAssign" then
    if #node.values ~= 1 then
      self:error("destructuring assignment needs exactly one value")
    end
    self:emit_pattern_local(node.pattern, self:emit_expr(node.values[1]))
  elseif node.kind == "LocalAssign" then
    self:emit_local_assign(node)
  elseif node.kind == "ExportAssign" then
    self:emit_export_assign(node)
  elseif node.kind == "ConstAssign" then
    self:emit_const_assign(node)
  elseif node.kind == "ExportConstAssign" then
    self:emit_export_const_assign(node)
  elseif node.kind == "FnDecl" then
    self:emit_fn_decl(node)
  elseif node.kind == "ClassDecl" then
    self:emit_class_decl(node)
  elseif node.kind == "ExprStmt" then
    self:line(self:emit_expr(node.expression))
  elseif node.kind == "Return" then
    if node.condition then
      local cond_expr = self:emit_condition_expr(node.condition)
      self:line("if " .. cond_expr .. " then")
      self:with_block(function()
        if node.values and #node.values > 0 then
          self:line("return " .. self:emit_expr_list(node.values))
        else
          self:line("return")
        end
      end)
      self:line("end")
    elseif node.values and #node.values > 0 then
      self:line("return " .. self:emit_expr_list(node.values))
    else
      self:line("return")
    end
  elseif node.kind == "Break" then
    if node.condition then
      self:line("if " .. self:emit_condition_expr(node.condition) .. " then")
      self:with_block(function()
        self:line("break")
      end)
      self:line("end")
    else
      self:line("break")
    end
  elseif node.kind == "If" then
    self:emit_if(node)
  elseif node.kind == "Unless" then
    self:emit_unless(node)
  elseif node.kind == "Case" then
    self:emit_case(node)
  elseif node.kind == "ForIn" then
    self:emit_for_in(node)
  elseif node.kind == "Match" then
    self:emit_match(node)
  elseif node.kind == "Let" then
    self:emit_let(node)
  elseif node.kind == "Throw" then
    self:line("error(" .. self:emit_expr(node.value) .. ", 0)")
  elseif node.kind == "Try" then
    self:emit_try(node)
  elseif node.kind == "Go" then
    self:line("__jaya_go(function() return " .. self:emit_expr(node.value) .. " end)")
  elseif node.kind == "ImplicitRequire" then
    if self:is_const(node.bind) then
      self:error("cannot reassign const: " .. node.bind)
    end
    if self:is_declared(node.bind) then
      self:line(node.bind .. " = __jaya_require(" .. string.format("%q", node.module) .. ", __jaya_source, __jaya_compiler_path)")
    else
      self:declare(node.bind)
      self:line("local " .. node.bind .. " = __jaya_require(" .. string.format("%q", node.module) .. ", __jaya_source, __jaya_compiler_path)")
    end
  elseif node.kind == "ConditionalStmt" then
    self:emit_conditional_stmt(node)
  else
    self:error("unsupported statement " .. tostring(node.kind))
  end
end

function Codegen:emit_for_in(node)
  local iterable = self:new_temp()
  local names = node.names or { node.name }
  self:line("do")
  self:with_block(function()
    self:line("local " .. iterable .. " = " .. self:emit_expr(node.iterable))
    if #names == 1 then
      self:line("for _, " .. names[1] .. " in __jaya_iter(" .. iterable .. ") do")
    else
      self:line("for " .. table.concat(names, ", ") .. " in __jaya_iter(" .. iterable .. ") do")
    end
    self:with_block(function()
      for _, name in ipairs(names) do
        self:declare(name)
      end
      for _, stmt in ipairs(node.body or {}) do
        self:emit_stmt(stmt)
      end
    end)
    self:line("end")
  end)
  self:line("end")
end

function Codegen:emit_assign(node)
  local pieces = {}
  local all_names = true
  for i, target in ipairs(node.targets) do
    pieces[i] = self:emit_lvalue(target)
    if target.kind ~= "Name" then
      all_names = false
    elseif self:is_const(target.value) then
      self:error("cannot reassign const: " .. target.value)
    end
  end
  local prefix = ""
  if node.local_default and all_names then
    local undeclared = false
    for _, target in ipairs(node.targets) do
      if not self:is_declared(target.value) then
        undeclared = true
        self:declare(target.value)
      end
    end
    if undeclared then
      prefix = "local "
    end
  end
  self:line(prefix .. table.concat(pieces, ", ") .. " = " .. self:emit_expr_list(node.values))
end

function Codegen:emit_const_assign(node)
  if #node.names ~= #node.values then
    self:error("const assignment codegen currently requires matching name/value counts")
  end
  for i, name in ipairs(node.names) do
    if self:is_declared(name) then
      self:error("cannot redeclare const: " .. name)
    end
    self:declare(name, { const = true, allow_reserved = node.from_prelude == true })
    self:line("local " .. name .. " = " .. self:emit_expr(node.values[i]))
  end
end

function Codegen:emit_local_assign(node)
  if not node.values or #node.values ~= #node.names then
    self:error("local assignment codegen currently requires matching name/value counts")
  end
  for i, pattern in ipairs(node.names) do
    if pattern.kind == "PatternName" and self:is_const(pattern.name) then
      self:error("cannot reassign const: " .. pattern.name)
    end
    self:emit_pattern_local(pattern, self:emit_expr(node.values[i]))
  end
end

function Codegen:emit_export_assign(node)
  if #node.names ~= #node.values then
    self:error("export assignment codegen currently requires matching name/value counts")
  end
  for i, name in ipairs(node.names) do
    if self:is_const(name) then
      self:error("cannot reassign const: " .. name)
    end
    if not self:is_declared(name) then
      self:declare(name)
      self:line("local " .. name .. " = " .. self:emit_expr(node.values[i]))
    else
      self:line(name .. " = " .. self:emit_expr(node.values[i]))
    end
    self:line("__jaya_exports." .. name .. " = " .. name)
  end
end

function Codegen:emit_export_const_assign(node)
  if #node.names ~= #node.values then
    self:error("export const assignment codegen currently requires matching name/value counts")
  end
  for i, name in ipairs(node.names) do
    if self:is_declared(name) then
      self:error("cannot redeclare const: " .. name)
    end
    self:declare(name, { const = true, allow_reserved = node.from_prelude == true })
    self:line("local " .. name .. " = " .. self:emit_expr(node.values[i]))
    self:line("__jaya_exports." .. name .. " = " .. name)
  end
end

function Codegen:emit_fn_decl(node)
  if self:is_const(node.name) then
    self:error("cannot redeclare const: " .. node.name)
  end
  local body_lines = self:emit_function_body(node.params, node.body)
  local already_declared = self:is_declared(node.name)
  if not already_declared then
    self:declare(node.name)
  end
  if already_declared then
    self:line(node.name .. " = function(" .. self:emit_param_signature(node.params) .. ")")
  else
    self:line("local function " .. node.name .. "(" .. self:emit_param_signature(node.params) .. ")")
  end
  self:with_block(function()
    for _, line in ipairs(body_lines) do
      self:line(line)
    end
  end)
  self:line("end")
  self:line("__jaya_register_params(" .. node.name .. ", " .. self:emit_param_meta(node.params) .. ", " .. string.format("%q", node.name) .. ", " .. string.format("%q", node.source or (self.source_name or "<unknown>")) .. ", " .. tostring(node.decl_line or 1) .. ", " .. tostring(node.decl_col or 1) .. ")")
  if node.exported then
    self:line("__jaya_exports." .. node.name .. " = " .. node.name)
  end
end

function Codegen:collect_class_fields(node)
  local fields = {}
  for _, param in ipairs(node.params or {}) do
    fields[#fields + 1] = param.name
  end
  for _, member in ipairs(node.members or {}) do
    if member.kind == "Property" and not member.static then
      fields[#fields + 1] = member.name
    end
  end
  return fields
end

function Codegen:collect_class_json_fields(node)
  local fields = {}
  for _, param in ipairs(node.params or {}) do
    if (param.visibility or "public") == "public" then
      fields[#fields + 1] = param.name
    end
  end
  for _, member in ipairs(node.members or {}) do
    if member.kind == "Property" and not member.static and (member.visibility or "public") == "public" then
      fields[#fields + 1] = member.name
    end
  end
  return fields
end

function Codegen:collect_class_fields_by_visibility(node, visibility)
  local fields = {}
  for _, param in ipairs(node.params or {}) do
    if (param.visibility or "public") == visibility then
      fields[#fields + 1] = param.name
    end
  end
  for _, member in ipairs(node.members or {}) do
    if member.kind == "Property" and not member.static and (member.visibility or "public") == visibility then
      fields[#fields + 1] = member.name
    end
  end
  return fields
end

function Codegen:emit_class_param_visibility_array(params)
  local items = {}
  for i, param in ipairs(params or {}) do
    items[i] = string.format("%q", param.visibility or "public")
  end
  return "{ " .. table.concat(items, ", ") .. " }"
end

function Codegen:emit_class_decl(node)
  if self:is_const(node.name) then
    self:error("cannot redeclare const: " .. node.name)
  end
  local already_declared = self:is_declared(node.name)
  if not already_declared then
    self:declare(node.name)
  end
  local bases = {}
  for i, base in ipairs(node.bases or {}) do
    bases[i] = self:emit_expr(base)
  end
  if already_declared then
    self:line(node.name .. " = __jaya_class(" .. string.format("%q", node.name) .. ", { " .. table.concat(bases, ", ") .. " })")
  else
    self:line("local " .. node.name .. " = __jaya_class(" .. string.format("%q", node.name) .. ", { " .. table.concat(bases, ", ") .. " })")
  end
  self:line(node.name .. ".__jaya_source = " .. string.format("%q", node.source or (self.source_name or "<unknown>")))
  self:line(node.name .. ".__jaya_line = " .. tostring(node.decl_line or 1))
  self:line(node.name .. ".__jaya_col = " .. tostring(node.decl_col or 1))

  local class_fields = self:collect_class_fields(node)
  local class_json_fields = self:collect_class_json_fields(node)
  local public_fields = self:collect_class_fields_by_visibility(node, "public")
  local private_fields = self:collect_class_fields_by_visibility(node, "private")
  local protected_fields = self:collect_class_fields_by_visibility(node, "protected")
  self:line(node.name .. ".__jaya_fields = { " .. table.concat((function()
    local items = {}
    for i, field in ipairs(class_fields) do
      items[i] = string.format("%q", field)
    end
    return items
  end)(), ", ") .. " }")
  self:line(node.name .. ".__jaya_json_fields = { " .. table.concat((function()
    local items = {}
    for i, field in ipairs(class_json_fields) do
      items[i] = string.format("%q", field)
    end
    return items
  end)(), ", ") .. " }")
  self:line(node.name .. ".__jaya_public_fields = { " .. table.concat((function()
    local items = {}
    for i, field in ipairs(public_fields) do
      items[i] = string.format("%q", field)
    end
    return items
  end)(), ", ") .. " }")
  self:line(node.name .. ".__jaya_private_fields = { " .. table.concat((function()
    local items = {}
    for i, field in ipairs(private_fields) do
      items[i] = string.format("%q", field)
    end
    return items
  end)(), ", ") .. " }")
  self:line(node.name .. ".__jaya_protected_fields = { " .. table.concat((function()
    local items = {}
    for i, field in ipairs(protected_fields) do
      items[i] = string.format("%q", field)
    end
    return items
  end)(), ", ") .. " }")
  self:line(node.name .. ".__jaya_param_names = " .. self:emit_param_name_array(node.params or {}))
  self:line(node.name .. ".__jaya_param_visibilities = " .. self:emit_class_param_visibility_array(node.params or {}))
  local constructor = nil
  for _, member in ipairs(node.members or {}) do
    if member.kind == "Property" then
      if member.static then
        if member.value then
          self:line(node.name .. ".__jaya_static_values." .. member.name .. " = " .. self:emit_expr(member.value))
        else
          self:line(node.name .. ".__jaya_static_values." .. member.name .. " = nil")
        end
      end
    elseif member.kind == "Constructor" then
      constructor = member
      self:emit_class_method(node.name, member, class_fields)
    elseif member.kind == "Method" then
      self:emit_class_method(node.name, member, class_fields)
    elseif member.kind == "Getter" or member.kind == "Setter" then
      self:emit_class_accessor(node.name, member, class_fields)
    else
      self:error("unsupported class member in codegen " .. tostring(member.kind))
    end
  end

  self:emit_class_construct(node, constructor, class_fields)

  if node.exported then
    self:line("__jaya_exports." .. node.name .. " = " .. node.name)
  end
end

function Codegen:emit_class_method(class_name, member, class_fields)
  local params = self:emit_param_names(member.params)
  local signature = self:emit_param_signature(member.params)
  local block_name = self:block_param_name(member.params)
  local kwrest_name = self:kwrest_param_name(member.params)
  local head
  if member.static then
    head = "function " .. class_name .. "." .. member.name .. "(" .. signature .. ")"
  else
    head = "function " .. class_name .. "." .. member.name .. "(self" .. (#signature > 0 and ", " .. signature or "") .. ")"
  end
  self:line(head)
  self.indent = self.indent + 1
  local child = Codegen.new()
  child.known_named_params = self.known_named_params
  child.lines = self.lines
  child.indent = self.indent
  child.scope_stack = { {} }
  child.temp_id = self.temp_id
  child.current_block_name = block_name
  child:declare(block_name)
  if kwrest_name ~= nil then
    child:declare(kwrest_name)
    child:line("if " .. kwrest_name .. " == nil then " .. kwrest_name .. " = {} end")
  end
  if not member.static then
    child:declare("self")
    child:line("local __jaya_super = __jaya_make_super(self, " .. class_name .. ")")
    child:declare("__jaya_super")
    local param_names = {}
    for _, param in ipairs(member.params) do
      if param.kind == "Param" or param.kind == "ClassParam" then
        param_names[param.name] = true
        child:declare(param.name)
      end
      if (param.kind == "Param" or param.kind == "ClassParam") and param.default then
        child:line("if " .. param.name .. " == nil then " .. param.name .. " = " .. child:emit_expr(param.default) .. " end")
      end
    end
    local seen = {}
    for _, field in ipairs(class_fields) do
      if not param_names[field] and not seen[field] then
        seen[field] = true
        child:declare(field)
        child:line("local " .. field .. " = self." .. field)
      end
    end
  else
    child:declare(member.name)
    child:line("local " .. member.name .. " = " .. class_name .. ".__jaya_static_values." .. member.name)
    for _, param in ipairs(member.params) do
      if param.kind == "Param" or param.kind == "ClassParam" then
        child:declare(param.name)
      end
      if (param.kind == "Param" or param.kind == "ClassParam") and param.default then
        child:line("if " .. param.name .. " == nil then " .. param.name .. " = " .. child:emit_expr(param.default) .. " end")
      end
    end
  end
  if member.body.kind == "ExprBody" then
    child:line("return " .. child:emit_expr(member.body.value))
  else
    for _, stmt in ipairs(member.body.body) do
      child:emit_stmt(stmt)
    end
  end
  self.temp_id = child.temp_id
  self.indent = self.indent - 1
  self:line("end")
  self:line("__jaya_register_params(" .. class_name .. "." .. member.name .. ", " .. self:emit_param_meta(member.params) .. ", " .. string.format("%q", member.name) .. ", " .. string.format("%q", self.source_name or "<unknown>") .. ", " .. tostring(member.decl_line or 1) .. ", " .. tostring(member.decl_col or 1) .. ")")
end

function Codegen:emit_class_accessor(class_name, member, class_fields)
  local params = self:emit_param_names(member.params)
  local signature = self:emit_param_signature(member.params)
  local slot
  if member.static then
    slot = member.kind == "Getter" and "__jaya_static_getters" or "__jaya_static_setters"
  else
    slot = member.kind == "Getter" and "__jaya_getters" or "__jaya_setters"
  end
  local head = class_name .. "." .. slot .. "." .. member.name .. " = function(" .. ((not member.static and member.kind == "Getter") and ("self" .. (#signature > 0 and ", " .. signature or "")) or
    (not member.static and member.kind == "Setter") and ("self" .. (#signature > 0 and ", " .. signature or "") ) or
    (member.static and signature or self:block_param_name(member.params))) .. ")"
  self:line(head)
  self.indent = self.indent + 1
  local child = Codegen.new()
  child.known_named_params = self.known_named_params
  child.lines = self.lines
  child.indent = self.indent
  child.scope_stack = { {} }
  child.temp_id = self.temp_id
  local param_names = {}
  if not member.static then
    child:declare("self")
    child:line("local __jaya_super = __jaya_make_super(self, " .. class_name .. ")")
    child:declare("__jaya_super")
    for _, param in ipairs(member.params) do
      param_names[param.name] = true
      child:declare(param.name)
      if param.default then
        child:line("if " .. param.name .. " == nil then " .. param.name .. " = " .. child:emit_expr(param.default) .. " end")
      end
    end
    local seen = {}
    for _, field in ipairs(class_fields) do
      if not param_names[field] and not seen[field] then
        seen[field] = true
        child:declare(field)
        child:line("local " .. field .. " = self." .. field)
      end
    end
  else
    child:declare(member.name)
    child:line("local " .. member.name .. " = " .. class_name .. ".__jaya_static_values." .. member.name)
    for _, param in ipairs(member.params) do
      child:declare(param.name)
      if param.default then
        child:line("if " .. param.name .. " == nil then " .. param.name .. " = " .. child:emit_expr(param.default) .. " end")
      end
    end
  end
  if member.body.kind == "ExprBody" then
    child:line("return " .. child:emit_expr(member.body.value))
  else
    for _, stmt in ipairs(member.body.body) do
      child:emit_stmt(stmt)
    end
    if not member.static then
      local seen = {}
      for _, field in ipairs(class_fields) do
        if not param_names[field] and not seen[field] then
          seen[field] = true
          child:line("self." .. field .. " = " .. field)
        end
      end
    else
      child:line(class_name .. ".__jaya_static_values." .. member.name .. " = " .. member.name)
    end
  end
  self.temp_id = child.temp_id
  self.indent = self.indent - 1
  self:line("end")
end

function Codegen:emit_class_construct(node, constructor, class_fields)
  self:line("function " .. node.name .. ".__jaya_construct(self, ...)")
  self:with_block(function()
    self:line("local __jaya_super = __jaya_make_super(self, " .. node.name .. ")")
    self:declare("__jaya_super")
    self:line("local __jaya_args = {...}")
    self:declare("__jaya_args")
    if not constructor and node.bases and #node.bases > 0 then
      self:line("__jaya_super(table.unpack(__jaya_args))")
    end
    for _, member in ipairs(node.members or {}) do
      if member.kind == "Property" and not member.static and member.value then
        self:line("self." .. member.name .. " = " .. self:emit_expr(member.value))
      end
    end
    local init_arg_names = {}
    for i, param in ipairs(node.params or {}) do
      self:line("local " .. param.name .. " = __jaya_args[" .. i .. "]")
      self:declare(param.name)
      if param.default then
        self:line("if " .. param.name .. " == nil then " .. param.name .. " = " .. self:emit_expr(param.default) .. " end")
      end
      self:line("self." .. param.name .. " = " .. param.name)
      init_arg_names[#init_arg_names + 1] = param.name
    end
    if constructor then
      self:line("return " .. node.name .. ".init(self" .. (#init_arg_names > 0 and ", " .. table.concat(init_arg_names, ", ") or "") .. ")")
    end
  end)
  self:line("end")
end

function Codegen:emit_if(node)
  local function emit_body(body)
    for _, stmt in ipairs(body or {}) do
      self:emit_stmt(stmt)
    end
  end
  local function emit_chain(index, else_body)
    local branch = node.branches[index]
    if not branch then
      emit_body(else_body)
      return
    end
    if branch.condition.kind == "LetCond" then
      local temp = self:new_temp()
      self:line("do")
      self:with_block(function()
        self:line("local " .. temp .. " = " .. self:emit_expr(branch.condition.value))
        self:line("if " .. temp .. " ~= nil and " .. temp .. " ~= false then")
        self:with_block(function()
          self:emit_pattern_local(branch.condition.pattern, temp)
          emit_body(branch.body)
        end)
        if node.branches[index + 1] or else_body then
          self:line("else")
          self:with_block(function()
            emit_chain(index + 1, else_body)
          end)
        end
        self:line("end")
      end)
      self:line("end")
      return
    end
    local keyword = index == 1 and "if" or "elseif"
    self:line(keyword .. " " .. self:emit_expr(branch.condition) .. " then")
    self:with_block(function()
      emit_body(branch.body)
    end)
    if node.branches[index + 1] then
      emit_chain(index + 1, else_body)
    elseif else_body then
      self:line("else")
      self:with_block(function()
        emit_body(else_body)
      end)
      self:line("end")
    else
      self:line("end")
    end
  end
  if #node.branches == 0 then
    return
  end
  emit_chain(1, node.else_body)
end

function Codegen:emit_if_branch(keyword, branch)
  if branch.condition.kind == "LetCond" then
    local temp = self:new_temp()
    self:line("do")
    self:with_block(function()
      self:line("local " .. temp .. " = " .. self:emit_expr(branch.condition.value))
      self:line(keyword .. " " .. temp .. " ~= nil and " .. temp .. " ~= false then")
      self:with_block(function()
        self:emit_pattern_local(branch.condition.pattern, temp)
        for _, stmt in ipairs(branch.body) do
          self:emit_stmt(stmt)
        end
      end)
    end)
    self:line("end")
  else
    self:line(keyword .. " " .. self:emit_expr(branch.condition) .. " then")
    self:with_block(function()
      for _, stmt in ipairs(branch.body) do
        self:emit_stmt(stmt)
      end
    end)
  end
end

function Codegen:emit_unless(node)
  local cond = node.condition
  if cond.kind == "LetCond" then
    local temp = self:new_temp()
    self:line("do")
    self:with_block(function()
      self:line("local " .. temp .. " = " .. self:emit_expr(cond.value))
      self:line("if " .. temp .. " == nil or " .. temp .. " == false then")
      self:with_block(function()
        for _, stmt in ipairs(node.body) do
          self:emit_stmt(stmt)
        end
      end)
      if node.else_body then
        self:line("else")
        self:with_block(function()
          self:emit_pattern_local(cond.pattern, temp)
          for _, stmt in ipairs(node.else_body) do
            self:emit_stmt(stmt)
          end
        end)
      end
      self:line("end")
    end)
    self:line("end")
    return
  end
  self:line("if not (" .. self:emit_expr(cond) .. ") then")
  self:with_block(function()
    for _, stmt in ipairs(node.body) do
      self:emit_stmt(stmt)
    end
  end)
  if node.else_body then
    self:line("else")
    self:with_block(function()
      for _, stmt in ipairs(node.else_body) do
        self:emit_stmt(stmt)
      end
    end)
  end
  self:line("end")
end

function Codegen:emit_condition_expr(cond)
  if cond.kind == "IfCond" then
    return self:emit_expr(cond.expr)
  elseif cond.kind == "UnlessCond" then
    return "not (" .. self:emit_expr(cond.expr) .. ")"
  end
  self:error("unsupported condition wrapper " .. tostring(cond.kind))
end

function Codegen:emit_case(node)
  local subject = self:new_temp()
  self:line("do")
  self:with_block(function()
    self:line("local " .. subject .. " = " .. self:emit_expr(node.subject))
    for i, clause in ipairs(node.whens or {}) do
      local keyword = i == 1 and "if" or "elseif"
      local tests = {}
      for j, value in ipairs(clause.values or {}) do
        tests[j] = subject .. " == " .. self:emit_expr(value)
      end
      self:line(keyword .. " " .. table.concat(tests, " or ") .. " then")
      self:with_block(function()
        for _, stmt in ipairs(clause.body) do
          self:emit_stmt(stmt)
        end
      end)
    end
    if node.else_body then
      self:line("else")
      self:with_block(function()
        for _, stmt in ipairs(node.else_body) do
          self:emit_stmt(stmt)
        end
      end)
    end
    self:line("end")
  end)
  self:line("end")
end

function Codegen:collect_pattern_names(pattern, out, seen)
  out = out or {}
  seen = seen or {}
  if pattern.kind == "PatternName" then
    if not seen[pattern.name] then
      seen[pattern.name] = true
      out[#out + 1] = pattern.name
    end
  elseif pattern.kind == "ArrayPattern" then
    for _, item in ipairs(pattern.items) do
      self:collect_pattern_names(item, out, seen)
    end
  elseif pattern.kind == "TablePattern" then
    for _, field in ipairs(pattern.fields) do
      self:collect_pattern_names(field.pattern, out, seen)
    end
  elseif pattern.kind == "ClassPattern" then
    for _, item in ipairs(pattern.args) do
      self:collect_pattern_names(item, out, seen)
    end
  end
  return out
end

function Codegen:emit_pattern_descriptor(pattern)
  if pattern.kind == "PatternWildcard" then
    return '{ kind = "wildcard" }'
  elseif pattern.kind == "PatternName" then
    return '{ kind = "name", name = ' .. string.format("%q", pattern.name) .. " }"
  elseif pattern.kind == "PatternLiteral" then
    return "{ kind = " .. string.format("%q", "literal") .. ", value = " .. self:emit_expr(pattern.value) .. " }"
  elseif pattern.kind == "ArrayPattern" then
    local items = {}
    for i, item in ipairs(pattern.items) do
      items[i] = self:emit_pattern_descriptor(item)
    end
    return '{ kind = "array", items = { ' .. table.concat(items, ", ") .. " } }"
  elseif pattern.kind == "TablePattern" then
    local fields = {}
    for i, field in ipairs(pattern.fields) do
      fields[i] = '{ key = ' .. string.format("%q", field.key) .. ", pattern = " .. self:emit_pattern_descriptor(field.pattern) .. " }"
    end
    return '{ kind = "table", fields = { ' .. table.concat(fields, ", ") .. " } }"
  elseif pattern.kind == "ClassPattern" then
    local args = {}
    for i, item in ipairs(pattern.args) do
      args[i] = self:emit_pattern_descriptor(item)
    end
    return '{ kind = "class", name = ' .. string.format("%q", pattern.name) .. ', args = { ' .. table.concat(args, ", ") .. " } }"
  end
  self:error("unsupported match pattern " .. tostring(pattern.kind))
end

function Codegen:emit_match(node)
  local value_temp = self:new_temp()
  self:line("do")
  self:with_block(function()
    self:line("local " .. value_temp .. " = " .. self:emit_expr(node.subject))
    for i, clause in ipairs(node.whens) do
      local keyword = (i == 1) and "if" or "elseif"
      local bind_temp = self:new_temp()
      self:line(keyword .. " (function() local " .. bind_temp .. " = {}; return __jaya_match(" .. value_temp .. ", " .. self:emit_pattern_descriptor(clause.pattern) .. ", " .. bind_temp .. "), " .. bind_temp .. " end)() then")
      self:with_block(function()
        self:line("local " .. bind_temp .. " = select(2, (function() local tmp = {}; return __jaya_match(" .. value_temp .. ", " .. self:emit_pattern_descriptor(clause.pattern) .. ", tmp), tmp end)())")
        for _, name in ipairs(self:collect_pattern_names(clause.pattern)) do
          self:declare(name)
          self:line("local " .. name .. " = " .. bind_temp .. "[" .. string.format("%q", name) .. "]")
        end
        for _, stmt in ipairs(clause.body) do
          self:emit_stmt(stmt)
        end
      end)
    end
    if node.else_body then
      self:line("else")
      self:with_block(function()
        for _, stmt in ipairs(node.else_body) do
          self:emit_stmt(stmt)
        end
      end)
    end
    self:line("end")
  end)
  self:line("end")
end

function Codegen:emit_let(node)
  self:line("do")
  self:with_block(function()
    for _, binding in ipairs(node.bindings) do
      self:emit_pattern_local(binding.pattern, self:emit_expr(binding.value))
    end
    for _, stmt in ipairs(node.body) do
      self:emit_stmt(stmt)
    end
  end)
  self:line("end")
end

function Codegen:emit_conditional_stmt(node)
  self:line("if " .. self:emit_condition_expr(node.condition) .. " then")
  self:with_block(function()
    self:emit_stmt(node.statement)
  end)
  self:line("end")
end

function Codegen:emit_catch_test(err_temp, catch_clause)
  if not catch_clause.types or #catch_clause.types == 0 then
    return "true"
  end
  local parts = {}
  for i, catch_type in ipairs(catch_clause.types) do
    parts[i] = "__jaya_catch_matches(" .. err_temp .. ", " .. self:emit_expr(catch_type) .. ")"
  end
  return table.concat(parts, " or ")
end

function Codegen:emit_try(node)
  if self:block_has_nonlocal_control(node.body) then
    self:error("try body cannot yet contain return or break in codegen")
  end
  for _, catch_clause in ipairs(node.catches or {}) do
    if self:block_has_nonlocal_control(catch_clause.body) then
      self:error("catch body cannot yet contain return or break in codegen")
    end
  end
  if self:block_has_nonlocal_control(node.finally_body) then
    self:error("finally body cannot yet contain return or break in codegen")
  end

  local ok_temp = self:new_temp()
  local err_temp = self:new_temp()
  local pending_temp = self:new_temp()
  local handled_temp = self:new_temp()

  self:line("do")
  self:with_block(function()
    local try_lines = self:compile_block_lines(node.body)
    self:line("local " .. ok_temp .. ", " .. err_temp .. " = xpcall(function()")
    self:with_block(function()
      for _, line in ipairs(try_lines) do
        self:line(line)
      end
    end)
    self:line("end, function(err) return err end)")
    self:line("local " .. pending_temp .. " = nil")
    self:line("if not " .. ok_temp .. " then")
    self:with_block(function()
      self:line("local " .. handled_temp .. " = false")
      for i, catch_clause in ipairs(node.catches or {}) do
        local catch_ok = self:new_temp()
        local catch_err = self:new_temp()
        local keyword = i == 1 and "if" or "elseif"
        self:line(keyword .. " " .. self:emit_catch_test(err_temp, catch_clause) .. " then")
        self:with_block(function()
          local catch_lines = self:compile_block_lines(catch_clause.body, function(child)
            child:declare("it")
            child:line("local it = " .. err_temp)
          end, true)
          self:line(handled_temp .. " = true")
          self:line("local " .. catch_ok .. ", " .. catch_err .. " = xpcall(function()")
          self:with_block(function()
            for _, line in ipairs(catch_lines) do
              self:line(line)
            end
          end)
          self:line("end, function(err) return err end)")
          self:line("if not " .. catch_ok .. " then")
          self:with_block(function()
            self:line(pending_temp .. " = " .. catch_err)
          end)
          self:line("end")
        end)
      end
      self:line("end")
      self:line("if not " .. handled_temp .. " then")
      self:with_block(function()
        self:line(pending_temp .. " = " .. err_temp)
      end)
      self:line("end")
    end)
    self:line("end")

    if node.finally_body then
      local finally_ok = self:new_temp()
      local finally_err = self:new_temp()
      local finally_lines = self:compile_block_lines(node.finally_body, nil, true)
      self:line("local " .. finally_ok .. ", " .. finally_err .. " = xpcall(function()")
      self:with_block(function()
        for _, line in ipairs(finally_lines) do
          self:line(line)
        end
      end)
      self:line("end, function(err) return err end)")
      self:line("if not " .. finally_ok .. " then")
      self:with_block(function()
        self:line(pending_temp .. " = " .. finally_err)
      end)
      self:line("end")
    end

    self:line("if " .. pending_temp .. " ~= nil then")
    self:with_block(function()
      self:line("error(" .. pending_temp .. ", 0)")
    end)
    self:line("end")
  end)
  self:line("end")
end

function Codegen:emit_expr_list(values)
  local parts = {}
  for i, value in ipairs(values) do
    parts[i] = self:emit_expr(value)
  end
  return table.concat(parts, ", ")
end

function Codegen:emit_lvalue(node)
  if node.kind == "Name" then
    return node.value
  elseif node.kind == "Member" then
    return self:emit_expr(node.object) .. "." .. node.name
  elseif node.kind == "Index" then
    return self:emit_expr(node.object) .. "[" .. self:emit_expr(node.index) .. "]"
  end
  self:error("unsupported assignment target " .. tostring(node.kind))
end

function Codegen:emit_expr(node)
  if node.kind == "Number" then
    return tostring(node.value)
  elseif node.kind == "String" then
    return string.format("%q", node.value)
  elseif node.kind == "InterpolatedString" then
    local parts = node.parts or {}
    if #parts == 0 then
      return string.format("%q", "")
    end
    local expr = self:emit_expr(parts[1])
    for i = 2, #parts do
      expr = "__jaya_add(" .. expr .. ", " .. self:emit_expr(parts[i]) .. ")"
    end
    return expr
  elseif node.kind == "Boolean" then
    return node.value and "true" or "false"
  elseif node.kind == "Nil" then
    return "nil"
  elseif node.kind == "Name" then
    return node.value
  elseif node.kind == "Unary" then
    if node.op == "~" then
      return "(~" .. self:emit_expr(node.value) .. ")"
    elseif node.op == "#" then
      return "__jaya_len(" .. self:emit_expr(node.value) .. ")"
    end
    return "(" .. node.op .. " " .. self:emit_expr(node.value) .. ")"
  elseif node.kind == "Binary" then
    if node.op == "+" then
      return "__jaya_add(" .. self:emit_expr(node.left) .. ", " .. self:emit_expr(node.right) .. ")"
    end
    return "(" .. self:emit_expr(node.left) .. " " .. node.op .. " " .. self:emit_expr(node.right) .. ")"
  elseif node.kind == "Call" then
    if node.callee.kind == "Name" and node.callee.value == "require" then
      if node.block then
        self:error("require does not accept a trailing block")
      end
      return "__jaya_require" .. self:emit_call_args(node.args, false, true)
    end
    if node.callee.kind == "Member" then
      if self:has_named_args(node.args) then
        return self:emit_named_member_call(node.callee.object, node.callee.name, node.args, node.block)
      end
      if node.block then
        local pos = self:emit_positional_arg_array(node.args)
        return "__jaya_call_member_with_block(" .. self:emit_expr(node.callee.object) .. ", " .. string.format("%q", node.callee.name) .. ", " .. pos .. ", " .. self:emit_block_arg(node.block) .. ")"
      end
      local args = {}
      for _, arg in ipairs(node.args) do
        if arg.kind ~= "PosArg" then
          self:error("named args are not yet supported in codegen")
        end
        args[#args + 1] = self:emit_expr(arg.value)
      end
      local suffix = #args > 0 and (", " .. table.concat(args, ", ")) or ""
      return "__jaya_call_member(" .. self:emit_expr(node.callee.object) .. ", " .. string.format("%q", node.callee.name) .. suffix .. ")"
    end
    if self:has_named_args(node.args) then
      return self:emit_named_call(node.callee, node.args, node.block)
    end
    return self:emit_call(node.callee, node.args, node.block)
  elseif node.kind == "MethodCall" then
    if self:has_named_args(node.args) then
      return self:emit_named_method_call(node.callee, node.method, node.args, false, node.block)
    end
    if node.block then
      local pos = self:emit_positional_arg_array(node.args)
      return "__jaya_call_method_with_block(" .. self:emit_expr(node.callee) .. ", " .. string.format("%q", node.method) .. ", " .. pos .. ", " .. self:emit_block_arg(node.block) .. ")"
    end
    local args = {}
    for i, arg in ipairs(node.args) do
      if arg.kind ~= "PosArg" then
        self:error("named args are not yet supported in codegen")
      end
      args[#args + 1] = self:emit_expr(arg.value)
    end
    local suffix = #args > 0 and (", " .. table.concat(args, ", ")) or ""
    return "__jaya_call_method(" .. self:emit_expr(node.callee) .. ", " .. string.format("%q", node.method) .. suffix .. ")"
  elseif node.kind == "Member" then
    return self:emit_expr(node.object) .. "." .. node.name
  elseif node.kind == "Index" then
    return "__jaya_get_index(" .. self:emit_expr(node.object) .. ", " .. self:emit_expr(node.index) .. ")"
  elseif node.kind == "Array" then
    local parts = {}
    for i, el in ipairs(node.elements) do
      parts[i] = self:emit_expr(el)
    end
    return "{ " .. table.concat(parts, ", ") .. " }"
  elseif node.kind == "Table" then
    local parts = {}
    for _, field in ipairs(node.fields) do
      if field.kind == "Field" then
        local key
        if can_emit_bare_key(field.name) then
          key = field.name
        else
          key = "[" .. string.format("%q", field.name) .. "]"
        end
        parts[#parts + 1] = key .. " = " .. self:emit_expr(field.value)
      else
        parts[#parts + 1] = self:emit_expr(field.value)
      end
    end
    return "{ " .. table.concat(parts, ", ") .. " }"
  elseif node.kind == "FnExpr" then
    local body_lines = self:emit_function_body(node.params, node.body)
    return "__jaya_register_params((function(" .. self:emit_param_signature(node.params) .. ")\n" ..
      self:indent_lines(body_lines, 1) .. "\nend), " .. self:emit_param_meta(node.params) .. ", nil, " .. string.format("%q", node.source or (self.source_name or "<unknown>")) .. ", " .. tostring(node.decl_line or 1) .. ", " .. tostring(node.decl_col or 1) .. ")"
  elseif node.kind == "Range" then
    return "__jaya_range(" .. self:emit_expr(node.start) .. ", " .. self:emit_expr(node["end"]) .. ", " .. (node.inclusive and "true" or "false") .. ")"
  elseif node.kind == "SafeMember" then
    return "__jaya_safe_member(" .. self:emit_expr(node.object) .. ", " .. string.format("%q", node.name) .. ")"
  elseif node.kind == "SafeIndex" then
    return "__jaya_safe_index(" .. self:emit_expr(node.object) .. ", " .. self:emit_expr(node.index) .. ")"
  elseif node.kind == "SafeCall" then
    if self:has_named_args(node.args) then
      return self:emit_named_call(node.callee, node.args, node.block, true)
    end
    if node.block then
      return "__jaya_call_safe_with_block(" .. self:emit_expr(node.callee) .. ", " .. self:emit_positional_arg_array(node.args) .. ", " .. self:emit_block_arg(node.block) .. ")"
    end
    return "__jaya_safe_call(" .. self:emit_expr(node.callee) .. self:emit_call_args(node.args, true) .. ")"
  elseif node.kind == "SafeMethodCall" then
    if self:has_named_args(node.args) then
      return self:emit_named_method_call(node.callee, node.method, node.args, true, node.block)
    end
    if node.block then
      local pos = self:emit_positional_arg_array(node.args)
      return "__jaya_call_safe_method_named_with_block(" .. self:emit_expr(node.callee) .. ", " .. string.format("%q", node.method) .. ", " .. pos .. ", { }, " .. self:emit_block_arg(node.block) .. ")"
    end
    local args = {}
    for _, arg in ipairs(node.args) do
      if arg.kind ~= "PosArg" then
        self:error("named args are not yet supported in codegen")
      end
      args[#args + 1] = self:emit_expr(arg.value)
    end
    local suffix = #args > 0 and (", " .. table.concat(args, ", ")) or ""
    return "__jaya_safe_method(" .. self:emit_expr(node.callee) .. ", " .. string.format("%q", node.method) .. suffix .. ")"
  elseif node.kind == "Super" then
    return "__jaya_super"
  elseif node.kind == "NewExpr" then
    if node.block then
      self:error("constructors do not yet accept trailing blocks")
    end
    if self:has_named_args(node.args) then
      return self:emit_named_call(node.class, node.args)
    end
    return "__jaya_new(" .. self:emit_expr(node.class) .. self:emit_call_args(node.args, true) .. ")"
  elseif node.kind == "Yield" then
    return self:emit_yield_expr(node)
  else
    self:error("unsupported expression " .. tostring(node.kind))
  end
end

function Codegen:emit_call(callee, args, block)
  if block then
    return "__jaya_call_with_block(" .. self:emit_expr(callee) .. ", " .. self:emit_positional_arg_array(args) .. ", " .. self:emit_block_arg(block) .. ")"
  end
  return self:emit_expr(callee) .. self:emit_call_args(args, false)
end

function Codegen:has_named_args(args)
  for _, arg in ipairs(args or {}) do
    if arg.kind == "NamedArg" then
      return true
    end
  end
  return false
end

function Codegen:emit_named_arg_tables(args)
  local positional = {}
  local named = {}
  local seen_named = {}
  local saw_named = false
  for _, arg in ipairs(args or {}) do
    if arg.kind == "PosArg" then
      if saw_named then
        self:error("positional arguments cannot follow named arguments in codegen")
      end
      positional[#positional + 1] = self:emit_expr(arg.value)
    elseif arg.kind == "NamedArg" then
      saw_named = true
      if seen_named[arg.name] then
        self:error("duplicate named argument: " .. arg.name)
      end
      seen_named[arg.name] = true
      named[#named + 1] = "[" .. string.format("%q", arg.name) .. "] = " .. self:emit_expr(arg.value)
    else
      self:error("unsupported call argument " .. tostring(arg.kind))
    end
  end
  return "{ " .. table.concat(positional, ", ") .. " }", "{ " .. table.concat(named, ", ") .. " }"
end

function Codegen:get_static_named_params(callee)
  if callee.kind == "Name" then
    return self.known_named_params[callee.value]
  end
  return nil
end

function Codegen:validate_static_named_args(callee, args)
  local params = self:get_static_named_params(callee)
  if not params then
    return
  end
  if params.kwrest ~= nil then
    return
  end
  local allowed = {}
  for _, name in ipairs(params.params or params) do
    allowed[name] = true
  end
  for _, arg in ipairs(args or {}) do
    if arg.kind == "NamedArg" and not allowed[arg.name] then
      self:error("unknown named argument for " .. callee.value .. ": " .. arg.name)
    end
  end
end

function Codegen:emit_block_arg(block)
  if not block then
    return "nil"
  end
  local body_lines = self:emit_function_body(block.params or {}, block.body)
  return "__jaya_register_params((function(" .. self:emit_param_signature(block.params or {}) .. ")\n" ..
    self:indent_lines(body_lines, 1) .. "\nend), " .. self:emit_param_meta(block.params or {}) .. ", nil, " .. string.format("%q", self.source_name or "<unknown>") .. ", " .. tostring(block.line or 1) .. ", " .. tostring(block.col or 1) .. ")"
end

function Codegen:emit_positional_arg_array(args)
  local parts = {}
  for _, arg in ipairs(args or {}) do
    if arg.kind ~= "PosArg" then
      self:error("named args are not yet supported in codegen")
    end
    parts[#parts + 1] = self:emit_expr(arg.value)
  end
  return "{ " .. table.concat(parts, ", ") .. " }"
end

function Codegen:emit_named_call(callee, args, block, safe)
  self:validate_static_named_args(callee, args)
  local pos, named = self:emit_named_arg_tables(args)
  if block then
    return "__jaya_call_named_with_block(" .. self:emit_expr(callee) .. ", " .. pos .. ", " .. named .. ", " .. self:emit_block_arg(block) .. ")"
  end
  return "__jaya_call_named(" .. self:emit_expr(callee) .. ", " .. pos .. ", " .. named .. ")"
end

function Codegen:emit_named_method_call(callee, method, args, safe, block)
  local pos, named = self:emit_named_arg_tables(args)
  local helper
  if safe then
    helper = block and "__jaya_call_safe_method_named_with_block" or "__jaya_call_safe_method_named"
  else
    helper = block and "__jaya_call_method_named_with_block" or "__jaya_call_method_named"
  end
  local suffix = block and (", " .. self:emit_block_arg(block)) or ""
  return helper .. "(" .. self:emit_expr(callee) .. ", " .. string.format("%q", method) .. ", " .. pos .. ", " .. named .. suffix .. ")"
end

function Codegen:emit_named_member_call(callee, method, args, block)
  local pos, named = self:emit_named_arg_tables(args)
  local suffix = block and (", " .. self:emit_block_arg(block)) or ", nil"
  return "__jaya_call_member_named(" .. self:emit_expr(callee) .. ", " .. string.format("%q", method) .. ", " .. pos .. ", " .. named .. suffix .. ")"
end

function Codegen:emit_call_args(args, include_leading_comma, append_require_context)
  local parts = {}
  for _, arg in ipairs(args) do
    if arg.kind ~= "PosArg" then
      self:error("named args are not yet supported in codegen")
    end
    parts[#parts + 1] = self:emit_expr(arg.value)
  end
  if append_require_context then
    parts[#parts + 1] = "__jaya_source"
    parts[#parts + 1] = "__jaya_compiler_path"
  end
  if include_leading_comma then
    if #parts == 0 then
      return ""
    end
    return ", " .. table.concat(parts, ", ")
  end
  return "(" .. table.concat(parts, ", ") .. ")"
end

function Codegen:block_param_name(params)
  for _, param in ipairs(params or {}) do
    if param.kind == "BlockParam" then
      return param.name
    end
  end
  return "__jaya_block"
end

function Codegen:emit_param_names(params)
  local parts = {}
  for _, param in ipairs(params) do
    if param.kind == "Param" or param.kind == "ClassParam" then
      parts[#parts + 1] = param.name
    elseif param.kind == "BlockParam" then
    elseif param.kind == "KwrestParam" then
      parts[#parts + 1] = param.name
    elseif param.kind == "RestParam" or param.kind == "VarargParam" then
      self:error("rest and vararg parameters are not yet supported in codegen")
    else
      self:error("only plain parameters are supported in codegen right now")
    end
  end
  return table.concat(parts, ", ")
end

function Codegen:emit_param_signature(params)
  local names = self:emit_param_names(params)
  local block_name = self:block_param_name(params)
  if names == "" then
    return block_name
  end
  return names .. ", " .. block_name
end

function Codegen:emit_param_name_array(params)
  local parts = {}
  for i, param in ipairs(params or {}) do
    if param.kind == "Param" or param.kind == "ClassParam" then
      parts[#parts + 1] = string.format("%q", param.name)
    elseif param.kind == "BlockParam" or param.kind == "KwrestParam" then
    else
      self:error("only plain parameters are supported in codegen right now")
    end
  end
  return "{ " .. table.concat(parts, ", ") .. " }"
end

function Codegen:kwrest_param_name(params)
  for _, param in ipairs(params or {}) do
    if param.kind == "KwrestParam" then
      return param.name
    end
  end
  return nil
end

function Codegen:emit_param_meta(params)
  local kwrest = self:kwrest_param_name(params)
  if kwrest == nil then
    return self:emit_param_name_array(params)
  end
  return "{ params = " .. self:emit_param_name_array(params) .. ", kwrest = " .. string.format("%q", kwrest) .. " }"
end

function Codegen:emit_function_body(params, body)
  local lines = {}
  local child = Codegen.new({ known_named_params = self.known_named_params })
  child.scope_stack = self:clone_scope_stack()
  child:push_scope()
  local block_name = self:block_param_name(params)
  local kwrest_name = self:kwrest_param_name(params)
  child.current_block_name = block_name
  child:declare(block_name)
  if kwrest_name ~= nil then
    child:declare(kwrest_name)
    child:line("if " .. kwrest_name .. " == nil then " .. kwrest_name .. " = {} end")
  end
  for _, param in ipairs(params) do
    if param.kind == "BlockParam" or param.kind == "KwrestParam" then
    elseif param.kind ~= "Param" and param.kind ~= "ClassParam" then
      child:error("only plain parameters are supported in codegen right now")
    end
    if param.kind == "Param" or param.kind == "ClassParam" then
      child:declare(param.name)
    end
    if (param.kind == "Param" or param.kind == "ClassParam") and param.default then
      child:line("if " .. param.name .. " == nil then " .. param.name .. " = " .. child:emit_expr(param.default) .. " end")
    end
  end
  if body.kind == "ExprBody" then
    child:line("return " .. child:emit_expr(body.value))
  else
    for _, stmt in ipairs(body.body) do
      child:emit_stmt(stmt)
    end
  end
  return child.lines
end

function Codegen:emit_yield_expr(node)
  local block_name = self.current_block_name or "__jaya_block"
  local wrapped = {}
  local has_named = false
  for _, arg in ipairs(node.args or {}) do
    if arg.kind == "NamedArg" then
      has_named = true
      wrapped[#wrapped + 1] = arg
    elseif arg.kind == "PosArg" then
      wrapped[#wrapped + 1] = arg
    else
      wrapped[#wrapped + 1] = { kind = "PosArg", value = arg }
    end
  end
  if has_named then
    local pos, named = self:emit_named_arg_tables(wrapped)
    return "__jaya_yield_named(" .. block_name .. ", " .. pos .. ", " .. named .. ")"
  end
  local parts = {}
  for _, arg in ipairs(wrapped) do
    parts[#parts + 1] = self:emit_expr(arg.value)
  end
  local suffix = #parts > 0 and (", " .. table.concat(parts, ", ")) or ""
  return "__jaya_yield(" .. block_name .. suffix .. ")"
end

function Codegen:indent_lines(lines, levels)
  local prefix = string.rep("  ", levels)
  local out = {}
  for i, line in ipairs(lines) do
    out[i] = prefix .. line
  end
  return table.concat(out, "\n")
end

function Codegen:emit_program(ast)
  self.lines = {}
  self.scope_stack = { {} }
  self.indent = 0
  self.temp_id = 0
  self.known_named_params = {}
  for _, stmt in ipairs(ast.body) do
    if (stmt.kind == "FnDecl" or stmt.kind == "ClassDecl") and stmt.name then
      local params = {}
      local source_params = stmt.params or {}
      for _, param in ipairs(source_params) do
        if param.kind == "Param" or param.kind == "ClassParam" then
          params[#params + 1] = param.name
        end
      end
      self.known_named_params[stmt.name] = {
        params = params,
        kwrest = self:kwrest_param_name(source_params),
      }
    end
  end
  self:line("local __jaya_source = " .. string.format("%q", self.source_name or "<unknown>"))
  self:line("local __jaya_compiler_path = " .. string.format("%q", self.compiler_path or "src/jpl.lua"))
  for line in LUA_PREAMBLE:gmatch("[^\n]+") do
    self:line(line)
  end
  local predeclared = {}
  for _, stmt in ipairs(ast.body) do
    if stmt.kind == "FnDecl" or stmt.kind == "ClassDecl" then
      if not predeclared[stmt.name] then
        predeclared[stmt.name] = true
        self:declare(stmt.name)
        self:line("local " .. stmt.name)
      end
    elseif stmt.kind == "ExportAssign" then
      for _, name in ipairs(stmt.names or {}) do
        if not predeclared[name] then
          predeclared[name] = true
          self:declare(name)
          self:line("local " .. name)
        end
      end
    end
  end
  for _, stmt in ipairs(ast.body) do
    self:emit_stmt(stmt)
  end
  self:line("return __jaya_exports")
  return table.concat(self.lines, "\n")
end

function JPL.compile_ast(ast, opts)
  opts = opts or {}
  local codegen = Codegen.new({
    source_name = opts.source_name,
    compiler_path = opts.compiler_path,
  })
  return codegen:emit_program(JPL.expand(JPL.resolve_includes(ast, opts.source_name)))
end

function JPL.compile(input, source)
  local ok, result = pcall(function()
    local codegen = Codegen.new({
      source_name = source,
      compiler_path = SELF_PATH,
    })
    return codegen:emit_program(JPL.expand(JPL.resolve_includes(JPL.parse(input, source), source)))
  end)
  if not ok then
    local msg = tostring(result)
    if msg:match("^Jaya ") then
      error(msg, 0)
    end
    error(string.format("Jaya compile error at %s: %s", source or "<input>", msg), 0)
  end
  return result
end

function JPL.run(input, source, env)
  local lua_code = JPL.compile(input, source)
  local chunk, err = load(lua_code, "@" .. (source or "<input>"), "t", env or _ENV)
  if chunk == nil then
    error(err, 0)
  end
  local ok, result = pcall(chunk)
  if not ok then
    error(result, 0)
  end
  return result
end

local function host_normalize_path(path)
  local absolute = type(path) == "string" and path:sub(1, 1) == "/"
  local parts = {}
  for piece in tostring(path):gmatch("[^/]+") do
    if piece == "." then
    elseif piece == ".." then
      if #parts > 0 and parts[#parts] ~= ".." then
        parts[#parts] = nil
      elseif not absolute then
        parts[#parts + 1] = piece
      end
    else
      parts[#parts + 1] = piece
    end
  end
  local joined = table.concat(parts, "/")
  if absolute then
    return "/" .. joined
  end
  return joined ~= "" and joined or "."
end

local function host_dirname(path)
  if type(path) ~= "string" then
    return "."
  end
  local dir = path:match("^(.*)/[^/]*$")
  if dir == nil or dir == "" then
    return "."
  end
  return dir
end

local function host_join_path(base, piece)
  if base == "." or base == "" then
    return piece
  end
  return base .. "/" .. piece
end

local function host_file_exists(path)
  local fh = io.open(path, "rb")
  if fh == nil then
    return false
  end
  fh:close()
  return true
end

local function host_read_file(path)
  local fh, err = io.open(path, "rb")
  if fh == nil then
    error(err, 0)
  end
  local data = fh:read("*a")
  fh:close()
  return data
end

local function include_call_path(stmt)
  if stmt.kind ~= "ExprStmt" or not stmt.expression or stmt.expression.kind ~= "Call" then
    return nil
  end
  local call = stmt.expression
  if call.block or call.callee.kind ~= "Name" or call.callee.value ~= "include" then
    return nil
  end
  if #(call.args or {}) ~= 1 or call.args[1].kind ~= "PosArg" or call.args[1].value.kind ~= "String" then
    error("Jaya compile error: include expects exactly one string path argument", 0)
  end
  return call.args[1].value.value
end

local function resolve_include_path(spec, source)
  if type(spec) ~= "string" then
    error("Jaya compile error: include expects a string path", 0)
  end
  local is_relative = spec:sub(1, 2) == "./" or spec:sub(1, 3) == "../"
  local is_absolute = spec:sub(1, 1) == "/"
  local candidates = {}
  local function push_candidates(raw)
    if raw:match("%.jpl$") then
      candidates[#candidates + 1] = raw
    else
      candidates[#candidates + 1] = raw .. ".jpl"
      candidates[#candidates + 1] = raw .. "/init.jpl"
    end
  end
  if is_relative or is_absolute then
    local raw = is_absolute and spec or host_normalize_path(host_join_path(host_dirname(source or "."), spec))
    push_candidates(raw)
  else
    push_candidates(host_normalize_path(host_join_path(SELF_DIR, "std/" .. spec)))
  end
  for _, candidate in ipairs(candidates) do
    candidate = host_normalize_path(candidate)
    if host_file_exists(candidate) then
      return candidate
    end
  end
  error(string.format("Jaya compile error at %s: include target not found: %s", source or "<input>", spec), 0)
end

local function mark_prelude_stmts(stmts)
  for _, stmt in ipairs(stmts or {}) do
    stmt.from_prelude = true
  end
end

function JPL.resolve_includes(ast, source, state)
  state = state or {
    included = {},
    loading = {},
    prelude_done = false,
  }
  local program_source = source or ast.source or "<input>"
  local body = {}
  if not state.prelude_done then
    state.prelude_done = true
    local prelude_path = host_normalize_path(host_join_path(SELF_DIR, "std/prelude.jpl"))
    if host_file_exists(prelude_path) and host_normalize_path(program_source) ~= prelude_path then
      state.loading[prelude_path] = true
      local prelude_ast = JPL.parse(host_read_file(prelude_path), prelude_path)
      prelude_ast = JPL.resolve_includes(prelude_ast, prelude_path, state)
      mark_prelude_stmts(prelude_ast.body)
      for _, prelude_stmt in ipairs(prelude_ast.body or {}) do
        body[#body + 1] = prelude_stmt
      end
      state.loading[prelude_path] = nil
      state.included[prelude_path] = true
    end
  end
  for _, stmt in ipairs(ast.body or {}) do
    local include_path = include_call_path(stmt)
    if include_path then
      local resolved = resolve_include_path(include_path, program_source)
      if state.loading[resolved] then
        error(string.format("Jaya compile error at %s: include cycle detected for %s", program_source, include_path), 0)
      end
      if not state.included[resolved] then
        state.loading[resolved] = true
        local included_ast = JPL.parse(host_read_file(resolved), resolved)
        included_ast = JPL.resolve_includes(included_ast, resolved, state)
        for _, included_stmt in ipairs(included_ast.body or {}) do
          body[#body + 1] = included_stmt
        end
        state.loading[resolved] = nil
        state.included[resolved] = true
      end
    else
      body[#body + 1] = stmt
    end
  end
  local out = clone_node(ast)
  out.body = body
  out.source = program_source
  return out
end

local function is_array(t)
  local n = 0
  for k in pairs(t) do
    if type(k) ~= "number" then
      return false
    end
    if k > n then
      n = k
    end
  end
  for i = 1, n do
    if t[i] == nil then
      return false
    end
  end
  return true
end

local function dump(value, indent, seen)
  indent = indent or ""
  seen = seen or {}
  local ty = type(value)
  if ty == "string" then
    return string.format("%q", value)
  elseif ty ~= "table" then
    return tostring(value)
  elseif seen[value] then
    return '"<cycle>"'
  end
  seen[value] = true
  local next_indent = indent .. "  "
  local parts = {}
  if is_array(value) then
    for i = 1, #value do
      parts[#parts + 1] = next_indent .. dump(value[i], next_indent, seen)
    end
    return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "]"
  end
  local keys = {}
  for k in pairs(value) do
    keys[#keys + 1] = k
  end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  for _, k in ipairs(keys) do
    parts[#parts + 1] = next_indent .. tostring(k) .. " = " .. dump(value[k], next_indent, seen)
  end
  return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
end

JPL.dump = dump
_G.JPL = JPL

local function read_file(path)
  local fh, err = io.open(path, "rb")
  if not fh then
    error(err, 0)
  end
  local data = fh:read("*a")
  fh:close()
  return data
end

local function write_file(path, data)
  local fh, err = io.open(path, "wb")
  if not fh then
    error(err, 0)
  end
  fh:write(data)
  fh:close()
end

local function file_exists(path)
  local fh = io.open(path, "rb")
  if fh == nil then
    return false
  end
  fh:close()
  return true
end

local function dirname(path)
  local dir = path:match("^(.*)/[^/]*$")
  if dir == nil or dir == "" then
    return "."
  end
  return dir
end

local function stem_name(path)
  local stem = path:match("([^/]+)$") or path
  stem = stem:gsub("%.jpl%.t$", "")
  stem = stem:gsub("%.jpl$", "")
  stem = stem:gsub("%.lua$", "")
  return stem
end

local function camelize(name)
  return (name:gsub("[-_]+([A-Za-z0-9])", function(ch)
    return ch:upper()
  end))
end

local function is_test_name(name)
  return type(name) == "string" and name:match("^test")
end

local function is_hook_name(name)
  return name == "before" or name == "after" or name == "beforeTest" or name == "afterTest"
end

local function sibling_module_info(test_path)
  local sibling = test_path:gsub("%.t$", "")
  if sibling == test_path then
    return nil
  end
  if not (sibling:match("%.jpl$") or sibling:match("%.lua$")) then
    return nil
  end
  if not file_exists(sibling) then
    return nil
  end
  return {
    path = sibling,
    bind = camelize(stem_name(sibling)),
  }
end

local function implicit_require_stmt(module_path, bind_name, test_path)
  local base = dirname(test_path)
  local rel = module_path
  if module_path:sub(1, #base) == base then
    local tail = module_path:sub(#base + 1)
    if tail:sub(1, 1) == "/" then
      tail = tail:sub(2)
    end
    rel = "./" .. tail
  end
  return {
    kind = "Assign",
    local_default = true,
    targets = { { kind = "Name", value = bind_name } },
    values = {
      {
        kind = "Call",
        callee = { kind = "Name", value = "require" },
        args = { { kind = "PosArg", value = { kind = "String", value = rel } } },
      },
    },
  }
end

local function implicit_member_alias_stmt(target_name, member_name)
  return {
    kind = "Assign",
    local_default = true,
    targets = { { kind = "Name", value = member_name } },
    values = {
      {
        kind = "Member",
        object = { kind = "Name", value = target_name },
        name = member_name,
      },
    },
  }
end

local function prepare_test_ast(ast, test_path)
  local out = clone_node(ast)
  local body = {}
  body[#body + 1] = implicit_require_stmt("test", "test", test_path)
  body[#body + 1] = implicit_member_alias_stmt("test", "assertEq")
  body[#body + 1] = implicit_member_alias_stmt("test", "assertNil")
  body[#body + 1] = implicit_member_alias_stmt("test", "compileAndLoad")
  local sibling = sibling_module_info(test_path)
  if sibling then
    body[#body + 1] = implicit_require_stmt(sibling.path, sibling.bind, test_path)
  end
  for _, stmt in ipairs(out.body or {}) do
    if stmt.kind == "FnDecl" and (is_test_name(stmt.name) or is_hook_name(stmt.name)) then
      stmt.exported = true
      stmt.local_default = false
    end
    body[#body + 1] = stmt
  end
  out.body = body
  return out
end

local function compile_chunk(ast, source, already_resolved)
  local lua_code
  if already_resolved then
    local codegen = Codegen.new({
      source_name = source,
      compiler_path = SELF_PATH,
    })
    lua_code = codegen:emit_program(JPL.expand(ast))
  else
    lua_code = JPL.compile_ast(ast, {
      source_name = source,
      compiler_path = SELF_PATH,
    })
  end
  local chunk, err = load(lua_code, "@" .. source, "t", _ENV)
  if chunk == nil then
    error(err, 0)
  end
  local ok, exports = pcall(chunk)
  if not ok then
    error(exports, 0)
  end
  return exports
end

local function discover_tests(exports)
  local tests = {}
  for name, value in pairs(exports or {}) do
    if is_test_name(name) and type(value) == "function" then
      tests[#tests + 1] = { name = name, fn = value }
    end
  end
  table.sort(tests, function(a, b) return a.name < b.name end)
  return tests
end

local function run_hook(exports, name)
  local fn = exports and exports[name]
  if type(fn) ~= "function" then
    return true
  end
  return pcall(fn)
end

local function list_test_files(args)
  if #args > 0 then
    return args
  end
  local files = {}
  local proc = io.popen([[find ./tests -type f -name '*.t' 2>/dev/null | sort]])
  if proc then
    for line in proc:lines() do
      files[#files + 1] = line
    end
    proc:close()
  end
  if #files == 0 then
    proc = io.popen([[find . -type f \( -name '*.jpl.t' -o -name 'jpl.t' \) | sort]])
    if proc then
      for line in proc:lines() do
        files[#files + 1] = line
      end
      proc:close()
    end
  end
  return files
end

local function run_test_module(path)
  local ast = JPL.resolve_includes(JPL.parse(read_file(path), path), path)
  ast = prepare_test_ast(ast, path)
  local exports = compile_chunk(ast, path, true)
  local tests = discover_tests(exports)
  local results = { path = path, tests = 0, passed = 0, failed = 0, failures = {} }
  if #tests == 0 then
    return results
  end
  local ok, err = run_hook(exports, "before")
  if not ok then
    results.failed = #tests
    results.tests = #tests
    results.failures[#results.failures + 1] = { name = "before", message = err }
    return results
  end
  for _, test in ipairs(tests) do
    results.tests = results.tests + 1
    local before_ok, before_err = run_hook(exports, "beforeTest")
    local test_ok, test_err
    if before_ok then
      test_ok, test_err = pcall(test.fn)
    else
      test_ok, test_err = false, before_err
    end
    local after_ok, after_err = run_hook(exports, "afterTest")
    if not test_ok or not after_ok then
      results.failed = results.failed + 1
      results.failures[#results.failures + 1] = {
        name = test.name,
        message = not test_ok and test_err or after_err,
      }
    else
      results.passed = results.passed + 1
    end
  end
  local after_ok, after_err = run_hook(exports, "after")
  if not after_ok then
    results.failures[#results.failures + 1] = { name = "after", message = after_err }
  end
  return results
end

local function print_test_results(results)
  for _, suite in ipairs(results) do
    io.write(suite.path, ": ", suite.passed, "/", suite.tests, " passed\n")
    for _, failure in ipairs(suite.failures) do
      io.write("  FAIL ", failure.name, "\n")
      io.write("    ", tostring(failure.message), "\n")
    end
  end
end

local function run_tests(args)
  local files = list_test_files(args)
  if #files == 0 then
    io.write("No Jaya tests found.\n")
    return 0
  end
  local all, total, passed, failed = {}, 0, 0, 0
  for _, path in ipairs(files) do
    local ok, result = pcall(run_test_module, path)
    if not ok then
      result = {
        path = path,
        tests = 0,
        passed = 0,
        failed = 1,
        failures = { { name = "module", message = result } },
      }
    end
    total = total + result.tests
    passed = passed + result.passed
    failed = failed + result.failed
    all[#all + 1] = result
  end
  print_test_results(all)
  io.write("\nSummary: ", passed, "/", total, " passed")
  if failed > 0 then
    io.write(", ", failed, " failed")
  end
  io.write("\n")
  return failed > 0 and 1 or 0
end

local function compiler_path()
  return SELF_PATH
end

local function execute_compiled(lua_code, source, env)
  local chunk, err = load(lua_code, "@" .. (source or "<input>"), "t", env or _ENV)
  if chunk == nil then
    error(err, 0)
  end
  local ok, result = pcall(chunk)
  if not ok then
    error(result, 0)
  end
  return result
end

local function promote_repl_ast(ast)
  local out = clone_node(ast)
  local body = {}
  for _, stmt in ipairs(out.body or {}) do
    if stmt.kind == "Assign" and stmt.local_default then
      local names = {}
      local can_export = #stmt.targets == #stmt.values
      for i, target in ipairs(stmt.targets or {}) do
        if target.kind ~= "Name" then
          can_export = false
          break
        end
        names[i] = target.value
      end
      if can_export then
        body[#body + 1] = {
          kind = "ExportAssign",
          names = names,
          values = clone_node(stmt.values),
          top_level_only = true,
        }
      else
        body[#body + 1] = stmt
      end
    elseif stmt.kind == "FnDecl" or stmt.kind == "ClassDecl" or stmt.kind == "MacroDecl" then
      stmt.exported = true
      stmt.local_default = false
      body[#body + 1] = stmt
    else
      body[#body + 1] = stmt
    end
  end
  out.body = body
  return out
end

local function print_repl_value(value)
  if value == nil then
    return
  end
  print(dump(value))
end

local function run_repl(preload_path)
  local env = setmetatable({
    __jaya_exports = {},
  }, {
    __index = _ENV,
  })
  if preload_path then
    local ok, result = pcall(function()
      local ast = JPL.parse(read_file(preload_path), preload_path)
      local promoted = promote_repl_ast(ast)
      local lua_code = JPL.compile_ast(promoted, {
        source_name = preload_path,
        compiler_path = compiler_path(),
      })
      return execute_compiled(lua_code, preload_path, env)
    end)
    if not ok then
      io.stderr:write(tostring(result), "\n")
      os.exit(1)
    end
    if type(result) == "table" then
      for key, value in pairs(result) do
        env[key] = value
      end
    end
  end
  io.write("Jaya REPL. Blank line runs buffered input. Use =expr to inspect a value. :quit to exit.\n")
  local buffer = {}
  while true do
    io.write(#buffer == 0 and "jaya> " or "....> ")
    local line = io.read("*line")
    if line == nil then
      if #buffer == 0 then
        io.write("\n")
        break
      end
      line = ""
    end
    if #buffer == 0 and (line == ":quit" or line == ":exit") then
      break
    end
    if #buffer == 0 and line:match("^=%s*") then
      local expr = line:gsub("^=%s*", "")
      local source = "<repl>"
      local ast = JPL.parse("export __repl_value = " .. expr, source)
      local promoted = promote_repl_ast(ast)
      local lua_code = JPL.compile_ast(promoted, {
        source_name = source,
        compiler_path = compiler_path(),
      })
      local ok, result = pcall(execute_compiled, lua_code, source, env)
      if not ok then
        io.stderr:write(tostring(result), "\n")
      else
        if type(result) == "table" then
          for key, value in pairs(result) do
            env[key] = value
          end
          print_repl_value(result.__repl_value)
        end
      end
    else
      if line ~= "" then
        buffer[#buffer + 1] = line
      end
      if line == "" and #buffer > 0 then
        local source = "<repl>"
        local input = table.concat(buffer, "\n")
        local ok, result = pcall(function()
          local ast = JPL.parse(input, source)
          local promoted = promote_repl_ast(ast)
          local lua_code = JPL.compile_ast(promoted, {
            source_name = source,
            compiler_path = compiler_path(),
          })
          return execute_compiled(lua_code, source, env)
        end)
        if not ok then
          io.stderr:write(tostring(result), "\n")
        elseif type(result) == "table" then
          for key, value in pairs(result) do
            env[key] = value
          end
          if result.__repl_value ~= nil then
            print_repl_value(result.__repl_value)
          end
        end
        buffer = {}
      end
    end
  end
end

local function run_cli()
  local cmd = arg[1]
  if cmd == nil then
    run_repl()
    return
  end
  if cmd == "--i" then
    run_repl(arg[2])
    return
  end
  if cmd == "--t" then
    local test_args = {}
    for i = 2, #arg do
      test_args[#test_args + 1] = arg[i]
    end
    os.exit(run_tests(test_args))
  end

  local mode = "run"
  local path = cmd
  if cmd == "--lua" then
    mode = "lua"
    path = arg[2]
  elseif cmd == "--ast" then
    mode = "ast"
    path = arg[2]
  elseif cmd == "--luac" then
    mode = "luac"
    path = arg[2]
  end

  local ok, result = pcall(function()
    if mode == "run" then
      if path == "-" then
        return JPL.run(io.read("*a"), "<stdin>")
      end
      return JPL.run(read_file(path), path)
    elseif mode == "lua" then
      local source = path and path ~= "-" and path or "<stdin>"
      local input = path and path ~= "-" and read_file(path) or io.read("*a")
      return JPL.compile(input, source)
    elseif mode == "luac" then
      local source = path and path ~= "-" and path or "<stdin>"
      local input = path and path ~= "-" and read_file(path) or io.read("*a")
      local lua_code = JPL.compile(input, source)
      local chunk, err = load(lua_code, "@" .. source, "t", _ENV)
      if chunk == nil then
        error(err, 0)
      end
      local output = arg[3] or "luac.out"
      write_file(output, string.dump(chunk))
      return output
    else
      local source = path and path ~= "-" and path or "<stdin>"
      local input = path and path ~= "-" and read_file(path) or io.read("*a")
      local ast = JPL.parse(input, source)
      return dump(ast)
    end
  end)
  if not ok then
    io.stderr:write(tostring(result), "\n")
    os.exit(1)
  end
  if mode ~= "run" and mode ~= "luac" and result ~= nil then
    print(result)
  end
end

if not _G.__JPL_AS_MODULE and arg and arg[0] and arg[0]:match("jpl%.lua$") then
  run_cli()
else
  return JPL
end
