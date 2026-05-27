# SevenOS Primary PC Gate

SevenOS can be tested aggressively on a secondary machine, but a primary PC
needs a stricter path. The goal is not only to install packages; it is to make
the OS layer supervised, repairable and understandable after reboot.

## Minimum Gate

Before replacing an existing daily OS, aim for:

- readiness: `>= 90%`
- Shield/security: `>= 70%`
- role profiles: `>= 70%`
- Windows Mode: `complete` or consciously accepted as `vm-ready`
- Seven Server: `RUN`
- Seven Core services: daemon and observer installed/running
- installer foundation: at least Archinstall/plan tooling available

Check it with:

```bash
seven primary
seven primary --json | python -m json.tool
seven daily
seven daily --json | python -m json.tool
seven phase-gate --json | python -m json.tool
```

## One-Command Consolidation

If the machine currently uses ML4W, switch the active desktop layer first:

```bash
seven migrate-ml4w plan
seven migrate-ml4w switch
```

On the test machine that should become your main workstation:

```bash
sudo -v
seven primary apply
seven primary
```

Equivalent installer entrypoint:

```bash
sudo -v
./install.sh daily-driver --yes
seven daily
```

This path performs:

- protected user-state backup;
- CLI, theme, session and wallpaper runtime refresh;
- Seven Hub installation;
- Shield/security consolidation;
- Forge DevOps, Shield, Studio, Windows, Pulse and Baobab profile completion;
- Windows app compatibility setup;
- Seven Server and deployment foundation;
- installer tooling foundation;
- Seven Core daemon and context observer service installation/start;
- profile workspace bootstrap;
- post-install checks.

## Manual Recovery Checks

If something feels incomplete after reboot:

```bash
seven hub
seven-control-center open
seven primary --json | python -m json.tool
seven session status --json | python -m json.tool
seven core health --json | python -m json.tool
seven keyboard status
seven-wallpaper status
seven flatpak status --json | python -m json.tool
seven windows resolve photoshop --json | python -m json.tool
seven shield status --json | python -m json.tool
seven profile plan --json | python -m json.tool
seven-wifi status-json | python -m json.tool
```

The native Hub is the preferred control surface. The lightweight web control
center is only a fallback, but it must still show the primary-PC gate, Shield,
Windows Mode, Server runtime and quick repair actions.

## Stop Conditions

Do not move the machine to primary use if:

- `seven daily` still says `not-ready`;
- UFW or Firejail are missing;
- the active desktop has no SevenOS session services;
- `seven profile plan` still shows critical profile gaps;
- you have no recovery/reinstall path documented for the machine.

## Keyboard

SevenOS defaults to English US + French keyboard layouts:

```bash
seven keyboard status
seven keyboard apply
```

Switch layouts with `Alt+Shift`.

## Waybar Network Controls

SevenOS expects the network module to be usable without opening a generic
terminal first:

```bash
seven-wifi menu
seven-wifi connect
seven-wifi status-json | python -m json.tool
```

Waybar actions:

- click Wi-Fi/network: open SevenOS network actions;
- middle-click Wi-Fi/network: scan and connect to a Wi-Fi network;
- right-click Wi-Fi/network: show NetworkManager status.

If the Wi-Fi menu does not appear, check:

```bash
command -v nmcli
systemctl is-active NetworkManager
command -v rofi
```

## SevenOS Spotlight

`Super+Space` opens SevenOS Spotlight:

```bash
seven-spotlight
```

Spotlight is the command surface for daily use. The native surface is
intentionally quiet at first open: only the search field and category icons are
shown. Results appear only after you start typing or choose a category icon, so
the panel stays ergonomic instead of becoming another dense menu.

It indexes:

- installed desktop applications;
- files, common folders, recent documents and project folders;
- active Hyprland windows so you can jump back to an open surface;
- clipboard history through `cliphist` or the current Wayland clipboard;
- previous Spotlight searches through `/history`;
- Firefox bookmarks when the local browser database is readable;
- SevenOS actions from the shared action registry;
- profile/workspace actions;
- system settings such as network, audio, power, notifications, wallpaper,
  keyboard, Bluetooth and monitoring;
