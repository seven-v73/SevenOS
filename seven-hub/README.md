# Seven Hub

Seven Hub is the user-facing control surface for SevenOS Phase 2.

The primary entrypoint is now the SevenOS Control Center, a local dashboard
served on `127.0.0.1`. It shows system readiness, security state, profile
coverage, Windows Mode, server/deploy status, theme/session actions, and
contextual "Fix now" actions.

The Rofi-powered Seven Hub remains available as a fast command palette for
keyboard-first workflows.

Current spaces:

- Control Center
- Dashboard
- Profiles
- Cyber
- Desktop
- VM & Windows
- Server & Deploy
- Ecosystem
- Installer
- Apps

## Features

- local Control Center dashboard
- readiness score overview
- security, profile, compatibility, deployment and theme status cards
- Seven Files status and quick launcher
- contextual actions that call the same `seven` and installer commands
- host readiness check
- installation status report
- SevenOS branding action
- Beyond the Desktop theme application
- dynamic `OK`, `PART`, `MISS`, and `RUN` badges in the action menu
- base desktop installation
- DEV, CYBERSECURITY, CREATION, WINDOWS, and SECURITY actions
- KVM/libvirt readiness check
- libvirt default network action
- non-destructive installer planning action
- full dry-run preview
- Seven Files launcher
- Virt Manager launcher
- Bottles launcher

## Install

From the repository root:

```bash
./install.sh hub
```

Then launch:

```bash
seven hub
```

Or launch the command palette directly:

```bash
seven-hub
```

In Hyprland, the base config binds the Control Center to `SUPER + SPACE` and
the command palette to `SUPER + H`.

## Notes

Seven Hub intentionally calls the same scripts as the CLI installer. This keeps the GUI thin and prevents the project from having two different sources of truth.
