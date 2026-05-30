# SevenOS Package Manager

SevenOS uses two complementary commands:

- `seven` is the system controller.
- `sevenpkg` is the package and application manager.

This keeps system operations separate from software installation.

The vocabulary and product rules for these commands live in:

- `docs/VISION.md`
- `docs/PRODUCT_STRATEGY.md`
- `docs/VOCABULARY.md`
- `docs/SEVENPKG_STRATEGY.md`

## seven

`seven` orchestrates SevenOS profiles, security, Windows app compatibility,
status checks, and high-level automation.

Examples:

```bash
seven update
seven doctor
seven status
seven hub
seven profile forge
seven profile shield
seven profile studio
seven shield enable
seven shield audit
seven windows run setup.exe
seven install blender --profile studio
```

## sevenpkg

`sevenpkg` is the SevenOS package brain. It exposes one public install/remove
language while keeping Equinox and the mini OS profiles on the right side of the
stability boundary.

The rule is:

```text
Equinox stays stable and minimal.
Mini OS profiles receive specialized packages in private rootfs views.
SevenPkg chooses and explains the source instead of exposing backend chaos.
```

`sevenpkg` is currently a SevenOS layer over:

- `pacman`
- `paru` or `yay`, when available
- Flatpak app flows
- SevenOS meta-packages
- future SevenRepo packages

`seven software ...` and `seven pkg ...` are friendly aliases for the same
software layer.

Examples:

```bash
sevenpkg install blender
sevenpkg remove blender
sevenpkg update
sevenpkg search blender
sevenpkg catalog blender
sevenpkg resolve blender
sevenpkg info forge
sevenpkg meta
sevenpkg status
sevenpkg doctor
sevenpkg owner nmap
sevenpkg plan
sevenpkg plan --json
sevenpkg optional
sevenpkg transaction install forge
sevenpkg transaction install forge --apply --yes
sevenpkg transaction remove blender
sevenpkg history
sevenpkg sources
sevenpkg strategy
sevenpkg strategy --json
seven software transaction install forge
seven pkg optional
```

Preview any command:

```bash
sevenpkg --dry-run install blender
seven --dry-run profile shield
```

Preview a guarded SevenOS transaction:

```bash
sevenpkg transaction install forge
sevenpkg transaction remove nmap
```

Apply one after review:

```bash
sevenpkg transaction install forge --apply --yes
```

SevenPkg uses a local transaction lock, so two package transactions cannot run
at the same time. Use `--wait` if the second transaction should wait:

```bash
sevenpkg transaction update --apply --yes --wait
```

## Meta-Packages

SevenOS meta-packages are declared in `sevenpkg/metapackages.json`.

Current meta-packages:

| Name | Role |
| --- | --- |
| `equinox` | stable host/admin platform for Seven Core, Settings, Store, Files, update and recovery |
| `forge` | DevOps mini OS for code, toolchains, containers, services and deploys |
| `shield` | cybersecurity mini OS for authorized audit, forensics and sandboxing |
| `studio` | creator mini OS for logo, video, audio, 3D and design tools |
| `baobab` | African cultural mini OS for heritage, languages, stories, sound, map, fashion, food, wisdom and offline memory |
| `pulse` | Linux gaming mini OS for Proton, low latency, overlays and performance |
| `atlas` | documents, OCR, maps, references, archives and travel mini OS |
| `griot` | documentation and knowledge toolkit |

Examples:

```bash
sevenpkg install forge
sevenpkg install shield
sevenpkg install studio
sevenpkg install pulse
sevenpkg install atlas
sevenpkg install griot
sevenpkg install baobab --optional
sevenpkg status
sevenpkg plan
sevenpkg optional
sevenpkg info shield
```

Optional packages declared by a mini OS stay visible through
`sevenpkg optional`. This keeps the main plan calm while still showing richer
tools that a user can install intentionally.

## Software Plan

`sevenpkg plan --json` is the machine-readable software readiness contract for
Seven Hub, Seven Server and the Control Plane.

`sevenpkg doctor --json` is the machine-readable health report for the package
manager itself. It checks the manifest, sources, mini OS layers, optional
visibility, transaction journal, transaction lock and removal guard.

`sevenpkg owner <package>` explains which SevenOS layer owns a package before
you install or remove it:

```bash
sevenpkg owner nmap hashcat
sevenpkg owner nmap --json
```

It combines:

- SevenOS meta-package completeness
- pacman availability
- optional `paru` / AUR availability
- Flatpak and Flathub readiness
- default Flatpak app gaps

Human preview:

```bash
sevenpkg plan
```

Machine contract:

```bash
sevenpkg plan --json
```

SevenOS uses this plan to guide app installation without making users reason
about pacman, AUR, Flatpak or future SevenRepo internals.

## App Catalog

SevenPkg uses `sevenpkg/apps.json` to map common apps to their natural SevenOS
domain:

```bash
sevenpkg catalog
sevenpkg catalog blender
sevenpkg resolve blender
seven install blender --preview
sevenpkg footprint
sevenpkg footprint --fast
```

Example: `blender` resolves to Studio, `wireshark-qt` resolves to Shield, and
`steam` resolves to Pulse. This makes public commands simple while keeping
Equinox stable.

JSON previews include `resolved_sources` so graphical surfaces can show the
real route:

```text
blender -> studio -> pacman -> profile-rootfs
bottles -> equinox -> flatpak -> global-system
```

