# Seven Hub GUI

This is the Tauri foundation for the future native Seven Hub.

The current production Hub remains:

- `seven hub` for the local dashboard
- `seven-hub` for the Rofi command palette

This directory exists to move Seven Hub toward a real lightweight desktop GUI
without adopting Electron.

## Goals

- native lightweight app
- Rust backend calling `seven` safely
- HTML/CSS UI using the SevenOS design system
- no privileged command without explicit confirmation
- same actions as CLI and Rofi Hub

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
