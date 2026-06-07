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
- Workspace 1 is the SevenOS home screen: widgets live there as a desktop
  composition, not as a control-panel window. Normal apps should not stay
  there.
- The Home surface must not draw a large parent panel. Widgets are independent
  glass cards placed directly over the wallpaper, with only a small ambient
  title and compact controls.
- The default compact Home must stay curated. It shows the essential cards
  only, with no decorative rails, stage bands, bottom status strip or dense
  metric chips by default. Secondary widgets remain available from Edit
  Widgets or denser layouts.
- The zone structure can use thin ambient lanes in non-compact layouts, not
  large background panels. Today, System State and Continuity should guide the
  eye without making Home feel like a dashboard window.
- The Home layout is spatial: clock and personal rhythm sit on the left,
  system state sits in the middle, and SevenAI/context/actions sit on the
  right. This keeps Home readable without feeling like Settings.
- Cards inherit a very quiet zone accent from their column. The accent should
  help orientation only: personal rhythm on the left, system confidence in the
  middle and continuity/actions on the right.
- Home opens with a personal greeting and tiny controls. Editing and hiding
  widgets should feel like ambient desktop actions, not like a settings panel.
- The Home header should expose identity first: greeting and Home/workspace
  badge. Active Mini OS, freshness and machine mood are optional in denser
  layouts only. Controls stay small and round so the header does not read like
  a toolbar.
- The Home header may include tiny context chips for the active Mini OS
  mission, active widget count and layout density. These chips give identity
  without adding another toolbar.
- The Home header may include one compact presence capsule: machine mood,
  network state and freshness. It replaces verbose status text and keeps the
  greeting personal while still making the Home screen feel alive.
- Ambient dots can mark transitions between Today, System State and Continuity
  zones. They should be decorative anchors only, never extra controls.
- Very light vertical rhythm lines may separate the Home zones. They must stay
  below the cards visually, with low opacity, so the wallpaper and widgets
  remain the primary experience.
- Each Home zone may end on a one-pixel shelf line. This grounds the cards
  spatially without drawing a containing panel or making the desktop feel like
  a window.
- Zone titles carry a tiny live status chip: day phase for Today, machine
  pressure for System State and recent local context for Continuity. This keeps
  Home understandable at a glance without adding another dashboard row.
- The greeting area exposes compact machine pills for CPU, RAM, disk and
  network. These are glanceable signals, not another settings dashboard.
- System and storage cards use dedicated metric rows rather than generic text
  so Home can be scanned quickly: load, memory and disk pressure should be
  visible in one glance.
- Home cards use calm visual priority: personal cards such as Notes and
  SevenAI can carry a slightly warmer accent, while system warning/danger
  states become visible through border and background pressure instead of loud
  alerts.
- Card headers use a tiny capsule treatment so every widget reads as a native
  SevenOS surface. The capsule must stay quiet: it identifies the card without
  stealing attention from the value or the user’s content.
- System pressure should also be translated into calm human labels such as
  Calm, Busy or Critical. The user should not need to interpret raw
  percentages to understand whether the machine needs attention.
- Network and Doctor cards use dedicated status rows with a small state dot,
  readable state text and one calm action. The user should understand
  connection and health without reading raw command output.
- Status rows may include a tiny human badge such as OK, Check or Urgent. The
  badge should explain urgency without turning the Home surface into an alert
  center.
- Prism and Mini OS cards must expose SevenOS identity without feeling like
  configuration panels: show the active space, a compact seven-space signal and
  calm chips for common space switches.
- Prism should explain the active space as a mission, not only a name.
  Equinox, Forge, Studio, Shield, Atlas, Baobab and Pulse should feel like
  meaningful modes from Home.
- Daily cards have their own rhythm. The calendar card should read as
  “today” first, with day, month, week and month progress visible without
  opening a full calendar app.
- The calendar card can include a compact week rhythm strip with the current
  day highlighted. It should feel like orientation, not scheduling.
- The main clock card is the emotional entry point of Home. It should expose
  the time, day phase, active Mini OS and a short trust line, instead of
  behaving like a generic status widget.
- The main clock card may show a tiny day-rhythm progress signal. It should
  help the user feel where they are in the day without becoming a calendar or
  productivity dashboard.
