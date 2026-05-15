# SevenOS Ecosystem Architecture

SevenOS is evolving from a Linux distribution layer into an all-in-one operating
ecosystem: desktop, development workstation, security lab, Windows bridge,
deployment node, personal cloud and intelligent automation surface.

The rule is simple:

> A module may be visionary, but the CLI must stay honest about its maturity.

## Product Model

SevenOS should behave like a unified product ecosystem:

```text
Identity -> Session -> Hub -> Profiles -> Apps -> Services -> Backup/Sync
```

The user should not feel they are assembling Arch components by hand. The OS
should offer one coherent path:

- one identity and session
- one control center
- one package/app surface
- one profile system
- one Windows compatibility path
- one security posture
- one deployment/backend layer
- one future cloud/store/automation layer

This is the Apple-like lesson SevenOS should borrow: not closed control, but
integration, continuity and predictable defaults.

## Ecosystem Modules

| Module | Purpose | Phase | Status |
| --- | --- | --- | --- |
| SevenAI | native system assistant and automation brain | 4 | planned |
| SevenCloud | personal backup, config sync and restore | 5 | planned |
| SevenStore | marketplace for apps, profiles, themes and modules | 5 | planned |
| SevenBox | rootless containers and sandboxed app runtime | 4 | preview |
| SevenShield Pro | advanced protection, scans and intrusion signals | 4 | planned |
| Adaptive UI | profile-aware desktop behavior and visual modes | 4 | preview |
| Windows Integration | guided VM, Wine, Bottles and future app integration | 2-4 | preview |
| SevenDoctor | auto-repair and guided remediation | 3-4 | preview |
| Advanced Profiles | Learn, Enterprise, Gaming, Cloud, AI Lab | 4 | planned |
| SevenIdentity | user identity, cultural accents, permissions and environment | 5 | planned |
| SevenCluster | multi-machine local cluster and resource sharing | 5 | planned |
| SevenFlow | no-code automation rules for system workflows | 5 | planned |

## All-In-One Process Map

Each ecosystem process must connect UI, command, data and safety. If a process
cannot be reached from Seven Hub or `seven`, it is not productized yet.

| Process | Layer | Status | Flow | Command |
| --- | --- | --- | --- | --- |
| First Run | experience | active | welcome, profile choice, theme, readiness, Hub | `seven welcome` |
| Daily Control | desktop | active | Waybar, Quick Settings, Seven Hub, actions registry | `seven hub` |
| Install Apps | software | preview | SevenPkg, Flatpak, profile apps, future SevenStore | `sevenpkg status` |
| Work Profiles | productivity | active | profile context, workspace, app readiness, next actions | `seven profile current` |
| Windows Apps | compatibility | preview | Windows profile, Bottles/Wine, KVM VM | `seven windows guide` |
| Security Trust | security | preview | Shield audit, hardening, sandbox, Cyber Lab | `seven shield audit` |
| Create & Media | creation | preview | Studio profile, creative apps, media workspace | `seven profile guide studio` |
| Develop & Deploy | deployment | preview | Forge/Horizon, stack detection, local API, deploy plan | `seven deploy plan .` |
| Personal Cloud | cloud | planned | encrypted backup, restore, machine sync | `seven ecosystem roadmap` |
| Marketplace | store | planned | trust policy, apps, themes, modules | `seven ecosystem roadmap` |
| Automation | automation | planned | triggers, confirmed actions, logs | `seven ecosystem roadmap` |
| Identity | identity | planned | user context, regional accents, permissions | `seven ecosystem roadmap` |

## Ecosystem Contracts

The ecosystem must be readable by both humans and UIs:

```bash
seven ecosystem
seven ecosystem summary
seven ecosystem processes
seven ecosystem --json
seven state --json
seven welcome status --json
seven welcome plan --json
seven session status --json
seven identity --json
seven identity packs --json
seven actions --json
seven profile gaps --json
seven profile plan --json
seven windows plan --json
seven experience --json
seven control --json
seven events --json
seven insights --json
seven shield status --json
seven shield plan --json
seven server status --json
seven server plan --json
seven installer plan --json
sevenpkg plan --json
```

`seven state --json` is the unified snapshot. It should contain welcome,
welcome plan, profiles, profile gaps, Windows Mode, Windows plan, Shield,
Seven Server, Installer, Control Plane, actions, manifest and event history so
the native Hub can become a real OS control plane without scraping terminal
text.

`seven welcome status --json` and `seven welcome plan --json` are the first-run
contracts. They let Seven Hub detect missing commands, shell files, user
services and trust/compatibility blockers immediately after installation.

`seven session status --json` is the shell runtime contract. It exposes the
login session, user service files and running Waybar/notifications/wallpaper
services as data for Seven Hub and Seven Server.

