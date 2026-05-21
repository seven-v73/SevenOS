return {
  key = "studio",
  title = "Studio Creator",
  role = "creator mini OS",
  workspace_policy = "canvas-preview-export",
  ui_density = "spacious",
  runtime_signals = {
    context = "creator",
    layout = "canvas-preview-export",
    priority = "gpu-and-media",
  },
  workspace_intent = {
    "1: asset manager and brief",
    "2: canvas and editor",
    "3: preview and capture",
    "4: export, render and audio",
  },
  actions = {
    "give creative canvases large surfaces",
    "float capture and mixer tools",
    "keep exports away from active canvas",
  },
  env_rules = {
    "env = SEVENOS_HYPR_PROFILE,studio",
    "env = SEVENOS_HYPR_LAYOUT,creator",
  },
  layout_rules = {
    "general {",
    "    gaps_in = 8",
    "    gaps_out = 16",
    "    border_size = 1",
    "    layout = dwindle",
    "    resize_on_border = true",
    "}",
  },
  animation_rules = {
    "animations {",
    "    animation = workspaces, 1, 8, sevenWorkspace, slidefade 30%",
    "    animation = windows, 1, 6, sevenOpen, popin 86%",
    "}",
  },
  window_rules = {
    "windowrule = match:class ^(krita)$, workspace 2",
    "windowrule = match:class ^(Blender)$, workspace 2",
    "windowrule = match:class ^(obs)$, float on, center on, size 72% 72%",
    "windowrule = match:class ^(Gimp|gimp.*|Inkscape)$, workspace 2",
    "windowrule = match:class ^(kdenlive|org.kde.kdenlive)$, workspace 4",
  },
}