- The bottom rhythm strip includes one contextual **Next action**. It is
  clickable and chooses the calmest useful path first: Wi-Fi, storage cleanup,
  Doctor, notes, then SevenAI.
- The bottom rhythm strip reads as a decision ribbon: system mood on the left,
  local context in the center and one clear next action on the right. It should
  never become a dense status bar or a second dock.
- Informational Home cards should avoid repeated "Open" buttons. Explicit
  action cards such as Apps, Quick Actions and SevenAI carry the interaction.
- Home action cards use compact two-line action cells: icon, short command and
  a muted hint. They should feel like native OS affordances rather than raw
  rectangular buttons.
- Home launch/action tiles may carry subtle role tones such as files, system,
  AI, store, warning, notes and theme. The tones are for recognition, not for a
  colorful launcher wall.
- Action cards should have hierarchy. One primary action may be visually
  stronger, while secondary actions remain calm, so the user is guided rather
  than faced with four equivalent buttons.
- SevenAI cards should show a short contextual suggestion and one clear path to
  ask more. Home should feel assisted, not noisy.
- SevenAI on Home behaves like a small local companion: one main suggestion,
  one local-state signal, one compact ask field and two calm actions. It should
  not become a log view or a diagnostic dump.
- In compact Home, SevenAI must stay short: no nested shortcut grid, no recent
  file list and no memory panel inside the card. Quick apps and recent context
  remain optional widgets or Spotlight sections, not default Home clutter.
- The compact SevenAI ask field answers inside the Home card when possible. It
  routes through local SevenOS contracts and keeps privileged changes behind
  preview/confirmation instead of executing them silently.
- Continuity cards should read as a resume stack, not a raw file list. Recent
  items show a clear name, quiet location detail and a direct path back into
  the work when SevenAI has approved local metadata.
- Recent items may show a small type capsule and a subtle open arrow. This
  improves recognition without turning Home into a file manager.
- Empty continuity states should look intentional: small symbol, calm title and
  one sentence explaining what will appear later.
- Notes on Home are personal memory, not a form. The card should expose a
  calm headline, recent/pinned notes and one quick capture field for ideas or
  reminders.
- Empty Notes states should invite capture with the same quiet visual language
  as Continuity, so first-run Home still feels complete.
- The quick note capture should feel embedded in the card: a quiet input with
  one compact add affordance. It should not compete with the dedicated Notes
  app action.
- The desktop remains calm: no widget should steal focus permanently.
- The desktop context menu is available by default on the Home surface.
  Application context menus must remain available, and SevenOS must ignore the
  widget menu when a normal app window is active.
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
| `ai` | SevenAI local suggestions, safe actions and memory shortcut. |
| `updates` | SevenOS update state and Settings shortcut. |
| `prism` | Active Mini OS and Prism status. |
| `mini-os` | Fast Mini OS switch shortcuts. |
| `notes` | Small local note card. |
| `tasks` | Quick task capture backed by Seven Notes. |
| `recent` | Recent local context known by SevenAI metadata learning. |
| `apps` | Essential app shortcuts for Home. |
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
| SevenOS | `doctor`, `ai`, `updates`, `prism`, `mini-os`, `quick` |
| Notes and work | `notes`, `tasks`, `recent`, `apps` |
| Media | `media` |

## Presets

| Preset | Default intent |
| --- | --- |
| `equinox` | Calm home surface: clock, calendar, system, storage, SevenAI, health, Prism, notes, network and actions. |
| `forge` | Development home: system load, storage, SevenAI, Doctor, tasks, recent context, Mini OS and actions. |
| `studio` | Creative home: storage, media, tasks, notes, recent assets and actions. |
| `shield` | Security home: Doctor, network, storage, SevenAI, tasks and Mini OS. |
| `atlas` | Knowledge home: calendar, notes, tasks, recent documents, storage, network and actions. |
| `baobab` | Cultural home: calendar, notes, weather, media, recent context, Prism and actions. |
| `pulse` | Gaming home: system, power, media, network, updates and Mini OS. |
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

Widget settings must stay window-sized, not page-sized: the header, summary
and footer remain fixed while presets, behavior, ordering and catalog live in
one scrollable content area. The Home order preview is capped so a large widget
set cannot make the preferences window overflow the screen.

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
- The stable default is productized: `seven widgets open` switches to workspace
  `1`, opens the widget layer there and keeps the Home guard enabled.
