local M = {}

local animation_rules = require("rules.animations")
local keybind_rules = require("rules.keybinds")
local window_rules = require("rules.windows")

local function read_file(path)
  local file = io.open(path, "r")
  if not file then return "" end
  local content = file:read("*a")
  file:close()
  return content or ""
end

local function push_unique(list, seen, value)
  if value and value ~= "" and not seen[value] then
    seen[value] = true
    list[#list + 1] = value
  end
end

local function repo_path(root, source)
  if source:match("^~/.config/hypr/conf/") then
    return root .. "/hyprland/conf/" .. source:match("([^/]+)$")
  end
  if source:match("^%./") then
    return root .. "/" .. source:gsub("^%./", "")
  end
  return nil
end

local function read_lines(path)
  local content = read_file(path)
  local lines = {}
  for line in content:gmatch("[^\n]+") do
    lines[#lines + 1] = line
  end
  return lines
end

local function normalized_target(rule)
  local kind, target = rule:match("match:(class)%s+([^,]+)")
  if not target then kind, target = rule:match("match:(title)%s+([^,]+)") end
  if not target then kind, target = rule:match("match:(namespace)%s+([^,]+)") end
  if not target then return nil end
  target = target:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""):lower()
  return kind .. ":" .. target
end

local function normalized_action(rule)
  local action = rule:match("^%s*windowrule%w*%s*=%s*.-,%s*(.+)$") or ""
  return action:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""):lower()
end

local function semantic_conflicts(rules)
  local by_target = {}
  local conflicts = {}
  for _, rule in ipairs(rules) do
    local target = normalized_target(rule)
    if target then
      local action = normalized_action(rule)
      if by_target[target] and by_target[target].action ~= action then
        conflicts[#conflicts + 1] = {
          target = target,
          first = by_target[target].rule,
          second = rule,
        }
      else
        by_target[target] = { action = action, rule = rule }
      end
    end
  end
  return conflicts
end

function M.map(root)
  local conf_path = root .. "/hyprland/hyprland.conf"
  local content = read_file(conf_path)
  local counts = {
    binds = 0,
    windowrules = 0,
    sources = 0,
    workspaces = 0,
    env = 0,
    animations = 0,
  }
  local sources, source_seen = {}, {}
  local commands, command_seen = {}, {}
  local dynamic = {}
  local static_bind_lines, static_window_lines = {}, {}
  local sourced_static_window_lines = {}

  for line in content:gmatch("[^\n]+") do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed:match("^bind") then
      counts.binds = counts.binds + 1
      static_bind_lines[#static_bind_lines + 1] = trimmed
    end
    if trimmed:match("^windowrule") then
      counts.windowrules = counts.windowrules + 1
      static_window_lines[#static_window_lines + 1] = trimmed
    end
    if trimmed:match("^workspace") then counts.workspaces = counts.workspaces + 1 end
    if trimmed:match("^env%s*=") then counts.env = counts.env + 1 end
    if trimmed:match("^animation%s*=") then counts.animations = counts.animations + 1 end
    local source = trimmed:match("^source%s*=%s*(.+)$")
    if source then
      counts.sources = counts.sources + 1
      push_unique(sources, source_seen, source)
      local path = repo_path(root, source)
      if path and not path:match("sevenos%-lua%-generated%.conf$") then
        for _, sourced_line in ipairs(read_lines(path)) do
          local sourced_trimmed = sourced_line:match("^%s*(.-)%s*$")
          if sourced_trimmed:match("^windowrule") then
            sourced_static_window_lines[#sourced_static_window_lines + 1] = sourced_trimmed
          end
        end
      end
    end
    for command in trimmed:gmatch("seven[%-%w]*") do
      push_unique(commands, command_seen, command)
    end
  end

  dynamic[#dynamic + 1] = "profile-aware waybar/status"
  dynamic[#dynamic + 1] = "seven-window smart actions"
  dynamic[#dynamic + 1] = "seven-workspace switching"
  dynamic[#dynamic + 1] = "wallpaper-theme generated colors"

  local lua_animations = animation_rules.rules and animation_rules.rules() or {}
  local lua_binds = keybind_rules.rules and keybind_rules.rules() or {}
  local lua_windows = window_rules.rules and window_rules.rules() or {}
  local static_seen = {}
  local bind_duplicates, window_duplicates = 0, 0
  for _, item in ipairs(static_bind_lines) do static_seen[item] = true end
  for _, item in ipairs(lua_binds) do
    if static_seen[item] then bind_duplicates = bind_duplicates + 1 end
  end
  static_seen = {}
  for _, item in ipairs(static_window_lines) do static_seen[item] = true end
  for _, item in ipairs(sourced_static_window_lines) do static_seen[item] = true end
  for _, item in ipairs(lua_windows) do
    if static_seen[item] then window_duplicates = window_duplicates + 1 end
  end
  local all_window_rules = {}
  for _, item in ipairs(sourced_static_window_lines) do all_window_rules[#all_window_rules + 1] = item end
  for _, item in ipairs(static_window_lines) do all_window_rules[#all_window_rules + 1] = item end
  for _, item in ipairs(lua_windows) do all_window_rules[#all_window_rules + 1] = item end
  local semantic = semantic_conflicts(all_window_rules)

  return {
    schema = "sevenos.hypr-lua.config-map.v1",
    source = conf_path,
    counts = counts,
    sources = sources,
    sevenos_commands = commands,
    dynamic_behaviors = dynamic,
    lua = {
      animations = #lua_animations,
      binds = #lua_binds,
      windowrules = #lua_windows,
      bind_duplicates = bind_duplicates,
      windowrule_duplicates = window_duplicates,
      static_bind_authority = counts.binds > 0,
      static_windowrule_authority = counts.windowrules > 0,
      static_animation_authority = counts.animations > 0,
    },
    conflicts = {
      bind_duplicates = bind_duplicates,
      windowrule_duplicates = window_duplicates,
      semantic_windowrule_conflicts = #semantic,
      semantic_windowrule_details = semantic,
      ok = bind_duplicates == 0 and window_duplicates == 0 and #semantic == 0,
    },
    migration = {
      static_layer = "hyprland.conf",
      generated_layer = "hyprland/conf/sevenos-lua-generated.conf",
      fallback_layer = "hyprland/conf/custom.conf",
    },
  }
end

return M