- system, security, Windows Mode and server commands;
- mail, contacts and calendar entrypoints when native apps are installed, with
  web fallbacks;
- quick calculations and practical conversions such as `42*7`, `15% of 240` or
  `10 km to mi`;
- definitions and web suggestions through the browser;
- quick actions such as timers and audio recording when the runtime tool exists;
- content search with queries such as `content docker compose` across common
  document/project folders;
- contextual intents such as preparing Forge, Studio or Cyber workspaces.

Use `Super` alone when you want the full app grid. `Super+A` remains a
compatibility shortcut. `Super+D` toggles the SevenOS Dock for Files, Apps,
Browser, Terminal, Spotlight, Hub and Settings. The Dock is a macOS-style
floating surface: the default renderer is the premium canvas Dock, with the
native GTK Dock kept as fallback. It separates folders from apps, shows running
indicators, magnifies on hover, previews open windows, accepts file drops, provides
right-click actions such as show windows, quit and force quit, and stores pinned
items in `~/.config/sevenos/dock.json`. The canvas Dock floats as an overlay by
default, so it does not push normal windows upward. It uses a subtle magnetic
focus effect with spring motion, hover-intent previews and a smooth slide reveal instead of an aggressive layout-stealing zoom, and also supports
drag reorder, middle-click new instance, scroll-to-cycle windows and macOS-style
folder stacks for Downloads/Home. Spotlight from the Dock opens the current
native Spotlight surface directly. Use `seven-dock repair` if the Dock is
missing after a session refresh. Use `SEVENOS_DOCK_RENDERER=native seven-dock repair`
only when the canvas renderer is unavailable.
Use `Super+Shift+H` or the
Spotlight action `Desktop · Open Seven Hub` for the Control Center.

Search is intentionally centralized here. The app grid, Hub fallback, quick
settings and power menu should behave like direct panels without their own
visible search bars. `Super+W` and `Super+R` also route back to Spotlight so
there is one command brain instead of multiple parallel launchers.

Useful checks:

```bash
seven-spotlight-native --probe
seven-settings-native --probe
SEVENOS_SPOTLIGHT_NATIVE=0 seven-spotlight rofi
```

## SevenOS Settings

`Super+,` opens the native SevenOS Settings app:

```bash
seven-settings
```

This is the normal-user configuration center. It groups the controls that
should not require terminal usage:

- wallpaper selection and Hyprpaper refresh;
- liquid glass appearance, dock, terminal style and Waybar repair;
- display brightness, monitor tools and Hyprland monitor override;
- Wi-Fi, NetworkManager and audio controls;
- US/French keyboard layout with Alt+Shift switching;
- Shield/security, profiles, power, apps and system maintenance.

Spotlight remains the only global search surface. Settings is intentionally
section-based, icon-led and action-oriented.

## SevenOS Terminal Profiles

SevenOS ships two Kitty profiles at the same time:

```bash
seven-terminal classic
seven-terminal dark
seven-terminal menu
```

Desktop shortcuts:

```text
Super+Enter       Terminal Classic
Super+Shift+Enter Terminal Dark
Super+Ctrl+Enter  Terminal theme menu
```

Open a new terminal after `./install.sh theme`; already-running Kitty windows
keep their previous config until they are closed.

The launcher opens a compact floating terminal instead of a tiled/fullscreen
window. It also uses a minimal shell profile, so it starts without country
signals, fastfetch or hardware/system descriptions:

```text
Super+Enter       640x420 Classic terminal
Super+Shift+Enter 640x420 Dark terminal
```

SevenOS prefers the native GTK/VTE terminal surface when `python-gobject` and
`vte3` are installed. That surface has real clickable SevenOS traffic-light
buttons:

```text
red    close
yellow minimize
green  maximize / restore
```

Check the active terminal path with:

```bash
seven-terminal status
```

