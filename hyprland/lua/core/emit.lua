local M = {}

local function line(out, value)
  out[#out + 1] = value
end

local function emit_list(out, title, items, prefix)
  if not items or #items == 0 then return end
  line(out, "")
  line(out, title)
  for _, item in ipairs(items) do
    line(out, (prefix or "") .. item)
  end
end

local function emit_map_comments(out, title, items)
  if not items then return end
  local keys = {}
  for key, _ in pairs(items) do keys[#keys + 1] = key end
  table.sort(keys)
  if #keys == 0 then return end
  line(out, "")
  line(out, title)
  for _, key in ipairs(keys) do
    line(out, "# " .. key .. " = " .. tostring(items[key]))
  end
end

function M.render(context)
  local profile = context.profile
  local common_animation_rules = context.common_animation_rules or {}
  local common_keybinds = context.common_keybinds or {}
  local mouse_binds = context.mouse_binds or {}
  local launchpad_modal_binds = context.launchpad_modal_binds or {}
  local common_window_rules = context.common_window_rules or {}
  local common_workspace_rules = context.common_workspace_rules or {}
  local out = {}
  line(out, "# SevenOS Lua generated Hyprland layer")
  line(out, "# Generated at " .. tostring(context.generated_at))
  line(out, "# Profile: " .. profile.key .. " - " .. profile.title)
  line(out, "# Safe generated layer: static Hyprland config remains the fallback.")
  line(out, "")
  line(out, "# Profile intent")
  line(out, "# role = " .. profile.role)
  line(out, "# workspace_policy = " .. profile.workspace_policy)
  line(out, "# ui_density = " .. profile.ui_density)
  emit_map_comments(out, "# Profile runtime signals", profile.runtime_signals)
  emit_list(out, "# Workspace intent", profile.workspace_intent, "# ")
  emit_list(out, "# Profile actions exposed to future event engine", profile.actions, "# ")
  line(out, "")
  line(out, "# Phase 3 emits common rules plus profile-aware rules.")
  line(out, "# Static Hyprland remains the fallback while Lua reaches parity.")
  emit_list(out, "# Profile environment", profile.env_rules)
  emit_list(out, "# Common animation rules", common_animation_rules)
  emit_list(out, "# Profile animation rules", profile.animation_rules)
  emit_list(out, "# Common keybinds", common_keybinds)
  emit_list(out, "# Common mouse binds", mouse_binds)
  emit_list(out, "# Launchpad modal submap", launchpad_modal_binds)
  emit_list(out, "# Common workspace rules", common_workspace_rules)
  emit_list(out, "# Profile layout rules", profile.layout_rules)
  emit_list(out, "# Profile workspace rules", profile.workspace_rules)
  emit_list(out, "# Common window rules", common_window_rules)
  emit_list(out, "# Profile window rules", profile.window_rules)
  line(out, "")
  return table.concat(out, "\n")
end

return M
