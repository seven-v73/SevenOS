# SevenOS OS-Stable Stack

This document defines the target development stack for SevenOS as a stable
operating system product, not as a collection of scripts. The design-first
experience stack is defined in `docs/DESIGN_FIRST_STACK.md`. The system
language and implementation boundaries are defined in
`docs/SYSTEM_LANGUAGE_STACK.md`.

The rule is:

```text
Scripts may bootstrap SevenOS.
Scripts must not be the long-term operating system.
```

SevenOS should become a packaged, service-oriented, typed and testable system
experience layer above Linux.

## Product Goal

SevenOS must feel fluid and autonomous because its core behavior is owned by
stable runtime components:

- supervised services
- typed local APIs
- native OS surfaces
- packaged components
- declarative state
- automated validation
- clear compatibility adapters

The visible experience must be design-first: every workflow starts from user
intent, exposes predictable states, streams progress, gives recovery paths and
uses shared SevenOS design tokens/components.

The user should interact with SevenOS as one coherent OS. They should not feel
that they are running a folder of Bash scripts.

## Target Stack

| Layer | Stable Stack | Role |
| --- | --- | --- |
| Linux foundation | Linux, systemd, udev, dbus, PipeWire, NetworkManager, Wayland portals | hardware, services, devices, audio, network and desktop primitives |
| Distribution base | Arch, pacman, libalpm, Flatpak, archiso | base packages, ISO, app delivery and host compatibility |
| Seven Core runtime | Rust, systemd user/system services, SQLite, JSON/Protobuf contracts | state, sessions, profiles, health, events and orchestration |
| SevenBus and IPC | Rust, dbus or local Unix sockets, typed event schemas | local actions, event stream, permissions and state updates |
| Seven Platform API | Rust services with stable JSON first, gRPC/Protobuf when needed | APIs consumed by Hub, Shell, Store, Settings and AI |
| Seven Shell | AGS/TypeScript for shell iteration, native GTK/libadwaita where system control requires it | panel, dock, launcher, quick settings, notifications and profile UI |
| Seven Applications | GTK/libadwaita, Tauri only as a transitional app shell, TypeScript for app UI where useful | Hub, Store, Files, Settings, Notes and other product surfaces |
| SevenAI | Python for AI integration, Rust boundary for local service contracts | assistant, analysis, OCR, recommendations and careful automation |
| Security | AppArmor first, bubblewrap/firejail, Polkit, systemd sandboxing, future SELinux track | permissions, containment, privileged prompts and auditability |
| Packaging | pacman packages, SevenOS component manifests, signed release artifacts | install, update, rollback and reproducible releases |
| Validation | shellcheck, py_compile, cargo test/check, npm typecheck/build, integration JSON contract tests, VM/ISO smoke | release confidence and regression detection |

## System Language Rule

SevenOS uses one system language made of contracts, states, commands and
product vocabulary. Implementation languages are chosen by boundary:

- Rust owns runtime state and services.
- TypeScript owns shell/app UI iteration.
- Python owns AI and analysis.
- Bash owns bootstrap and compatibility only.
- JSON/SQLite own machine-readable state.
- Seven Design Engine owns visual and interaction tokens.

## Design-First Runtime Rule

Modern SevenOS surfaces should be built as:

```text
Intent
  -> stable contract
  -> backend job/service
  -> cached state and SevenBus events
  -> reusable component
  -> native SevenOS surface
```

This prevents the UI from becoming a launcher for scripts. The backend owns
state and progress; the frontend owns clarity, interaction and detail.

## What Scripts Are Allowed To Do

Scripts are still useful, but only in narrow roles:

- bootstrap a development machine
- adapt existing Linux tools during migration
- provide compatibility entrypoints for old commands
- run release checks
- call the stable daemon/API layer
- perform one-shot packaging or ISO build tasks

Scripts must not permanently own:

- session state
- profile lifecycle
- permission decisions
- package policy
- user identity
- service health
- event storage
- shell behavior
- security enforcement

When a script starts carrying state or policy, it becomes a candidate for
migration into Seven Core, SevenBus, a packaged helper or a native app.

## Stable Component Boundaries

SevenOS should be split into components that can later become packages:

