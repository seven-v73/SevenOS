# SevenOS System Experience Layer

This document is the main architectural reference for the long-term direction
of SevenOS.

The companion document `docs/HYBRID_OS_ARCHITECTURE.md` names the same strategy
as a local user-space hybrid operating architecture: Linux keeps the kernel and
hardware foundation, while SevenOS adds the orchestration, services, shell and
SevenAI layers above it.

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
Kernel / Hardware Interface
  -> Linux, drivers, libinput, ALSA, PipeWire
  -> Seven Core
  -> SevenBus
  -> Seven Daemon Runtime
  -> Seven Shell
  -> Seven Hub
  -> Profiles / Ecosystem
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
  daemon, session manager, profile engine, context engine, scheduler, power, input, audio and AI hooks

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
- user-space process scheduling policy
- semantic workflow context
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

The first migration out of Bash is SevenBus event writing:

```text
seven events log
  -> seven-daemon emit
  -> ~/.local/state/sevenos/events.jsonl
```

If the Rust writer is unavailable, the Bash/Python fallback remains. That is
the long-term migration rule: Bash stays as glue and compatibility, while
SevenDaemon takes over stateful system behavior step by step.

The second migration is SevenBus state reading:

```text
seven core snapshot --json
  -> seven-daemon snapshot --json
  -> typed source/state/writer counts from SevenBus
```

This gives Seven Hub and Seven Shell a daemon-native view of the event stream
without parsing shell output. The reader is implemented with `serde_json` and
reports invalid event lines separately, so corrupted local event history does
not break the whole OS state contract.

The third migration is event listing and summaries:

```text
seven events --json
seven events summary-json
  -> seven-daemon events --json
  -> seven-daemon summary --json
```

The public commands keep their Bash entrypoints for compatibility, but the
event stream is now read by the Rust runtime when available.

The fourth migration is local runtime health:

```text
seven core health --json
  -> seven-daemon health --json
  -> /proc uptime, load, memory, session and SevenBus health
```

This is the beginning of Seven Core behaving like an OS runtime: lightweight,
local and daemon-owned state that Hub/Shell can read without executing a chain
of shell scripts.

Seven Shell consumes that health contract:

```text
seven shell status --json
  -> runtime_health
  -> seven-daemon health --json
```

The shell layer should increasingly display daemon-owned state instead of
launching independent probes for every widget.

The fifth migration is profile inventory:

```text
seven core profiles --json
  -> seven-daemon profiles --json
  -> daemon-owned profile state, package counts, bootstrap state and app readiness
```

This does not delete `profiles/profile-manager.sh` yet. Instead, it creates the
first Rust-owned profile contract so Bash can become a compatibility wrapper
over time. The long-term target is:

```text
seven profile status --json
  -> SevenDaemon profile engine
  -> Seven Hub / Seven Shell without parsing shell output
```

The sixth migration is trust posture:

```text
seven shield status --json
  -> seven-daemon shield --json
  -> daemon-owned firewall, sandbox, audit tool and workspace posture

seven shield plan --json
  -> seven-daemon shield-plan --json
  -> daemon-owned prioritized remediation plan
```

`security/shield-status.sh` remains the human CLI and fallback surface, but the
machine contract now has a Rust owner. This is important because Shield is not a
theme feature: it is part of the SevenOS trust runtime that Seven Hub, Seven
Shell and future SevenAI must be able to read without scraping shell output.

Shield also exposes a native workspace surface:

```text
seven shield dashboard
seven shield dashboard --json
seven shield mode
seven shield mode --json
  -> seven-daemon cyberspace --json
seven shield workspaces
seven shield context recon
seven shield layout web
seven shield hud
seven shield tools
seven shield labs
seven shield scope
seven shield scope --json
seven shield report
seven shield open
```

This surface aggregates posture, profile completeness, authorized scope, lab
presets, workspace folders, tools and quick actions. It makes cybersecurity
feel like a SevenOS mode rather than a disconnected set of terminal commands.

The next Shield layer is CyberSpace:

```text
Shield profile
  -> CyberSpace context engine
  -> Hyprland workspaces
  -> scoped labs, reports and tools
  -> Seven Hub Security Center
```

CyberSpace maps human intent to OS behavior. `recon`, `web`, `reversing`,
`network`, `forensics`, `exploit`, `intel`, `logs` and `sandbox` are not just
labels: they define workspace targets, preferred tools, safe actions and
dashboard state. SevenOS still delegates CPU scheduling to Linux, but Shield can
now express what the user is doing before tools are opened.

The machine-owned contracts are:

```text
seven-daemon cyberspace --json
seven-daemon cyberspace-plan --json
```

This is the bridge toward `seven-cyberd`: Bash remains the user command surface,
while Seven Core owns the context map and plan that Hub and Server consume.

The seventh migration is local backend readiness:

```text
seven server status --json
  -> seven-daemon server --json
  -> daemon-owned service, bind, dependency and endpoint posture

seven server plan --json
  -> seven-daemon server-plan --json
  -> daemon-owned local API and deployment remediation plan
```

