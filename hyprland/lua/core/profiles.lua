local M = {}

local known_profiles = {
  "equinox",
  "baobab",
  "forge",
  "shield",
  "studio",
  "windows",
  "pulse",
}

local fallback = {
  key = "equinox",
  title = "Equinox Balance",
  role = "balanced general mini OS",
  workspace_policy = "neutral",
  ui_density = "balanced",
  window_rules = {},
}

function M.load(key, root)
  local ok, profile = pcall(dofile, root .. "/hyprland/lua/profiles/" .. key .. ".lua")
  if ok and type(profile) == "table" then
    return profile
  end
  return fallback
end

function M.known()
  local items = {}
  for index, key in ipairs(known_profiles) do
    items[index] = key
  end
  return items
end

return M
