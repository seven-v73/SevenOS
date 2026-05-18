# SevenOS Ecosystem Architecture

SevenOS is evolving from a Linux distribution layer into an all-in-one operating
ecosystem: desktop, development workstation, security lab, Windows bridge,
deployment node, personal cloud and intelligent automation surface.

For the long-term system direction, read
`docs/SYSTEM_EXPERIENCE_LAYER.md`. It is the reference for Seven Core,
SevenBus, Seven Shell, Seven Hub, hardware intelligence and AI orchestration.

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

This is the SevenOS ecosystem lesson SevenOS should borrow: not closed control, but
integration, continuity and predictable defaults.

## Ecosystem Modules

| Module | Purpose | Phase | Status |
| --- | --- | --- | --- |
| SevenAI | local system assistant and automation brain | 4 | preview |
| SevenCloud | personal backup, config sync and restore | 5 | preview |
| SevenStore | marketplace for apps, profiles, themes and modules | 5 | preview |
| SevenBox | rootless containers and sandboxed app runtime | 4 | preview |
| SevenShield | hardening, scans, scope and cybersecurity workspaces | 2-4 | preview |
| Adaptive UI | profile-aware desktop behavior and visual modes | 4 | preview |
| Windows Integration | guided VM, Wine, Bottles and future app integration | 2-4 | preview |
| SevenDoctor | auto-repair and guided remediation through Control Plane | 3-4 | preview |
| Seven Profiles | Baobab, Forge, Shield, Studio, Windows, Horizon and Griot | 2-4 | active |
| SevenIdentity | user identity, cultural accents, permissions and environment | 5 | preview |
| SevenCluster | multi-machine local cluster and resource sharing | 5 | preview |
| SevenFlow | no-code automation rules for system workflows | 5 | preview |

## All-In-One Process Map

Each ecosystem process must connect UI, command, data and safety. If a process
cannot be reached from Seven Hub or `seven`, it is not productized yet.

| Process | Layer | Status | Flow | Command |
| --- | --- | --- | --- | --- |
| First Run | experience | active | welcome, profile choice, theme, readiness, Hub | `seven welcome` |
| Daily Control | desktop | active | Waybar, Quick Settings, Seven Hub, actions registry | `seven hub` |
| Install Apps | software | preview | SevenStore, SevenPkg, Flatpak, profile apps | `seven store` |
| Work Profiles | productivity | active | profile context, workspace, app readiness, next actions | `seven profile current` |
| Windows Apps | compatibility | preview | Windows profile, Bottles/Wine, KVM VM | `seven windows guide` |
| Security Trust | security | preview | Shield audit, hardening, sandbox, Cyber Lab | `seven shield audit` |
| Create & Media | creation | preview | Studio profile, creative apps, media workspace | `seven profile guide studio` |
| Develop & Deploy | deployment | preview | Forge/Horizon, stack detection, local API, deploy plan | `seven deploy plan .` |
| Local Guidance | intelligence | preview | state, insights, action registry, next best commands | `seven ai plan` |
| Personal Cloud | cloud | preview | local-first backup plan and restore contract | `seven cloud` |
| Marketplace | store | preview | modules, apps, actions and guided install | `seven store` |
| Automation | automation | preview | recipes, confirmed actions, logs | `seven flow` |
| Identity | identity | preview | user context, regional accents, permissions | `seven identity` |
| Private Mesh | cluster | preview | explicit nodes, local/private compute policy | `seven cluster` |

## Ecosystem Contracts

The ecosystem must be readable by both humans and UIs:

