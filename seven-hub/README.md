# Seven Hub

Seven Hub is the lightweight control center for SevenOS Phase 2.

The current implementation is a Rofi-powered launcher with a terminal fallback. It exposes the existing SevenOS installer workflows through a single menu while the future full GUI is designed.

## Features

- host readiness check
- installation status report
- African first theme application
- base desktop installation
- DEV, CYBERSECURITY, CREATION, WINDOWS, and SECURITY actions
- KVM/libvirt readiness check
- libvirt default network action
- full dry-run preview
- Virt Manager launcher
- Bottles launcher

## Install

From the repository root:

```bash
./install.sh hub
```

Then launch:

```bash
seven-hub
```

In Hyprland, the base config binds the launcher to `SUPER + H`.

## Notes

Seven Hub intentionally calls the same scripts as the CLI installer. This keeps the GUI thin and prevents the project from having two different sources of truth.
