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
seven widgets move notes up
seven widgets move system down
seven widgets open
seven widgets toggle
seven widgets settings
seven widgets hide
seven widgets home 1
seven widgets right-click enable
seven widgets weather Abidjan
seven widgets preset active
seven widgets merge active
seven widgets restore
seven widgets preset forge
seven widgets layout calm-grid
seven widgets layout compact-grid
seven widgets layout focus-stack
seven widgets reset
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
- The widget picker is grouped by user intent: daily rhythm, system status,
  SevenOS controls, notes/work and media. It should not feel like a raw module
  list.
- The picker includes local search by widget name, description and group so a
  growing catalog remains fast to navigate.
- Presets are profile-aware: the user can start from Equinox, Forge, Studio,
  Shield, Atlas, Baobab, Pulse, Calm or Focus instead of building a layout from
  zero.
- Presets have two UX paths: **Preset** replaces the current home surface,
  while **Complete** only adds missing recommendations and preserves user
  choices.
- Risky changes create a local previous-state backup. **Restore** lets the
  user undo the last widget layout/configuration change without touching notes
  or other SevenOS settings.
- Mutating actions write a short localized feedback message in the settings
  surface so the user sees what changed without opening logs.
- Layouts are user-facing: `calm-grid`, `compact-grid` and `focus-stack`
  change density without changing which widgets are enabled.
- Ordering is user-facing: widgets can move up/down from the settings UI or
  with `seven widgets move <key> up|down`.
- Widgets can be added, removed and hidden without terminal knowledge.
- The desktop menu shows current state first: visible/hidden, widget count,
  active layout, home workspace and active Mini OS.
- The widget layer must survive reboot through `~/.config/sevenos/widgets.json`.
- Mini OS can recommend widgets, but Equinox owns the widget runtime.

## Initial Widgets

| Key | Purpose |
| --- | --- |
| `clock` | Time, date and active locale. |
| `system` | CPU, memory and disk overview. |
| `battery` | Battery/AC status and power profile. |
| `storage` | Available disk space and Files shortcut. |
| `doctor` | Seven Doctor health and issue count. |
| `prism` | Active Mini OS and Prism status. |
| `mini-os` | Fast Mini OS switch shortcuts. |
| `notes` | Small local note card. |
| `tasks` | Quick task capture backed by Seven Notes. |
| `calendar` | Day/month progress and week rhythm. |
| `media` | Current playerctl media state and play/pause. |
| `network` | Network state shortcut. |
| `weather` | Opt-in local weather card; no external provider is called by default. |
| `quick` | Common SevenOS actions. |

## Picker Groups

| Group | Widgets |
| --- | --- |
| Daily | `clock`, `calendar`, `weather` |
| System status | `system`, `battery`, `storage`, `network` |
| SevenOS | `doctor`, `prism`, `mini-os`, `quick` |
| Notes and work | `notes`, `tasks` |
| Media | `media` |

## Presets

| Preset | Default intent |
| --- | --- |
| `equinox` | Calm home surface: clock, health, Prism, notes, network and actions. |
| `forge` | Development home: system load, storage, Doctor, tasks, Mini OS and actions. |
| `studio` | Creative home: storage, media, tasks, notes and actions. |
| `shield` | Security home: Doctor, network, storage, tasks and Mini OS. |
| `atlas` | Knowledge home: calendar, notes, tasks, storage, network and actions. |
| `baobab` | Cultural home: calendar, notes, weather, media, Prism and actions. |
| `pulse` | Gaming home: system, power, media, network and Mini OS. |
| `calm` | Minimal low-noise home. |
| `focus` | Work-focused notes, tasks and system status. |

Commands:

```bash
seven widgets preset active
seven widgets merge active
seven widgets restore
seven widgets preset studio
seven widgets reset
```

## Layouts

| Layout | UX |
| --- | --- |
| `calm-grid` | Balanced default with two columns and comfortable spacing. |
| `compact-grid` | Denser three-column layout for users who want more live cards visible. |
| `focus-stack` | Single-column layout for notes, tasks and essential state. |

The layout only changes presentation. It never removes widgets.

## Ordering

SevenOS keeps the enabled widget order in `~/.config/sevenos/widgets.json`.
The settings surface separates **Home order** from **Available widgets** so the
user can first arrange the active home surface, then decide what else should be
enabled. Users can reorder from the settings surface with the up/down controls,
or with:

```bash
seven widgets move notes up
seven widgets move system down
```

Applying a preset replaces the order with the preset order. Manual moves mark
the current preset as `custom`.

## Architecture

```text
seven widgets
├── menu        desktop context menu
├── settings    add/remove widgets
├── move        reorder an enabled widget
├── open        display the desktop widget layer
├── hide        close the widget layer
├── toggle      show/hide the widget layer from the desktop menu
├── home        choose the workspace used as the SevenOS home screen
├── preset      apply a profile-aware widget set
├── merge       add missing recommended widgets without removing user choices
├── restore     restore the previous widget configuration
├── layout      choose calm-grid, compact-grid or focus-stack
├── reset       restore the default calm widget set
├── right-click opt-in desktop context menu flag
├── status      machine-readable widget state
└── doctor      validate config, commands and Hyprland route
```

The implementation is GTK-native first. AGS/layer-shell can later replace the
rendering layer, but the public commands and config contract must stay stable.

## Reference Patterns

Seven Widgets intentionally borrows the good parts of common Hyprland widget
ecosystems without making them mandatory:

- Eww-style widgets: small independent cards and explicit state files.
- AGS/Astal-style widgets: reactive shell surfaces that can later move to a
  richer Wayland shell runtime.
- HyprPanel-style dashboards: practical cards for system, media, network and
  quick actions.

SevenOS keeps the first implementation GTK-native because it is already shipped
in the base requirements and is easier to validate on a new machine.

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
- Drag-and-drop preset editing.
- Weather provider with explicit location consent.
- Calendar and tasks.
- Baobab cultural phrase, Forge services, Pulse performance and Shield alerts.
