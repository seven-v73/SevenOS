return {
  key = "horizon",
  title = "Horizon Cloud",
  role = "cloud and server mini OS",
  workspace_policy = "services-logs-endpoints",
  ui_density = "operational",
  runtime_signals = {
    context = "cloud-server",
    layout = "services-logs-endpoints",
    priority = "network-and-io",
  },
  workspace_intent = {
    "1: deployment cockpit",
    "2: terminal and SSH",
    "3: logs and monitoring",
    "4: endpoints and docs",
  },
  actions = {
    "route dashboards to operations workspace",
    "keep logs and monitoring visible",
    "avoid mixing deploy controls with general browsing",
  },
  env_rules = {
    "env = SEVENOS_HYPR_PROFILE,horizon",
    "env = SEVENOS_HYPR_LAYOUT,operations",
  },
  layout_rules = {
    "general {",
    "    gaps_in = 5",
    "    gaps_out = 10",
    "    border_size = 1",
    "    layout = dwindle",
    "    resize_on_border = true",
    "}",
  },
  animation_rules = {
    "animations {",
    "    animation = workspaces, 1, 6, sevenWorkspace, slidefade 18%",
    "    animation = layers, 1, 4, sevenMenu, popin 96%",
    "}",
  },
  window_rules = {
    "windowrule = match:title ^(Horizon Center)$, float on, center on",
    "windowrule = match:title ^(.*Grafana.*|.*Prometheus.*|.*Caddy.*)$, workspace 3",
    "windowrule = match:class ^(SevenTerminal.*)$, workspace 2",
  },
}