| Component | Owns |
| --- | --- |
| `sevenos-core` | `seven-daemon`, SevenBus, state snapshots, events, health and profile runtime |
| `sevenos-cli` | `seven`, `sevenpkg`, compatibility commands and user-facing terminal contracts |
| `sevenos-shell` | panel, dock, quick settings, notifications, launcher and widgets |
| `sevenos-hub` | control center, repair, settings bridge and profile management |
| `sevenos-apps` | Store, Files, Notes, Reader and product applications |
| `sevenos-profiles` | Equinox, Forge, Shield, Studio, Pulse, Baobab and Atlas profile contracts |
| `sevenos-identity` | design tokens, language packs, symbols, themes and onboarding language |
| `sevenos-installer` | archiso profile, Calamares/Archinstall route and live installer state |
| `sevenos-security` | Shield contracts, hardening, sandbox policy and trust state |
| `sevenos-ai` | local assistant runtime, model adapters and knowledge contracts |

The current repository may remain monorepo-style, but the architecture should
respect these future package boundaries.

## Runtime Ownership

Long-running runtime behavior belongs to services, not scripts.

```text
Seven Hub / Shell / CLI
  -> Seven Platform API
  -> SevenBus
  -> seven-daemon and domain services
  -> systemd, pacman, Flatpak, Hyprland, NetworkManager, libvirt
```

`seven` remains the human command entrypoint, but the command should become a
client of the stable runtime instead of the runtime itself.

## Data And State

SevenOS state should use structured storage:

- SQLite for local durable state
- JSON schemas for simple public contracts
- Protobuf or another typed schema when service boundaries need stronger typing
- JSONL only for append-only event logs
- config files for declarative defaults

Avoid hidden state encoded in shell output, temporary text files or terminal
formatting.

## Native UI Direction

SevenOS UI should be product surfaces, not script launchers.

Rules:

- Hub, Settings, Store, Files and Shell should consume stable APIs.
- Human text is for users; JSON is for machines.
- Rofi and terminal menus are fallbacks, not the final control surface.
- Tauri is acceptable for fast product iteration, but core OS control should
  move toward native Linux integration and supervised services.
- Shell surfaces must survive missing optional services with clear fallback
  states.

## Security And Privilege

SevenOS needs predictable privilege boundaries:

- normal actions run as the user
- privileged actions go through Polkit or a small audited helper
- every destructive or security-sensitive action has preview and confirmation
- security decisions are logged
- services use systemd hardening where practical
- profiles do not leak heavy or risky services into each other

No frontend should call `sudo` directly. No AI layer should bypass confirmation
for system-changing actions.

## Packaging And Release Direction

The stable OS path is:

```text
repository
  -> component manifests
  -> pacman packages / archiso image
  -> signed release artifacts
  -> SevenOS update and rollback route
```

`/opt/SevenOS` can remain a transition path, but public SevenOS should move
toward installable packages and a reproducible ISO.

Release readiness requires:

- clean source tree
- reproducible package or ISO build
- contract tests passing
- VM/live ISO smoke passing
- rollback path verified
- installer route verified
- public quality gate green

## Migration Order

SevenOS should migrate away from scripts in this order:

1. Keep existing commands stable for users.
2. Freeze JSON contracts for `state`, `actions`, `profiles`, `health`,
   `installer`, `update`, `shell` and `quality`.
3. Move event writing, health and state snapshots into `seven-daemon`.
4. Move session/profile lifecycle into Seven Core.
5. Move package decisions into a package service/API over pacman, Flatpak and
   future sources.
6. Move shell behavior into Seven Shell services and native surfaces.
7. Package components and make `/opt/SevenOS` a compatibility/development path.
8. Require release gates before public claims.

## Development Rules

New SevenOS development should follow these rules:

- add a script only when bootstrapping, adapting or testing
- add a service when behavior is long-running or stateful
- add a schema when another component reads the output
- add a package boundary when a feature could ship independently
- add a native UI contract before building a visible OS surface
- add a test gate before calling a subsystem stable

This keeps SevenOS fluid because the user sees one system, and autonomous
because the system owns its state through stable components instead of fragile
script chains.
