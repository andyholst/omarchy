local captured = {}
local seen_order = {}

hl = {
  env = function(name, value)
    table.insert(seen_order, name)
    if name == "PATH" then return end
    captured[name] = value
  end,
  config = function() end,
  monitor = function() end,
  bind = function() end,
  window_rule = function() end,
  workspace_rule = function() end,
  layer_rule = function() end,
  gesture = function() end,
  animation = function() end,
  curve = function() end,
  exec_cmd = function() end,
  dispatch = function() end,
  on = function() end,
  timer = function() end,
}

o = {
  shell_succeeds = function(command)
    -- Lua 5.3+ os.execute returns true for exit 0, nil otherwise
    local success = os.execute(command .. ' >/dev/null 2>&1')
    return success == true
  end,
  shell_quote = function(path)
    return "'" .. path:gsub("'", "'\\''") .. "'"
  end,
}

package.path = os.getenv("OMARCHY_PATH") .. "/?.lua;" .. package.path
dofile(os.getenv("OMARCHY_PATH") .. "/default/hypr/nvidia.lua")

local json_encode
json_encode = function(value)
  if type(value) == 'table' then
    local parts = {}
    local is_array = #value > 0
    if is_array then
      for _, v in ipairs(value) do
        table.insert(parts, json_encode(v))
      end
      return '[' .. table.concat(parts, ',') .. ']'
    end
    for k, v in pairs(value) do
      table.insert(parts, json_encode(k) .. ':' .. json_encode(v))
    end
    return '{' .. table.concat(parts, ',') .. '}'
  end
  if type(value) == 'string' then
    return '"' .. value:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
  end
  return tostring(value)
end

print(json_encode({ env = captured, order = seen_order }))
