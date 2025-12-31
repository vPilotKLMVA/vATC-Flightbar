-- json.lua
-- Simple JSON encoding and decoding in pure Lua.
-- Based on the JSON.lua library from rxi (https://github.com/rxi/json.lua)

local json = {}

local escape_char_map = {
  ["\\"] = "\\\\",
  ["\""] = "\\\"",
  ["\b"] = "\\b",
  ["\f"] = "\\f",
  ["\n"] = "\\n",
  ["\r"] = "\\r",
  ["\t"] = "\\t",
}

local escape_char_map_inv = { ["\\/"] = "/" }
for k, v in pairs(escape_char_map) do
  escape_char_map_inv[v] = k
end


local function escape_char(c)
  return escape_char_map[c] or string.format("\\u%04x", c:byte())
end


local function encode_nil(val)
  return "null"
end


local function encode_table(val)
  local res = {}
  local n = 0
  for k, v in pairs(val) do
    n = n + 1
    res[n] = json.encode(k) .. ":" .. json.encode(v)
  end
  return "{" .. table.concat(res, ",") .. "}"
end


local function encode_array(val)
  local res = {}
  for i, v in ipairs(val) do
    res[i] = json.encode(v)
  end
  return "[" .. table.concat(res, ",") .. "]"
end


local function encode_string(val)
  return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end


local function encode_number(val)
  if val ~= val or val <= -math.huge or val >= math.huge then
    return "null"
  end
  return string.format("%.14g", val)
end


local type_func_map = {
  ["nil"] = encode_nil,
  ["table"] = encode_table,
  ["string"] = encode_string,
  ["number"] = encode_number,
  ["boolean"] = tostring,
}


function json.encode(val)
  local t = type(val)
  local f = type_func_map[t]
  if f then
    return f(val)
  end
  error("unexpected type '" .. t .. "'")
end


local function next_char(str, idx, patt, plain)
  local i = idx
  while true do
    i = str:find(patt, i, plain)
    if not i then return nil end
    if str:sub(i - 1, i - 1) ~= "\\" then
      return i
    end
    i = i + 1
  end
end


local function decode_error(str, idx, msg)
  local line_count = 1
  local col_count = 1
  for i = 1, idx - 1 do
    col_count = col_count + 1
    if str:sub(i, i) == "\n" then
      line_count = line_count + 1
      col_count = 1
    end
  end
  error(string.format("%s at line %d col %d", msg, line_count, col_count))
end


local function codepoint_to_utf8(n)
  -- http://scripts.sil.org/cms/scripts/page.php?item_id=IWS-Appendixa#647832f4
  local f = math.floor
  if n <= 0x7f then
    return string.char(n)
  elseif n <= 0x7ff then
    return string.char(f(n / 64) + 192, n % 64 + 128)
  elseif n <= 0xffff then
    return string.char(f(n / 4096) + 224, f(n / 64) % 64 + 128, n % 64 + 128)
  elseif n <= 0x10ffff then
    return string.char(f(n / 262144) + 240, f(n / 4096) % 64 + 128, f(n / 64) % 64 + 128, n % 64 + 128)
  end
  error(string.format("invalid unicode codepoint '%x'", n))
end


local function parse_unicode_escape(s)
  local n1 = tonumber(s:sub(1, 2), 16)
  local n2 = tonumber(s:sub(3, 4), 16)
  local n3 = tonumber(s:sub(5, 6), 16)
  local n4 = tonumber(s:sub(7, 8), 16)
  return codepoint_to_utf8(n1 * 4096 + n2 * 256 + n3 * 16 + n4)
end


local function parse_string(str, i)
  local res = {}
  local j = i + 1
  local k = j

  while j <= #str do
    local x = str:byte(j)

    if x < 32 then
      decode_error(str, j, "control character in string")

    elseif x == 92 then -- `\`, escape sequence
      table.insert(res, str:sub(k, j - 1))
      j = j + 1

      x = str:byte(j)
      if x == 34 then
        table.insert(res, "\"")
      elseif x == 92 then
        table.insert(res, "\\")
      elseif x == 47 then
        table.insert(res, "/")
      elseif x == 98 then
        table.insert(res, "\b")
      elseif x == 102 then
        table.insert(res, "\f")
      elseif x == 110 then
        table.insert(res, "\n")
      elseif x == 114 then
        table.insert(res, "\r")
      elseif x == 116 then
        table.insert(res, "\t")
      elseif x == 117 then
        local s = str:sub(j + 1, j + 4)
        table.insert(res, parse_unicode_escape(s))
        j = j + 4
      else
        decode_error(str, j, "invalid escape sequence")
      end

      j = j + 1
      k = j

    elseif x == 34 then -- `"`, end of string
      table.insert(res, str:sub(k, j - 1))
      return table.concat(res), j + 1

    else
      j = j + 1
    end
  end

  decode_error(str, i, "expected closing quote for string")
end


local function parse_number(str, i)
  local x = str:match("^[%-+]?[0-9%.eE]+", i)
  if not x then
    decode_error(str, i, "invalid number")
  end
  local n = tonumber(x)
  if not n then
    decode_error(str, i, "invalid number")
  end
  return n, i + #x
end


local function parse_literal(str, i)
  local x = str:match("^%a+", i)
  if not x then
    decode_error(str, i, "expected literal")
  end
  if x == "true" then
    return true, i + 4
  elseif x == "false" then
    return false, i + 5
  elseif x == "null" then
    return nil, i + 4
  end
  decode_error(str, i, "invalid literal '" .. x .. "'")
end


local function parse_array(str, i)
  local res = {}
  local n = 1
  i = i + 1
  while true do
    local x
    i = str:match("^%s*", i)
    if str:sub(i, i) == "]" then
      return res, i + 1
    end
    x, i = json.decode(str, i)
    res[n] = x
    n = n + 1
    i = str:match("^%s*", i)
    local c = str:sub(i, i)
    if c == "]" then
      return res, i + 1
    elseif c ~= "," then
      decode_error(str, i, "expected ']' or ','")
    end
    i = i + 1
  end
end


local function parse_object(str, i)
  local res = {}
  i = i + 1
  while true do
    local key, val
    i = str:match("^%s*", i)
    if str:sub(i, i) == "}" then
      return res, i + 1
    end
    key, i = json.decode(str, i)
    if type(key) ~= "string" then
      logMessage("Error: Expected a string for key, got " .. type(key))
      decode_error(str, i, "expected string for key")
    end
    i = str:match("^%s*", i)
    if str:sub(i, i) ~= ":" then
      decode_error(str, i, "expected ':' after key")
    end
    i = i + 1
    val, i = json.decode(str, i)
    res[key] = val
    i = str:match("^%s*", i)
    local c = str:sub(i, i)
    if c == "}" then
      return res, i + 1
    elseif c ~= "," then
      decode_error(str, i, "expected '}' or ','")
    end
    i = i + 1
  end
end


local char_func_map = {
  ["\""] = parse_string,
  ["0"] = parse_number,
  ["1"] = parse_number,
  ["2"] = parse_number,
  ["3"] = parse_number,
  ["4"] = parse_number,
  ["5"] = parse_number,
  ["6"] = parse_number,
  ["7"] = parse_number,
  ["8"] = parse_number,
  ["9"] = parse_number,
  ["-"] = parse_number,
  ["t"] = parse_literal,
  ["f"] = parse_literal,
  ["n"] = parse_literal,
  ["["] = parse_array,
  ["{"] = parse_object,
}


function json.decode(str, idx)
  idx = idx or 1
  local c = str:match("^%s*(.)", idx)
  if not c then
    return nil, idx
  end
  local f = char_func_map[c]
  if f then
    return f(str, idx)
  end
  decode_error(str, idx, "unexpected character '" .. c .. "'")
end

return json
