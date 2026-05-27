# Seven Smart Window System

Seven Smart Window System, or SSWS, is the SevenOS window experience layer above Hyprland.

Its goal is to make window control feel visual, predictable and premium without exposing window-manager vocabulary to normal users.

## Product Contract

SSWS combines four engines:

- SevenDecor: unified visual language for window controls, rounded geometry, active/inactive states and future traffic-light decoration overrides.
- SevenLayout: smart tiling, floating, focus, creative and studio placement policies.
- SevenEffects: cinematic Hyprland animation presets, blur, depth and profile-aware visual feedback.
- SevenAI Core: future workspace memory, context sessions and predictive layouts.

## Traffic-Light Logic

SevenOS native apps use macOS-style traffic lights as the public mental model:

- Red closes the window.
- Yellow toggles tiled/floating mode through `seven-window toggle-float`.
- Green performs smart maximize through `seven-window smart-maximize`.
- Green double-click or explicit fullscreen uses `seven-window fullscreen`.
- The Prism keeps the main click simple: click to expose red/yellow/green, click
  the Prism again or the small close glyph to collapse.
- Prism right-click or long press opens `seven-window advanced-menu` with split,
  scratchpad, pin/unpin, workspace move, target lock/unlock, focus mode,
  hide-for-app and reset placement actions.
- When expanded, the Prism shows a compact target chip. If a target is locked,
  the chip is marked `LOCK` and red/yellow/green keep acting on that window
  until unlocked.
- The target chip is interactive: click it to lock/unlock immediately, or scroll
  over it to cycle through windows on the current workspace and lock the chosen
  target.
- Double-clicking the Prism resets it to adaptive follow mode and clears target
  lock.
- For non-native apps, `seven-window controls` opens a small SevenDecor overlay
  above the active window. It stores the target window address before the
  overlay takes focus, then forwards red/yellow/green actions back to that
  target through Hyprland.

For third-party apps, SSWS phase 1 maps the same behavior to keyboard shortcuts and Hyprland rules. A deeper SevenDecor compositor/plugin layer can later override titlebars globally.

## Modes

- Smart: default balanced tiling/floating behavior.
- Focus: one dominant app, wider gaps and calmer inactive windows.
- Creative: floating-friendly space for design, media and art workflows.
- Studio: dense professional layout for multi-app, multi-monitor work.

Mode state is stored in:

```text
~/.config/sevenos/window-mode.env
~/.config/sevenos/window-mode.json
```

## User Commands

```bash
seven-window status
seven-window status --json
seven-window mode smart
seven-window mode focus
seven-window mode creative
seven-window mode studio
seven-window toggle-float
seven-window smart-maximize
seven-window fullscreen
seven-window split-left
seven-window split-right
seven-window mosaic
seven-window layout-menu
seven-window advanced-menu
seven-window controls-unlock
seven-window controls
seven-window controls-start
seven-window controls-stop
seven-window controls-toggle
seven-window controls-enable
seven-window controls-disable
seven-window controls-status
seven-window controls-effect on
seven-window controls-effect off
seven-window controls-effect toggle
seven-window controls-items
seven-window controls-item add settings
seven-window controls-item custom browser Browser B firefox '#6EA8FF'
seven-window controls-item add accessibility
seven-window controls-item add apps
seven-window controls-item add terminal
seven-window controls-item add files
seven-window controls-item add help
seven-window controls-item add launchpad
seven-window controls-item set daily
seven-window controls-item set dev
seven-window controls-item set clean
seven-window controls-item move terminal up
seven-window controls-item remove settings
seven-window controls-item clear
seven-window controls-reset-hidden
seven-window decor-status
seven-window decor-apply
```

The `seven window ...` command exposes the same API through the main SevenOS controller.

## Hyprland Integration

SSWS is loaded from:

```text
hyprland/conf/sevenos-windows.conf
```

That file classifies app windows into sensible defaults:

- dialogs, settings, quick panels and utilities float;
- terminals, editors and browsers remain tiled by default;
- media, picture-in-picture and SevenOS system panels receive dedicated placement rules.

## Roadmap

Phase 1:

- SevenOS command layer.
- Hyprland rules and shortcuts.
- User-visible mode state.
- Layout menu and safe actions.
- GTK client-side decoration coverage with left-side traffic-light styling.

## Decoration Coverage

SSWS phase 1 is honest about what Linux allows from user space:

- SevenOS native apps: full traffic-light controls because the apps draw their own header controls.
- GTK client-side decoration apps: good coverage through `gtk-decoration-layout=close,minimize,maximize:` and SevenDecor GTK CSS.
- Qt apps: partial coverage because button placement and rendering depend on Qt/Kvantum/window decoration behavior.
- Electron apps: partial coverage because many apps draw custom titlebars.
- Java, SDL and XWayland apps: Hyprland can place, animate and toggle them, but cannot inject real titlebar buttons in phase 1.

Run this to apply current user-space coverage:

```bash
seven-window decor-apply
```

Run this to see the coverage truth:

```bash
seven-window decor-status --json
```

Phase 2:

- SevenDecor overlay for non-native apps through `seven-window controls`;
- permanent Prism control through `seven-window controls-start` and
  `sevenos-window-controls.service`; the Prism is collapsed by default and
  expands to red/yellow/green actions on click;
- advanced Prism menu through right-click/long press or `seven-window
  advanced-menu`;
- target disambiguation for crowded workspaces through the expanded target chip
  and lock/unlock actions;
- Prism visible labels and tooltips follow `SEVENOS_LANGUAGE`,
  `~/.config/sevenos/language.conf` or the system `LANG`;
- discreet Prism indicators: mini OS accent color, halo for floating/fullscreen
  targets, lower opacity when idle, and optional electric Prism pulses from
  vertices to the center through `seven-window controls-effect toggle`;
- optional Prism items: up to 7 user-selected shortcuts become connected
  vertices around the Prism center through `seven-window controls-item add ...`;
- `Super+Alt+D` toggles the Prism on/off globally; `Super+Ctrl+Alt+D` opens the
  one-shot controls overlay;
- when enabled, the Prism is a user session service, so it remains present
  across mini OS changes until explicitly disabled;
- adaptive placement near the active window's top-left corner, clamped to the
  monitor so the controls do not leave the visible screen;
- manual placement by dragging the Prism; double-clicking the Prism returns to
  adaptive placement;
- per-app hiding from the advanced menu; `seven-window controls-reset-hidden`
  clears hidden app rules;
- profile-aware layouts from `profile-ui.json`;
- workspace memory;
- app category learning;
- Control Center integration.

Phase 3:

- SevenDecor plugin/protocol layer;
- global traffic-light decoration override;
- deeper Wayland/XWayland compatibility behavior.