`server/seven-server.sh` still owns the development HTTP server and service
install/start actions. The state contract, however, now has a Rust owner. This
keeps the future Hub/Server relationship clean: Hub can ask SevenDaemon what the
backend state is, while the server process focuses on serving API routes.

The eighth migration is Windows Mode readiness:

```text
seven windows status --json
  -> seven-daemon windows --json
  -> daemon-owned Wine, Bottles, KVM, libvirt and VM posture

seven windows plan --json
  -> seven-daemon windows-plan --json
  -> daemon-owned compatibility remediation plan
```

`bin/seven-windows-assistant` remains the human guide and action surface for
opening Bottles, Virt Manager or creating a VM. The readiness contract moves to
SevenDaemon so Hub and Shell can reason about compatibility without inheriting a
large Bash decision tree.

The ninth migration is installer readiness:

```text
seven installer status --json
  -> seven-daemon installer --json
  -> daemon-owned Archinstall, Calamares, Archiso and ISO builder posture

seven installer plan --json
  -> seven-daemon installer-plan --json
  -> daemon-owned distribution readiness plan
```

The important boundary is safety: SevenDaemon reads installer state and plans
the next steps, but it does not perform destructive disk operations. Real install
actions stay behind the existing planner, doctor and explicit installer commands
until the Calamares/ISO path is mature.

The tenth migration is software readiness:

```text
sevenpkg status --json
  -> seven-daemon packages --json
  -> daemon-owned meta-package, package count and source posture

sevenpkg plan --json
  -> seven-daemon packages-plan --json
  -> daemon-owned software remediation plan
```

`sevenpkg` remains the public user command for installing apps and SevenOS
software layers. The decision contract moves into SevenDaemon so Seven Hub,
Seven Shell and Seven Server can read software posture without reimplementing
package logic in Python or Bash.

The eleventh migration is product diagnosis:

```text
seven insights --json
  -> seven-daemon insights --json
  -> daemon-owned diagnosis across Shield, Server, Profiles, Windows, Installer and Packages
```

This does not replace the full historical `scripts/state.sh` aggregation yet.
It creates a faster OS-native path for the question Hub asks constantly:
what should the user fix or activate next?

The twelfth migration is the phase transition gate:

```text
seven phase-gate --json
  -> seven-daemon phase-gate --json
  -> daemon-owned B2 -> B3 decision contract
```

The human `seven phase-gate` command still runs the full check suite. The JSON
contract is intentionally daemon-native so Hub, Server and release tooling can
read a transition decision quickly without spawning the entire validation stack.

## Seven Context Engine

Seven Context Engine sits just above raw process/window observation. It is the
semantic layer that answers: what is the user actually doing?

```text
Processes + windows + profile + events
  -> Seven Context Engine
  -> Forge DevOps / Studio / Shield / Windows / Pulse / Streaming context
  -> Seven Scheduler, Seven Shell, Seven Hub, future SevenAI
```

The first implementation is:

```text
seven context status --json
seven context graph --json
seven context plan --json
seven context emit
seven core observe --json
seven core start-observer
```

It builds a lightweight context graph from process topology and Hyprland window
state when available. This is the strategic difference between a PID-centric
desktop and a context-aware OS.

`seven core observe --json` is the first daemon-facing bridge: SevenDaemon asks
the Context Engine to emit one typed SevenBus context event. The next runtime
step is turning this into a supervised loop owned by SevenDaemon.

`seven-context-observer.service` is that first supervised loop. It belongs to
`sevenos-session.target`, runs locally as the user, and periodically records the
semantic context through SevenBus so future Shell/Hub surfaces can react to a
live OS signal instead of only on-demand script output.

## Seven Scheduler

Seven Scheduler is the user-space process and thread orchestration layer.

It does not replace Linux CFS. It gives SevenOS a contextual policy engine above
the kernel scheduler:

```text
Applications
  -> Seven Shell context
  -> Seven Core Scheduler Layer
  -> Linux CFS Scheduler
  -> CPU
```

The first implementation is intentionally conservative:

```text
seven scheduler status --json
seven scheduler plan --json
seven scheduler apply
```

It groups processes by SevenOS profile:

- Baobab: core OS services and shell
- Forge: editors, compilers and containers
- Shield: audit, sandbox and network security tools
- Studio: media, graphics, audio and 3D production
- Windows: Wine, Bottles, Lutris and KVM/QEMU
- Forge DevOps: containers, Caddy, deployment and services

The current layer detects matching workloads, exposes a policy contract, and
previews nice/power/IO hints plus future cgroups v2, systemd slice and `uclamp`
targets. Future versions should move observation and policy execution into
SevenDaemon, with SevenBus carrying foreground app, profile and AI intent
events.

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
small C IPC/hardware probes
Unix socket
typed event schema
Hub/Shell clients
```

C is deliberately constrained here. It is the physical and nervous layer for
SevenBus IPC probes, hardware communication, power/input/audio adjacency and
future security hooks. It is not the product brain, the UI, or the ecosystem
language.

Current C foothold:

```text
seven-core/bus-c/
bin/sevenbus-probe
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
- Shield, Server, installer and software readiness blockers reduced

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
- collapse into a compositor theme with scripts
- add hundreds of scripts without contracts
- copy other desktop systems directly
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
