return {
  key = "windows",
  title = "Windows Bridge",
  role = "Windows VM mini OS",
  workspace_policy = "vm-first",
  ui_density = "guided",
  runtime_signals = {
    context = "windows-bridge",
    layout = "vm-and-companion",
    priority = "vm-stability",
  },
  workspace_intent = {
    "1: Windows VM",
    "2: shared files",
    "3: Wine and Bottles",
    "4: VM settings and snapshots",
  },
  actions = {
    "keep VM surfaces large and centered",
    "separate helper tools from full Windows desktop",
    "prefer VM-first experience over ad-hoc Wine windows",
  },
  env_rules = {
    "env = SEVENOS_HYPR_PROFILE,windows",
    "env = SEVENOS_HYPR_LAYOUT,vm-first",
  },
  layout_rules = {
    "general {",
    "    gaps_in = 4",
    "    gaps_out = 8",
    "    border_size = 1",
    "    layout = dwindle",
    "    resize_on_border = true",
    "}",
  },
  animation_rules = {
    "animations {",
    "    animation = windows, 1, 4, sevenOpen, popin 90%",
    "    animation = workspaces, 1, 6, sevenWorkspace, slidefade 20%",
    "}",
  },
  window_rules = {
    "windowrule = match:class ^(virt-manager)$, float on, center on, size 82% 82%",
    "windowrule = match:title ^(Windows.*)$, workspace 1",
    "windowrule = match:class ^(Bottles)$, workspace 3",
  },
}
