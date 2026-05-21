local M = {
  schema = "sevenos.hypr-lua.animations.v1",
  phase = "profile-aware-animations",
}

M.common_rules = {
  "animations {",
  "    enabled = true",
  "    bezier = seven, 0.16, 1.00, 0.30, 1.00",
  "    bezier = sevenOpen, 0.18, 1.00, 0.22, 1.00",
  "    bezier = sevenMove, 0.20, 1.00, 0.32, 1.00",
  "    bezier = sevenWorkspace, 0.16, 1.00, 0.24, 1.00",
  "    bezier = sevenExit, 0.30, 0.00, 0.80, 0.15",
  "    bezier = sevenMenu, 0.10, 1.00, 0.00, 1.00",
  "    animation = windows, 1, 5, sevenOpen, popin 88%",
  "    animation = windowsOut, 1, 4, sevenExit, popin 94%",
  "    animation = border, 1, 8, seven",
  "    animation = fade, 1, 5, seven",
  "    animation = layers, 1, 5, sevenMenu, popin 96%",
  "    animation = workspaces, 1, 7, sevenWorkspace, slidefade 24%",
  "    animation = specialWorkspace, 1, 5, sevenMove, slidevert",
  "}",
}

function M.rules()
  return M.common_rules
end

return M
