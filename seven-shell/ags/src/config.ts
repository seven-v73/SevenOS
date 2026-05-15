import type { ShellTile } from "./contracts";

export const shellName = "Seven Shell";

export const shellPrinciple =
  "AGS surfaces replace visible friction gradually while Rofi remains fallback.";

export const quickSettingsTiles: ShellTile[] = [
  {
    icon: "view-dashboard-symbolic",
    title: "Control Center",
    subtitle: "Open Seven Hub Native",
    actionId: "hub.open",
  },
  {
    icon: "view-app-grid-symbolic",
    title: "Apps",
    subtitle: "Open the application library",
    actionId: "apps.open",
  },
  {
    icon: "folder-symbolic",
    title: "Files",
    subtitle: "Open the active profile workspace",
    actionId: "files.open",
  },
  {
    icon: "security-high-symbolic",
    title: "Shield",
    subtitle: "Show trust posture",
    actionId: "security.status",
  },
  {
    icon: "preferences-system-symbolic",
    title: "Phase Gate",
    subtitle: "Show what blocks the next phase",
    actionId: "phase.gate",
  },
  {
    icon: "applications-engineering-symbolic",
    title: "Stack",
    subtitle: "Show the phased stack strategy",
    actionId: "stack.status",
  },
];

export const plannedSurfaces = [
  "quick-settings",
  "notifications",
  "launcher",
  "dock",
] as const;
