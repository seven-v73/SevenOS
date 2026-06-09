# SevenOS Stack Strategy

SevenOS must not become a pile of unrelated technologies. The stack grows by
phase, with one major new runtime introduced only when the previous layer is
testable through JSON contracts, checks and Seven Hub.

This strategy supports `docs/SYSTEM_EXPERIENCE_LAYER.md` and
`docs/HYBRID_OS_ARCHITECTURE.md`, the main references for SevenOS as a system
experience layer and user-space hybrid OS architecture above Linux and Arch.
The stable product target is defined in `docs/OS_STABLE_STACK.md`. The
design-first experience stack is defined in `docs/DESIGN_FIRST_STACK.md`.
The language boundaries for building SevenOS are defined in
`docs/SYSTEM_LANGUAGE_STACK.md`.

## Principle

```text
Contracts first. Native surfaces second. New runtimes only when they replace
real friction.
```

For the OS-stable direction, the sharper rule is:

```text
Scripts may bootstrap SevenOS.
Scripts must not be the long-term operating system.
```

## Phase Order

| Phase | Focus | Stack |
| --- | --- | --- |
| B2-B3 | Freeze JSON contracts and separate adapters from OS ownership | Bash/Python as compatibility, GTK4/libadwaita, Rust daemon scaffold |
| B3 | Seven Shell and long-running system core | Rust, systemd services, SevenBus, AGS + TypeScript shell iteration, small C probes |
| Phase 4 | Product apps, AI and package APIs | Rust services, Python AI, GTK/libadwaita or Tauri app surfaces, SQLite |
| Phase 5 | Store, Cloud, Sync and packaged releases | pacman/libalpm integration, signed packages, Seven Cloud services, typed APIs |

## Current Rule

SevenOS keeps the existing Bash/Python scripts while they are useful as
bootstrap, compatibility and release-check adapters. The work now is not a
blind rewrite; it is to move stateful OS behavior behind stable JSON contracts,
Seven Core services and package boundaries so native interfaces can control the
system without parsing terminal text.

Anything long-running, stateful, security-sensitive or profile-owning should
move out of scripts and into Seven Core, SevenBus, a supervised service or a
native product surface.

## OS-Stable Target

The target stack is:

| Layer | Stable direction |
| --- | --- |
| Core runtime | Rust, `seven-daemon`, systemd services, SQLite, typed state contracts |
| IPC/events | SevenBus through Rust, dbus or local Unix sockets, JSON/Protobuf schemas |
| CLI | `seven` and `sevenpkg` as clients of stable runtime contracts |
| Shell | AGS/TypeScript for shell iteration, native Linux integration for final control |
| Apps | GTK/libadwaita or Tauri where useful, all consuming Seven Platform APIs |
| AI | Python for models and analysis, behind explicit SevenAI service contracts |
| Security | Polkit, AppArmor first, sandboxing, audited privileged helpers |
| Packaging | pacman packages, archiso, signed artifacts, update/rollback route |
| Tests | contract tests, build checks, VM/live ISO smoke and public quality gates |

Design-first work follows the same direction: define the user intent, backend
contract, states, errors, progress and recovery before building the visible
surface. SevenOS UI should consume Seven Core and SevenBus state instead of
launching scripts and waiting for terminal output.

## Next Technical Move

The next major UI move is:

```text
Seven Shell with AGS + TypeScript
```

Seven Shell should replace the most visible Rofi surfaces gradually:

- Quick Settings
- Notification Center
- Dock / pinned apps
- Launcher / overview
- profile-aware widgets

Rofi remains a fallback, not the main OS control plane.

## Seven Core Contract

Use:

```bash
seven core
seven core status --json
seven core plan --json
seven core bus --json
seven core doctor
```

The JSON contracts are:

- `sevenos.core.v1`
- `sevenos.core-plan.v1`
- `sevenos.bus.v1`

Seven Core is the B2-B3 bridge between the existing Bash/Python contracts and
the future Rust daemon. It makes the system experience layer visible today
without forcing a rewrite before the Hub, Shell and Server can consume it.

## Rust Boundary

Rust enters after the shell contracts are stable, as:

- `seven-daemon`
- event and IPC broker
- session/profile orchestrator
- performance and trust monitor

Rust should not be introduced as a rewrite impulse. It enters where SevenOS
needs a reliable long-running process.

## C Boundary

C is allowed only for the physical and nervous layer of SevenOS:

- drivers and hardware-adjacent communication;
- ultra-low-level IPC probes for SevenBus;
- future power, input, audio and security hooks;
- tiny audited binaries where ABI and startup cost matter.

C must not become the Hub, the Shell, the profile engine or the ecosystem
logic. The current C foothold is `sevenbus-probe`, a local IPC capability probe
used to prepare SevenBus without moving product logic into C.

## Python Boundary

Python is the AI and analysis layer:

- SevenAI
- error explanation
- system recommendations
- local model integration
- OCR / vision experiments

Python should not own boot-critical session control or security enforcement.

## App Boundary

Flutter, Qt and GTK are for product applications:

- Seven Store
- Seven Cloud
- Seven Notes
- Seven Settings
- Seven Media

Do not build multiple versions of the same app in different stacks at the same
time. Pick one per product.

## Machine Contract

Use:

```bash
seven stack
seven stack --json
seven stack doctor
```

The JSON contract is `sevenos.stack.v1`. Seven Hub and Seven Server should use
it to show which stacks are active, next, planned or blocked.

## Seven Shell Contract

Use:

```bash
seven shell
seven shell status --json
seven shell plan --json
seven shell preview
seven shell doctor
```

The JSON contracts are:

- `sevenos.shell.v1`
- `sevenos.shell-plan.v1`

These contracts let Seven Hub and Seven Server prepare the AGS shell without
removing the stable Waybar/Rofi/GTK fallback.
