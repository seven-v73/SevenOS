local sep = package.config:sub(1, 1)
local script = arg[0] or ""
local root = script:gsub(sep .. "hyprland" .. sep .. "lua" .. sep .. "init%.lua$", "")
if root == script then
  root = os.getenv("SEVENOS_ROOT") or "."
end

package.path = table.concat({
  root .. "/hyprland/lua/?.lua",
  root .. "/hyprland/lua/?/init.lua",
  package.path,
}, ";")

local audit = require("core.audit")
local emit = require("core.emit")
local profiles = require("core.profiles")
local animation_rules = require("rules.animations")
local keybind_rules = require("rules.keybinds")
local window_rules = require("rules.windows")

local state_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local state_dir = state_home .. "/sevenos/hypr-lua"
local generated_path = root .. "/hyprland/conf/sevenos-lua-generated.conf"
local config_map_path = root .. "/hyprland/lua/config_map.json"
local runtime_plan_path = root .. "/hyprland/lua/profile_runtime.json"

local function mkdir_p(path)
  os.execute(string.format("mkdir -p %q", path))
end

local function write_file(path, content)
  local file = assert(io.open(path, "w"))
  file:write(content)
  file:close()
end

local function read_file(path)
  local file = io.open(path, "r")
  if not file then return "" end
  local content = file:read("*a")
  file:close()
  return content or ""
end

local function json_escape(value)
  value = tostring(value or "")
  value = value:gsub("\\", "\\\\")
  value = value:gsub('"', '\\"')
  value = value:gsub("\n", "\\n")
  value = value:gsub("\r", "\\r")
  return '"' .. value .. '"'
end

