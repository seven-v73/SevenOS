return {
  key = "equinox",
  title = "Equinox Balance",
  role = "balanced general mini OS",
  workspace_policy = "neutral",
  ui_density = "balanced",
  runtime_signals = {
    context = "general",
    layout = "balanced",
    priority = "normal",
  },
  workspace_intent = {
    "1: daily work",
    "2: reading and files",
    "3: communication",
    "4: media",
    "5: optional focused workload",
  },
  actions = {
    "keep essential controls visible",
    "route SevenOS native panels as centered floating surfaces",
    "avoid profile-specific dominance",
  },
  env_rules = {
    "env = SEVENOS_HYPR_PROFILE,equinox",
    "env = SEVENOS_HYPR_LAYOUT,balanced",
  },
  layout_rules = {
    "general {",
    "    gaps_in = 5",
    "    gaps_out = 10",
    "    border_size = 1",
    "    layout = dwindle",
    "    resize_on_border = true",
    "}",
    "decoration {",
    "    dim_inactive = true",
    "    dim_strength = 0.06",
    "}",
  },
  animation_rules = {
    "# Equinox keeps the cinematic balanced SevenOS motion preset.",
  },
  window_rules = {
    "windowrule = match:class ^(SevenStoreNative)$, float on, center on, size 1180 740",
  },
}
