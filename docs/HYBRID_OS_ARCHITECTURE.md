# SevenOS Hybrid OS Architecture

SevenOS does not modify the Linux kernel to become intelligent. It builds a
local, user-space hybrid operating architecture above Linux.

The goal is:

```text
Linux stability + SevenOS orchestration + SevenAI context = an adaptive OS
```

SevenOS should feel like a complete operating system because it coordinates
desktop, services, profiles, apps, security, Windows compatibility and local AI
through one system layer.

## Definition

SevenOS is a user-space hybrid operating system layer:

- Linux keeps CPU, memory, drivers, filesystems, networking and security
  primitives.
- Arch keeps packages, systemd, PipeWire, Wayland, Hyprland, libvirt and
  distribution freshness.
- SevenOS adds the intelligent control plane, event bus, shell surfaces,
  profile workflows, local diagnostics, remediation playbooks and assistant
  logic.

This is intentionally not a kernel fork. It is an OS experience layer with
strict local contracts.

## Layer Stack

```text
SevenAI Layer
  local language understanding, diagnostics, confirmation, learning

Seven Runtime Orchestrator
  autonomous profiles, Equinox global balance, composition, conflict resolver

Seven System Orchestration Layer
  decisions, profiles, scheduler hints, repair plans, trusted actions

User-Space Services Layer
  SevenDaemon, SevenBus, context observer, Server, app registry, indexers

Desktop / UI Layer
  Hyprland, Waybar, Seven Hub, Spotlight, Quick Settings, Files, Dock

Arch / Linux Platform
  pacman, systemd, PipeWire, NetworkManager, libvirt, portals

Linux Kernel
  process model, memory, drivers, devices, networking, filesystems
```

## Runtime Flow

```text
User intent
  -> Seven Hub / Spotlight / Waybar / CLI
  -> seven action registry
  -> SevenAI or Control Plane decision
  -> Seven Runtime Orchestrator
  -> Capability Fusion Engine and Conflict Resolver
  -> SevenBus event and audit trail
  -> SevenDaemon / system service / Hyprland / package tool
  -> Linux kernel and hardware
```

The user should not have to know whether an action uses Hyprland, systemd,
NetworkManager, Wine, Flatpak or libvirt. SevenOS should explain the action,
request confirmation when needed, execute it through the proper layer and keep
an event trail.

## Layer Responsibilities

### Linux Kernel

SevenOS leaves this layer stable and upstream-friendly:

- process scheduling primitives;
- memory and filesystem management;
- device drivers;
- network stack;
- Linux security primitives.

SevenOS may read kernel and `/proc` state, but it does not pretend to replace
the kernel.

### Desktop / UI Layer

This layer makes the system approachable:

- Hyprland for Wayland composition and workspaces;
- Waybar for glanceable controls;
- Seven Hub for system control;
- Seven Spotlight for actions and AI intents;
- Seven Files, Quick Settings, Dock and notifications for daily use.

The UI layer must stay simple for normal users. Technical state is surfaced
only when it helps decision-making.

### User-Space Services Layer

This is the first real hybrid layer. It contains local services that turn Linux
signals into SevenOS state:

- `seven-daemon` for runtime health, event reading and future policy;
- SevenBus as the typed local event stream;
- context observer for active workflow signals;
- Seven Server for local API surfaces;
- app registry and package metadata for reliable automation;
- Windows Mode resolver for Wine, Bottles, Lutris and KVM decisions.

These services must stay local-first. Remote control requires authentication,
TLS, permissions and audit logging before it exists.

### System Orchestration Layer

This layer decides what should happen:

- profile/session orchestration;
- system readiness and phase gates;
- action prioritization through `seven control`;
- Scheduler user-space hints;
- repair plans and confirmation gates;
- Shield trust posture;
- Windows compatibility routing;
- installer and deployment readiness.

The orchestration layer never hides risk. System-changing actions need preview,
confirmation and logs.

### Seven Runtime Orchestrator

