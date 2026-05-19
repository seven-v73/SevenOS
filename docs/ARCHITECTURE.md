# SevenOS Architecture

SevenOS is designed as an operating ecosystem, not a theme pack. Every module
must belong to a clear layer, expose a predictable command path, and connect to
the user experience through `seven`, `sevenpkg`, Seven Hub, or Seven Server.

The long-term architecture references are `docs/SYSTEM_EXPERIENCE_LAYER.md`
and `docs/HYBRID_OS_ARCHITECTURE.md`. Together they define SevenOS as a
system experience layer and local user-space hybrid OS architecture above
Linux and Arch: Seven Core, SevenBus, Seven Shell, Seven Hub and future
intelligent services.

## Product Problem

Linux is powerful but fragmented. SevenOS exists to make development,
cybersecurity, creation, Windows compatibility, deployment and daily desktop
work feel like one coherent environment.

The promise is:

> one intelligent Linux ecosystem to create, secure, develop, run, deploy and
> maintain digital work without assembling a different toolchain every day.

## System Layers

| Layer | Role | Current Modules |
| --- | --- | --- |
| SevenAI Layer | local language interface, diagnostics, playbooks, confirmation and guidance | `scripts/ai.sh`, `scripts/seven_ai_agent.py`, Seven Spotlight AI intents |
| Orchestration Layer | system decisions, action priorities, profile/session policy and repair plans | `scripts/control-plane.sh`, `scripts/scheduler.sh`, `scripts/events.sh`, `seven-core/` |
| System Core | entrypoints, bootstrap, Seven Core, SevenBus, status, repair and phase checks | `install.sh`, `bootstrap.sh`, `bin/seven`, `scripts/*.sh`, `seven-core/` |
| Package Layer | package manifests, meta-packages, future package boundaries and software sources | `sevenpkg`, `scripts/packages-*.txt`, `sevenpkg/metapackages.json`, `sevenos.dotinst` |
| Service Layer | local services, deployment, VM and background session | `seven-session`, `seven-server`, `seven-deploy`, `vm/` |
| UI Layer | desktop shell, hub, files, theme and visible controls | Hyprland, Waybar, Rofi, Kitty, Mako, Seven Hub, Seven Files, Tauri prototype, native GTK target |
| Security Layer | hardening, audit, sandbox and cyber workspaces | `security/`, Shield profile, UFW, Firejail, Bubblewrap |
| Compatibility Layer | Windows apps, VM, Wine/Bottles/Lutris/KVM | `profiles/windows.sh`, `bin/seven-windows-assistant`, `vm/windows-mode.sh`, `vm/windows-vm.sh` |
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
- `seven state --json` is the unified machine snapshot for native UI,
  automation and future Seven Server endpoints. It includes Control Plane
  priorities so UI surfaces can show the next best actions without recomputing
  decisions locally.
- `seven actions --json` is the shared action registry for Seven Hub, Waybar,
  Quick Settings and future native surfaces. UI code should prefer action IDs
  over hardcoded command strings when possible.
- `seven actions category <name>` gives focused action sets for small panels
  such as Apps, Security or Desktop.
- Seven Hub runs registered actions through `run_seven_action(action_id)`.
  Direct command execution is kept only as a compatibility path for safe legacy
  buttons and recommendations.
- `seven manifest` is the install/migration contract. It defines future
  package boundaries, protected user paths and restore plans for upgrades.
- `seven ecosystem --json` is the product ecosystem contract. It declares
  modules, maturity states and end-to-end user processes.
- `seven identity --json` is the Beyond the Desktop product language contract. It
  declares principles, profile roles, symbols, stories and future regional
  accent packs so identity can appear in Hub, onboarding and profiles.
- `seven identity packs --json` is the regional accent pack contract. It keeps
  optional cultural variants structured before they become theme modules.
- `seven identity current --json` is the active identity preference contract.
  It records which accent pack the current user selected.
- `seven experience --json` is the OS coherence contract. It scores whether
  identity, shell, Hub, profiles, actions, Windows, security, server and
  installer feel connected enough for a normal user.
- `seven welcome status --json` is the first-run session contract. It checks
  commands, shell files, user services, network, firewall and Windows VM
  services from the point of view of the current user.
- `seven welcome plan --json` is the onboarding remediation contract. It tells
  Seven Hub what must be installed, enabled or repaired before SevenOS feels
  complete after reboot.
- `seven session status --json` is the desktop session runtime contract. It
  exposes login entry, user service files and active session services so SevenOS
  can verify its shell like a real OS session, not loose autostart commands.
- `seven control --json` is the decision contract. It converts readiness,
  first-run, experience, Shield, Server and profile gaps into prioritized
  actions for Seven Hub and future automation.
- `seven control apply` previews those actions first. Execution requires an
  explicit `--apply`, preserving user trust around system-changing operations.
- `seven events --json` is the local event journal for decisions, previews and
  future executed actions.
- `seven insights --json` converts state, trust, profile and control signals
  into product-facing blockers and next actions for Hub and Seven Server.
- `seven phase-gate --json` converts those signals into a transition decision:
  whether SevenOS can move beyond B2, and which trust, backend, installer,
  profile or software gates still block that move.
- `seven stack --json` defines the technology adoption order. It keeps AGS,
  Rust, Python AI, Flutter and Qt in their proper phases instead of letting
  every promising stack enter the system at once.