Use `sevenpkg footprint --json` before release or ISO preparation to see rootfs
size, duplication and catalog coverage. Use `sevenpkg footprint --fast --json`
inside quick checks when package structure matters more than byte-size scans.
It keeps the six mini OS views powerful without letting them silently become
heavy.

Install multiple ordinary packages:

```bash
sevenpkg install nmap hashcat wireshark-qt
sevenpkg transaction remove nmap hashcat
```

Removal is guarded. If a package belongs to a SevenOS mini OS layer, SevenPkg
shows the owning profile and blocks the real removal unless `--force` is used.
This prevents accidental damage to Forge, Shield, Studio, Atlas, Pulse, Baobab
or Equinox.

Pass profile-specific arguments to a SevenOS meta-package:

```bash
sevenpkg install shield core
sevenpkg install shield sandbox
```

## Sources

`sevenpkg install <package>` uses source `auto` by default:

1. checks official Arch repositories through `pacman`
2. checks AUR through `paru` when installed
3. reports a clear miss if neither source has the package

Force a source:

```bash
sevenpkg install blender --source pacman
sevenpkg install visual-studio-code-bin --source aur
sevenpkg install brave-bin --source yay
```

`sevenrepo` is reserved for the future SevenOS repository.

## Profile Installs

`sevenpkg` can install packages for one SevenOS profile:

```bash
sevenpkg install --profile forge htop --source pacman
sevenpkg forge install code --source pacman
sevenpkg studio install blender --source pacman
sevenpkg forge sources
sevenpkg pulse update --preview
sevenpkg baobab packages --query foliate
sevenpkg remove --profile forge htop --preview
sevenpkg update --profile forge --preview
sevenpkg install --profile forge visual-studio-code-bin --source paru
sevenpkg forge helper paru
sevenpkg profile-install shield nmap --source pacman --preview
sevenpkg profile-remove shield nmap --preview
sevenpkg install --profile equinox htop --source pacman
sevenpkg profile-limits
sevenpkg profile-limits forge
sevenpkg profile-sources forge
sevenpkg profile-packages forge --query htop
```

Equinox is the system/admin host profile, so its installs use the normal global
Arch-compatible system. This scope should stay small and guarded. Other mini OS
profiles install into their own rootfs with
`seven-profile-run --rootfs-writable`, then verify and reseal the rootfs. Those
packages are private to the target mini OS and are not visible to other mini OS
package views by default.

Equinox host packages are Equinox-only by default unless an explicit global
package policy exposes selected commands to mini OS package views:

```bash
sevenpkg global-policy mongodb
sevenpkg global-expose mongodb --profiles forge --commands mongod mongosh
sevenpkg global-expose mongodb --all-mini-os --commands mongod mongosh
sevenpkg global-restrict mongodb
sevenpkg global-clear mongodb
```

This affects only command visibility from the host package store. Installing the
same package with `sevenpkg forge install mongodb` still creates a private Forge
rootfs install instead.

Long-running daemons can also be attached to one mini OS through user systemd
units that execute inside that profile rootfs:

```bash
sevenpkg profile-service mongodb forge
sevenpkg profile-service mongodb forge --enable --start
sevenpkg profile-service status forge mongodb
sevenpkg profile-service stop forge mongodb
sevenpkg profile-service remove forge mongodb
```

The MongoDB preset stores data under `/profile/data/mongodb`, which maps to the
target mini OS data root, and binds to `127.0.0.1` by default. Use the generic
form for other daemons:

```bash
sevenpkg profile-service create forge api -- node /workspace/server.js
```

The profile-first shortcuts are the easiest syntax for the public workflow:
`sevenpkg forge install code`, `sevenpkg shield install nmap`,
`sevenpkg studio packages --query blender`. Use `sevenpkg forge sources` to see
whether `pacman`, `paru` or `yay` are ready for that mini OS. If the target
rootfs is missing on a new machine, SevenPkg builds it before the
profile-scoped pacman install. AUR packages stay private only when `paru` or
`yay` is available inside the target rootfs; use `sevenpkg <profile> helper
paru` or `sevenpkg <profile> helper yay` to build that helper inside the mini OS
rootfs. SevenPkg installs the rootfs build dependencies, clones the helper from
AUR, builds it with `makepkg` as a normal profile user, installs the built
package through the rootfs admin path, then verifies and reseals the target
rootfs.

When a mini OS is active, concrete package installs default to that mini OS:

```bash
sevenpkg install htop --source pacman
sevenpkg remove htop --preview
sevenpkg update --preview
sevenpkg install --global htop --source pacman
sevenpkg remove --global htop --preview
sevenpkg update --global --preview
```

The unqualified install/remove/update commands target the active mini OS rootfs.
The `--global` commands force the global Equinox/system scope. SevenOS
meta-packages such as `forge` or `shield` keep their normal SevenOS layer
behavior unless `--profile` is explicit.

`sevenpkg profile-limits --json` exposes the machine-readable contract for
installation scope, rootfs readiness and AUR helper availability per profile.
Add a profile name, for example `sevenpkg profile-limits forge --json`, to focus
the output on one mini OS.

`sevenpkg profile-sources forge --json` exposes the same source readiness as a
focused contract for one mini OS. The public shortcut is:

```bash
sevenpkg forge sources
sevenpkg forge sources --json
```

`sevenpkg profile-packages --json` exposes the installed package inventory per
profile. Mini OS profiles read their own rootfs pacman database; Equinox reads
the host pacman database.
