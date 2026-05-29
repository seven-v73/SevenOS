# SevenOS Native Fallback Contract

SevenOS public interactions must prefer native SevenOS surfaces. Legacy menus
may remain only as emergency fallbacks for minimal sessions, missing GTK, or
explicit developer overrides.

## Rules

- Public launchers open a native SevenOS surface first.
- Rofi/terminal fallbacks are allowed only behind an explicit probe, missing
  graphical runtime, or an environment override.
- User-facing reports must distinguish "public blocker" from "internal
  fallback kept".
- Installed `/opt/SevenOS` systems must use the same contract as the source
  tree.

## Required Public Routes

- Apps: SevenOS Launchpad native.
- Spotlight: SevenOS Spotlight native.
- Quick Settings: SevenOS Quick Settings native.
- Wi-Fi: Quick Settings Wi-Fi panel native for menu/open/connect.
- Power: Quick Settings Power panel native for menu/open.
- Terminal palette: SevenOS Actions native filtered to terminal workflows.
