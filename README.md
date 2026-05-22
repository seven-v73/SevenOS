# SevenOS

SevenOS is an experimental intelligent Linux distribution focused on context-aware mini OS profiles, security tooling, creative production, Windows compatibility, local deployment, and the Beyond the Desktop product identity. It uses an Arch-compatible foundation and a Wayland compositor stack as implementation layers, while normal users operate the system through SevenOS surfaces first.

This repository is currently in **Phase B2 — product consolidation before ISO**. It contains the post-install OS layer, Seven Hub Native, `seven`/`sevenpkg`, profile contracts, an app-first Windows compatibility layer, identity assets, Seven Server/Deploy foundations, Seven Shell AGS planning, repair planning, a persistent wallpaper/session runtime, and an early SevenOS live profile.

It is **not yet a complete standalone distribution**. The next major gate is **B3**, blocked until trust, server, installer and profile completeness improve.

## Vision

SevenOS aims to become a futuristic intelligent Linux ecosystem for productivity, creation, cybersecurity, Windows compatibility, deployment, personal cloud workflows, and digital sovereignty.

The main long-term reference is:

```text
docs/SYSTEM_EXPERIENCE_LAYER.md
```

That document defines SevenOS as a **system experience layer above Linux and
Arch**, not merely as a themed distribution.

It is built around foundation pillars:

- `seven` as the system controller
- `sevenpkg` as the package and application manager
- `seven about` as the public identity and edition contract for About screens,
  Settings, Hub and installer surfaces
- `seven about doctor` as the gate that validates this public identity before
  release-facing surfaces rely on it
- `seven lifecycle` as the SevenOS-first maintenance contract for updates,
  repair, protected state, recovery and release gates
- `seven update` as the SevenOS-first update surface above pacman, Flatpak,
  AUR helpers and profile bundles
- `seven recovery` as the SevenOS-first recovery route for protected state,
  backups, repair and installer/recovery gates
- `seven health` as the daily SevenOS health surface above product, lifecycle,
  update, recovery, foundations, distribution and service diagnostics
- `seven smoke` as the fast public-product gate for Hub, Settings and release
  flows, before running the full developer UX audit
- `seven support` as the local-first support route for health, product,
  recovery, events and optional diagnostic bundles without automatic upload
- `seven product` as the compact public product facade for Hub, Settings,
  Welcome and installer surfaces
- `seven foundations` as the SevenOS ownership map that links public surfaces
  to their technical foundations without making backend tools the first user
  workflow
- `sevenos.dotinst` as the install, restore, migration and packaging contract
- Seven Hub as the user-facing control center
- SevenOS Settings as the normal-user configuration center for wallpaper, displays, Wi-Fi, sound, keyboard, security, profiles, apps and system repair
- Seven Server and Seven Deploy as the service/deployment foundation
- Seven Core and SevenBus as the system experience layer foundation
- Seven Context Engine as the semantic workflow layer above raw processes/windows
- Seven Scheduler as the safe user-space process policy layer above Linux CFS
- Windows App Layer as the app-first compatibility path before optional VM fallback
- Calamares/Archinstall as the install path foundation
- GTK/libadwaita as the native Seven Hub direction
- Tauri as a prototype/fallback for GUI experiments
- Seven Shell as the AGS + TypeScript shell direction for B3
- Flatpak/Flathub as the mainstream application bridge
- Seven Ecosystem as the roadmap for AI, cloud, marketplace, containers, automation, and identity modules
- `seven autonomy` as the distribution-autonomy contract that keeps Arch,
  Hyprland, pacman and service internals behind SevenOS-first surfaces.
- `seven platform` as the public vocabulary map for SevenOS Software, Seven
  Smart Window System, SevenOS Session, Mini OS Runtime, Installer, Seven Core
  and Windows Bridge.
- `seven mask` as the public masking contract that verifies launcher names,
  installer portals, software surfaces and identity files present SevenOS before
  backend implementation details.
- `seven dynamic` as the adaptive OS contract that verifies profile UI,
  semantic context, theme runtime, wallpaper palette and compositor accents move
  together.
- `seven surfaces` as the public surface contract that verifies normal workflows
  have SevenOS-native entrypoints before terminal or backend fallbacks.
