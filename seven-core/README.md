# Seven Core

Seven Core is the foundation of the SevenOS System Experience Layer. It does
not replace Linux, Arch, systemd, PipeWire or Hyprland. It coordinates them so
SevenOS can feel like a coherent operating system instead of a set of scripts.

## Purpose

Seven Core owns the system-facing contracts that Seven Hub, Seven Shell, Seven
Server and future native services consume:

- unified machine state through `seven state --json`;
- prioritized decisions through `seven control --json`;
- local audit history through `seven events`;
- product health through `seven insights`;
- phase safety through `seven phase-gate --json`;
- future daemon orchestration through `seven-daemon`.

## SevenBus

SevenBus starts as a strict JSON event envelope written to the local user state
journal. The first implementation is intentionally simple and inspectable:

```text
~/.local/state/sevenos/events.jsonl
```

Later, the same envelope can move to a typed local IPC transport backed by
`seven-daemon`. This keeps the migration safe: UI code can use the same event
shape before and after the daemon becomes active.

## C Boundary

SevenOS uses C only where it belongs: the physical and nervous system layer.

```text
C = drivers, hardware communication, ultra-low-level IPC probes, power/input/audio adjacency
Rust = SevenDaemon, policy, orchestration, long-running safe runtime
TypeScript/GTK/Tauri = shell and user-facing control surfaces
```

The first C component is:

```bash
sevenbus-probe --json
```

It checks local Unix socket capabilities for future SevenBus IPC work. It does
not replace SevenDaemon and does not own product logic.

## Daemon Path

`seven-core/daemon` is a Rust scaffold for the future `seven-daemon`.

The first responsibility of the daemon is not to become a giant background
process. Its job is narrower:

1. supervise SevenOS event streams;
2. expose fast local status to shell surfaces;
3. coordinate profile, session, security and server events;
4. keep unsafe operations behind policy and confirmation.

The daemon is now launchable through:

```bash
seven-daemon --json
seven-daemon snapshot --json
seven-daemon health --json
seven-daemon cyberspace --json
seven-daemon cyberspace-plan --json
seven-daemon events --json
seven-daemon summary --json
seven-daemon compact-bus --keep 5000 --json
seven-daemon actions --json
seven-daemon surfaces --json
seven-daemon installer-flow --json
seven-daemon update --json
seven-daemon update-plan --json
seven-daemon doctor-task --json
seven-daemon experience --json
seven-daemon profiles-status --json
seven-daemon profile-gaps --json
seven-daemon profile-plan --json
seven-daemon profile-health --json
seven-daemon packages-strategy --json
seven-daemon packages-catalog --json
seven-daemon packages-footprint --json
seven-daemon action-plan core.health --json
seven-daemon action-run core.health --json
seven-daemon emit --source core --type event --message "SevenBus event"
seven-daemon serve
seven core install-service
seven core start
seven core logs
```

`seven events log` now prefers the Rust event writer when `seven-daemon` is
available, then falls back to the older Bash/Python writer. This is the intended
migration style for SevenOS: preserve working commands while moving the system
logic into a system language.

`seven core snapshot --json` exposes the daemon view of SevenBus: valid event
count, invalid event count, source counts, state counts, writer counts and the
last valid event. The reader uses `serde_json`, which keeps Core state
inspection out of fragile shell text parsing.

`seven events --json` and `seven events summary-json` now prefer the same Rust
reader through `seven-daemon events` and `seven-daemon summary`, with the Bash
reader kept as a compatibility fallback.

`seven core health --json` is a daemon-owned runtime health surface. It reads
local `/proc` data, session variables, event integrity and SevenOS state paths
from Rust, giving Hub and Shell a fast OS-level signal without walking the
whole Bash stack.

`seven core compact-bus --keep 5000 --json` is the local SevenBus retention
command. It archives the current JSONL journal and rewrites the active journal
with the most recent valid events. This keeps the current JSONL transport usable
until typed local IPC replaces it.

