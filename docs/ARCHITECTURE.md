# SevenOS Architecture

SevenOS is designed as an operating ecosystem, not a theme pack. Every module
must belong to a clear layer, expose a predictable command path, and connect to
the user experience through `seven`, `sevenpkg`, Seven Hub, or Seven Server.

## Product Problem

Linux is powerful but fragmented. SevenOS exists to make development,
cybersecurity, creation, Windows compatibility, deployment and daily desktop
work feel like one coherent environment.

The promise is:

> one African first Linux ecosystem to create, secure, develop, run, deploy and
> maintain digital work without assembling a different toolchain every day.

## System Layers

| Layer | Role | Current Modules |
| --- | --- | --- |
| System Core | entrypoints, bootstrap, status, repair and phase checks | `install.sh`, `bootstrap.sh`, `bin/seven`, `scripts/*.sh` |
| Package Layer | package manifests, meta-packages and software sources | `sevenpkg`, `scripts/packages-*.txt`, `sevenpkg/metapackages.json` |
| Service Layer | local services, deployment, VM and background session | `seven-session`, `seven-server`, `seven-deploy`, `vm/` |
| UI Layer | desktop shell, hub, files, theme and visible controls | Hyprland, Waybar, Rofi, Kitty, Mako, Seven Hub, Seven Files, Tauri prototype, native GTK target |
| Security Layer | hardening, audit, sandbox and cyber workspaces | `security/`, Shield profile, UFW, Firejail, Bubblewrap |
| Compatibility Layer | Windows apps, VM, Wine/Bottles/Lutris/KVM | `profiles/windows.sh`, `vm/windows-mode.sh`, `vm/windows-vm.sh` |
| Deployment Layer | local API, stack detection and personal cloud direction | `server/`, `docs/DEPLOYMENT.md`, Horizon profile |
| Identity Layer | product language, branding, palette and cultural coherence | `identity/`, `branding/`, `docs/VOCABULARY.md` |
| Installer Layer | ISO, live profile and future disk install flow | `archiso/`, `installer/` |

## Control Plane

SevenOS uses a single control plane:

```text
User
  -> Seven Hub / Seven Control Center / CLI
  -> seven
  -> install.sh, scripts, profiles, vm, security, server
  -> pacman, systemd, Hyprland, libvirt, rootless services
```

Rules:

- `seven` is the human entrypoint for system operations.
- `sevenpkg` handles packages and meta-packages.
- Seven Hub exposes the same actions as `seven`, not a second truth.
- Seven Hub UI implementations must consume stable SevenOS data contracts
  (`seven status --json`, `seven profile status --json`, `seven readiness --json`)
  instead of scraping human terminal output.
- Seven Server may observe and orchestrate, but remote control stays local-only
  until authentication, TLS and audit logging exist.
- `install.sh` remains the compatibility layer for direct script targets.

## Interface Strategy

SevenOS must feel like an operating system, not a browser dashboard. The UI
strategy is therefore split into prototype and native target.

| Surface | Role | State |
| --- | --- | --- |
| Rofi Hub | fast command palette and fallback launcher | Active |
| Local web Control Center | simple local dashboard for diagnostics | Active |
| Tauri Seven Hub | productization prototype, action workflow and JSON validation | Preview |
| Native Seven Hub | long-term OS Control Center using GTK4 + libadwaita | Planned |

Rules:

- Tauri is useful for fast iteration, but it is not the final OS shell model.
- Native Seven Hub should use GTK4 + libadwaita, system portals, notifications,
  file integration and accessibility primitives.
- Both Tauri and native Hub must speak the same SevenOS command/data contracts.
- UI state belongs to SevenOS (`seven`, profile manager, status JSON), not to
  the frontend implementation.
- Web technologies may remain for docs, local dashboards or marketplace
  previews, but core system control must move toward native Linux components.

Native Hub target modules:

```text
seven-hub/native
├── Dashboard  -> readiness, services, repair suggestions
├── Profiles   -> Forge, Shield, Studio, Windows, Horizon activation
├── Apps       -> sevenpkg, Flatpak, future SevenStore
├── Security   -> Shield, UFW, sandbox, Cyber Lab
├── Windows    -> Wine, Bottles, KVM, VM assistant
├── System     -> theme, session, updates, logs
└── Files      -> Seven Files integration and workspace shortcuts
```

## UX Contract

Actions must be:

- discoverable through Seven Hub or Waybar when they are daily actions
- scriptable through `seven` when they are system actions
- reversible or dry-runnable when they change the system
- visible in `seven readiness`, `seven doctor`, `seven phase-gate`, or
  `seven architecture doctor`

Examples:

```bash
seven hub
seven files
seven profile forge
seven shield audit
seven windows status
seven server status
seven deploy plan .
seven repair ux --apply
```

## Architecture Rules

1. A new capability must declare its layer.
2. A new user-facing capability must have a `seven` or Seven Hub entrypoint.
3. A new package set must live in `scripts/packages-*.txt` or
   `sevenpkg/metapackages.json`.
4. A new background feature must have status, doctor or dry-run behavior.
5. A new visual feature must be included in UX checks.
6. A new strategic module must be marked active, preview or planned.

## Maturity States

| State | Meaning |
| --- | --- |
| Active | usable as part of the normal SevenOS flow |
| Preview | implemented enough to test, not release-grade |
| Planned | documented direction, not promised as working |

## Current Architecture Snapshot

Active:

- `seven`
- `sevenpkg`
- Seven Hub command palette
- Seven Control Center dashboard
- Seven Files
- Seven session bootstrap
- desktop theme and toolkit coherence
- post-install, readiness, repair and phase-gate checks

Preview:

- Windows Mode
- Seven Hub Tauri GUI scaffold
- Seven Hub native architecture contract
- `seven-server`
- `seven-deploy`
- Archiso profile
- installer planner
- Calamares profile scaffold
- Flatpak/Bottles bridge
- cybersecurity lab presets

Planned:

- SevenAI
- SevenCloud
- SevenStore
- SevenBox full runtime
- SevenFlow
- SevenIdentity
- SevenCluster

## Quality Gate

Before a higher phase, run:

```bash
seven architecture doctor
seven ecosystem doctor
seven readiness
seven phase-gate
```