- The desktop widget layer has a double placement contract: Hyprland declares
  `Seven Widgets Desktop` on workspace `1`, and the GTK runtime silently moves
  and recenters the mapped window by address. This prevents stale positions
  when the user opens Home from another workspace.
- The home workspace is configurable with `seven widgets home <number>`, but
  workspace `1` remains the public default.
- The automatic home guard is enabled by default. Normal application windows
  opened while the user is on the Home workspace are moved by the Hyprland event
  bridge:
  - work apps and unknown apps -> workspace `2`;
  - browsers and readers -> workspace `3`;
  - media/creative apps -> workspace `4`;
  - security tools -> workspace `7`.
- When the user leaves Home, the desktop widget layer stays attached to the
  Home workspace instead of following the user across workspaces. If the window
  is closed by Hyprland or a session reload, the event bridge recreates it when
  the user returns to Home and widgets are still marked visible.
- The Home widget surface is responsive and owned by the app. Hyprland keeps it
  floating on Home, but does not force a fixed size that would make it overflow
  on smaller displays.
- The Home layout is organized as a desktop composition, not a control panel:
  Today, System State and Continuity zones keep the home screen scannable.
- The Home header should greet first, then expose a compact identity strip for
  day phase, active Mini OS and freshness. Avoid long diagnostic subtitles.
- The Home header presence capsule may include a tiny trust indicator. It
  should show machine mood at a glance without becoming a diagnostics panel.
- Zone headers may expose tiny `01/02/03` orientation marks so Home reads like
  a deliberate OS surface. These marks must stay secondary to the zone title.
- The Home surface may use subtle stage bands, horizon lines and anchor marks
  behind widgets to feel like an OS landing space. These elements must remain
  passive, low contrast and non-interactive.
- Widget cards may use a tiny bottom mood line to reinforce their zone
  identity and warning state. It is decorative context only, not a separate
  progress indicator.
- Home cards should feel placed on the desktop: subtle elevation, low-opacity
  glass and restrained hover feedback. Avoid heavy filled panels that make
  workspace 1 look like a control-center window.
- A lightweight Today strip summarizes network state, free space and the first
  local SevenAI hint without opening a separate assistant window. It should read
  as a calm continuity ribbon: confidence, quick context, then next action.
- The Today strip may include a tiny state signal and bounded one-line action
  copy so it remains glanceable on smaller screens.
- Personal widgets such as Notes should expose recency and quick capture in
  place, with calm chips and no separate panel. Home should help the user
  resume thoughts without opening a full app first.
- Quick actions on Home should keep stable tile dimensions, framed icons and
  one-line hints. They are launch affordances, not large command cards.
- Continuity items should feel resumable: compact type badges, a small active
  marker and a quiet open affordance are preferred over long file lists.
- Empty Home states should feel like calm invitations, not missing content:
  framed symbols, short titles and two-line details keep widgets useful before
  the user has local context.
- The Clock card may expose a compact day-rhythm rail. It should communicate
  time progression at a glance without using a technical progress meter.
- System cards on Home should summarize health first, then expose compact
  pressure chips. Avoid duplicating the same metric as both chip and progress
  bar on the Home surface.
- Network on Home should communicate availability and a single next action:
  show the active Wi-Fi/Ethernet name when known, manage when connected and
  connect when offline. Detailed diagnostics belong in the network surface.
- Seven Doctor on Home should reassure first and expose only the next useful
  health summary. Scores and raw counts may live in tooltips or the Doctor
  surface.
- The Prism card should read as the active identity compass for SevenOS:
  current Mini OS first, mission second, compact universe marker third.
- System overlays such as Spotlight, Launchpad, Quick Settings, Dock, window
  controls and the widget menu are allowed to appear on the home surface.

The guard can be inspected or changed without touching config files:

```bash
seven widgets guard
seven widgets guard on
seven widgets guard off
seven widgets home 1
```

SevenOS writes the runtime policy to:

```bash
~/.config/sevenos/workspace-home.env
```

The user service `sevenos-hypr-lua-events.service` reads this file and applies
the routing policy during Hyprland sessions.

## Future

- Drag-and-drop layout editing.
- Drag-and-drop preset editing.
- Weather provider with explicit location consent.
- Calendar and tasks.
- Baobab cultural phrase, Forge services, Pulse performance and Shield alerts.