If `native: MISS` appears, install the native terminal dependencies and refresh
the installed SevenOS commands:

```bash
sudo pacman -S --needed python-gobject vte3
./install.sh cli
hyprctl reload
```

SevenOS also guards against `pyenv` masking Arch Python modules: native GTK
surfaces relaunch through `/usr/bin/python` when the system bindings are
available there.

If GTK/VTE is not installed yet, SevenOS falls back to Kitty with visual
traffic-light markers and these shortcuts:

```text
Ctrl+Shift+W close terminal tab/window
Ctrl+Shift+M move terminal to the SevenOS scratch workspace
Ctrl+Shift+F toggle fullscreen
```

## SevenOS Launchpad

`Super` opens the SevenOS Launchpad. It is intentionally an icon-first app grid:
large icons, soft spacing, a compact app filter at the top and no system command
results. Global actions, files, settings and intelligence still belong to
`Super+Space` Spotlight.

When GTK is available, SevenOS uses the native Launchpad surface first: a
fullscreen icon grid with large app icons, a compact top filter and Escape to
close. Rofi remains only the fallback for machines missing GTK bindings.

## Seven Files

`seven-files` now prefers the native Seven Files surface before
falling back to Nautilus. The native surface provides a SevenOS sidebar,
traffic-light controls, toolbar navigation and large icon grid:

```bash
seven-files
seven-files downloads
seven-files pictures
```

If the native surface does not open, verify the same GTK Python path used by the
terminal:

```bash
seven-files-native --probe
```

If an old fullscreen Kitty window keeps appearing, close all Kitty windows and
re-apply the active desktop layer:

```bash
./install.sh cli
./install.sh theme
hyprctl reload
```

## Notification Center

The Waybar notification icon opens a native SevenOS Notification Center first:

```bash
seven-quick-settings notifications
seven-waybar-notifications menu
seven-notification-center-native --probe
```

The Control Center exposes a Notifications panel for quick open, clear, focus
and restart actions. The full center is content-first: active notifications
appear as cards, an empty state appears when the desktop is clear, and actions
are compact icon buttons with tooltips. Rofi is only a fallback if GTK bindings
are unavailable.
The clear action supports the modern SwayNC backend (`swaync-client -C`) and
falls back to Mako (`makoctl dismiss --all`) on lighter installs.

## Settings From Waybar

The Waybar Settings icon and `Super+,` open native SevenOS Settings:

```bash
seven-settings
seven-settings-native --probe
```

This surface is not a command list. It exposes direct controls for wallpaper,
appearance, displays, Wi-Fi, sound, keyboard, security, profiles, power, apps,
maintenance and system updates. `seven-quick-settings` remains available as a
fallback panel, but it is no longer the Waybar entrypoint.

## Seven Hub

Seven Hub Native is the primary Control Center:

```bash
seven hub
seven-hub-native open
```

The default view is compact and visual: readiness, Shield, UX, daily-driver
state, quick OS shortcuts, profile status, security, Windows, server, apps and
identity. Long diagnostics remain available through action buttons and terminal
output, not as the first screen.

## Waybar Profile And Shield

Profile and Shield are compact state icons in the menu bar:

```bash
seven-waybar-profile json
seven-waybar-security json
seven-profile-center-native --probe
seven-shield-center-native --probe
```

Clicking the Profile icon opens a native profile center. Clicking Shield opens a
native trust center with posture, ready/open items and prioritized Shield
actions. Text-heavy Rofi menus are kept only as fallback.

## Waybar System Centers

Network, audio, battery, system and clock modules use compact icons in the menu
bar and open native centers on click:

```bash
seven-waybar-center-native network
seven-waybar-center-native audio
seven-waybar-center-native power
seven-waybar-center-native system
seven-waybar-center-native time
```

The bar stays quiet, while the clicked center exposes direct controls, sliders
and icon actions.

## Product Rule

SevenOS should become a primary OS only when the user can recover, inspect and
repair the system through `seven`, Seven Hub and documented gates, not by
remembering scattered Arch commands.
