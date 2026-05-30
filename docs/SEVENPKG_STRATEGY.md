# SevenPkg Strategy

SevenOS must not become a visible mix of Arch, Debian, Fedora, openSUSE and
Nix package managers. That would make the system harder to explain, harder to
repair and easier to break.

The stable direction is:

```text
Equinox host stays coherent and Arch-compatible.
SevenPkg is the public package brain.
Mini OS profiles receive specialized packages in isolated rootfs views.
Extra engines are opt-in capabilities, not host defaults.
```

The user-facing contract stays simple:

```bash
seven install blender
sevenpkg install blender
sevenpkg studio install blender
sevenpkg pulse install steam
```

The user should not need to know whether a package comes from pacman, Flatpak,
AUR or a future lab engine. SevenPkg chooses the safest source for the current
domain, shows the impact, then applies through guarded transactions.

## Architecture Decision

SevenOS has seven identities:

```text
Equinox  -> host platform and orchestration layer
Forge    -> development and deployment mini OS
Studio   -> creator mini OS
Shield   -> cybersecurity mini OS
Atlas    -> documents, maps, OCR and research mini OS
Baobab   -> African cultural and educational mini OS
Pulse    -> gaming and performance mini OS
```

Equinox is not a normal workspace. It is the platform that boots, repairs,
updates and coordinates everything else.

Mini OS profiles are where domain-specific tools live. Their installs are
private by default, so Pulse gaming tools do not pollute Studio, Shield tools do
not appear in Baobab, and Forge services do not become global boot noise.

## Source Policy

| Identity | Engine Name | Default Scope | Recommended Sources | Rule |
| --- | --- | --- | --- | --- |
| Equinox | SevenPkg Host Engine | global system | pacman, Flatpak | Keep the host minimal: system components, core apps, shared runtimes and recovery tools only. |
| Forge | Forge Engine | profile rootfs | pacman, AUR helpers | Fresh SDKs, containers, local services and deployment tools stay in Forge. |
| Studio | Studio Engine | profile rootfs | pacman, Flatpak | Prefer stable creative apps and sandboxed desktop runtimes where they improve compatibility. |
| Shield | Shield Engine | profile rootfs | pacman, optional lab engines | Intrusive tools, forensic tools and reproducible labs stay scoped to Shield. |
| Atlas | Atlas Engine | profile rootfs | pacman, Flatpak | Favor reliable document, OCR, map and research tools over novelty. |
| Baobab | Baobab Engine | profile rootfs | SevenOS content, pacman, Flatpak | Cultural content, language packs, archives and offline resources are more important than package novelty. |
| Pulse | Pulse Engine | profile rootfs | pacman, AUR helpers | Gaming runtimes stay current and private to Pulse unless explicitly shared. |

This does not mean SevenOS embeds a full Ubuntu/Fedora/openSUSE system for
each mini OS. The baseline remains the current Arch-compatible rootfs model.
Other engines may appear only when they add real value:

- Nix can be introduced later as a Shield lab engine for reproducible security
  environments.
- Flatpak can be preferred for mainstream desktop apps with stronger sandboxing
  or better upstream packaging.
- AUR helpers remain opt-in and profile-scoped.
- AppImage or vendor installers stay explicit and visible.

## Equinox Rule

Equinox should stay boring in the best sense: stable, recoverable and small.

Allowed in Equinox:

- Seven Core, Seven Shell, Settings, Files, Store and installer tooling
- drivers, portals, network, audio, theme and session components
- recovery, update, backup and rollback tooling
- shared runtimes that are deliberately exposed by policy

Avoid in Equinox:

- heavy creator suites
- gaming launchers and Proton stacks
- intrusive security tools
- development databases and cloud daemons
- random user apps installed globally because they were convenient

If an Equinox package must be visible inside a mini OS, use the explicit global
package policy:

```bash
sevenpkg global-expose <package> --profiles forge --commands <command>
sevenpkg global-restrict <package>
sevenpkg global-policy <package>
```

## SevenPkg Catalog Direction

The next step is a domain catalog. Each app should declare a natural owner and
preferred sources:

```yaml
name: blender
domain: studio
recommended_source: pacman
alternatives: [flatpak]

name: wireshark
domain: shield
recommended_source: pacman
notes: requires authorized scope for capture workflows

name: steam
domain: pulse
recommended_source: pacman
requirements: [multilib]
```

Then:

```bash
seven install blender
```

can become:

```text
Blender belongs to Studio.
Recommended source: pacman.
Impact: large creative app.
Install into Studio? yes/no
```

This keeps SevenOS public-friendly while preserving technical control.

## Commands

Use these commands to inspect the current strategy:

```bash
sevenpkg strategy
sevenpkg strategy --json
sevenpkg profile-limits
sevenpkg profile-sources forge
sevenpkg forge sources
sevenpkg global-policy
```

Use these commands for actual package work:

```bash
sevenpkg studio install blender --source pacman
sevenpkg pulse install steam --source pacman
sevenpkg shield install wireshark-qt --source pacman
sevenpkg forge install code --source pacman
```

The ideal long-term public UI is Seven Store. It should call the same SevenPkg
strategy and present engines as SevenOS concepts, not raw backend names.