local function json_encode(value)
  local kind = type(value)
  if kind == "nil" then return "null" end
  if kind == "boolean" then return value and "true" or "false" end
  if kind == "number" then return tostring(value) end
  if kind == "string" then return json_escape(value) end
  if kind == "table" then
    local is_array = true
    local max = 0
    for key, _ in pairs(value) do
      if type(key) ~= "number" then is_array = false break end
      if key > max then max = key end
    end
    local parts = {}
    if is_array then
      for i = 1, max do parts[#parts + 1] = json_encode(value[i]) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    for key, item in pairs(value) do
      parts[#parts + 1] = json_escape(key) .. ":" .. json_encode(item)
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return json_escape(value)
end

local function active_profile()
  local env_path = state_home .. "/sevenos/profile.env"
  local content = read_file(env_path)
  local profile =
    content:match('SEVENOS_ACTIVE_PROFILE="([%w%-_]+)"') or
    content:match("SEVENOS_ACTIVE_PROFILE=([%w%-_]+)") or
    content:match('SEVENOS_PROFILE="([%w%-_]+)"') or
    content:match("SEVENOS_PROFILE=([%w%-_]+)")
  return profile or "equinox"
end

local function is_json_flag(value)
  return value == "--json" or value == "json"
end

local function selected_profile(default_profile)
  for index = 2, #arg do
    local value = arg[index]
    if value and not is_json_flag(value) then
      return value
    end
  end
  return default_profile or active_profile()
end

local function wants_json()
  for index = 2, #arg do
    if is_json_flag(arg[index]) then return true end
  end
  return false
end

local function status_payload()
  return {
    schema = "sevenos.hypr-lua.v1",
    root = root,
    lua = _VERSION,
    active_profile = active_profile(),
    generated = generated_path,
    config_map = config_map_path,
    architecture = "lua-intent-to-hyprland-conf",
    fallback = "static-hyprland-conf",
    safe_mode = true,
  }
end

local function profile_plan_payload(profile_key)
  local profile = profiles.load(profile_key, root)
  return {
    schema = "sevenos.hypr-lua.profile-runtime.v1",
    profile = profile.key,
    title = profile.title,
    role = profile.role,
    workspace_policy = profile.workspace_policy,
    ui_density = profile.ui_density,
    runtime_signals = profile.runtime_signals or {},
    workspace_intent = profile.workspace_intent or {},
    actions = profile.actions or {},
    env_rules = profile.env_rules or {},
    common_animation_rules = animation_rules.common_rules or {},
    common_keybinds = keybind_rules.common_binds or {},
    mouse_binds = keybind_rules.mouse_binds or {},
    common_window_rules = window_rules.common_rules or {},
    common_workspace_rules = window_rules.workspace_rules or {},
    layout_rules = profile.layout_rules or {},
    workspace_rules = profile.workspace_rules or {},
    window_rules = profile.window_rules or {},
    generated = generated_path,
    fallback = "static-hyprland-conf",
    safe_mode = true,
  }
end

local function write_profile_plan(profile_key)
  local payload = profile_plan_payload(profile_key)
  local encoded = json_encode(payload) .. "\n"
  mkdir_p(root .. "/hyprland/lua")
  mkdir_p(state_dir)
  write_file(runtime_plan_path, encoded)
  write_file(state_dir .. "/profile_runtime.json", encoded)
  return payload, encoded
end

local function status(json)
  local payload = status_payload()
  if json then
    print(json_encode(payload))
  else
    print("SevenOS Hypr Lua Engine")
    print("Lua:       " .. payload.lua)
    print("Profile:   " .. payload.active_profile)
    print("Generated: " .. payload.generated)
    print("Fallback:  " .. payload.fallback)
  end
end

local function list_profiles(json)
  local items = profiles.known()
  if json then
    print(json_encode({
      schema = "sevenos.hypr-lua.profiles.v1",
      active_profile = active_profile(),
      profiles = items,
    }))
  else
    print("SevenOS Hypr Lua profiles")
    for _, item in ipairs(items) do
      local marker = item == active_profile() and "*" or " "
      print(marker .. " " .. item)
    end
  end
end

local function plan(profile_key, json)
  local payload, encoded = write_profile_plan(profile_key)
  if json then
    io.write(encoded)
  else
    print("SevenOS Hypr Lua profile plan")
    print("Profile:      " .. payload.profile .. " - " .. payload.title)
    print("Role:         " .. payload.role)
    print("Layout:       " .. payload.workspace_policy)
    print("Window rules: " .. tostring(#payload.window_rules))
    print("Env rules:    " .. tostring(#payload.env_rules))
    print("Plan:         " .. runtime_plan_path)
  end
end

local function do_audit(json)
  local map = audit.map(root)
  mkdir_p(root .. "/hyprland/lua")
  mkdir_p(state_dir)
  local encoded = json_encode(map) .. "\n"
  write_file(config_map_path, encoded)
  write_file(state_dir .. "/config_map.json", encoded)
  if json then
    io.write(encoded)
  else
    print("SevenOS Hypr Lua audit")
    print("Binds:       " .. tostring(map.counts.binds))
    print("Windowrules: " .. tostring(map.counts.windowrules))
    print("Sources:     " .. tostring(map.counts.sources))
    print("Scripts:     " .. tostring(#map.sevenos_commands))
    print("Map:         " .. config_map_path)
  end
end

local function generate(profile_key)
  profile_key = profile_key or active_profile()
  local profile = profiles.load(profile_key, root)
  local conf = emit.render({
    profile = profile,
    common_keybinds = keybind_rules.common_binds or {},
    mouse_binds = keybind_rules.mouse_binds or {},
    common_animation_rules = animation_rules.common_rules or {},
    common_window_rules = window_rules.common_rules or {},
    common_workspace_rules = window_rules.workspace_rules or {},
    generated_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  })
  write_file(generated_path, conf)
  write_profile_plan(profile.key)
  print("Generated " .. generated_path)
end

local function apply(profile_key)
  generate(profile_key)
  local target = state_home .. "/hypr/conf/sevenos-lua-generated.conf"
  mkdir_p(state_home .. "/hypr/conf")
  os.execute(string.format("cp %q %q", generated_path, target))
  if os.getenv("HYPRLAND_INSTANCE_SIGNATURE") then
    os.execute("hyprctl reload >/dev/null 2>&1 || true")
  end
  print("Applied " .. target)
end

local function doctor()
  local ok = true
  local hyprland_conf = read_file(root .. "/hyprland/hyprland.conf")
  if not hyprland_conf:find("sevenos%-lua%-generated%.conf") then
    print("MISS source include: sevenos-lua-generated.conf")
    ok = false
  end
  if not read_file(generated_path):find("SevenOS Lua generated") then
    print("MISS generated fallback file")
    ok = false
  end
  if not profiles.load(active_profile(), root) then
    print("MISS active profile module")
    ok = false
  end
  if not window_rules.common_rules or #window_rules.common_rules < 20 then
    print("MISS common Lua window rules")
    ok = false
  end
  if not keybind_rules.common_binds or #keybind_rules.common_binds < 50 then
    print("MISS common Lua keybind rules")
    ok = false
  end
  for _, key in ipairs(profiles.known()) do
    local profile = profiles.load(key, root)
    if profile.key ~= key then
      print("MISS profile module: " .. key)
      ok = false
    end
  end
  if not read_file(runtime_plan_path):find("sevenos%.hypr%-lua%.profile%-runtime%.v1") then
    write_profile_plan(active_profile())
  end
  if ok then
    print("SevenOS Hypr Lua Engine: OK")
  else
    os.exit(1)
  end
end

local command = arg[1] or "status"
local json = wants_json()
local profile_key = selected_profile(active_profile())

if command == "status" then status(json)
elseif command == "json" then status(true)
elseif command == "profiles" then list_profiles(json)
elseif command == "plan" then plan(profile_key, json)
elseif command == "audit" then do_audit(json)
elseif command == "generate" then generate(profile_key)
elseif command == "apply" then apply(profile_key)
elseif command == "doctor" then doctor()
elseif command == "help" or command == "-h" or command == "--help" then
  print("Usage: seven hypr lua <status|profiles|plan|audit|generate|apply|doctor> [profile] [--json]")
else
  io.stderr:write("Unknown Hypr Lua action: " .. command .. "\n")
  os.exit(1)
end
