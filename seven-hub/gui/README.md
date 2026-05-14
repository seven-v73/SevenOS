# Seven Hub GUI

This is the Tauri foundation for the native Seven Hub Control Center.

The current production Hub remains:

- `seven hub` for the local dashboard
- `seven-hub` for the Rofi command palette

This directory moves Seven Hub away from terminal-first workflows and toward a
real lightweight desktop GUI without adopting Electron.

## Goals

- native lightweight app
- Rust backend calling `seven` safely
- HTML/CSS UI using the SevenOS design system
- no privileged command without explicit confirmation
- same actions as CLI and Rofi Hub
- dashboard with readiness score, services, profiles and recommendations
- user-facing actions for repair, security, profiles, apps and system health
- backend snapshot so the interface can show system state without opening a terminal

## Current Productization Step

Seven Hub now exposes a Control Center structure:

- left navigation for Dashboard, Profiles, Security, Apps and System
- readiness score pulled from `seven readiness --json`
- service cards for Network, Firewall, Windows Mode and Seven Server
- profile cards for Forge, Shield, Studio and Windows
- recommendation cards mapped to safe SevenOS commands
- output drawer for readable command results

The Rofi Hub remains available as a command palette fallback, but the product
direction is that normal users should operate SevenOS from this GUI.

## Commands

Install the stack:

```bash
./seven-hub/gui-stack.sh install
```

Inspect readiness:

```bash
./seven-hub/gui-stack.sh doctor
```

Development command:

```bash
./seven-hub/gui-stack.sh dev
```

Build command:

```bash
./seven-hub/gui-stack.sh build
```