This layer implements the Layered Autonomous Profiles Architecture.

Each profile is complete in its own domain and exposes four internal layers:

```text
Profile
  Kernel Layer        resource intent, performance posture, isolation
  Runtime Layer       services, tools and domain-specific dependencies
  Experience Layer    UI, workflow and profile-specific surfaces
  Intelligence Layer  SevenAI rules, behavior and local knowledge
```

The rule is:

```text
No profile dependency, only profile collaboration.
```

Baobab does not depend on Forge. Shield does not depend on Horizon. Studio does
not inherit developer services. Each profile can run alone.

The global system adds a fifth invisible layer:

```text
Composition Layer
  controlled fusion, resource arbitration, conflict resolution, anti-nuisance
```

The rule is:

- one profile is visible as the dominant runtime;
- other profiles collaborate through explicit capabilities;
- duplicate services are avoided;
- conflicts are resolved by policy;
- heavy stacks do not leak across profile boundaries.

#### Profile Domains

| Profile | Domain | Rule |
| --- | --- | --- |
| Equinox Balance | balanced general computing | neutral daily mini OS; no specialized profile dominates |
| Baobab Culture | culture and learning | African knowledge, languages and community memory; no dev/security/cloud/gaming stack |
| Forge Developer | development | engineering, toolchains, containers and builds |
| Shield Cybersecurity | security | authorized audit, sandbox, forensics, reports and safe scope |
| Studio Creator | creation | logos, design, video, audio, capture and 3D production |
| Windows Bridge | Windows compatibility | complete VM-first Windows path with Wine/Bottles fallback |
| Horizon Cloud | cloud/server | server, deploy, reverse proxy, services and local API |
| Pulse Gaming | Linux gaming | Proton, low latency, overlays, controllers and foreground responsiveness |

For example:

```text
seven runtime plan equinox forge shield studio horizon pulse
```

means:

- `equinox` stays neutral;
- Forge contributes light dev capability only when needed;
- Shield contributes basic safety rules without launching scans;
- Studio/Horizon/Pulse remain controlled fragments instead of full noisy stacks.

Another example:

```text
seven runtime plan baobab shield horizon
```

means:

- `baobab` owns the visible cultural experience;
- Shield and Horizon can collaborate only through explicit injected rules;
- Baobab remains clean: no Docker, no dev toolchain, no cloud daemons, no gaming runtime.

The current implementation is deliberately safe. It exposes the composite
runtime, lifecycle, conflict decisions and resource allocation plan, then only
writes local runtime state when the user explicitly confirms with
`--apply --yes`.

### SevenAI Layer

SevenAI is the human language layer over the same contracts:

- understands ordinary requests such as "open Blender", "stop Firefox",
  "mon wifi ne marche pas", "mets le thème light";
- reads local context before acting;
- maps language to action IDs and playbooks;
- explains in the current system language;
- keeps memory local;
- uses web only when the user explicitly allows it;
- never requires paid tokens or external providers for basic OS control.

SevenAI is not a chatbot bolted onto the desktop. It is an OS agent interface
to the local control plane.

## Current Repository Anchors

| Capability | Current Anchor |
| --- | --- |
| Control entrypoint | `bin/seven` |
| Action registry | `scripts/actions.sh` |
| Unified state | `scripts/state.sh` |
| Control decisions | `scripts/control-plane.sh` |
| Runtime orchestration | `scripts/runtime-orchestrator.sh`, `seven runtime` |
| Local event bus | `scripts/events.sh`, `seven-core/daemon` |
| Runtime health | `seven core health --json` |
| Context | `scripts/context.sh`, `seven-context-observer.service` |
| SevenAI | `scripts/ai.sh`, `scripts/seven_ai_agent.py` |
| Scheduler | `scripts/scheduler.sh` |
| Shell | Hyprland, Waybar, Seven Hub, Spotlight |
| Windows routing | `bin/seven-windows-assistant`, `vm/windows-app-runner.sh` |