- `seven routes` as the user-intent routing contract that maps normal tasks to
  SevenOS surfaces and actions before backend implementation tools.
- `seven distribution` as the top-level distribution contract across autonomy,
  public masking, dynamic UI, surfaces, routes, release channel and installer
  readiness.
- `seven channel` as the product release channel contract, so Hub and Settings
  can say dev/testing/stable before exposing branch, commit and dirty worktree
  details.
- `seven foundations` as the foundation ownership contract, so Hub, Settings
  and Doctor can say SevenOS Software, Seven Smart Window System, SevenOS Shell,
  Mini OS Runtime, Shield, Windows Bridge and Lifecycle before showing pacman,
  Hyprland, Waybar, libvirt or systemd.

SevenOS aims to provide:

- a lightweight Arch Linux foundation
- a Wayland desktop based on Hyprland
- modular profiles for development, cybersecurity, and creation
- context-aware orchestration that understands Forge DevOps, Studio, Shield, Windows, Pulse and Streaming workflows
- Windows application compatibility through Wine, Bottles, Proton/Lutris, and optional KVM/QEMU fallback
- local deployment through `seven-server` and `seven-deploy`
- future intelligent modules such as SevenAI, SevenCloud, SevenStore, SevenBox, SevenFlow, and SevenIdentity
- a Seven Hub control center
- a future Seven Shell layer for AGS panels, launcher, dock and widgets
- a premium dark glass identity with Seven Blue, Seven Violet, Seven Cyan, Cyber Green, contextual AI and subtle cinematic depth
- a vocabulary and workflow model that makes Linux easier to live with
- an action runner that prefers native logs and notifications over visible
  terminal windows for normal Hub/Settings workflows

## Current Product State

SevenOS is not packaged as a standalone ISO yet. The current focus is making the
post-install OS layer reliable enough to test on real hardware before moving to
Calamares/Archiso distribution work.

What is already testable:

- `seven` as a unified system controller.
- `seven about` as a SevenOS-first About surface with edition, active mini OS,
  channel and distribution state.
- `seven lifecycle` as a SevenOS-first maintenance surface for update, repair,
  restore/protection, installer and release workflows.
- `seven product` as a compact SevenOS product snapshot for native surfaces.
- `sevenpkg` as the SevenOS software layer over pacman/meta-packages.
- Seven Hub / Control Center entrypoints.
- Native SevenOS Settings for daily desktop and system configuration.
- Forge DevOps, Shield, Studio, Windows and Pulse profile contracts.
- CyberSpace and Shield workspace foundations.
- Seven Core, SevenBus and SevenDaemon foundations.
- Seven Server local API foundation.
- App-first Windows compatibility through `seven run <app>`.
- Persistent Hyprpaper wallpaper runtime through `seven-wallpaper serve`.
- Distribution autonomy checks through `seven autonomy` and
  `docs/DISTRIBUTION_AUTONOMY.md`.
- Public masking checks through `seven mask`, so Hub/Settings can distinguish a
  SevenOS-first surface from a backend-visible Arch/Hyprland workflow.
- Dynamic adaptation checks through `seven dynamic`, linking profile UI,
  wallpaper colors, theme runtime and the Hyprland dynamic layer.
- Public surface checks through `seven surfaces`, covering Hub, Settings, Store,
  Files, Reader, Terminal, Launchpad, Spotlight, Shield, Windows and Doctor.
- User-intent route checks through `seven routes`, so install, repair, network,
  mini OS, Windows and window-management tasks stay SevenOS-first.
- Top-level distribution checks through `seven distribution`, distinguishing a
  daily-driver SevenOS distribution from a public ISO release candidate.
- Release channel/status checks through `seven channel`, `seven release` and
  `seven-installer status --json`.
- Calamares runtime source checks through `seven installer runtime`, keeping
  the graphical ISO gate explicit instead of silently assuming a package source.

The current quality gate remains:

```bash
./scripts/design-check.sh
./scripts/ux-check.sh
./scripts/check.sh
```

## Inspirations And References

SevenOS is not a fork of these projects. It studies their public architecture,
UX patterns and tooling choices to build an independent next-generation Linux
ecosystem.

