# SevenOS Liquid Glass OS Direction

SevenOS uses desktop-grade systems as a quality reference, not as a copy
target. The goal is a desktop that feels calm, readable, spatial and integrated
while keeping the SevenOS identity: futuristic, premium, context-aware and
Linux-native.

## Core Material Rule

SevenOS uses a 70/30 balance:

- 70% transparent minimal UI for focus, speed and readability.
- 30% liquid glass on active surfaces: Waybar islands, Dock, Spotlight, Seven
  Files, notifications, Control Center and overlays.

Liquid glass is delivered by Hyprland compositor blur plus translucent
surfaces, soft borders, subtle gradients and consistent spacing. Production
Linux shell CSS does not use web-only `backdrop-filter`.

## Interface Anatomy

### Menu Bar

The top Waybar behaves as a floating cockpit:

- left: SevenOS identity, Apps and workspaces;
- center: Spotlight, media and SevenAI;
- right: profile, security, CPU/RAM, Bluetooth, audio, network, notifications,
  clock, battery and power.

Every visible item must be clickable or carry useful state. Decorative modules
are not allowed.

### Dock

The Dock is a workflow surface:

- pinned apps and system surfaces on the left;
- folders and files on the right;
- running indicators below active apps;
- context menus for open, windows, quit, force quit, keep/remove and settings;
- compact liquid frame, not a large panel.

### Windows

Native SevenOS apps follow a SevenOS Files anatomy:

- traffic lights;
- toolbar for global actions;
- sidebar for navigation;
- central canvas for content;
- optional right inspector/preview.

### Spotlight

Spotlight is the only global search surface. On open, it must stay quiet:

- search field;
- category icons;
- no examples and no long result list.

Results appear only after typing or after selecting a category. This keeps the
desktop elegant and prevents SevenOS from feeling like a terminal menu.

### Notification Center

Notifications are not an action menu. The notification center must show useful
system events first:

- active notifications as cards;
- a quiet empty state when clear;
- icon-only controls for test, restore, dismiss, focus and restart;
- no visible list of maintenance commands as the primary content.

### Quick Settings

Quick Settings is a control surface, not a launcher. It should expose direct
state and immediate controls:

- connectivity tiles for Wi-Fi and Bluetooth;
- Focus tile wired to notifications Do Not Disturb;
- active profile tile;
- sliders for sound and display;
- compact icon actions for Apps, Files, Monitor, Hub and Power.

Avoid repeating action descriptions inside the panel. Descriptions belong in
tooltips, docs or Spotlight.

## Interaction

- `Super` opens Launchpad.
- `Super+Space` opens Spotlight.
- `Super+D` toggles Dock.
- `Super+E` opens Seven Files.

SevenOS should feel keyboard-first and pointer-friendly at the same time.

## Ecosystem Direction

The visual system should support future continuity features:

- universal clipboard through the SevenOS clipboard layer;
- widgets and notification center;
- profile-aware desktop state;
- SevenBus events for cross-surface updates;
- AI/context suggestions inside Spotlight without visual overload.

## Non-Negotiables

- No flat black-on-black utility surfaces without translucent depth.
- No oversized glass sheets everywhere.
- No aggressive neon or cyberpunk cliché; cyber mode stays premium and useful.
- No search bars outside Spotlight unless the app is a dedicated search tool.
- No decorative UI element without a real action or state.
- No direct clone branding. SevenOS keeps its own vocabulary and profile
  logic.