`seven identity --json` is the African first contract. It turns sovereignty,
transmission, creation, protection, community, resilience, profile roles and
regional accent packs into data that Seven Hub can show instead of leaving
identity as only wallpaper or README language.

`seven identity packs --json` is the regional accent pack contract. It keeps
future Pan-African, West, North, Central, East, Southern and Diaspora packs
structured before they become installable theme modules.

`seven windows plan --json` is the Windows compatibility plan. It translates
Wine, Bottles, KVM, libvirt networking and VM creation gaps into a guided setup
sequence for Seven Hub and Windows Mode.

`seven profile gaps --json` is the work-mode completeness contract. It lists
missing packages and missing app launch surfaces for Baobab, Forge, Shield,
Studio, Windows and Horizon.

`seven profile plan --json` sorts those gaps into a prioritized completion
path, so Seven Hub and Control Plane can guide the user through real work-mode
activation instead of dumping a static package list.

`seven experience --json` is the coherence score. It exists to catch the exact
problem SevenOS must avoid: many working pieces that still feel disconnected to
a normal user.

`seven control --json` is the prioritized action plan. It merges readiness,
first-run, experience, Shield, Server and profiles into one OS decision surface
for Seven Hub and future automation.

`seven control apply` previews the next prioritized actions. It remains
non-destructive unless `--apply` is explicitly passed, so the system can guide
users without surprising them.

`seven events --json` is the local event journal. It gives SevenOS a traceable
memory of previews, decisions and future executed actions.

`seven insights --json` is the product diagnosis layer. It turns raw state,
profiles, trust posture and Control Plane recommendations into a concise list
of blockers with severity, impact and next command.

`seven shield plan --json` is the trust remediation plan. It gives Seven Hub
and Seven Server a clean list of firewall, sandbox and audit actions, ordered
by severity, so security work becomes guided and visible instead of hidden in
scripts.

`seven server plan --json` is the backend remediation plan. It makes the local
API layer actionable by listing service, rootless container, proxy and JSON
tooling gaps with commands Seven Hub can launch or preview.

`seven installer plan --json` is the distribution readiness plan. It lists the
missing pieces between SevenOS as a post-install layer and SevenOS as a bootable,
installable operating system.

`sevenpkg plan --json` is the software readiness plan. It combines SevenOS
meta-packages, pacman/AUR availability, Flatpak/Flathub and default app gaps so
Seven Hub can guide application setup without exposing package-manager details.

## Native Hub Integration

Seven Hub Native should expose the ecosystem as a visual product map:

- Dashboard summary: active modules, preview modules and process count.
- Ecosystem page: module maturity, purpose and phase.
- Process page/section: first run, daily control, apps, profiles, Windows,
  security, deployment and future cloud/store/automation flows.
- Actions: process entries should point back to `seven` commands or registered
  action IDs.
- Native Hub process rows should be action-oriented: every process needs a
  command that can be launched or inspected from the Hub.

This keeps the ecosystem fluid: the user can see where a feature belongs,
whether it is ready, and how to start it from the same control center.

## Current Foundation

Already present:

- `seven` system controller
- `sevenpkg` package and meta-package layer
- Seven Hub categorized control center
- Forge, Shield, Studio, Horizon, Griot and Baobab vocabulary
- Windows Mode helpers
- `seven-server` local API foundation
- `seven-deploy` deployment planner
- readiness and phase-gate scorecards
- African first identity layer

## Phase Discipline

### Phase 4: Intelligent OS Preview

The next innovation phase should focus on:

- `seven ecosystem` visibility
- SevenDoctor repair suggestions
- SevenBox rootless container UX
- Adaptive UI profile status
- SevenAI interface contract, without hardcoding one provider

### Phase 5: Connected Ecosystem

Later:

- SevenCloud backups and restore
- SevenStore module registry
- SevenIdentity and regional accent packs
- SevenFlow automation engine
- SevenCluster personal/private compute mesh

## Safety Rules

- AI must never run privileged commands without explicit confirmation.
- Cloud sync must be opt-in and encrypted.
- Marketplace packages must declare source, permissions and trust level.
- Container execution should default to rootless mode.
- Remote API must stay local-only until auth, TLS and audit logs exist.
- Auto-repair should explain every change before applying it.

## Commands

```bash
seven ecosystem
seven ecosystem summary
seven ecosystem processes
seven ecosystem --json
seven insights
seven ecosystem roadmap
seven ecosystem doctor
seven repair
seven doctor fix
seven phase-gate
seven readiness
```

Future commands:

```bash
seven ai "explain this error"
seven cloud backup
seven store search blender
seven box run app --sandbox
seven flow list
seven identity status
```