`seven-daemon actions --json` is the first native action contract. It exposes
stable SevenOS intentions such as health, profile status, installer readiness,
software planning, Server/Deploy planning and Windows compatibility planning.
The goal is to let Settings, Hub, Doctor and Store ask the daemon what can be
done, instead of each surface knowing a different script list.

`seven-daemon surfaces --json` is the fast native surface contract. It checks
that the essential SevenOS graphical entrypoints exist for Settings, Doctor,
Store, Installer, Files, Reader, Terminal, Widgets, Notes, Hub, Home and
Actions. The deeper `seven surfaces doctor` gate still owns legacy-screen,
profile-awareness and visual consistency checks, but the daemon now gives UI
surfaces a cheap runtime signal.

`seven-daemon action-plan <id> --json` returns the policy and command metadata
for one action. `seven-daemon action-run <id> --json` only executes read-only
actions for now. State-changing actions are visible but blocked behind
`confirmation-required` until the policy service owns authorization and
rollback. This is the migration rule: Rust owns contracts and safe state first;
scripts remain adapters until each workflow has a native service.

`seven-daemon cyberspace --json` and `seven-daemon cyberspace-plan --json`
turn Shield CyberSpace into a daemon-readable contract. The Bash surface still
handles human commands and Hyprland dispatch, while Rust owns the context map,
scope state and remediation plan that Hub, Server and future `seven-cyberd`
will consume.

`seven-daemon profiles-status --json`, `seven-daemon profile-gaps --json`,
`seven-daemon profile-plan --json` and `seven-daemon profile-health --json`
are the native Mini OS profile contracts. They keep the seven identities
visible to Settings, Hub, Store and state snapshots without shelling through
the older profile scripts for every refresh. The scripts still exist as human
commands and compatibility adapters, but runtime surfaces should prefer these
daemon contracts.

`seven-waybar-profile` follows this rule too: the desktop profile indicator
reads `seven-daemon profiles-status --json` first and only falls back to
`seven profile status --json` when the daemon is unavailable. Fast shell
surfaces should use this pattern so the desktop feels like a running system,
not a collection of commands being relaunched on every paint.

Seven Settings follows the same native-first path for software overview:
the graphical "software status" panel reads `seven-daemon packages --json`
first and only falls back to `sevenpkg status --json` when Core is unavailable.
Package installation remains a SevenPkg workflow; package readiness and UI
summary state are daemon-owned.

The same split now covers the SevenPkg public model. `seven-daemon
packages-strategy --json`, `seven-daemon packages-catalog --json` and
`seven-daemon packages-footprint --json` expose the package strategy, app
catalog and rootfs footprint as native state contracts. `sevenpkg` remains the
transaction engine for installs, removals, helpers and profile package
maintenance; Seven Core owns fast read models for UI and release gates.

The current service is a user service:

```text
systemd/user/seven-daemon.service
```

It is also pulled into `sevenos-session.target`, so the SevenOS desktop session
can grow toward a coordinated runtime instead of independent autostart scripts.

## Current Commands

```bash
seven core
seven core status --json
seven core plan --json
seven core doctor
seven core bus --json
seven core snapshot --json
seven core health --json
seven core compact-bus --keep 5000 --json
seven core actions --json
seven core surfaces --json
seven core installer-flow --json
seven core update --json
seven core update-plan --json
seven core doctor-task --json
seven core experience --json
seven core profiles-status --json
seven core profile-gaps --json
seven core profile-plan --json
seven core profile-health --json
seven core packages-strategy --json
seven core packages-catalog --json
seven core packages-footprint --json
seven core action-plan core.health --json
seven core action-run core.health --json
seven-daemon actions --json
seven-daemon action-plan core.health --json
seven core install-service
seven core start
```

These commands are part of the B2-B3 transition. They make SevenOS more
autonomous without hiding Linux from advanced users.
