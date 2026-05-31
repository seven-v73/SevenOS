# Seven Widgets

Seven Widgets is the optional desktop widget layer for SevenOS. It lets the
user place calm, profile-aware information on the home screen without turning
the desktop into a dashboard.

## Goal

Widgets should feel like an OS feature, not like scripts on top of the system.
The user can open the desktop context menu, choose **Add widget**, select a
widget, and see it appear on the SevenOS home screen.

The safe default path is:

```bash
Super + Ctrl + W -> choose widget
```

Command equivalents:

```bash
seven widgets menu
seven widgets add clock
seven widgets open
seven widgets settings
seven widgets hide
seven widgets home 1
seven widgets right-click enable
seven widgets doctor --json
```

## UX Contract

- Widgets are optional and user-controlled.
- Workspace 1 is the SevenOS home screen: widgets may live there, normal apps
  should not stay there.
- The desktop remains calm: no widget should steal focus permanently.
- The desktop context menu is opt-in. Application context menus must remain
  available, and SevenOS must not bind a global right click by default.
- Every widget has a clear name, short description and Mini OS relevance.
- Widgets can be added, removed and hidden without terminal knowledge.
- The widget layer must survive reboot through `~/.config/sevenos/widgets.json`.
- Mini OS can recommend widgets, but Equinox owns the widget runtime.

## Initial Widgets

| Key | Purpose |
| --- | --- |
| `clock` | Time, date and active locale. |
| `system` | CPU, memory and disk overview. |
| `doctor` | Seven Doctor health and issue count. |
| `prism` | Active Mini OS and Prism status. |
| `notes` | Small local note card. |
| `network` | Network state shortcut. |
| `quick` | Common SevenOS actions. |

## Architecture

```text
seven widgets
├── menu        desktop context menu
├── settings    add/remove widgets
├── open        display the desktop widget layer
├── hide        close the widget layer
├── home        choose the workspace used as the SevenOS home screen
├── right-click opt-in desktop context menu flag
├── status      machine-readable widget state
└── doctor      validate config, commands and Hyprland route
```

The implementation is GTK-native first. AGS/layer-shell can later replace the
rendering layer, but the public commands and config contract must stay stable.

## Safety

The desktop right-click hook must be conservative and opt-in. If an active
application window is detected, SevenOS should not open the widget menu. Users
always keep the keyboard fallback:

```bash
Super + Ctrl + W
```

## Home Workspace Policy

SevenOS treats workspace `1` as **Accueil**. It is the quiet home surface for
wallpaper, desktop widgets and SevenOS ambient controls.

Rules:

- `Seven Widgets Desktop` must never use `pin on`, otherwise widgets would
  appear on every workspace.
- The stable default is manual: `seven widgets open` switches to workspace `1`
  and opens the widget layer there.
- The home workspace is configurable with `seven widgets home <number>`, but
  workspace `1` remains the public default.
- The automatic home guard is experimental and disabled by default. When enabled,
  normal application windows opened while the user is on workspace `1` are moved
  by the Hyprland event bridge:
  - work apps and unknown apps -> workspace `2`;
  - browsers and readers -> workspace `3`;
  - media/creative apps -> workspace `4`;
  - security tools -> workspace `7`.
- System overlays such as Spotlight, Launchpad, Quick Settings, Dock, window
  controls and the widget menu are allowed to appear on the home surface.

The guard can be enabled for testing:

```bash
mkdir -p ~/.config/sevenos
printf 'SEVENOS_HOME_WORKSPACE_GUARD=1\n' > ~/.config/sevenos/workspace-home.env
systemctl --user restart sevenos-hypr-lua-events.service
```

The guard can be disabled again:

```bash
mkdir -p ~/.config/sevenos
printf 'SEVENOS_HOME_WORKSPACE_GUARD=0\n' > ~/.config/sevenos/workspace-home.env
systemctl --user restart sevenos-hypr-lua-events.service
```

## Future

- Drag-and-drop layout editing.
- Per Mini OS presets.
- Weather provider with explicit location consent.
- Calendar and tasks.
- Baobab cultural phrase, Forge services, Pulse performance and Shield alerts.