```bash
seven ecosystem
seven ecosystem summary
seven ecosystem processes
seven ecosystem maturity
seven ecosystem --json
seven state --json
seven welcome status --json
seven welcome plan --json
seven session status --json
seven identity --json
seven identity packs --json
seven identity current --json
seven actions --json
seven stack --json
seven shell status --json
seven shell plan --json
seven adaptive --json
seven profile gaps --json
seven profile plan --json
seven windows plan --json
seven experience --json
seven control --json
seven events --json
seven insights --json
seven phase-gate --json
seven ai focus
seven shield status --json
seven shield plan --json
seven server status --json
seven server plan --json
seven installer plan --json
seven installer graphical --json
seven hub status --json
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

`seven identity --json` is the Beyond the Desktop contract. It turns fluidity,
transparency, intelligent minimalism, depth, contextuality, visible security,
profile roles and accent packs into data that Seven Hub can show instead of
leaving identity as only wallpaper or README language.

`seven identity packs --json` is the regional accent pack contract. It keeps
future Pan-African, West, North, Central, East, Southern and Diaspora packs
structured before they become installable theme modules.

`seven identity current --json` is the active identity preference. It lets
Seven Hub and future installers know which accent pack the user selected.

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

`seven ecosystem maturity` is the product-readiness map. It scores each module
by visible state, file presence, executable or documented surface, machine
contract and process links. This prevents SevenOS from hiding weak previews
behind a good global score.

`seven hub status --json` is the Hub product-surface contract. It checks the
native Hub, fallback launcher, Control Center, desktop entries, Settings route,
action registry and dashboard data contracts so SevenAI can tell whether the
Hub is truly ready as the default graphical control surface.

`seven events --json` is the local event journal. It gives SevenOS a traceable
memory of previews, decisions and future executed actions.

`seven insights --json` is the product diagnosis layer. It turns raw state,
profiles, trust posture and Control Plane recommendations into a concise list
of blockers with severity, impact and next command.

`seven phase-gate --json` is the higher-phase decision contract. It checks
whether B2 can move toward B3 by looking at readiness, experience, Control
Plane, Shield, Seven Server, installer, Windows Mode, profiles, software and
the active SevenOS identity pack.

`seven stack --json` is the stack discipline contract. It records the chosen
order: JSON contracts and native Hub first, then AGS/TypeScript shell, then
Rust daemon, then AI and product apps. This keeps SevenOS from adopting every
interesting runtime at once.

`seven shell status --json` and `seven shell plan --json` are the B3 shell
contracts. They describe how AGS/TypeScript will replace Quick Settings,
Notifications, Launcher and Dock surfaces gradually while keeping Waybar/Rofi
fallbacks active.

`seven adaptive --json` is the profile-aware UI contract. It checks whether the
active profile, shell state, Waybar profile indicator, Hub actions and semantic
context engine are connected enough for SevenOS to feel mode-aware instead of
only themed.

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

`seven installer graphical --json` is the public graphical installer route. It
checks the Calamares module profile, SevenOS branding, live ISO desktop launcher
and `seven-installer` fallback, while keeping the Calamares runtime as an
explicit downstream/package availability gap.

`sevenpkg plan --json` is the software readiness plan. It combines SevenOS
meta-packages, pacman/AUR availability, Flatpak/Flathub and default app gaps so
Seven Hub can guide application setup without exposing package-manager details.

## Native Hub Integration

Seven Hub Native should expose the ecosystem as a visual product map:

- Dashboard summary: active modules, preview modules and process count.
- Ecosystem page: module maturity, product level, purpose and phase.
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
- Beyond the Desktop identity layer

## Phase Discipline

### Phase 4: Intelligent OS Preview

The next innovation phase should focus on:

- `seven ecosystem` visibility
- SevenDoctor repair suggestions
- SevenBox rootless container UX
- Adaptive UI profile status
- SevenAI Local interface contract, without hardcoding one provider

SevenAI Local is intentionally provider-neutral in this phase. `seven ai`,
`seven ai plan`, `seven ai focus` and `seven ai --json` read SevenOS state,
insights, shell, installer, ecosystem maturity, packages and actions, then
produce a concise plan. It gives the OS a visible assistant surface now while
leaving room for model-backed providers later.

SevenAI Agent adds the first executable OS-agent foundation:

- `seven ai open settings` parses natural language into `OPEN_APP` and opens
  the resolved app through the SevenOS app registry.
- `seven ai stop blender` parses ordinary language into `KILL_PROCESS`,
  resolves a safe process name from the app registry and previews the stop
  action before `--apply`.
- `seven ai "mon wifi ne marche pas"` maps to a Wi-Fi repair intent, but only
  previews system changes until `--apply` is explicit.
- `seven ai apps --json` exposes the app registry used for launch decisions.
- `seven ai context --json` exposes local process and Hyprland context.
- `seven ai memory --json` exposes a local-only event log for short-term
  behavior learning.
- `seven ai "mets le thème light"` and `seven ai "workspace 2"` expose natural
  desktop control for SevenOS theme and Hyprland workspaces.
- `seven ai shortcuts`, `seven ai knowledge` and `seven ai workflow` let the
  assistant explain SevenOS, keyboard-first workflows and workspace discipline
  without needing the web.
- `seven ai llm --json` exposes the complete provider-neutral LLM contract.
- `seven ai web "query" --json --web` can perform an explicit web lookup; web
  access stays disabled by default and never sends system context implicitly.
- `seven ai provider "question" --json` runs the active SevenOS local provider:
  deterministic, no account, no token cost, no external data flow.
- `seven ai diagnose system --json` inspects load, memory, disk, top processes,
  failed units and NetworkManager state.
- `seven ai playbook wifi_repair --json` exposes confirmed auto-healing steps
  before any repair action runs.
- `seven ai research "query" --json --web` uses explicit web access and stores
  research results in the local SQLite cache.

By default the agent answers as a normal user-facing assistant, not as raw
JSON. Machine-readable output stays available through `--json` for Hub,
Spotlight and automation surfaces. SevenAI follows the configured SevenOS
language: English systems receive English guidance, French systems receive
French guidance, and `SEVENAI_LANG=fr|en` can override that for tests.

The safety contract is simple: app/UI actions can run directly, system actions
are previewed unless `--apply` is present, privileged package/root actions must
remain explicit and explain their command before execution, and the provider
layer must stay local-only unless a future user-controlled adapter is explicitly
installed by the user.

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
seven ecosystem maturity
seven ecosystem --json
seven insights
seven ecosystem roadmap
seven ecosystem doctor
seven repair
seven doctor fix
seven phase-gate
seven readiness
```

Specialized preview commands:

```bash
seven ai plan
seven ai focus
seven ai open settings
seven ai "mon wifi ne marche pas"
seven ai apps --json
seven ai context --json
seven ai shortcuts
seven ai knowledge
seven ai llm --json
seven ai provider "mon wifi ne marche pas" --json
seven ai diagnose system --json
seven ai playbook wifi_repair --json
seven ai research "Hyprland" --json
seven adaptive plan
seven cloud plan
seven store apps
seven box profiles
seven flow recipes
seven cluster nodes
seven identity status
```