## Runtime Contracts

The hybrid architecture is not only documentation. It is exposed as live state:

```text
seven architecture hybrid
seven architecture matrix
seven architecture matrix --json
seven state --json
seven runtime status --json
seven runtime plan equinox forge shield horizon pulse --json
```

`seven architecture matrix --json` is the product contract for Hub, Spotlight,
SevenAI and future Seven Server endpoints. It includes:

- layer readiness and maturity;
- ownership boundaries;
- public contracts each layer exposes;
- capabilities users should experience;
- safety model and risk level;
- gaps and next actions.

This keeps SevenOS honest: if a layer is not measurable, it is not treated as a
finished OS layer.

## Ownership Matrix

| Layer | Owner | Main Contracts | Safety Rule |
| --- | --- | --- | --- |
| SevenAI | SevenAI agent and provider | `seven ai`, diagnostics, playbooks | safe-by-default, confirm before system changes |
| Runtime | Seven Runtime Orchestrator | `seven runtime status --json`, `seven runtime plan ...` | plan first, apply local state only with confirmation |
| Orchestration | `seven control`, actions, scheduler, repair | `seven control --json`, `seven actions --json` | preview before apply |
| User-Space Services | SevenDaemon, SevenBus, context services | `seven core health --json`, `seven events --json` | local audit trail |
| Desktop/UI | Hyprland, Waybar, Hub, Spotlight, native apps | `seven hub`, `seven-spotlight`, `seven-files` | normal-user workflows first |
| Linux Platform | Arch/systemd/PipeWire/NetworkManager/libvirt | `systemctl`, `pacman`, `nmcli`, portals | admin confirmation for system changes |
| Linux Kernel | upstream Linux | `/proc`, `/dev` | read-only observation from SevenOS |

## Implementation Rules

1. Contracts before magic.
   Every intelligent surface must rely on stable commands or JSON contracts.

2. Local-first by default.
   SevenAI, SevenBus and diagnostics must work without cloud accounts.

3. Human-readable for people, JSON for software.
   Public CLI responses should be understandable; Hub and daemons consume JSON.

4. Confirmation before power.
   Safe UI actions can run immediately. System and root actions require preview
   and explicit apply.

5. Bash remains glue, Rust owns long-running state.
   Existing scripts keep compatibility while SevenDaemon gradually takes over
   runtime logic.

6. UI stays calm.
   SevenOS may be intelligent, but it should not flood the user with technical
   noise.

## Build Path

### Phase 1: Contracts

- keep `seven state --json`, `seven actions --json`, `seven control --json`,
  `seven ai ... --json` stable;
- ensure Hub and Spotlight use action IDs where possible;
- write SevenBus events for previews and important actions.

### Phase 2: Observation

- expand daemon-owned health;
- observe active workspace, app, profile, network and service health;
- keep the context observer local and explainable.

### Phase 3: Orchestration

- move repeated shell probes into SevenDaemon;
- connect Scheduler, Shield, Windows Mode and profiles through control
  decisions;
- add playbooks with safe, system and root levels.

### Phase 4: SevenAI System Agent

- map natural language to actions and playbooks;
- explain decisions in the active language;
- integrate confirmation UI in Spotlight and Hub;
- store local memory in SQLite.

### Phase 5: Product OS

- Seven Hub becomes the normal-user control surface;
- Seven Shell becomes the integrated desktop layer;
- Seven Server exposes local-only API state;
- remote or cloud features remain opt-in, authenticated and audited.

## Success Criteria

SevenOS reaches the intended architecture when a user can say:

```text
open blender
stop firefox
mon wifi ne marche pas
optimise mon système
installe un outil de dev
change le thème en light
```

and SevenOS can:

- understand the intent;
- inspect relevant local context;
- choose the right action or playbook;
- explain the plan in human language;
- request confirmation when needed;
- execute safely;
- record the event locally;
- improve the next suggestion without leaking user data.
