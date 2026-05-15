import type { ShellTile } from "./contracts";

export const dockTiles: ShellTile[] = [
  {
    icon: "view-dashboard-symbolic",
    title: "Hub",
    subtitle: "SevenOS Control Center",
    actionId: "hub.open",
  },
  {
    icon: "view-app-grid-symbolic",
    title: "Apps",
    subtitle: "SevenOS application library",
    actionId: "apps.open",
  },
  {
    icon: "folder-symbolic",
    title: "Files",
    subtitle: "Profile workspace",
    actionId: "files.open",
  },
  {
    icon: "utilities-terminal-symbolic",
    title: "Terminal",
    subtitle: "Advanced SevenOS control",
    actionId: "doctor.run",
  },
];