- `seven shell status --json` and `seven shell plan --json` define the B3 AGS
  shell migration without removing Waybar/Rofi/GTK fallbacks too early.
- `seven core status --json`, `seven core plan --json` and
  `seven core bus --json` define the System Experience Layer foundation. They
  expose SevenBus, the local event journal, daemon scaffold and Core readiness
  to Seven Hub, Seven Server and future Seven Shell surfaces.
- `seven profile gaps --json` is the profile completeness contract. It exposes
  missing packages, unavailable profile apps and install/open commands so
  profiles behave like real work modes.
- `seven profile plan --json` is the prioritized work-mode completion plan.
  Control Plane and Hub should use it when deciding which profile to complete
  first.
- `seven windows status --json` must stay strict JSON. Human success messages
  are forbidden on JSON contracts because Seven Hub and Seven Server depend on
  clean machine-readable output.
- `seven windows plan --json` is the compatibility remediation contract. It
  orders Wine/Bottles, KVM/libvirt, networking and Windows VM creation into a
  guided path for non-terminal users.
- `seven shield status --json` and `seven server status --json` expose trust
  and local API readiness directly, so the Hub does not infer critical state
  from generic status text.
- `seven shield plan --json` is the trust remediation contract. It prioritizes
  firewall, sandbox and audit tooling so Shield becomes an actionable OS layer
  instead of a static security badge.
- `seven server plan --json` is the local backend remediation contract. It
  prioritizes service installation, runtime startup, rootless containers and
  local-only API policy before SevenOS moves toward a personal operating cloud.
- `seven installer plan --json` is the distribution readiness contract. It
  exposes Archinstall, Calamares, Archiso and ISO build gaps before SevenOS
  graduates from post-install layer to installable OS.
- `sevenpkg plan --json` is the software readiness contract. It links
  SevenOS meta-packages, Flatpak, Flathub and future SevenRepo work into one
  app installation plan.
- Seven Server may observe and orchestrate, but remote control stays local-only
  until authentication, TLS and audit logging exist.
- `install.sh` remains the compatibility layer for direct script targets.

## Install And Migration Contract

SevenOS uses `sevenos.dotinst` as the first productization bridge between a Git
repository and future pacman packages or ISO upgrades.

The manifest defines:

- metadata for the SevenOS distribution layer
- component boundaries such as `sevenos-cli`, `sevenos-hyprland`,
  `sevenos-hub`, `sevenos-profiles`, `sevenos-server` and `sevenos-installer`
- user-owned paths that must be preserved during updates
- restore-plan entries for theme/session migrations
- checks that must pass before packaging or publishing

Useful commands:

```bash
seven manifest doctor
seven manifest restore-plan
seven manifest components
seven manifest protected
seven migrate plan
seven migrate backup
```

This keeps SevenOS from becoming a hard overwrite of user dotfiles. The OS can
upgrade its system layer while respecting personal monitor, keyboard, profile
and custom Hyprland state.

`seven migrate backup` creates a timestamped copy of existing protected paths
under `~/.local/share/sevenos/migrations/`. It is the safe pre-upgrade step for
test machines and future packaged releases.

## Interface Strategy

SevenOS must feel like an operating system, not a browser dashboard. The UI
strategy is therefore split into prototype and native target.

| Surface | Role | State |
| --- | --- | --- |
| Rofi Hub | fast command palette and fallback launcher | Active |
| SevenOS Shell | GNOME-like overview, quick settings, scratchpad and polished Hyprland rules | Active |
| Local web Control Center | simple local dashboard for diagnostics | Active |
| Tauri Seven Hub | productization prototype, action workflow and JSON validation | Preview |
| Native Seven Hub | OS Control Center using GTK4 + libadwaita | Active foundation |

Rules:

- Tauri is useful for fast iteration, but it is not the final OS shell model.
- Native Seven Hub should use GTK4 + libadwaita, system portals, notifications,
  file integration and accessibility primitives.
- Both Tauri and native Hub must speak the same SevenOS command/data contracts.
- UI state belongs to SevenOS (`seven`, profile manager, status JSON), not to
  the frontend implementation.
- Web technologies may remain for docs, local dashboards or marketplace
  previews, but core system control must move toward native Linux components.
- Hyprland should feel like an OS shell, not raw tiling. SevenOS keeps an
  Activities-like overview through `seven-overview`, a quick settings surface
  through `seven-quick-settings`, and window rules that make dialogs, audio,
  network and picture-in-picture windows behave predictably.

Native Hub target modules:

```text
seven-hub/native
├── Dashboard  -> readiness, services, repair suggestions
├── First Run  -> welcome status, onboarding plan and post-install blockers
├── Profiles   -> Forge, Shield, Studio, Windows, Horizon activation
├── Actions    -> shared `seven actions --json` registry
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
seven state --json
seven session status --json
seven identity --json
seven identity packs --json
seven identity current --json
seven actions --json
seven architecture matrix
seven architecture matrix --json
seven ecosystem processes
seven ecosystem --json
seven stack --json
seven shell status --json
seven shell plan --json
seven experience
seven experience --json
seven control
seven control --json
seven phase-gate --json
seven profile forge
seven shield status
seven shield plan
seven shield plan --json
seven shield audit
seven windows status
seven windows plan
seven windows plan --json
seven windows guide
seven windows apps
seven windows vm
seven server status
seven server status --json
seven server plan
seven server plan --json
seven installer status --json
seven installer plan
seven installer plan --json
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
