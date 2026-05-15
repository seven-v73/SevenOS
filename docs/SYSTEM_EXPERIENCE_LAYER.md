# SevenOS System Experience Layer

This document is the main architectural reference for the long-term direction
of SevenOS.

SevenOS should not be understood as:

```text
Arch Linux + Hyprland + theme + scripts
```

SevenOS should be understood as:

```text
a sovereign system experience layer above Linux and Arch
```

The Linux kernel and Arch base provide hardware support, packages, drivers,
systemd, Wayland, PipeWire and the low-level platform. SevenOS adds the layer
that makes these pieces feel like one coherent operating system.

## Core Thesis

Modern operating systems are won through orchestration.

Apple does not win only because of XNU. Windows does not win only because of
NT. Android, ChromeOS and SteamOS are recognizable because each adds a strong
system layer above Linux or another kernel foundation.

SevenOS should follow that path:

```text
Hardware
  -> Linux Kernel
  -> Arch Base
  -> Seven Core
  -> SevenBus
  -> Seven Shell
  -> Seven Hub
  -> Seven Apps, Profiles, AI and Cloud
```

## Why This Layer Exists

Linux desktop is powerful but fragmented:

| Domain | Common Problem |
| --- | --- |
| Audio | PipeWire, ALSA and app routing are not always understandable |
| UI | GTK, Qt, web apps and shell surfaces feel inconsistent |
| Config | files are scattered across many directories |
| Services | systemd, DBus, user services and scripts do not feel unified |
| Drivers | hardware quality depends heavily on vendor support |
| Power | battery, thermals and GPU policies vary by machine |
| Notifications | notification surfaces are rarely tied to workflows |
| UX | the user sees components instead of one system |

SevenOS exists to build a coherent layer over that fragmentation.

## Layer Model

```text
Seven Apps
  Notes, Store, Cloud, Settings, Studio, future Companion

Seven Hub
  control center, profile manager, trust view, app flow, installer flow

Seven Shell
  panels, launcher, dock, widgets, notifications, overview

SevenBus
  typed local event bus, state updates, commands, permissions

Seven Core
  daemon, session manager, profile engine, power, input, audio and AI hooks

Arch Base
  pacman, systemd, PipeWire, Hyprland, Flatpak, libvirt

Linux Kernel
  drivers, process model, filesystems, networking, memory, security primitives

Hardware
  CPU, GPU, battery, input, displays, audio, storage, network
```

## Seven Core

Seven Core is the future system service layer.

It should not replace Linux. It should coordinate Linux.

Responsibilities:

- system state aggregation
- profile/session orchestration
- trust and Shield posture
- Windows Mode state
- app and package workflow state
- deployment/backend state
- future power and performance policies
- future AI context signals

Near-term implementation:

```text
seven core --json
seven core plan --json
seven core bus --json
seven state --json
seven control --json
seven events --json
seven insights --json
Seven Server local API
seven-core/daemon Rust scaffold
```

Future implementation:

```text
seven-daemon in Rust
```

Rust enters here because long-running orchestration benefits from memory safety,
typed events and predictable performance.

Current repository anchor:

```text
seven-core/
  README.md
  bus-schema.json
  daemon/
    Cargo.toml
    src/main.rs
```

This is the B2-B3 bridge. The shell and Hub can consume Core state today, while
the Rust daemon remains a small, testable scaffold instead of a premature
rewrite.

Runtime bridge:

```text
bin/seven-daemon
systemd/user/seven-daemon.service
systemd/user/sevenos-session.target
```

`seven-daemon` is intentionally small for now: it reports its contract, watches
the local event journal count, and can run as a user service. The point is to
introduce a supervised runtime boundary before moving orchestration logic out
of Bash.

## SevenBus

SevenBus is the future local event and command bus for SevenOS.

It should be:

- local-first
- typed
- async
- permission-aware
- observable
- safe by default

SevenBus should not expose remote control until authentication, TLS, audit logs
and permission policy exist.

Initial form:

```text
JSON contracts + Seven Server endpoints + local JSONL event journal
```

Future form:

```text
Rust daemon IPC
Unix socket
typed event schema
Hub/Shell clients
```

Example future events:

```text
profile.changed
shield.posture.changed
power.mode.changed
windows.vm.ready
app.install.completed
shell.surface.opened
ai.intent.received
```

## Seven Shell

Seven Shell is the SevenOS desktop shell layer.

Current fallback:

```text
Hyprland + Waybar + GTK shell panels + Rofi
```

B3 target:

```text
AGS + TypeScript
```

Seven Shell should own:

- quick settings
- notification center
- launcher
- dock
- widgets
- profile-aware controls
- overview behavior

Rofi remains a fallback, not the main OS control plane.

Important rule:

```text
Seven Shell must consume SevenOS JSON contracts.
It must not parse human CLI output.
```

