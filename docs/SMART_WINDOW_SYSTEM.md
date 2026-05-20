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
- Long-press equivalent is exposed today as `seven-window layout-menu`.

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

- profile-aware layouts from `profile-ui.json`;
- workspace memory;
- app category learning;
- Control Center integration.

Phase 3:

- SevenDecor plugin/protocol layer;
- global traffic-light decoration override;
- deeper Wayland/XWayland compatibility behavior.