| Project | Link | What SevenOS Learns From It |
| --- | --- | --- |
| Arch Linux | [archlinux.org](https://archlinux.org/) / [GitLab](https://gitlab.archlinux.org/archlinux) | Minimal base, rolling package ecosystem, pacman workflow and distribution discipline. |
| Archiso | [github.com/archlinux/archiso](https://github.com/archlinux/archiso) | Live ISO structure, profile overlays and reproducible image building. |
| Hyprland | [github.com/hyprwm/Hyprland](https://github.com/hyprwm/Hyprland) | Modern Wayland compositor foundation, tiling, animations, workspaces and window rules. |
| end-4 dots-hyprland | [github.com/end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) | Shell-like Hyprland UX: overview, quick controls, polished window rules and GNOME-like ergonomics. |
| ML4W dotfiles | [github.com/mylinuxforwork/dotfiles](https://github.com/mylinuxforwork/dotfiles) | Mature dotfile installation logic, protected restore paths, modular desktop configuration and update discipline. |
| Calamares | [github.com/calamares/calamares](https://github.com/calamares/calamares) | Future graphical installer direction for a real SevenOS installation flow. |
| Tauri | [github.com/tauri-apps/tauri](https://github.com/tauri-apps/tauri) | Lightweight native app shell used for the current Seven Hub GUI prototype. |
| GTK / Libadwaita | [gitlab.gnome.org/GNOME/libadwaita](https://gitlab.gnome.org/GNOME/libadwaita) | Native Linux control-center direction, accessibility and GNOME-class application behavior. |
| Flatpak | [github.com/flatpak/flatpak](https://github.com/flatpak/flatpak) | Sandboxed app delivery and mainstream Linux application ecosystem through Flathub. |
| Bottles | [github.com/bottlesdevs/Bottles](https://github.com/bottlesdevs/Bottles) | User-friendly Windows compatibility environments over Wine. |
| QEMU | [gitlab.com/qemu-project/qemu](https://gitlab.com/qemu-project/qemu) | Future Windows Mode virtualization foundation with KVM and VirtIO. |

SevenOS keeps its own product direction:

- Beyond the Desktop identity, not generic theme stacking.
- `seven` as the system control plane.
- `sevenpkg` as the software layer.
- Seven Hub as the user-facing control center.
- Profiles for Forge DevOps, Shield, Studio, Windows and Pulse workflows.
- Migration and packaging contracts through `sevenos.dotinst`.

## Why Beyond The Desktop?

SevenOS treats visual identity as product architecture, not as decoration.

The point is to build a Linux ecosystem shaped by fluidity, transparency,
intelligent minimalism, depth, contextuality and visible security:

- fluidity: shell motion and shortcuts make the system feel alive
- transparency: Hyprland blur and translucent layers create spatial hierarchy
- intelligent minimalism: useful features are exposed without procedural clutter
- depth: glow, glass and gradients give SevenOS a premium OS signature
- contextuality: profiles, SevenAI and Shield tune actions to the current work
- visible security: cyber signals stay observable without becoming noisy

The visual language supports this direction through profile roles, reusable
symbols, cinematic glass surfaces and optional future accent packs. It should
never become a collage of flags or motifs.

Useful identity commands:

```bash
seven identity
seven identity --json
seven identity packs
seven identity packs --json
seven identity current
seven identity current --json
seven identity activate pan-african
seven identity plan
seven identity doctor
seven identity doctor --json
```

## Current Status

Implemented:

- repository structure
- base installer entrypoint
- modular profile scripts
- package manifests
- SevenOS install manifest with protected user paths
- Hyprland, Waybar, Rofi, Kitty, Mako and Hyprpaper configuration
- Seven Hub Native GTK/libadwaita foundation
- Seven Hub Tauri GUI prototype
- `seven` system controller
- `sevenpkg` package/application manager
- `seven state --json` unified machine state
- `seven phase-gate --json` B2 -> B3 transition contract
- `seven b3 status`, `seven b3 plan --json` and `seven b3 apply` as the B2 -> B3 consolidation orchestrator
- B3 phase targets documented in [`docs/B3_CONSOLIDATION.md`](docs/B3_CONSOLIDATION.md)
- `seven stack --json` stack discipline contract
- `seven shell status --json` and `seven shell plan --json` AGS shell migration contracts
- `seven core status --json`, `seven core plan --json` and `seven core bus --json` system experience contracts
- `seven context status --json` semantic workflow detection for a context-aware Linux platform
- `seven context emit` SevenBus event bridge for the detected workflow context
- `seven core observe --json` daemon-facing one-shot context observation
- `seven core install-service` installs both SevenDaemon and the context observer user services
- `seven scheduler status --json` context-aware process grouping above Linux CFS
- `seven-daemon` Rust runtime scaffold with a user service path through `seven core install-service`
- `seven-context-observer.service` for continuous local semantic context observations
- Rust-backed SevenBus event emission through `seven-daemon emit`, with Bash fallback kept for compatibility
- daemon-native SevenBus state snapshots through `seven core snapshot --json`, backed by typed Rust JSON parsing
- daemon-native event list and summary reads through `seven-daemon events` and `seven-daemon summary`
- daemon-native runtime health through `seven core health --json`, reading `/proc`, session and event integrity from Rust
- daemon-native profile inventory through `seven core profiles --json`, the first step toward moving profile state out of Bash
- daemon-native Shield posture through `seven-daemon shield --json` / `shield-plan --json`, so trust state is no longer only script-owned
- daemon-native Server readiness through `seven-daemon server --json` / `server-plan --json`, moving the local backend contract into Seven Core
- daemon-native Windows Mode readiness through `seven-daemon windows --json` / `windows-plan --json`, keeping the guided assistant as the UX layer
- daemon-native Installer readiness through `seven-daemon installer --json` / `installer-plan --json`, keeping destructive install actions outside the runtime
- daemon-native software readiness through `seven-daemon packages --json` / `packages-plan --json`, while `sevenpkg` remains the user-facing package/app command
- daemon-native product diagnosis through `seven-daemon insights --json`, so Hub can show priorities without waiting on the large Bash state aggregator
- daemon-native phase transition gate through `seven-daemon phase-gate --json`, while the human phase gate keeps the full long-form repository audit
- C-boundary SevenBus probe through `sevenbus-probe --json` for future low-level IPC/hardware-adjacent work
- `seven architecture` product/system architecture map
- `seven repair` guided repair planner
- `seven ecosystem` innovation roadmap
- `seven manifest` install, restore and package-boundary inspector
- `seven-server` local API foundation
- `seven-deploy` deployment planner
- `seven-core` foundation with SevenBus schema and `seven-daemon` Rust scaffold
- `systemd/user/seven-daemon.service` and `systemd/user/seven-context-observer.service` integrated with the SevenOS session target
- Seven Shell AGS/TypeScript scaffold
- Calamares installer profile scaffold
- Seven Hub Tauri GUI scaffold
- Flatpak/Flathub bridge with Bottles candidate
- initial Archiso profile and ISO build script
- Beyond the Desktop identity foundation
- active SevenOS accent pack preference
- Windows Mode helper workflow

Not implemented yet:

- full Arch installation automation
- final ISO installer flow
- production-ready Seven Shell AGS desktop
- production-ready Seven Hub settings panels
- automated Windows VM provisioning
- GPU passthrough automation
- real SevenAI/SevenCloud/SevenStore implementations

Current phase gate snapshot:

```text
Phase: B2
Decision: blocked for B3
Passing: user experience foundation
Blocking: readiness, control plane score, Shield trust posture, Seven Server, installer path
Warnings: Windows Mode, profile completeness, software plan, stack readiness
```

Run the live status with:

```bash
seven phase-gate --json
seven b3 status
seven b3 plan --json
seven b3 plan --phase trust
seven b3 doctor
seven stack --json
seven shell plan --json
```

`seven b3 apply` is a preview by default. It only executes when explicitly run
with `--apply`, and it orders the work as trust, backend, profiles, shell, then
installer. This is the preferred path for making SevenOS more OS-like without
turning the project into scattered terminal scripts.

The phase filters let a tester fix one OS layer at a time:

```bash
seven b3 apply --phase trust --limit 4
seven b3 apply --phase backend --limit 4
seven b3 apply --phase profiles --limit 4
```

B3 is considered satisfactory only when these phase targets are met and no
critical/high action remains open:

| Layer | Target |
|-------|--------|
| Trust / Shield | 70% |
| Seven Server backend | 80% |
| Profiles | 70% |
| Seven Shell | 65% |
| Installer foundation | 50% |

## Project Health Commands

Use these before pushing or testing a new machine:

```bash
./scripts/design-check.sh
seven smoke --json | python -m json.tool
seven doctor release --json | python -m json.tool
./scripts/ux-check.sh
./scripts/check.sh
seven phase-gate --json | python -m json.tool
seven b3 plan --json | python -m json.tool
seven state --json | python -m json.tool
seven stack --json | python -m json.tool
seven shell status --json | python -m json.tool
seven shell plan --json | python -m json.tool
seven windows resolve photoshop --json | python -m json.tool
seven-wallpaper status
```

Expected current truth:

```text
SevenOS is coherent enough for test machines.
SevenOS is not yet ready to be presented as a final standalone distro.
Seven Shell is planned/foundation, not active replacement.
AGS is prepared but not mandatory until the runtime workflow is settled.
```

## Repository Layout

```text
SevenOS/
├── install.sh
├── bootstrap.sh
├── profiles/
│   ├── dev.sh
│   ├── cybersecurity.sh
│   ├── creation.sh
│   ├── windows.sh
│   └── all.sh
├── hyprland/
│   ├── hyprland.conf
│   ├── waybar/
│   └── rofi/
├── identity/
│   ├── README.md
│   ├── palette.sh
│   └── wallpaper/
├── scripts/
│   ├── lib.sh
│   ├── packages-base.txt
│   ├── packages-dev.txt
│   ├── packages-cybersecurity.txt
│   ├── packages-creation.txt
│   └── packages-windows.txt
│   └── packages-windows-aur.txt
├── vm/
├── security/
├── docs/
│   ├── VISION.md
│   ├── PRODUCT_STRATEGY.md
│   ├── UX_PRINCIPLES.md
│   └── VOCABULARY.md
├── seven-hub/
│   ├── bin/
│   ├── install.sh
│   └── seven-hub.desktop
├── seven-shell/
│   └── ags/
└── archiso/
    └── profile/
```

## Requirements

- Arch Linux or Arch-based system
- `pacman`
- `sudo`
- internet connection
- 8 GB RAM minimum, 16 GB recommended
- CPU virtualization support for future VM workflows

## Product Direction

Start here before making strategic changes:

- `docs/ARCHITECTURE.md`
- `docs/SYSTEM_EXPERIENCE_LAYER.md`
- `docs/CONTEXT_ENGINE.md`
- `docs/SCHEDULING.md`
- `docs/CYBERSPACE.md`
- `docs/WINDOWS_APP_LAYER.md`
- `docs/VISION.md`
- `docs/PRODUCT_STRATEGY.md`
- `docs/UX_PRINCIPLES.md`
- `docs/VOCABULARY.md`
- `docs/OS_CRITERIA.md`
- `docs/ECOSYSTEM.md`
- `docs/STACK_STRATEGY.md`
- `docs/DEPLOYMENT.md`
- `docs/PHASE_GATE.md`
- `docs/B3_CONSOLIDATION.md`
- `docs/PRIMARY_PC.md`
- `docs/TEST_MACHINE.md`
- `docs/PRE_PUSH.md`

SevenOS is guided by one product question:

> Does this make Linux more sovereign, more fluid, more culturally coherent,
> and easier to live with every day?

Its architecture is checked by:

```bash
seven architecture
seven architecture doctor
```

## Usage

For a complete test-machine flow, use:

```text
docs/TEST_MACHINE.md
```

Before pushing a phase to GitHub, use:

```text
docs/PRE_PUSH.md
```

Clone the repository:

```bash
git clone https://github.com/seven-v73/SevenOS.git
cd SevenOS
```

Install the base desktop layer:

```bash
chmod +x install.sh bootstrap.sh profiles/*.sh
./install.sh base
```

Do not run `sudo ./install.sh ...`. The installer must run as your normal user;
it asks for `sudo` internally only when needed.

The base layer installs packages, SevenOS branding, `seven`, `sevenpkg`, the desktop theme, Kitty polish, terminal country signals, and the wallpaper.
`sevenosctl` remains available only as a legacy compatibility helper.

Install a profile:

```bash
./install.sh dev
./install.sh cybersecurity
./install.sh cyber-audit
./install.sh cyber-lab --name webapp
./install.sh creation
./install.sh windows
./install.sh security
./install.sh cli
./install.sh branding
./install.sh theme
./install.sh hub
./install.sh iso-tools
./install.sh vm-check
./install.sh vm-network
./install.sh blackarch-setup --dry-run
./install.sh installer-plan
./install.sh installer-check
./install.sh installer-script
./install.sh server
./install.sh installer-stack
./install.sh hub-gui-stack
./install.sh flatpak status
./install.sh flatpak setup
```

Check whether the current host is ready for SevenOS features:

```bash
./install.sh doctor
./install.sh post-install
```

Show the current SevenOS installation status:

```bash
./install.sh status
seven status
seven post-install
seven welcome
seven welcome status --json
seven welcome plan
seven welcome plan --json
seven session status
seven session status --json
seven hub
seven dashboard
seven architecture
seven architecture doctor
seven installer status
seven installer status --json
seven installer plan
seven installer plan --json
seven installer doctor
seven-daemon packages --json
seven-daemon packages-plan --json
seven-daemon insights --json
seven hub-gui status
seven hub-gui doctor
seven flatpak status
seven ecosystem
seven ecosystem processes
seven ecosystem --json
seven ecosystem roadmap
seven stack
seven stack --json
seven stack doctor
seven shell
seven shell status --json
seven shell plan
seven shell preview
seven experience
seven experience --json
seven control
seven control --json
seven control apply --limit 5
seven events
seven events --json
seven insights
seven insights --json
seven phase-gate --json
seven shield status
seven shield status --json
seven readiness
seven primary
seven primary --json
seven migrate-ml4w plan
seven migrate-ml4w switch
seven keyboard status
seven keyboard apply
seven daily
seven daily --json
seven daily plan
seven phase-gate
seven repair
seven repair ux --apply
seven doctor fix
seven improve
seven improve security --apply --yes
seven windows status
```

Install everything:

```bash
./install.sh all
```

Preview without installing packages:

```bash
./install.sh dev --dry-run
```

Run local checks:

```bash
./scripts/check.sh
seven smoke doctor
seven doctor release
./scripts/ux-check.sh
./scripts/phase-gate.sh
./scripts/post-install.sh
```

Build a live ISO:

```bash
./install.sh iso-tools
./install.sh iso
```

Preview the ISO build commands:

```bash
./install.sh iso --dry-run
```

Check VM readiness:

```bash
./install.sh vm-check
```

Start the libvirt default network:

```bash
./install.sh vm-network
```

Preview a Windows VM creation command:

```bash
./install.sh vm-windows \
  --iso /path/to/windows.iso \
  --virtio-iso /path/to/virtio-win.iso \
  --os win11 \
  --dry-run
```

Create a non-destructive installation plan:

```bash
./install.sh installer-plan
./install.sh installer-check
./install.sh installer-script
```

The installer plan currently covers disk target, hostname, user, LUKS, filesystem, bootloader, timezone, locale, keymap, swap strategy, and SevenOS profiles.

Launch Seven Hub after installing it:

```bash
seven hub
seven-hub
```

`seven hub` and `seven-hub` open the native GTK/libadwaita Control Center when
the graphical stack is available. The Rofi/terminal command palette remains
available as `seven-hub menu` or by opening a focused category such as
`seven-hub Profiles`.

## Identity

SevenOS uses the Beyond the Desktop identity system: Deep Void backgrounds, translucent glass surfaces, Seven Blue for primary interaction, Seven Violet for identity depth, Seven Cyan for active focus, and Seven Green for cyber/security signals.

The identity source of truth lives in `identity/README.md`.

The current desktop theme uses transparent minimal surfaces with frosted liquid glass accents, SevenOS SVG icons, and a
rendered wallpaper applied through Hyprpaper.

The wallpaper runtime is intentionally managed as a persistent user service:

```bash
seven-wallpaper status
seven-wallpaper refresh
systemctl --user status sevenos-wallpaper.service
```

If the desktop becomes black after a theme update, refresh the session layer:

```bash
./install.sh theme
systemctl --user daemon-reload
systemctl --user restart sevenos-wallpaper.service
seven-wallpaper status
```

For the complete icon experience, install the base profile package set, which includes `ttf-jetbrains-mono-nerd`.

The theme layer also writes GTK and Qt preferences so file manager windows,
settings dialogs, Rofi, Waybar, Kitty, Mako, and Seven Hub stay aligned with
SevenOS Design System v1 instead of falling back to disconnected toolkit themes.

SevenOS provides `seven`, the main CLI for daily system control:

```bash
seven status
seven welcome
seven welcome status --json
seven welcome plan --json
seven session status --json
seven hub
seven dashboard
seven architecture
seven architecture doctor
seven readiness
seven phase-gate
seven phase-gate --json
seven ecosystem
seven ecosystem roadmap
seven stack
seven shell
seven server status
seven server status --json
seven server plan
seven server plan --json
seven deploy ./my-project
seven improve
seven improve daily --apply --yes
seven doctor
seven profile forge
seven profile list
seven profile status
seven profile bootstrap all
seven profile gaps
seven profile gaps --json
seven profile plan
seven profile plan --json
seven shield status
seven shield plan
seven shield plan --json
seven shield audit
seven files
seven files menu
seven-power
sevenpkg meta
sevenpkg status
sevenpkg plan
sevenpkg plan --json
sevenpkg info shield
sevenpkg install forge
```

`seven` is the main SevenOS system controller. `sevenpkg` is the package and
application manager over pacman, paru, SevenOS meta-packages, and future
SevenRepo packages. See `docs/package-manager.md`.

Desktop controls:

```bash
seven hub
seven hub-native status
seven-control-center open
seven-hub
seven-hub menu
seven-files
seven-files menu
seven-power
seven-power lock
```

`seven hub` and `seven-hub` are the main OS-native Hub entrypoints. They prefer
the GTK/libadwaita Hub and fall back to the keyboard-first command palette
organized into focused spaces: Dashboard, Profiles, Cyber, Desktop,
VM & Windows, Server & Deploy, Ecosystem, Installer, and Apps.

If the graphical dashboard cannot open a browser, it prints the local URL and
falls back to the `seven-hub menu` command palette.

`seven files` opens the SevenOS file experience. It prefers Nautilus for a
polished Wayland desktop and falls back to other file managers or `xdg-open`.
The base layer installs GVfs, archive support, network shares, phone mounting,
recent files, trash support, and quick previews.

Apply only the desktop theme:

```bash
./install.sh theme
```

## Profiles

### DEV

Installs development tools such as Git, Node.js, Python, Rust, Docker, Helix, Neovim, and VS Code-compatible tooling where available.

### CYBERSECURITY

Installs a broad official Arch cybersecurity layer:

- core network, web, cracking, and exploitation tools
- forensic analysis tools
- reverse engineering tools
- wireless testing tools
- sandbox and isolation helpers

Audit the current machine:

```bash
./install.sh cyber-audit
seven shield dashboard
seven shield dashboard --json
seven shield mode
seven shield mode --json
seven-daemon cyberspace --json
seven-daemon cyberspace-plan --json
seven shield workspaces
seven shield context recon
seven shield context web
seven shield hud
seven shield status
seven shield plan
seven shield bootstrap
seven shield workspace --json
seven shield tools
seven shield scope
seven shield scope --json
seven shield report
```

CyberSpace turns Shield into a context-aware mode instead of a simple tools
collection. It maps the cybersecurity workflow into dedicated workspaces:
Recon, Web Pentest, Reverse Engineering, Network, Forensics, Exploitation,
Threat Intel, Logs & Monitoring, and Sandbox. Use `Super+C` to open the
CyberSpace map and `Super+Ctrl+C` to show the Cyber HUD.

Install by category when you do not want the full cyber layer:

```bash
./install.sh cybersecurity core
./install.sh cybersecurity forensics
./install.sh cybersecurity reversing
./install.sh cybersecurity wireless
./install.sh cybersecurity sandbox
```

Open an isolated lab shell:

```bash
seven shield lab --preset web
seven shield lab --preset forensics
seven shield lab --preset reversing
```

The lab uses a private Firejail home and may show a prompt such as
`sevenos-webapp`. Type `exit` to return to your normal SevenOS shell before
running general `seven` commands.

SevenOS also provides an optional BlackArch bridge for specialized tools:

```bash
./install.sh blackarch-setup --dry-run
./install.sh blackarch-setup --yes
./install.sh blackarch-category webapp
./install.sh blackarch-tool feroxbuster
```

BlackArch is opt-in because it adds an external package repository. SevenOS should stay stable for daily use, then scale up when deeper security work is needed.

Use responsibly and only on systems and networks where you have permission.

## Daily Driver Gate

Before installing SevenOS on a primary PC, use the daily driver gate:

```bash
seven primary
seven primary --json | python -m json.tool
seven daily
seven daily --json | python -m json.tool
```

`seven primary` is the user-facing gate for a real workstation. It aggregates
readiness, Shield/security, profiles, Windows Mode, Seven Server, Seven Core and
Flatpak app delivery into one verdict. The recommended consolidation path is:

```bash
sudo -v
seven primary apply
seven primary
```

The installer entrypoint is:

```bash
sudo -v
./install.sh daily-driver --yes
seven primary
```

SevenOS should reach at least 90% readiness, 70% Shield/security and 70% role
profile coverage before replacing an existing primary workstation.

See `docs/PRIMARY_PC.md` for the full stop conditions and recovery checks.

### CREATION

Installs creative tools such as GIMP, Krita, Inkscape, Blender, Kdenlive, OBS Studio, and audio/video utilities.

DaVinci Resolve is not installed automatically because it is not distributed through the official Arch repositories.

### WINDOWS

Installs compatibility tools such as Wine, Winetricks, Lutris, Flatpak, QEMU, and Virt Manager.

The installer configures Flathub, installs Bottles through Flatpak when possible, enables `libvirtd`, and adds the current user to the `libvirt` group.

Windows Mode is exposed as a guided user flow:

```bash
seven run photoshop
seven windows catalog
seven windows resolve photoshop --json
seven windows run /path/to/setup.exe
seven windows guide
seven windows status
seven windows status --json
seven windows plan
seven windows plan --json
seven windows apps
seven windows vm
```

SevenOS now treats Windows compatibility as an app-first layer:

- Wine for direct `.exe` / `.msi` launching.
- Bottles for accessible non-terminal app bottles.
- Proton / Lutris for games.
- KVM/QEMU only as the optional fallback for heavy apps or full Windows sessions.

The resolver exposes a machine-readable contract for Seven Hub, Seven Shell and
SevenDaemon:

```bash
seven windows catalog --json | python -m json.tool
seven windows resolve photoshop --json | python -m json.tool
SEVENOS_DRY_RUN=1 seven run photoshop
```

This lets SevenOS decide whether an app should use Wine, Bottles, Proton/Lutris
or the optional VM path without forcing users to download a Windows ISO first.

VM creation still needs a user-provided Windows ISO and, for best
storage/network support, the VirtIO driver ISO. SevenOS does not download or
redistribute Windows images:

```bash
./install.sh vm-check
./install.sh vm-network
seven windows create \
  --iso /path/to/windows.iso \
  --virtio-iso /path/to/virtio-win.iso \
  --os win11
```

Use `--os win10` for a Windows 10 VM.

### SECURITY

Installs a base hardening layer with UFW, Firejail, Bubblewrap, OpenSSH, GnuPG, KeePassXC, rkhunter, and Lynis.

The installer enables UFW with denied incoming traffic and allowed outgoing traffic by default.

### SEVEN HUB

Installs the SevenOS Control Center dashboard plus the Rofi command palette.
Both expose the same installer and `seven` actions as the CLI: status, doctor,
base, profiles, Windows compatibility, security hardening, deployment status,
theme repair, and dry-run preview.

Windows VM provisioning and GPU passthrough will be handled in later phases.

## Roadmap

### Phase 1

- Arch post-install scripts
- Hyprland desktop layer
- modular profiles
- package manifests
- first reproducible Git workflow

### Phase 2

- Seven Hub MVP
- profile launch actions
- Windows and VM launch actions
- dry-run installation preview

### Phase 3

- Archiso integration
- live SevenOS ISO profile
- non-destructive installer planning TUI
- installer flow

### Phase 4

- complete distribution packaging
- release channel
- hardware validation

### Phase 5

- SevenOS ecosystem
- app store
- cloud services
- deeper Windows integration

## License

SevenOS is licensed under the MIT License. See `LICENSE`.