## Seven Hub

Seven Hub is the user-facing control center.

It should expose:

- system readiness
- phase gate
- profiles
- app/software setup
- Shield/security
- Windows Mode
- Seven Server/deployment
- identity/accent packs
- stack and shell status
- repair actions

The current direction is GTK/libadwaita for native Linux integration.
Tauri stays useful as a prototype/fallback, but it is not the final OS shell
model.

## Hardware Intelligence

SevenOS should eventually understand hardware as part of the experience.

Do not start by writing drivers. Start by observing and coordinating existing
Linux interfaces:

- `udev`
- `upower`
- `powerprofilesctl`
- `libinput`
- PipeWire
- NetworkManager
- systemd
- `/proc`
- `/sys`
- Vulkan/DRM/KMS later

Future components:

| Component | Role | Timing |
| --- | --- | --- |
| Seven Power | battery, CPU/GPU, thermals, performance profiles | after B3 daemon |
| Seven Input | gestures, shortcuts, contextual controls | after Shell is stable |
| Seven Audio | PipeWire routing, low-latency profiles, noise workflows | Phase 4 |
| Seven Memory | pressure monitoring, app sleeping, preload suggestions | Phase 4+ |
| Seven Compositor | custom compositor or deep Hyprland/wlroots/smithay path | much later |

## Seven Compositor

The compositor is central to an OS experience because it controls:

- windows
- input focus
- animations
- overlays
- scaling
- GPU presentation
- gestures
- visual continuity

But SevenOS should not start by building a compositor.

Near-term:

```text
Use Hyprland well.
Build Seven Shell and Seven Core around it.
```

Long-term options:

```text
deep Hyprland integration
wlroots-based compositor
smithay-based Rust compositor
```

This belongs after SevenDaemon, SevenBus and Seven Shell have proven the
experience model.

## AI Native Direction

SevenOS should not merely add a chatbot.

The future direction is intent-centric computing:

```text
user intent
  -> AI context engine
  -> SevenBus
  -> confirmed system actions
  -> visible result and event log
```

Examples:

```text
"Prepare my Forge workspace."
"Optimize this laptop for battery."
"Explain why Windows Mode is not ready."
"Open a secure web testing lab."
"Summarize my system blockers before an ISO build."
```

Rules:

- AI suggests and explains before it changes.
- system-changing actions require confirmation.
- AI uses SevenOS contracts, not fragile terminal scraping.
- security-sensitive paths stay deterministic and auditable.

## Technology Boundaries

SevenOS uses multiple technologies, but each has a boundary.

| Domain | Preferred Technology | Boundary |
| --- | --- | --- |
| Kernel | Linux | do not rewrite |
| Base system | Arch | package/runtime foundation |
| System daemon | Rust | long-running orchestration, IPC, trust |
| Low-level critical code | C/Rust | only when Linux interfaces require it |
| Shell | AGS + TypeScript | panels, widgets, launcher, dock |
| Hub | GTK/libadwaita | native control center |
| AI | Python first, Rust later | analysis, suggestions, local models |
| Apps | Flutter, Qt or GTK | one stack per product app |
| Packaging | pacman, Flatpak, future SevenRepo | do not hide trust/source details |

## Phase Roadmap

### B2: Product Consolidation

Current phase.

Focus:

- JSON contracts
- Hub Native foundation
- Seven Server foundation
- phase gate
- stack discipline
- shell planning
- test-machine reliability

### B3: System Experience Foundation

Next phase.

Focus:

- SevenDaemon Rust foundation
- SevenBus local event model
- Seven Shell AGS first active panels
- Seven Hub talks to daemon/bus where possible
- Shield, Server and installer blockers reduced

### Phase 4: Intelligent OS Preview

Focus:

- SevenAI
- Seven Power
- notification intelligence
- audio/profile routing
- rootless container workflows
- richer native apps

### Phase 5: Connected Ecosystem

Focus:

- SevenStore
- SevenCloud
- sync and restore
- extensions
- marketplace
- multi-machine workflows

### Phase 6: Deep Graphics And Hardware

Long-term.

Focus:

- compositor research
- Vulkan/DRM/KMS experiments
- advanced input layer
- tighter GPU/power scheduling

## Non-Goals

SevenOS should not:

- rewrite the Linux kernel
- become only a beautiful Hyprland rice
- add hundreds of scripts without contracts
- copy macOS or Windows directly
- introduce every language at once
- expose remote system control before trust policy exists
- replace working Linux foundations prematurely

## Immediate Principle

For every new SevenOS feature, ask:

```text
Does this strengthen the system experience layer?
Does it expose state through a contract?
Can Hub/Shell use it without parsing human text?
Does it make Linux more sovereign, fluid and coherent?
```

If the answer is no, it is probably decoration or fragmentation.
