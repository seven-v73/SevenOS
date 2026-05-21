return {
  key = "forge",
  title = "Forge Developer",
  role = "developer mini OS",
  workspace_policy = "code-terminal-browser",
  ui_density = "productive",
  runtime_signals = {
    context = "developer",
    layout = "code-terminal-browser",
    priority = "build-and-debug",
  },
  workspace_intent = {
    "1: IDE and source tree",
    "2: terminals and local servers",
    "3: browser documentation",
    "4: containers and logs",
  },
  actions = {
    "prefer tiling for IDE, terminal and browsers",
    "keep build tools visible",
    "route package/store surfaces away from coding workspace",
  },
  env_rules = {
    "env = SEVENOS_HYPR_PROFILE,forge",
    "env = SEVENOS_HYPR_LAYOUT,developer",
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
    "    animation = workspaces, 1, 6, sevenWorkspace, slidefade 18%",
    "    animation = windows, 1, 4, sevenOpen, popin 92%",
    "}",
  },
  window_rules = {
    "windowrule = match:class ^(Code)$, workspace 1",
    "windowrule = match:class ^(jetbrains-.*)$, workspace 1",
    "windowrule = match:class ^(SevenTerminal.*)$, workspace 2",
    "windowrule = match:class ^(Google-chrome|firefox)$, workspace 3",
    "windowrule = match:title ^(.*localhost.*)$, workspace 3",
  },
}
