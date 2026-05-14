# Seven Hub Native

Seven Hub Native is the target Control Center for SevenOS.

The current Tauri app remains useful as a productization prototype, but SevenOS
should not depend on browser-like UI for its core operating-system surfaces.
The native target is GTK4 + libadwaita, backed by the same `seven` JSON
contracts already used by the prototype.

## Product Role

Seven Hub Native should feel like a system application:

- native Linux windowing and accessibility
- GTK file, notification and portal integration
- profile-aware interface states
- no terminal-first flows for normal users
- clear confirmation before system-changing actions
- consistent SevenOS identity without becoming a decorative theme

## Data Contracts

The native UI must consume these commands as stable APIs:

```bash
seven status --json
seven state --json
seven actions --json
seven profile status --json
seven profile current --json
seven profile apps --json
seven windows status --json
seven readiness --json
sevenpkg status --json
```

Human-facing command output is not an API. If a view needs new data, add a JSON
contract to `seven`, `sevenpkg`, or a future local `seven-server` endpoint.

## Modules

| Module | Purpose | First data source |
| --- | --- | --- |
| Dashboard | readiness, services, urgent repairs | `seven readiness --json` |
| Profiles | active profile, workspaces, install/activate | `seven profile status --json` |
| Actions | safe and state-changing OS actions | `seven actions --json` |
| Ecosystem | modules, maturity and all-in-one user flows | `seven ecosystem --json` |
| Apps | packages, metapackages, Flatpak bridge | `sevenpkg status --json` |
| Security | Shield, firewall, sandbox, Cyber Lab | `seven status --json` |
| Windows | Wine, Bottles, KVM, VM state | `seven windows status --json` |
| System | theme, session, updates, logs | `seven status --json` |
| Files | workspace shortcuts and file manager actions | `seven profile current --json` |

## Stack Decision

Preferred stack:

```text
GTK4 + libadwaita + Rust or Python/GObject
```

Rust is preferred for long-term system reliability. Python/GObject is acceptable
for early native prototypes if iteration speed matters.

Avoid Electron for core SevenOS surfaces. Web UI may still be used for local
diagnostics, documentation, marketplace previews or developer dashboards.

## Migration Path

1. Keep Tauri as the visible prototype.
2. Harden JSON contracts in `seven` and `sevenpkg`.
3. Build the native Dashboard, Profiles, Actions and Ecosystem views first.
   `bin/seven-hub-native` now starts this path with live state from
   `seven readiness --json`, `seven profile status --json` and
   `seven actions --json`, plus `seven ecosystem --json`.
4. Add Security, Apps and Windows-specific pages.
5. Keep Tauri as a prototype while `seven-hub` defaults to the native Hub
   whenever GTK/libadwaita is available.

The goal is not to throw away the current Hub. The goal is to make the frontend
replaceable because the real system state lives in SevenOS itself.

## Current Prototype

Run:

```bash
seven hub-native
seven hub-native status
seven-hub
```

The prototype is intentionally focused: Dashboard, Profiles, Actions and
Ecosystem first, because these define how SevenOS becomes an adaptive OS instead
of a static Arch theme.

As modules grow, prefer `seven state --json` when a view needs a full snapshot
instead of calling multiple commands individually.
