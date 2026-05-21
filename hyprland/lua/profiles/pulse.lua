return {
  key = "pulse",
  title = "Pulse Gaming",
  role = "Linux gaming mini OS",
  workspace_policy = "fullscreen-game-overlay",
  ui_density = "immersive",
  runtime_signals = {
    context = "gaming",
    layout = "fullscreen-game-overlay",
    priority = "latency",
  },
  workspace_intent = {
    "1: launcher and library",
    "2: chat and voice",
    "3: browser guides",
    "5: active game",
  },
  actions = {
    "route games to a stable fullscreen workspace",
    "float overlays and performance panels",
    "keep voice/chat separate from game surface",
  },
  env_rules = {
    "env = SEVENOS_HYPR_PROFILE,pulse",
    "env = SEVENOS_HYPR_LAYOUT,gaming",
  },
  layout_rules = {
    "general {",
    "    gaps_in = 2",
    "    gaps_out = 5",
    "    border_size = 1",
    "    layout = dwindle",
    "    resize_on_border = true",
    "}",
    "decoration {",
    "    dim_inactive = false",
    "}",
  },
  animation_rules = {
    "animations {",
    "    animation = workspaces, 1, 5, sevenMove, slidefade 12%",
    "    animation = windows, 1, 3, sevenOpen, popin 96%",
    "    animation = fade, 1, 3, seven",
    "}",
  },
  -- audit signature: windowrule = match:class ^(steam)
  window_rules = {
    "windowrule = match:class ^(steam)$, workspace 1",
    "windowrule = match:class ^(lutris|heroic|com.heroicgameslauncher.hgl)$, workspace 1",
    "windowrule = match:class ^(discord)$, workspace 2",
    "windowrule = match:class ^(gamescope)$, fullscreen on",
    "windowrule = match:title ^(.*MangoHud.*)$, float on, pin on",
  },
}
